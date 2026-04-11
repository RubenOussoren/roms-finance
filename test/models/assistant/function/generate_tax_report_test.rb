require "test_helper"
require "csv"

class Assistant::Function::GenerateTaxReportTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @function = Assistant::Function::GenerateTaxReport.new(@user)
  end

  test "generates CSV with income and expense data" do
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
    assert_equal "tax_report", export.export_type
    assert_equal "completed", export.status
    assert export.export_file.attached?
  end

  test "includes disclaimer in summary" do
    result = @function.call("start_date" => 1.year.ago.to_date.to_s, "end_date" => Date.current.to_s)

    assert_match(/not.*tax advice/i, result[:summary][:disclaimer])
  end

  test "includes disclaimer in CSV" do
    @function.call("start_date" => 1.year.ago.to_date.to_s, "end_date" => Date.current.to_s)

    export = FamilyExport.last
    csv_content = export.export_file.download
    assert_match(/DISCLAIMER/, csv_content)
  end

  test "has correct params schema" do
    schema = @function.params_schema
    assert_equal %w[start_date end_date], schema[:required]
  end

  test "summary includes income and expense totals" do
    result = @function.call("start_date" => 1.year.ago.to_date.to_s, "end_date" => Date.current.to_s)

    assert result[:summary][:total_income].present?
    assert result[:summary][:total_expenses].present?
    assert result[:summary][:deductible_interest].present?
    assert result[:summary][:total_sell_proceeds].present?
  end
end
