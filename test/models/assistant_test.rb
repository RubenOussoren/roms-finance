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

    @chat.expects(:add_error).with { |error| error.message.include?("Please retry") }.once

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

    assert_no_difference "AssistantMessage.count" do
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

    assert_no_difference "AssistantMessage.count" do
      @assistant.respond_to(@message)
      message = @chat.messages.ordered.where(type: "AssistantMessage").last
      assert_equal 1, message.tool_calls.size
    end
  end

  test "fallback dispatches and persists the effective model before streaming" do
    Setting.stubs(:default_ai_model).returns("gpt-5-mini")
    @assistant.expects(:get_model_provider).with("gpt-5.4").returns(nil)
    @assistant.expects(:get_model_provider).with("gpt-5-mini").returns(@provider)
    attempt = @chat.reserve_initial_attempt(@message).first
    data = Provider::LlmConcept::ChatResponse.new(id: "fallback", model: nil,
      messages: [], function_requests: [], input_tokens: 1_000_000, output_tokens: 0)
    @provider.expects(:chat_response).with do |prompt, **options|
      assert_equal @message.content, prompt
      assert_equal "gpt-5-mini", options[:model]
      assert_equal "gpt-5-mini", attempt.reload.ai_model
      options[:streamer].call(provider_text_chunk("Fallback answer"))
      options[:streamer].call(Provider::LlmConcept::ChatStreamChunk.new(type: "response", data: data))
      true
    end.returns(provider_success_response(data))

    @assistant.respond_to(@message)

    assert attempt.reload.complete?
    assert_equal "gpt-5-mini", attempt.ai_model
    assert_equal "gpt-5.4", @message.reload.ai_model
    # gpt-5-mini input is $0.25 per million tokens: 25 cents.
    assert_equal 25, attempt.cost_cents
    assert_equal 1_000_000, attempt.input_tokens
  end

  test "provider returned model controls attribution and pricing" do
    @assistant.expects(:get_model_provider).with("gpt-5.4").returns(@provider)
    data = Provider::LlmConcept::ChatResponse.new(id: "returned", model: "gpt-5-mini",
      messages: [], function_requests: [], input_tokens: 1_000_000, output_tokens: 1_000_000)
    @provider.expects(:chat_response).with do |prompt, **options|
      assert_equal "gpt-5.4", options[:model]
      options[:streamer].call(provider_text_chunk("Answer"))
      options[:streamer].call(Provider::LlmConcept::ChatStreamChunk.new(type: "response", data: data))
      true
    end.returns(provider_success_response(data))

    attempt = @assistant.respond_to(@message)

    assert attempt.reload.complete?
    assert_equal "gpt-5-mini", attempt.ai_model
    # $0.25 input + $2.00 output per million tokens = 225 cents.
    assert_equal 225, attempt.cost_cents
  end

  test "unavailable requested and default models fail without fictitious fallback" do
    Setting.stubs(:default_ai_model).returns("unavailable-default")
    @assistant.expects(:get_model_provider).with("gpt-5.4").returns(nil)
    @assistant.expects(:get_model_provider).with("unavailable-default").returns(nil)
    @provider.expects(:chat_response).never
    @chat.expects(:add_error).with { |error| error.message.include?("No AI provider is available") }

    attempt = @assistant.respond_to(@message)

    assert attempt.reload.failed?
    assert_equal "gpt-5.4", attempt.ai_model
    assert_equal "", attempt.content
  end

  test "unavailable default is not resolved twice" do
    Setting.stubs(:default_ai_model).returns("gpt-5.4")
    @assistant.expects(:get_model_provider).with("gpt-5.4").returns(nil).once
    @chat.expects(:add_error).with { |error| error.message.include?("Settings") }
    assert @assistant.respond_to(@message).reload.failed?
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
