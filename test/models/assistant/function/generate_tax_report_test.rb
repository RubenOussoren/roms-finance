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

  test "personal-use HELOC matches are source evidence not established deductions" do
    assert @user.family.debt_optimization_strategies.exists?
    account = heloc(@user, "Synthetic personal-use HELOC")
    entry = interest(account, "Interest on personal renovation", "123.45", "CAD")
    refund = interest(account, "Interest refund", "-23.45", "USD")
    interest(account, "Principal payment", "900", "CAD")
    interest(account, "Interest outside period", "800", "CAD", date: Date.new(2025, 12, 31))

    result, rows = report
    assert_equal 2, result[:summary][:candidate_interest_entries_count]
    assert_equal "Requires review; eligibility not established", result[:summary][:interest_review_status]
    assert_match(/jurisdictional eligibility/, result[:summary][:interest_review_limitations])
    assert_includes rows, [ entry.id, "2026-01-15", account.name, entry.name, "123.45", "CAD", "Requires review; eligibility not established" ]
    assert_includes rows, [ refund.id, "2026-01-15", account.name, refund.name, "-23.45", "USD", "Requires review; eligibility not established" ]
    refute_match(/Deductible Interest|deductible_interest/i, rows.to_json + result.to_json + @function.description)
    refute_includes rows.flatten, "Principal payment"
    refute_includes rows.flatten, "Interest outside period"
    assert_equal @user.id, FamilyExport.last.reload.requested_by_user_id
    assert_equal "completed", FamilyExport.last.status
  end

  test "candidate review does not depend on a debt strategy or invent known zero eligibility" do
    @user = users(:empty)
    @function = Assistant::Function::GenerateTaxReport.new(@user)
    refute @user.family.debt_optimization_strategies.exists?
    result, = report
    assert_equal 0, result[:summary][:candidate_interest_entries_count]
    assert_equal "Requires review; eligibility not established", result[:summary][:interest_review_status]
    entry = interest(heloc(@user, "Synthetic unlinked HELOC"), "INTEREST", "12", "USD")
    result, rows = report
    assert_equal 1, result[:summary][:candidate_interest_entries_count]
    assert_includes rows.flatten, entry.id
  end

  test "candidate evidence excludes restricted foreign-family and non-HELOC accounts" do
    @user = users(:family_member)
    @function = Assistant::Function::GenerateTaxReport.new(@user)
    visible = heloc(users(:family_admin), "Synthetic visible HELOC")
    allowed = interest(visible, "Interest visible", "10", "USD")
    [ "hidden", "balance_only" ].each do |visibility|
      account = heloc(users(:family_admin), "Synthetic #{visibility} HELOC")
      account.account_permissions.create!(user: @user, visibility: visibility)
      interest(account, "Interest #{visibility}", "9000", "USD")
    end
    interest(heloc(users(:empty), "Synthetic foreign HELOC"), "Interest foreign", "8000", "USD")
    interest(accounts(:depository), "Interest checking", "7000", "USD")

    result, rows = report
    assert_equal 1, result[:summary][:candidate_interest_entries_count]
    assert_includes rows.flatten, allowed.id
    [ "hidden", "balance_only", "foreign", "checking" ].each do |restricted|
      refute_match(/Interest #{restricted}/, rows.to_json + result.to_json)
    end
  end

  test "RubyLLM boundary returns review status and no deductible scalar" do
    entry = interest(heloc(@user, "Synthetic personal-use boundary"), "Interest personal", "34", "USD")
    adapter = Provider::RubyLlm::FunctionToolAdapter.new([ @function ])
    result = adapter.tool_classes.sole.new.call(start_date: "2026-01-01", end_date: "2026-01-31")
    assert_equal result, adapter.tool_calls_log.sole[:result]
    assert_equal 1, result[:summary][:candidate_interest_entries_count]
    refute result[:summary].key?(:deductible_interest)
    assert_match(/eligibility not established/, result[:summary][:interest_review_status])
    export = FamilyExport.find(result[:download_path].split("/")[-2])
    assert_includes CSV.parse(export.export_file.download).flatten, entry.id
  end

  test "formula-prefixed candidate text is literal while negative amounts retain signs" do
    [ "=", "+", "-", "@", "\t", "\r", "\n", "  =" ].each do |prefix|
      account = heloc(@user, "#{prefix}Synthetic account")
      interest(account, "#{prefix}interest", "-10", "USD")
    end
    result, rows = report
    assert_equal 8, result[:summary][:candidate_interest_entries_count]
    candidates = rows.select { |row| row.size == 7 && row.last == "Requires review; eligibility not established" }
    assert_equal 8, candidates.size
    candidates.each do |row|
      assert row[2].start_with?("'")
      assert row[3].start_with?("'")
      assert_equal "-10.0", row[4]
    end
  end

  test "has correct params schema" do
    schema = @function.params_schema
    assert_equal %w[start_date end_date], schema[:required]
  end

  test "summary includes income and expense totals" do
    result = @function.call("start_date" => 1.year.ago.to_date.to_s, "end_date" => Date.current.to_s)

    assert result[:summary][:total_income].present?
    assert result[:summary][:total_expenses].present?
    assert result[:summary].key?(:candidate_interest_entries_count)
    refute result[:summary].key?(:deductible_interest)
    assert result[:summary][:total_sell_proceeds].present?
  end
  private
    def heloc(owner, name)
      owner.family.accounts.create!(name: name, accountable: Loan.new, subtype: "heloc", currency: "USD", balance: 0, created_by_user: owner)
    end

    def interest(account, name, amount, currency, date: Date.new(2026, 1, 15))
      account.entries.create!(name: name, date: date, amount: amount, currency: currency, entryable: Transaction.new)
    end

    def report
      result = @function.call("start_date" => "2026-01-01", "end_date" => "2026-01-31")
      [ result, CSV.parse(FamilyExport.find(result[:download_path].split("/")[-2]).export_file.download) ]
    end
end
