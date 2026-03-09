require "test_helper"

class AssistantTest < ActiveSupport::TestCase
  include ProviderTestHelper

  setup do
    @chat = chats(:two)
    @message = @chat.messages.create!(
      type: "UserMessage",
      content: "What is my net worth?",
      ai_model: "gpt-5.4"
    )
    @assistant = Assistant.for_chat(@chat)
    @provider = mock
  end

  test "errors get added to chat" do
    @assistant.expects(:get_model_provider).with("gpt-5.4").returns(@provider)

    error = StandardError.new("test error")
    @provider.expects(:chat_response).returns(provider_error_response(error))

    @chat.expects(:add_error).with(error).once

    assert_no_difference "AssistantMessage.count"  do
      @assistant.respond_to(@message)
    end
  end

  test "responds to basic prompt" do
    @assistant.expects(:get_model_provider).with("gpt-5.4").returns(@provider)

    text_chunks = [
      provider_text_chunk("I do not "),
      provider_text_chunk("have the information "),
      provider_text_chunk("to answer that question")
    ]

    response_chunk = provider_response_chunk(
      id: "1",
      model: "gpt-5.4",
      messages: [ provider_message(id: "1", text: text_chunks.join) ],
      function_requests: []
    )

    response = provider_success_response(response_chunk.data)

    @provider.expects(:chat_response).with do |message, **options|
      text_chunks.each do |text_chunk|
        options[:streamer].call(text_chunk)
      end

      options[:streamer].call(response_chunk)
      true
    end.returns(response)

    assert_difference "AssistantMessage.count", 1 do
      @assistant.respond_to(@message)
      message = @chat.messages.ordered.where(type: "AssistantMessage").last
      assert_equal "I do not have the information to answer that question", message.content
      assert_equal 0, message.tool_calls.size
    end
  end

  test "responds with tool function calls" do
    @assistant.expects(:get_model_provider).with("gpt-5.4").returns(@provider).once

    # RubyLLM handles tool calls internally in a single chat_response call.
    # The response includes tool_calls_log with executed function details.
    text_chunks = [
      provider_text_chunk("Your net worth is "),
      provider_text_chunk("$124,200")
    ]

    tool_calls_log = [
      { function_name: "get_accounts", arguments: {}, result: "test value" }
    ]

    response_chunk = provider_response_chunk(
      id: "1",
      model: "gpt-5.4",
      messages: [ provider_message(id: "1", text: text_chunks.join) ],
      function_requests: [],
      tool_calls_log: tool_calls_log
    )

    response = provider_success_response(response_chunk.data)

    @provider.expects(:chat_response).with do |message, **options|
      text_chunks.each do |text_chunk|
        options[:streamer].call(text_chunk)
      end

      options[:streamer].call(response_chunk)
      true
    end.returns(response).once

    assert_difference "AssistantMessage.count", 1 do
      @assistant.respond_to(@message)
      message = @chat.messages.ordered.where(type: "AssistantMessage").last
      assert_equal 1, message.tool_calls.size
    end
  end

  private
    def provider_function_request(id:, call_id:, function_name:, function_args:)
      Provider::LlmConcept::ChatFunctionRequest.new(
        id: id,
        call_id: call_id,
        function_name: function_name,
        function_args: function_args
      )
    end

    def provider_message(id:, text:)
      Provider::LlmConcept::ChatMessage.new(id: id, output_text: text)
    end

    def provider_text_chunk(text)
      Provider::LlmConcept::ChatStreamChunk.new(type: "output_text", data: text)
    end

    def provider_response_chunk(id:, model:, messages:, function_requests:, tool_calls_log: [])
      Provider::LlmConcept::ChatStreamChunk.new(
        type: "response",
        data: Provider::LlmConcept::ChatResponse.new(
          id: id,
          model: model,
          messages: messages,
          function_requests: function_requests,
          tool_calls_log: tool_calls_log
        )
      )
    end
end
