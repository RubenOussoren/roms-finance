require "test_helper"

class Provider::RubyLlm::FunctionToolAdapterTest < ActiveSupport::TestCase
  setup do
    @function = mock("typed function")
    @function.stubs(:name).returns("typed_lookup")
    @function.stubs(:description).returns("Synthetic typed lookup")
    @schema = {
      type: "object",
      properties: {
        accounts: { type: "array", items: { enum: [ "Checking", "Loan" ] }, minItems: 1, uniqueItems: true },
        extra_payment: { type: "number" },
        page: { type: "integer" },
        order: { enum: [ "asc", "desc" ] }
      },
      required: [ "accounts", "page", "order" ],
      additionalProperties: false
    }
    @function.stubs(:params_schema).returns(@schema)
    @adapter = Provider::RubyLlm::FunctionToolAdapter.new([ @function ])
    @tool = @adapter.tool_classes.first.new
  end

  test "raw JSON schema preserves all declared constraints" do
    assert_equal @schema.deep_stringify_keys, @tool.parameters_schema
  end

  test "valid arrays numbers and integers round trip without coercion" do
    args = { "accounts" => [ "Checking" ], "extra_payment" => 200.5, "page" => 1, "order" => "asc" }
    @function.expects(:call).with(args).returns({ total: 200.5 })
    assert_equal({ total: 200.5 }, @tool.call(**args))
    assert_equal [ { function_name: "typed_lookup", arguments: args, result: { total: 200.5 } } ], @adapter.tool_calls_log
  end

  test "optional numeric value may be omitted but not coerced from string or null" do
    @function.expects(:call).with({ "accounts" => [ "Loan" ], "page" => 1, "order" => "desc" }).returns("ok")
    assert_equal "ok", @tool.call(accounts: [ "Loan" ], page: 1, order: "desc")
    @function.expects(:call).never
    [ "200", nil, true, Float::INFINITY ].each do |value|
      result = @tool.call(accounts: [ "Loan" ], page: 1, order: "desc", extra_payment: value)
      assert_equal "invalid_arguments", result.dig(:error, :type)
      assert_equal "$.extra_payment", result.dig(:error, :details, 0, :path)
    end
  end

  test "invalid arguments are recoverable and logged without executing the function" do
    @function.expects(:call).never
    [
      { accounts: "Checking", page: 1, order: "asc" },
      { accounts: [], page: 1, order: "asc" },
      { accounts: [ "Checking", "Checking" ], page: 1, order: "asc" },
      { accounts: [ "Unknown" ], page: 1, order: "asc" },
      { accounts: [ "Checking" ], page: "1", order: "asc" },
      { accounts: [ "Checking" ], page: 1.5, order: "asc" },
      { accounts: [ "Checking" ], page: 1, order: "random" },
      { accounts: [ "Checking" ], page: 1 },
      { accounts: [ "Checking" ], page: 1, order: "asc", unexpected: "no" }
    ].each do |args|
      result = @tool.call(**args)
      assert_equal "invalid_arguments", result.dig(:error, :type), args.inspect
      assert result.dig(:error, :details).present?
      assert_equal result, @adapter.tool_calls_log.last.fetch(:result)
    end
    assert_equal 9, @adapter.tool_calls_log.length
  end

  test "unsupported schema contracts fail closed at registration" do
    @function.expects(:call).never
    [
      @schema.merge(maxItems: 2),
      @schema.merge(type: "unsupported"),
      @schema.merge(required: [ "undeclared" ]),
      @schema.merge(additionalProperties: { type: "string" }),
      @schema.deep_merge(properties: { extra_payment: { minimum: 0 } })
    ].each do |schema|
      @function.stubs(:params_schema).returns(schema)
      adapter = Provider::RubyLlm::FunctionToolAdapter.new([ @function ])
      assert_raises(ArgumentError) { adapter.tool_classes }
      assert_empty adapter.tool_calls_log
    end
  end

  test "invalid mutation arguments never create a memory" do
    function = Assistant::Function::SaveMemory.new(users(:family_admin))
    tool = Provider::RubyLlm::FunctionToolAdapter.new([ function ]).tool_classes.sole.new
    function.expects(:call).never
    assert_no_difference "AiMemory.count" do
      result = tool.call(category: "preference", content: 123, expires_at: "")
      assert_equal "invalid_arguments", result.dig(:error, :type)
    end
  end

  test "actual transaction schema has no impossible required fields" do
    function = Assistant::Function::GetTransactions.new(users(:family_admin))
    schema = function.params_schema.deep_stringify_keys
    assert_empty schema.fetch("required") - schema.fetch("properties").keys
  end
end
