class Provider::RubyLlm < Provider
  include LlmConcept

  Error = Class.new(Provider::Error)

  def supports_model?(model)
    ::RubyLLM.models.find(model).present?
  rescue
    false
  end

  # Main chat interface. RubyLLM handles the full tool call loop internally —
  # when the model requests a tool call, RubyLLM executes it via the adapter
  # and continues the conversation automatically.
  #
  # @param prompt [String] the user's message
  # @param model [String] model identifier (e.g., "gpt-4.1", "claude-sonnet-4-20250514")
  # @param instructions [String] system prompt
  # @param function_instances [Array<Assistant::Function>] function objects for tool execution
  # @param messages [Array<Hash>] conversation history [{role:, content:}]
  # @param streamer [Proc, nil] streaming callback receiving ChatStreamChunk objects
  def chat_response(prompt, model:, instructions: nil, function_instances: [], messages: [], streamer: nil)
    with_provider_response do
      chat = ::RubyLLM.chat(model: model)

      # Set system instructions
      chat.with_instructions(instructions) if instructions.present?

      # Register function tools via adapter — RubyLLM will call execute() automatically
      tool_adapter = FunctionToolAdapter.new(function_instances)
      tool_adapter.tool_classes.each { |tool_class| chat.with_tool(tool_class) }

      # Load conversation history
      messages.each do |msg|
        chat.add_message(role: msg[:role].to_sym, content: msg[:content])
      end

      # Stream or synchronous request
      response_message = if streamer.present?
        chat.ask(prompt) do |chunk|
          if chunk.content.present?
            streamer.call(ChatStreamChunk.new(type: "output_text", data: chunk.content))
          end
        end
      else
        chat.ask(prompt)
      end

      parsed = parse_response(response_message, tool_adapter.tool_calls_log)

      # Emit the final response event for streaming consumers
      if streamer.present?
        streamer.call(ChatStreamChunk.new(type: "response", data: parsed))
      end

      parsed
    end
  end

  def auto_categorize(transactions: [], user_categories: [])
    with_provider_response do
      AutoCategorizer.new(
        transactions: transactions,
        user_categories: user_categories
      ).auto_categorize
    end
  end

  def auto_detect_merchants(transactions: [], user_merchants: [])
    with_provider_response do
      AutoMerchantDetector.new(
        transactions: transactions,
        user_merchants: user_merchants
      ).auto_detect_merchants
    end
  end

  private
    def parse_response(message, tool_calls_log = [])
      ChatResponse.new(
        id: SecureRandom.uuid,
        model: message.model_id,
        messages: [
          ChatMessage.new(
            id: SecureRandom.uuid,
            output_text: message.content || ""
          )
        ],
        function_requests: [],
        tool_calls_log: tool_calls_log
      )
    end
end
