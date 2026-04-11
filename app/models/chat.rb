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

  def needs_assistant_response?
    conversation_messages.ordered.last.role != "assistant"
  end

  def retry_last_message!
    update!(error: nil)

    last_message = conversation_messages.ordered.last

    if last_message.present? && last_message.role == "user"

      ask_assistant_later(last_message)
    end
  end

  def add_error(e)
    update! error: e.to_json
    broadcast_append target: "messages", partial: "chats/error", locals: { chat: self }
  end

  def clear_error
    update! error: nil
    broadcast_remove target: "chat-error"
  end

  def assistant
    @assistant ||= Assistant.for_chat(self)
  end

  def ask_assistant_later(message)
    clear_error
    AssistantResponseJob.perform_later(message)
  end

  def ask_assistant(message)
    assistant.respond_to(message)
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

    msgs = conversation_messages.ordered.limit(10)
    return if msgs.size < 4

    provider = Provider::Registry.for_concept(:llm).providers.first
    return unless provider

    transcript = msgs.map { |m| "#{m.role}: #{m.content}" }.join("\n")
    prompt = "Summarize this conversation in 2-3 sentences, focusing on the key topics and any decisions or preferences expressed:\n\n#{transcript}"

    response = provider.chat_response(prompt, model: Setting.default_ai_model, instructions: "You are a concise summarizer. Return only the summary, no preamble.")
    text = response.data&.messages&.first&.output_text
    update!(summary: text) if text.present?
  rescue => e
    Rails.logger.error("Chat summary generation failed: #{e.message}")
  end
end
