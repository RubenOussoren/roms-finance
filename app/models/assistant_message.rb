class AssistantMessage < Message
  FLUSH_INTERVAL = 0.1 # seconds
  STALL_AFTER = 5.minutes

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

  def calculate_cost
    model_info = RubyLLM.models.find(ai_model)
    return 0 unless model_info

    tokens = RubyLLM::Tokens.new(input: input_tokens || 0, output: output_tokens || 0)
    ((model_info.cost_for(tokens).total || 0) * 100).round # cents
  rescue
    0
  end

  private

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
