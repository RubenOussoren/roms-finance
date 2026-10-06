class Assistant
  include Provided, Configurable, Broadcastable

  MAX_CONVERSATION_MESSAGES = 20

  attr_reader :chat, :instructions

  class << self
    def for_chat(chat)
      config = config_for(chat)
      new(chat, instructions: config[:instructions], family: config[:family])
    end
  end

  def initialize(chat, instructions: nil, family: nil, functions: [])
    @chat = chat
    @instructions = instructions
    @family = family
    @functions = functions
  end

  def respond_to(message, attempt: nil)
    unless message.is_a?(UserMessage) && message.chat_id == chat.id
      raise Chat::RetryUnavailable, "Send a prompt in this chat to request a reply."
    end
    assistant_message = attempt || chat.reserve_initial_attempt(message).first
    unless assistant_message.is_a?(AssistantMessage) && assistant_message.persisted? &&
        assistant_message.chat_id == chat.id && assistant_message.origin_user_message_id == message.id
      raise Chat::RetryUnavailable, "The reply does not belong to this prompt."
    end
    return assistant_message unless assistant_message.claim_execution!

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    function_instances = select_functions(message.content)

    provider = get_model_provider(message.ai_model)

    # Fallback to default model if requested model isn't available
    if provider.nil? && message.ai_model != Setting.default_ai_model
      provider = get_model_provider(Setting.default_ai_model)
      Rails.logger.warn("AI model '#{message.ai_model}' unavailable, falling back to '#{Setting.default_ai_model}'")
    end

    unless provider
      fail_response(assistant_message, "No AI provider is available. Please check AI configuration in Settings, then retry this reply.")
      return assistant_message
    end

    setup_done = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Rails.logger.info("[AI Chat] Setup took #{((setup_done - started_at) * 1000).round}ms (#{function_instances.size} functions, model=#{message.ai_model})")

    responder = Assistant::Responder.new(
      message: message,
      instructions: instructions,
      function_instances: function_instances,
      llm: provider
    )

    assistant_message.start_streaming!
    first_token_at = nil

    thinking_stopped = false

    responder.on(:output_text) do |text|
      assistant_message.with_pending_execution do
        unless first_token_at
          first_token_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          Rails.logger.info("[AI Chat] TTFT #{((first_token_at - setup_done) * 1000).round}ms (time from API call to first token)")
        end

        unless thinking_stopped
          stop_thinking
          thinking_stopped = true
        end

        assistant_message.append_text!(text)
      end
    end

    responder.on(:response) do |data|
      assistant_message.with_pending_execution do
        stop_thinking unless thinking_stopped
        assistant_message.flush_buffer!

        # Track token usage
        assistant_message.input_tokens = data[:input_tokens] || 0
        assistant_message.output_tokens = data[:output_tokens] || 0
        assistant_message.cost_cents = assistant_message.calculate_cost

        # Persist any tool calls that RubyLLM executed during the conversation
        if data[:tool_calls_log].present?
          data[:tool_calls_log].each do |log_entry|
            assistant_message.tool_calls.build(
              type: "ToolCall::Function",
              provider_id: SecureRandom.uuid,
              provider_call_id: SecureRandom.uuid,
              function_name: log_entry[:function_name],
              function_arguments: log_entry[:arguments].to_json,
              function_result: log_entry[:result]
            )
          end
        end
        assistant_message.save!
      end
    end

    conversation_history = build_conversation_history(message)
    responder.respond(messages: conversation_history)
    assistant_message.with_pending_execution do
      assistant_message.flush_buffer!
      assistant_message.update!(status: :complete)
    end
    assistant_message
  rescue Chat::RetryUnavailable
    raise
  rescue Faraday::TooManyRequestsError
    fail_response(assistant_message, "I'm a bit busy right now. Please retry this reply in a moment.")
  rescue Faraday::UnauthorizedError, Faraday::ForbiddenError
    fail_response(assistant_message, "AI is temporarily unavailable. Please check AI configuration in Settings, then retry this reply.")
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed
    fail_response(assistant_message, "Having trouble connecting to the AI provider. Please retry this reply.")
  rescue
    # Provider exceptions can contain credentials or request bodies; never render them.
    fail_response(assistant_message, "The AI reply could not be completed. Please retry this reply.")
  end

  private
    attr_reader :functions, :family

    def select_functions(message_content)
      if family
        self.class.send(:available_functions, family, message_content)
      else
        functions
      end.map { |fn| fn.new(chat.user) }
    end

    def fail_response(attempt, error_message)
      return unless attempt&.persisted?
      # Match recovery's chat -> attempt lock order. Emit errors only after releasing
      # the attempt lock, and only when this worker actually terminalized its reply.
      chat.with_lock do
        # A failed completion/save may leave dirty attributes on this instance.
        # Reload persisted state before locking; keep the private streaming buffer.
        attempt.reload
        failed = attempt.with_pending_execution do
          attempt.flush_buffer!
          attempt.update!(status: :failed)
        end
        if failed
          stop_thinking
          chat.add_error(Provider::Error.new(error_message))
        end
      end
      attempt
    end

    def build_conversation_history(current_message)
      prompts = chat.messages.where(type: "UserMessage")
        .where("conversation_turn < ?", current_message.conversation_turn)
        .order(conversation_turn: :desc).limit(MAX_CONVERSATION_MESSAGES)

      prompts.to_a.reverse.flat_map do |prompt|
        response = chat.authoritative_response_for(prompt)
        turn = [ { role: prompt.role, content: prompt.content } ]
        turn << { role: response.role, content: response.content } if response
        turn
      end.last(MAX_CONVERSATION_MESSAGES)
    end
end
