require "test_helper"
require "csv"

class Assistant::Function::GenerateInvestmentReportTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @function = Assistant::Function::GenerateInvestmentReport.new(@user)
  end

  test "generates CSV with holdings and trades" do
    result = @function.call("start_date" => 1.year.ago.to_date.to_s, "end_date" => Date.current.to_s)

    assert result[:download_path].present?
    assert_match %r{/family_exports/.+/download}, result[:download_path]
    assert result[:filename].end_with?(".csv")
    assert result[:summary][:currency].present?
  end

  test "creates FamilyExport with correct type" do
    assert_difference "FamilyExport.count", 1 do
      @function.call("start_date" => 1.year.ago.to_date.to_s, "end_date" => Date.current.to_s)
    end

    export = FamilyExport.last
    assert_equal "investment_report", export.export_type
    assert_equal "completed", export.status
    assert export.export_file.attached?
  end

  test "has correct params schema" do
    schema = @function.params_schema
    assert_equal %w[start_date end_date], schema[:required]
  end

  test "summary includes market value and counts" do
    result = @function.call("start_date" => 1.year.ago.to_date.to_s, "end_date" => Date.current.to_s)

    assert result[:summary][:total_market_value].present?
    assert result[:summary].key?(:holdings_count)
    assert result[:summary].key?(:trade_count)
  end
end
