require "test_helper"

class FinanceTooltipHelperTest < ActionView::TestCase
  test "finance_tooltip returns rendered tooltip for known term" do
    result = finance_tooltip("Volatility")
    assert result.present?, "Should return non-empty content for known term"
  end

  test "finance_tooltip returns empty string for unknown term" do
    result = finance_tooltip("NonexistentTerm")
    assert_equal "", result
  end

  test "all FINANCIAL_TERMS produce output" do
    FinanceTooltipHelper::FINANCIAL_TERMS.each_key do |term|
      result = finance_tooltip(term)
      assert result.present?, "Expected non-empty tooltip for '#{term}'"
    end
  end

  test "tooltip contains the definition text" do
    result = finance_tooltip("Volatility")
    assert_includes result, FinanceTooltipHelper::FINANCIAL_TERMS["Volatility"]
  end
end
