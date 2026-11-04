class AssistantMessage < Message
  FLUSH_INTERVAL = 0.1 # seconds
  STALL_AFTER = 5.minutes
  SNAPSHOT_SUFFIX = "-([0-9]{4}-[0-9]{2}-[0-9]{2}|[0-9]{8})$".freeze

  # Keep raw provider names in history; normalize only comparisons and reporting.
  def self.base_model_name(name)
    name.to_s.sub(/#{SNAPSHOT_SUFFIX}/, "")
  end

  def model_changed?
    origin_user_message.present? &&
      self.class.base_model_name(ai_model) != self.class.base_model_name(origin_user_message.ai_model)
  end

  belongs_to :origin_user_message, class_name: "UserMessage", optional: true
  belongs_to :replaces_message, class_name: "AssistantMessage", optional: true
  has_one :replacement, class_name: "AssistantMessage", foreign_key: :replaces_message_id

  validates :attempt_number, numericality: { only_integer: true, greater_than: 0 }, if: -> { origin_user_message_id.present? }
  validate :valid_attempt_links

  validates :ai_model, presence: true

  def role
    "assistant"
  end

  def stalled?
    pending? && updated_at.present? && updated_at < STALL_AFTER.ago
  end

  # Every provider write must recheck the durable fence, not an in-memory status.
  def with_pending_execution
    with_lock do
      unless pending? && execution_claimed_at.present?
        @buffer = +""
        next false
      end
      yield
      true
    end
  end

  def previous_version?
    complete? && origin_user_message.present? && chat.authoritative_response_for(origin_user_message)&.id != id
  end

  # The row lock serializes competing deliveries; it is released before provider work.
  def claim_execution!
    with_lock do
      next false unless pending? && execution_claimed_at.nil? && origin_user_message_id.present?
      update!(execution_claimed_at: Time.current)
      true
    end
  end

  def request_response
    return unless origin_user_message&.conversation_turn.present?
    chat.assistant.respond_to(origin_user_message, attempt: self)
  end

  def start_streaming!
    @buffer = +""
    @last_flush = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def append_text!(text)
    with_pending_execution do
      @buffer ||= +""
      @buffer << text
      flush_buffer! if should_flush?
    end
  end

  def flush_buffer!
    with_pending_execution do
      next if @buffer.blank?
      self.content = (content || "") + @buffer
      save!
      @buffer = +""
      @last_flush = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end

  # The dispatched model is explicit: the prompt may have fallen back before
  # dispatch and must not be used to infer pricing. nil means unavailable pricing,
  # distinct from a genuinely free or rounded-zero reply.
  def calculate_cost(dispatched_model: nil)
    return nil if input_tokens.nil? || output_tokens.nil?

    tokens = RubyLLM::Tokens.new(input: input_tokens, output: output_tokens)
    [ ai_model, dispatched_model ].compact.uniq.each do |name|
      total = catalog_cost(name, tokens)
      return (total * 100).round unless total.nil? # cents
    end
    nil
  end

  private

    def catalog_cost(name, tokens)
      catalog_model(name)&.cost_for(tokens)&.total
    rescue StandardError
      # Accounting metadata must not invalidate a successful reply. Try the next
      # name, without logging exceptions that may contain provider data.
      Rails.logger.warn("[AI Chat] Model cost estimate unavailable")
      nil
    end

    def catalog_model(name)
      RubyLLM.models.find(name)
    rescue RubyLLM::ModelNotFoundError
      nil
    end

    def valid_attempt_links
      if origin_user_message_id.present?
        origin = chat.messages.find_by(id: origin_user_message_id, type: "UserMessage")
        errors.add(:origin_user_message, "must be an explicitly ordered prompt in this chat") unless origin&.conversation_turn.present?
        errors.add(:conversation_turn, "is only for user prompts") if conversation_turn.present?
        if attempt_number == 1
          errors.add(:replaces_message, "must be absent on the initial attempt") if replaces_message_id.present?
        elsif attempt_number.present?
          previous = chat.messages.find_by(id: replaces_message_id, type: "AssistantMessage")
          unless previous && previous.origin_user_message_id == origin_user_message_id && previous.attempt_number == attempt_number - 1
            errors.add(:replaces_message, "must be the preceding attempt for the same prompt")
          end
        end
      elsif attempt_number.present? || replaces_message_id.present? || execution_claimed_at.present?
        errors.add(:origin_user_message, "is required for a response attempt")
      end
    end

    def should_flush?
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - (@last_flush || 0)
      elapsed >= FLUSH_INTERVAL
    end
end
