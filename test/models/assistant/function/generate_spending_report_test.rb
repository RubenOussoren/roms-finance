require "test_helper"
require "csv"

class Assistant::Function::GenerateSpendingReportTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @function = Assistant::Function::GenerateSpendingReport.new(@user)
  end

  test "generates CSV with transaction data" do
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
    assert_equal "spending_report", export.export_type
    assert_equal "completed", export.status
    assert export.export_file.attached?
  end

  test "CSV has correct headers" do
    result = @function.call("start_date" => 1.year.ago.to_date.to_s, "end_date" => Date.current.to_s)

    export = FamilyExport.last
    csv_content = export.export_file.download
    rows = CSV.parse(csv_content)
    assert_equal %w[Date Account Name Amount Currency Classification Category Merchant Tags], rows.first
  end

  test "summary includes top categories" do
    result = @function.call("start_date" => 1.year.ago.to_date.to_s, "end_date" => Date.current.to_s)

    assert result[:summary][:top_categories].is_a?(Array)
    assert result[:summary][:top_categories].size <= 5
  end

  test "has correct params schema" do
    schema = @function.params_schema
    assert_equal %w[start_date end_date], schema[:required]
  end

  test "empty date range returns valid result" do
    result = @function.call("start_date" => Date.current.to_s, "end_date" => Date.current.to_s)

    assert result[:download_path].present?
    assert_equal 0, result[:summary][:transaction_count]
  end
end
