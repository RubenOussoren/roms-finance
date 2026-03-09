require "test_helper"
require "csv"

class Assistant::Function::GenerateNetWorthReportTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @function = Assistant::Function::GenerateNetWorthReport.new(@user)
  end

  test "generates CSV with net worth data" do
    result = @function.call("start_date" => 1.year.ago.to_date.to_s, "end_date" => Date.current.to_s)

    assert result[:download_path].present?
    assert_match %r{/family_exports/.+/download}, result[:download_path]
    assert result[:filename].end_with?(".csv")
    assert result[:summary][:account_count] > 0
    assert result[:summary][:currency].present?
  end

  test "creates FamilyExport with correct type" do
    assert_difference "FamilyExport.count", 1 do
      @function.call("start_date" => 1.year.ago.to_date.to_s, "end_date" => Date.current.to_s)
    end

    export = FamilyExport.last
    assert_equal "net_worth_report", export.export_type
    assert_equal "completed", export.status
    assert export.export_file.attached?
  end

  test "has correct params schema" do
    schema = @function.params_schema
    assert_equal %w[start_date end_date], schema[:required]
    assert schema[:properties][:start_date].present?
    assert schema[:properties][:end_date].present?
  end
end
