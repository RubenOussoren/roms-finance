# frozen_string_literal: true

require "test_helper"

class Assistant::FunctionTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @function = Assistant::Function::GetIncomeStatement.new(@user)
  end

  test "safe_parse_date with valid date" do
    assert_equal Date.new(2026, 2, 28), @function.send(:safe_parse_date, "2026-02-28")
  end

  test "safe_parse_date with invalid leap year date falls back to end of month" do
    assert_equal Date.new(2026, 2, 28), @function.send(:safe_parse_date, "2026-02-29")
  end

  test "safe_parse_date with invalid day falls back to end of month" do
    assert_equal Date.new(2026, 4, 30), @function.send(:safe_parse_date, "2026-04-31")
  end

  test "safe_parse_date with valid leap year date" do
    assert_equal Date.new(2024, 2, 29), @function.send(:safe_parse_date, "2024-02-29")
  end

  test "safe_parse_date with nil returns nil" do
    assert_nil @function.send(:safe_parse_date, nil)
  end

  test "safe_parse_date with blank string returns nil" do
    assert_nil @function.send(:safe_parse_date, "")
  end

  test "safe_parse_date with invalid month returns nil" do
    assert_nil @function.send(:safe_parse_date, "2026-13-15")
  end
end
