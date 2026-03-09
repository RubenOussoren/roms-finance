class Assistant
  include Provided, Configurable, Broadcastable

  MAX_CONVERSATION_MESSAGES = 20

  attr_reader :chat, :instructions

  class << self
    def for_chat(chat)
      config = config_for(chat)
      new(chat, instructions: config[:instructions], functions: config[:functions])
    end
  end

  def initialize(chat, instructions: nil, functions: [])
    @chat = chat
    @instructions = instructions
    @functions = functions
  end

  def respond_to(message)
    assistant_message = AssistantMessage.new(
      chat: chat,
      content: "",
      ai_model: message.ai_model,
      status: :pending
    )

    function_instances = build_function_instances

    responder = Assistant::Responder.new(
      message: message,
      instructions: instructions,
      function_instances: function_instances,
      llm: get_model_provider(message.ai_model)
    )

    assistant_message.start_streaming!

    responder.on(:output_text) do |text|
      if assistant_message.content.blank?
        stop_thinking
        assistant_message.append_text!(text)
      else
        assistant_message.append_text!(text)
      end
    end

    responder.on(:response) do |data|
      assistant_message.flush_buffer!

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
    attr_reader :functions

    def build_function_instances
      functions.map { |fn| fn.new(chat.user) }
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
