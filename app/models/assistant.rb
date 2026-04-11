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

  def respond_to(message)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    assistant_message = AssistantMessage.new(
      chat: chat,
      content: "",
      ai_model: message.ai_model,
      status: :pending
    )

    function_instances = select_functions(message.content)

    provider = get_model_provider(message.ai_model)

    # Fallback to default model if requested model isn't available
    if provider.nil? && message.ai_model != Setting.default_ai_model
      provider = get_model_provider(Setting.default_ai_model)
      Rails.logger.warn("AI model '#{message.ai_model}' unavailable, falling back to '#{Setting.default_ai_model}'")
    end

    unless provider
      chat.add_error(Provider::Error.new(
        "No AI provider is available for model '#{message.ai_model}'. Please verify your API keys in Settings."
      ))
      return
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

    responder.on(:response) do |data|
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
    end

    conversation_history = build_conversation_history(message)
    responder.respond(messages: conversation_history)
    assistant_message.update!(status: :complete) if assistant_message.persisted?
  rescue Faraday::TooManyRequestsError => e
    assistant_message.flush_buffer! if assistant_message.persisted?
    assistant_message.update!(status: :failed) if assistant_message.persisted?
    stop_thinking
    chat.add_error(Provider::Error.new("I'm a bit busy right now. Please try again in a moment."))
  rescue Faraday::UnauthorizedError, Faraday::ForbiddenError => e
    assistant_message.flush_buffer! if assistant_message.persisted?
    assistant_message.update!(status: :failed) if assistant_message.persisted?
    stop_thinking
    Rails.logger.error("AI provider authentication error: #{e.message}")
    chat.add_error(Provider::Error.new("AI is temporarily unavailable. Your admin has been notified."))
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
    assistant_message.flush_buffer! if assistant_message.persisted?
    assistant_message.update!(status: :failed) if assistant_message.persisted?
    stop_thinking
    chat.add_error(Provider::Error.new("Having trouble connecting to the AI provider. Please try again."))
  rescue => e
    assistant_message.flush_buffer! if assistant_message.persisted?
    assistant_message.update!(status: :failed) if assistant_message.persisted?
    stop_thinking
    chat.add_error(e)
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

    def build_conversation_history(current_message)
      prior_messages = chat.conversation_messages
        .where.not(id: current_message.id)
        .ordered
        .last(MAX_CONVERSATION_MESSAGES)

      prior_messages.map do |msg|
        { role: msg.role, content: msg.content }
      end
    end
end
