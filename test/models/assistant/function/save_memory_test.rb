require "test_helper"

class Assistant::Function::SaveMemoryTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @function = Assistant::Function::SaveMemory.new(@user)
  end

  test "saves a memory successfully" do
    result = @function.call("category" => "preference", "content" => "Prefers weekly summaries", "expires_at" => "")

    assert result[:saved]
    assert_equal "preference", result[:category]
    assert AiMemory.find(result[:id])
  end

  test "saves memory with expiration" do
    expires = 1.week.from_now.iso8601
    result = @function.call("category" => "context", "content" => "Temporary note", "expires_at" => expires)

    assert result[:saved]
    memory = AiMemory.find(result[:id])
    assert_not_nil memory.expires_at
  end

  test "returns error for invalid category" do
    result = @function.call("category" => "invalid", "content" => "Test", "expires_at" => "")

    assert_not result[:saved]
    assert_match(/not included/, result[:error])
  end

  test "has correct params schema" do
    schema = @function.params_schema
    assert_equal %w[category content expires_at], schema[:required]
    assert_includes schema[:properties][:category][:enum], "preference"
  end
end
