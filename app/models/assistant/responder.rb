class Assistant::Responder
  def initialize(message:, instructions:, function_instances:, llm:)
    @message = message
    @instructions = instructions
    @function_instances = function_instances
    @llm = llm
  end

  def on(event_name, &block)
    listeners[event_name.to_sym] << block
  end

  # RubyLLM handles the complete tool call loop internally:
  # ask → model requests tool → execute → model continues → final response
  # No manual follow-up requests needed.
  def respond(messages: [])
    streamer = proc do |chunk|
      case chunk.type
      when "output_text"
        emit(:output_text, chunk.data)
      when "response"
        response = chunk.data
        emit(:response, {
          id: response.id,
          tool_calls_log: response.tool_calls_log
        })
      end
    end

    get_llm_response(streamer: streamer, messages: messages)
  end

  private
    attr_reader :message, :instructions, :function_instances, :llm

    def get_llm_response(streamer:, messages: [])
      response = llm.chat_response(
        message.content,
        model: message.ai_model,
        instructions: instructions,
        function_instances: function_instances,
        messages: messages,
        streamer: streamer
      )

      unless response.success?
        raise response.error
      end

      response.data
    end

    def emit(event_name, payload = nil)
      listeners[event_name.to_sym].each { |block| block.call(payload) }
    end

    def listeners
      @listeners ||= Hash.new { |h, k| h[k] = [] }
    end
end
