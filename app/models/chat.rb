class Chat < ApplicationRecord
  include Debuggable

  belongs_to :user

  has_one :viewer, class_name: "User", foreign_key: :last_viewed_chat_id, dependent: :nullify # "Last chat user has viewed"
  has_many :messages, dependent: :destroy

  validates :title, presence: true

  scope :ordered, -> { order(created_at: :desc) }

  class << self
    def start!(prompt, model:)
      create!(
        title: generate_title(prompt),
        messages: [ UserMessage.new(content: prompt, ai_model: model) ]
      )
    end

    def generate_title(prompt)
      prompt.first(80)
    end
  end

  class RetryUnavailable < StandardError; end

  def needs_assistant_response?
    prompt = latest_explicit_prompt
    prompt.present? && !linked_attempts(prompt).where(status: :complete).exists?
  end

  def response_in_progress?
    messages.where(type: "AssistantMessage", status: :pending).where.not(origin_user_message_id: nil).exists?
  end

  def legacy_context?
    messages.where(type: "UserMessage", conversation_turn: nil).exists? ||
      messages.where(type: "AssistantMessage", origin_user_message_id: nil).exists?
  end

  def retry_last_message!(message_id: nil, recover_interrupted: false)
    created = false
    attempt = with_lock do
      source = if message_id.present?
        messages.find(message_id)
      else
        prompt = latest_explicit_prompt
        linked_attempts(prompt).order(attempt_number: :desc).first if prompt
      end
      unless source.is_a?(AssistantMessage) && source.origin_user_message&.conversation_turn.present?
        raise RetryUnavailable, "This reply has no explicit prompt link. Send a new prompt to continue."
      end

      replacement = source.replacement
      next replacement if replacement
      source.with_lock do
        if source.pending? && recover_interrupted && source.stalled?
          # Explicitly abandon idle output; this does not prove the worker is dead.
          source.update!(status: :failed)
        end
      end
      next source if source.pending?

      inflight = linked_attempts(source.origin_user_message).find_by(status: :pending)
      next inflight if inflight

      # Branch from the latest attempt so one origin has a single replacement chain.
      latest = linked_attempts(source.origin_user_message).order(attempt_number: :desc).first
      if latest.id != source.id
        raise RetryUnavailable, "A newer attempt exists. Retry the latest reply instead."
      end
      created = true
      messages.create!(type: "AssistantMessage", content: "", status: :pending,
        ai_model: source.origin_user_message.ai_model,
        origin_user_message: source.origin_user_message, replaces_message: source,
        attempt_number: source.attempt_number + 1)
    end
    enqueue_attempt(attempt) if created
    attempt
  end

  def add_error(e)
    update! error: e.to_json
    broadcast_update target: "chat-error-container", partial: "chats/error", locals: { chat: self }
  end

  def clear_error
    update! error: nil
    broadcast_remove target: "chat-error"
  end

  def assistant
    @assistant ||= Assistant.for_chat(self)
  end

  def ask_assistant_later(message)
    attempt, created = reserve_initial_attempt(message)
    enqueue_attempt(attempt) if created
    attempt
  end

  # Direct synchronous callers use the same reservation and execution claim as jobs.
  def ask_assistant(message)
    assistant.respond_to(message)
  end

  def reserve_initial_attempt(message)
    unless message.is_a?(UserMessage) && message.persisted? && message.chat_id == id && message.conversation_turn.present?
      raise RetryUnavailable, "Send a new prompt to request a reply; legacy prompts cannot be inferred."
    end
    with_lock do
      existing = linked_attempts(message).find_by(attempt_number: 1)
      next [ existing, false ] if existing
      [ messages.create!(type: "AssistantMessage", content: "", status: :pending,
          ai_model: message.ai_model, origin_user_message: message, attempt_number: 1), true ]
    end
  end

  def authoritative_response_for(prompt)
    linked_attempts(prompt).where(status: :complete).order(attempt_number: :desc).first
  end

  def conversation_messages
    if debug_mode?
      messages
    else
      messages.where(type: [ "UserMessage", "AssistantMessage" ])
    end
  end

  def generate_summary
    return if summary.present?

    # Apply the same explicit-link boundary to summary requests as normal replies.
    msgs = messages.where(type: "UserMessage").where.not(conversation_turn: nil)
      .order(conversation_turn: :asc).limit(10).flat_map do |prompt|
        [ prompt, authoritative_response_for(prompt) ].compact
      end.first(10)
    return if msgs.size < 4

    provider = Provider::Registry.for_concept(:llm).providers.first
    return unless provider

    transcript = msgs.map { |m| "#{m.role}: #{m.content}" }.join("\n")
    prompt = "Summarize this conversation in 2-3 sentences, focusing on the key topics and any decisions or preferences expressed:\n\n#{transcript}"

    response = provider.chat_response(prompt, model: Setting.default_ai_model, instructions: "You are a concise summarizer. Return only the summary, no preamble.")
    text = response.data&.messages&.first&.output_text
    update!(summary: text) if text.present?
  rescue => e
    Rails.logger.error("Chat summary generation failed (#{e.class})")
  end

  private
    def latest_explicit_prompt
      messages.where(type: "UserMessage").where.not(conversation_turn: nil).order(conversation_turn: :desc).first
    end

    def linked_attempts(prompt)
      messages.where(type: "AssistantMessage", origin_user_message_id: prompt.id)
    end

    def enqueue_attempt(attempt)
      clear_error
      job = AssistantResponseJob.perform_later(attempt)
      raise "Enqueue rejected" unless job
    rescue
      attempt.with_lock do
        attempt.update!(status: :failed) if attempt.pending? && attempt.execution_claimed_at.nil?
      end
      add_error(Provider::Error.new("The reply could not be queued. Please retry this reply."))
    end
end
