require "test_helper"

class Provider::RubyLlmTest < ActiveSupport::TestCase
  include WebMock::API
  setup do
    WebMock.reset!
    @provider = Provider::RubyLlm.new
    @api_key = RubyLLM.config.openai_api_key
    RubyLLM.config.openai_api_key = "test-key"
  end

  teardown do
    WebMock.reset!
    RubyLLM.config.openai_api_key = @api_key
  end

  test "plain chat uses Chat Completions and maps model and token usage" do
    stub_chat("Hello", usage: { prompt_tokens: 12, completion_tokens: 4 })

    response = @provider.chat_response("Hi", model: "gpt-5-mini", instructions: "Be helpful",
      messages: [ { role: "user", content: "Earlier question" }, { role: "assistant", content: "Earlier answer" } ])

    assert response.success?, response.error&.message
    assert_equal "gpt-5-mini", response.data.model
    assert_equal "Hello", response.data.messages.first.output_text
    assert_equal 12, response.data.input_tokens
    assert_equal 4, response.data.output_tokens
    assert_requested(:post, "https://api.openai.com/v1/chat/completions") do |req|
      messages = JSON.parse(req.body).fetch("messages")
      messages.map { |message| message.fetch("content") } == [ "Be helpful", "Earlier question", "Earlier answer", "Hi" ]
    end
    assert_nil RubyLLM.config.model_registry_store
    assert_equal :chat_completions, RubyLLM.config.openai_protocol
  end

  test "tool loop executes adapted functions and records their arguments and results" do
    function = mock("function")
    function.stubs(:name).returns("lookup")
    function.stubs(:description).returns("Look up a value")
    function.stubs(:params_schema).returns(properties: { query: { type: "string", description: "Search query" }, optional: { type: "string", description: "Optional value" } }, required: [ "query" ])
    function.expects(:call).with({ "query" => "balance" }).returns("42")

    stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
      { status: 200, headers: json_headers, body: {
        id: "tool-response", model: "gpt-5-mini", choices: [ { finish_reason: "tool_calls", message: {
          role: "assistant", content: nil, tool_calls: [ { id: "call-1", type: "function", function: { name: "lookup", arguments: '{"query":"balance"}' } } ]
        } } ], usage: { prompt_tokens: 10, completion_tokens: 2 }
      }.to_json },
      { status: 200, headers: json_headers, body: chat_body("Your balance is 42") }
    )

    response = @provider.chat_response("Balance?", model: "gpt-5-mini", function_instances: [ function ])

    assert response.success?, response.error&.message
    assert_equal "Your balance is 42", response.data.messages.first.output_text
    assert_equal [ { function_name: "lookup", arguments: { "query" => "balance" }, result: "42" } ], response.data.tool_calls_log
    assert_requested(:post, "https://api.openai.com/v1/chat/completions", times: 2) do |req|
      schema = JSON.parse(req.body).dig("tools", 0, "function", "parameters")
      schema.present? && schema["required"] == [ "query" ] && schema.dig("properties", "query", "description") == "Search query"
    end
  end

  test "actual transaction arrays and integers reach the tool through the provider loop" do
    function = Assistant::Function::GetTransactions.new(users(:family_admin))
    args = { "accounts" => [ accounts(:depository).name ], "page" => 1, "order" => "asc" }
    stub_tool_loop(function.name, args)

    response = @provider.chat_response("Show checking transactions", model: "gpt-5-mini", function_instances: [ function ])

    assert response.success?, response.error&.message
    call = response.data.tool_calls_log.sole
    assert_equal args, call.fetch(:arguments)
    result = call.fetch(:result)
    assert result.fetch(:transactions).any?
    assert_equal [ accounts(:depository).name ], result.fetch(:transactions).map { |txn| txn.fetch(:account) }.uniq
    assert_equal 50, result.fetch(:page_size)
    assert_requested(:post, "https://api.openai.com/v1/chat/completions", times: 2) do |req|
      JSON.parse(req.body).dig("tools", 0, "function", "parameters") == function.params_schema.deep_stringify_keys
    end
  end

  test "numeric loan scenario reaches the real calculator through the provider loop" do
    account = accounts(:loan)
    account.update!(balance: 1200)
    account.accountable.update!(interest_rate: 0)
    Loan.any_instance.stubs(:monthly_payment).returns(Money.new(100, "USD"))
    function = Assistant::Function::GetLoanPayoff.new(users(:family_admin))
    args = { "account_name" => account.name, "extra_payment" => 200 }
    stub_tool_loop(function.name, args)

    response = @provider.chat_response("What if I pay an extra 200?", model: "gpt-5-mini", function_instances: [ function ])

    assert response.success?, response.error&.message
    call = response.data.tool_calls_log.sole
    assert_equal args, call.fetch(:arguments)
    result = call.fetch(:result)
    # At zero interest: 1200 / (100 + 200) = 4 months, vs baseline 12.
    assert_equal 4, result.fetch(:months_to_payoff)
    assert_equal 8, result.dig(:extra_payment_scenario, :months_saved)
    assert_equal "$200.00", result.dig(:extra_payment_scenario, :extra_monthly_payment)
    assert_equal "$0.00", result.fetch(:total_interest_remaining)
    assert_requested(:post, "https://api.openai.com/v1/chat/completions", times: 2) do |req|
      JSON.parse(req.body).dig("tools", 0, "function", "parameters") == function.params_schema.deep_stringify_keys
    end
  end

  test "invalid arguments return a typed tool error and the conversation continues" do
    function = Assistant::Function::GetLoanPayoff.new(users(:family_admin))
    function.expects(:call).never
    invalid_args = { "account_name" => accounts(:loan).name, "extra_payment" => "200" }
    stub_tool_loop(function.name, invalid_args)

    response = @provider.chat_response("Loan scenario", model: "gpt-5-mini", function_instances: [ function ])

    assert response.success?, response.error&.message
    assert_equal "Synthetic final response", response.data.messages.sole.output_text
    error = response.data.tool_calls_log.sole.fetch(:result).fetch(:error)
    assert_equal "invalid_arguments", error.fetch(:type)
    assert_equal [ { path: "$.extra_payment", message: "must be number" } ], error.fetch(:details)
    assert_requested(:post, "https://api.openai.com/v1/chat/completions") do |req|
      message = JSON.parse(req.body).fetch("messages").find { |msg| msg["role"] == "tool" }
      message && JSON.parse(message.fetch("content")).dig("error", "type") == "invalid_arguments"
    end
  end

  test "provider corrects a malformed numeric argument before the function executes" do
    function = Assistant::Function::GetLoanPayoff.new(users(:family_admin))
    valid = { "account_name" => accounts(:loan).name, "extra_payment" => 200 }
    function.expects(:call).once.with(valid).returns({ months_to_payoff: 4 })
    stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
      { status: 200, headers: json_headers, body: tool_call_body(function.name, valid.merge("extra_payment" => "200"), id: "bad-call") },
      { status: 200, headers: json_headers, body: tool_call_body(function.name, valid, id: "corrected-call") },
      { status: 200, headers: json_headers, body: chat_body("Corrected scenario: 4 months") }
    )

    response = @provider.chat_response("Loan scenario", model: "gpt-5-mini", function_instances: [ function ])

    assert response.success?, response.error&.message
    assert_equal "Corrected scenario: 4 months", response.data.messages.sole.output_text
    calls = response.data.tool_calls_log
    assert_equal 2, calls.length
    assert_equal "invalid_arguments", calls.first.dig(:result, :error, :type)
    assert_equal({ months_to_payoff: 4 }, calls.last.fetch(:result))
    assert_equal valid, calls.last.fetch(:arguments)
    assert_requested(:post, "https://api.openai.com/v1/chat/completions", times: 3)
  end

  test "streaming emits text and final response using the real chunk API" do
    chunks = [
      { id: "stream-1", model: "gpt-5-mini", choices: [ { index: 0, delta: { role: "assistant", content: "Hello" }, finish_reason: nil } ] },
      { id: "stream-1", model: "gpt-5-mini", choices: [ { index: 0, delta: {}, finish_reason: "stop" } ], usage: { prompt_tokens: 3, completion_tokens: 1 } }
    ]
    body = chunks.map { |chunk| "data: #{chunk.to_json}\n\n" }.join + "data: [DONE]\n\n"
    stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(status: 200, headers: { "Content-Type" => "text/event-stream" }, body: body)
    events = []

    response = @provider.chat_response("Hi", model: "gpt-5-mini", streamer: ->(chunk) { events << chunk })

    assert response.success?, response.error&.message
    assert_equal [ "output_text", "response" ], events.map(&:type)
    assert_equal "Hello", events.first.data
    assert_equal response.data, events.last.data
    assert_equal 3, response.data.input_tokens
    assert_equal 1, response.data.output_tokens
  end

  test "Anthropic chat remains provider agnostic" do
    original_key = RubyLLM.config.anthropic_api_key
    RubyLLM.config.anthropic_api_key = "test-key"
    stub_request(:post, "https://api.anthropic.com/v1/messages").to_return(status: 200, headers: json_headers,
      body: { id: "anthropic-1", type: "message", role: "assistant", model: "claude-sonnet-4-6",
        content: [ { type: "text", text: "Hello from Claude" } ], stop_reason: "end_turn",
        usage: { input_tokens: 7, output_tokens: 3 } }.to_json)

    response = @provider.chat_response("Hi", model: "claude-sonnet-4-6")

    assert response.success?, response.error&.message
    assert_equal "claude-sonnet-4-6", response.data.model
    assert_equal "Hello from Claude", response.data.messages.first.output_text
    assert_equal 7, response.data.input_tokens
    assert_equal 3, response.data.output_tokens
  ensure
    RubyLLM.config.anthropic_api_key = original_key
  end

  test "tools without parameters keep an empty argument schema" do
    function = Assistant::Function::GetAccounts.new(users(:family_admin))
    tool = Provider::RubyLlm::FunctionToolAdapter.new([ function ]).tool_classes.first.new

    assert_equal function.name, tool.name
    assert_equal({}, tool.parameters_schema.fetch("properties"))
    assert_equal [], tool.parameters_schema.fetch("required")
  end

  test "long acronym tool names use the patched underscore implementation" do
    tool_class = Class.new(RubyLLM::Tool)
    tool_class.define_singleton_method(:name) { "A" * 100_000 + "Tool" }

    name = Timeout.timeout(5) { tool_class.tool_name }

    assert_equal "a" * 100_000, name
  end

  test "missing token counts default to zero" do
    stub_chat("Hello", usage: {})
    response = @provider.chat_response("Hi", model: "gpt-5-mini")
    assert response.success?, response.error&.message
    assert_equal 0, response.data.input_tokens
    assert_equal 0, response.data.output_tokens
  end

  test "auto categorizer parses text content from RubyLLM 2 messages" do
    stub_chat('{"categorizations":[{"transaction_id":"tx-1","category_name":"Groceries"},{"transaction_id":"tx-2","category_name":"null"}]}')
    response = @provider.auto_categorize
    assert response.success?, response.error&.message
    assert_equal "Groceries", response.data.first.category_name
    assert_nil response.data.last.category_name
  end

  test "auto merchant detector parses text content from RubyLLM 2 messages" do
    stub_chat('{"merchants":[{"transaction_id":"tx-1","business_name":"Shop","business_url":"null"}]}')
    response = @provider.auto_detect_merchants
    assert response.success?, response.error&.message
    assert_equal "Shop", response.data.first.business_name
    assert_nil response.data.first.business_url
  end

  test "provider errors remain wrapped in the application response" do
    stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(status: 400, headers: json_headers,
      body: { error: { message: "Invalid request", type: "invalid_request_error" } }.to_json)
    response = @provider.chat_response("Hi", model: "gpt-5-mini")
    assert_not response.success?
    assert_instance_of Provider::RubyLlm::Error, response.error
    assert_match "Invalid request", response.error.message
  end

  private
    def stub_tool_loop(name, arguments)
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        { status: 200, headers: json_headers, body: tool_call_body(name, arguments) },
        { status: 200, headers: json_headers, body: chat_body("Synthetic final response") }
      )
    end

    def tool_call_body(name, arguments, id: "typed-call-1")
      { id: "typed-tool-response", model: "gpt-5-mini", choices: [ { finish_reason: "tool_calls", message: {
        role: "assistant", content: nil, tool_calls: [ { id: id, type: "function", function: { name: name, arguments: arguments.to_json } } ]
      } } ], usage: { prompt_tokens: 10, completion_tokens: 2 } }.to_json
    end

    def json_headers
      { "Content-Type" => "application/json" }
    end

    def stub_chat(content, usage: { prompt_tokens: 10, completion_tokens: 2 })
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200, headers: json_headers, body: chat_body(content, usage: usage))
    end

    def chat_body(content, usage: { prompt_tokens: 10, completion_tokens: 2 })
      { id: "response-1", model: "gpt-5-mini", choices: [ { index: 0, finish_reason: "stop", message: { role: "assistant", content: content } } ], usage: usage }.to_json
    end
end
