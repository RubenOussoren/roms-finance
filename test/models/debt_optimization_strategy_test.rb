require "test_helper"

# 🇨🇦 Tests for Canadian Modified Smith Manoeuvre debt optimization strategy
class DebtOptimizationStrategyTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @strategy = debt_optimization_strategies(:smith_manoeuvre)
  end

  test "valid strategy with required attributes" do
    strategy = DebtOptimizationStrategy.new(
      family: @family,
      name: "Test Strategy",
      strategy_type: "baseline",
      rental_income: 2000,
      rental_expenses: 500,
      simulation_months: 120
    )
    assert strategy.valid?
  end

  test "requires name" do
    @strategy.name = nil
    assert_not @strategy.valid?
    assert_includes @strategy.errors[:name], "can't be blank"
  end

  test "requires family" do
    @strategy.family = nil
    assert_not @strategy.valid?
    assert_includes @strategy.errors[:family], "must exist"
  end

  test "simulation_months must be positive" do
    @strategy.simulation_months = 0
    assert_not @strategy.valid?
    assert_includes @strategy.errors[:simulation_months], "must be greater than 0"
  end

  test "simulation_months must be at most 600" do
    @strategy.simulation_months = 601
    assert_not @strategy.valid?
    assert_includes @strategy.errors[:simulation_months], "must be less than or equal to 600"
  end

  test "strategy types" do
    assert DebtOptimizationStrategy.strategy_types.keys.include?("baseline")
    assert DebtOptimizationStrategy.strategy_types.keys.include?("modified_smith")
  end

  test "statuses" do
    assert DebtOptimizationStrategy.statuses.keys.include?("draft")
    assert DebtOptimizationStrategy.statuses.keys.include?("simulated")
    assert DebtOptimizationStrategy.statuses.keys.include?("active")
    assert DebtOptimizationStrategy.statuses.keys.include?("completed")
  end

  test "returns baseline simulator for baseline strategy" do
    @strategy.strategy_type = "baseline"
    assert_instance_of BaselineSimulator, @strategy.simulator
  end

  test "returns canadian smith manoeuvre simulator for modified_smith strategy" do
    @strategy.strategy_type = "modified_smith"
    assert_instance_of ::CanadianSmithManoeuvrSimulator, @strategy.simulator
  end

  test "effective_marginal_tax_rate uses jurisdiction" do
    # Default should return a rate (uses Canada default)
    rate = @strategy.effective_marginal_tax_rate
    assert rate >= 0
    assert rate <= 1
  end

  test "baseline_entries returns only baseline ledger entries" do
    @strategy.ledger_entries.create!(
      month_number: 0,
      calendar_month: Date.current,
      scenario_type: "baseline"
    )
    @strategy.ledger_entries.create!(
      month_number: 0,
      calendar_month: Date.current,
      scenario_type: "modified_smith"
    )

    assert_equal 1, @strategy.baseline_entries.count
    assert @strategy.baseline_entries.all? { |e| e.scenario_type == "baseline" }
  end

  test "strategy_entries returns only modified_smith ledger entries" do
    @strategy.ledger_entries.create!(
      month_number: 0,
      calendar_month: Date.current,
      scenario_type: "baseline"
    )
    @strategy.ledger_entries.create!(
      month_number: 0,
      calendar_month: Date.current,
      scenario_type: "modified_smith"
    )

    assert_equal 1, @strategy.strategy_entries.count
    assert @strategy.strategy_entries.all? { |e| e.scenario_type == "modified_smith" }
  end

  test "prepay_only_entries returns only prepay_only ledger entries" do
    @strategy.ledger_entries.create!(
      month_number: 0,
      calendar_month: Date.current,
      scenario_type: "prepay_only"
    )

    assert_equal 1, @strategy.prepay_only_entries.count
  end

  test "calculate_summary_metrics computes correct financial outputs from ledger entries" do
    strategy = @strategy

    # Clear any existing entries
    strategy.ledger_entries.destroy_all

    base_date = Date.new(2026, 1, 1)

    # Create 3 baseline entries: mortgage pays off at month 3
    # primary_mortgage_interest: 100 + 90 + 80 = 270
    # rental_mortgage_interest:   50 + 40 + 30 = 120
    # Total baseline mortgage interest = 390
    strategy.ledger_entries.create!(scenario_type: "baseline", month_number: 1, calendar_month: base_date,
      primary_mortgage_interest: 100, rental_mortgage_interest: 50, primary_mortgage_balance: 5000)
    strategy.ledger_entries.create!(scenario_type: "baseline", month_number: 2, calendar_month: base_date + 1.month,
      primary_mortgage_interest: 90, rental_mortgage_interest: 40, primary_mortgage_balance: 3000)
    strategy.ledger_entries.create!(scenario_type: "baseline", month_number: 3, calendar_month: base_date + 2.months,
      primary_mortgage_interest: 80, rental_mortgage_interest: 30, primary_mortgage_balance: 0)

    # Create 3 strategy entries: mortgage pays off at month 2 (1 month earlier)
    # primary_mortgage_interest: 95 + 75 + 0 = 170
    # rental_mortgage_interest:  45 + 35 + 0 = 80
    # Total strategy mortgage interest = 250
    # heloc_interest: 10 + 15 + 20 = 45
    strategy.ledger_entries.create!(scenario_type: "modified_smith", month_number: 1, calendar_month: base_date,
      primary_mortgage_interest: 95, rental_mortgage_interest: 45, heloc_interest: 10,
      primary_mortgage_balance: 4000, cumulative_tax_benefit: 5)
    strategy.ledger_entries.create!(scenario_type: "modified_smith", month_number: 2, calendar_month: base_date + 1.month,
      primary_mortgage_interest: 75, rental_mortgage_interest: 35, heloc_interest: 15,
      primary_mortgage_balance: 0, cumulative_tax_benefit: 12)
    strategy.ledger_entries.create!(scenario_type: "modified_smith", month_number: 3, calendar_month: base_date + 2.months,
      primary_mortgage_interest: 0, rental_mortgage_interest: 0, heloc_interest: 20,
      primary_mortgage_balance: 0, cumulative_tax_benefit: 20)

    strategy.send(:calculate_summary_metrics!)

    # total_interest_saved = 390 - 250 = 140
    assert_equal 140, strategy.total_interest_saved.to_i

    # total_tax_benefit = last strategy entry's cumulative_tax_benefit = 20
    assert_equal 20, strategy.total_tax_benefit.to_i

    # net_benefit = interest_saved + tax_benefit - heloc_interest = 140 + 20 - 45 = 115
    assert_equal 115, strategy.net_benefit.to_i

    # months_accelerated = baseline_payoff(3) - strategy_payoff(2) = 1
    assert_equal 1, strategy.months_accelerated
  end

  test "unchanged reruns replace rows without changing numerical results or reports" do
    travel_to Time.zone.local(2026, 1, 15) do
      @strategy.update!(simulation_months: 3)
      chart = @strategy.chart_series_builder
      audit = @strategy.audit_trail
      @strategy.run_simulation!
      rows = simulation_rows(@strategy)
      ids = @strategy.ledger_entries.pluck(:id)
      series = chart.all_series
      report = audit.generate_summary_report

      @strategy.run_simulation!

      assert_equal rows, simulation_rows(@strategy)
      assert_empty ids & @strategy.ledger_entries.pluck(:id)
      assert_equal 9, @strategy.ledger_entries.size
      assert_equal series, chart.all_series
      assert_equal report, audit.generate_summary_report
      assert @strategy.simulated?
    end
  end

  test "changed unsaved inputs rerun with fresh ledger chart and audit output" do
    travel_to Time.zone.local(2026, 1, 15) do
      @strategy.update!(simulation_months: 3)
      @strategy.run_simulation!
      chart = @strategy.chart_series_builder
      audit = @strategy.audit_trail
      old_series = chart.debt_comparison_series
      old_report = audit.generate_annual_report(2026)
      @strategy.ledger_entries.load

      @strategy.simulation_months = 2
      @strategy.rental_income += 1000
      @strategy.run_simulation!

      assert_equal 6, @strategy.ledger_entries.size
      assert_equal 2, chart.debt_comparison_series[:strategy].size
      assert_not_equal old_series, chart.debt_comparison_series
      assert_equal @strategy.rental_income * 2, audit.generate_annual_report(2026)[:rental_income][:total_gross_income]
      assert_not_equal old_report, audit.generate_annual_report(2026)
      assert_equal @strategy.rental_income, @strategy.reload.rental_income
    end
  end

  test "rerun clears payoff acceleration when shortened horizon no longer reaches payoff" do
    @strategy.update!(simulation_months: 300)
    @strategy.run_simulation!
    assert_not_nil @strategy.months_accelerated

    @strategy.simulation_months = 2
    @strategy.run_simulation!

    assert_nil @strategy.reload.months_accelerated
    assert_equal 0, @strategy.chart_series_builder.summary_metrics[:months_accelerated]
    assert_equal 0, @strategy.audit_trail.generate_summary_report[:totals][:months_accelerated]
  end

  test "switching to baseline clears comparison metrics from previous simulation" do
    @strategy.update!(simulation_months: 2)
    @strategy.run_simulation!
    assert_not_nil @strategy.net_benefit

    @strategy.strategy_type = "baseline"
    @strategy.run_simulation!

    assert_equal [ "baseline" ], @strategy.ledger_entries.distinct.pluck(:scenario_type)
    assert_nil @strategy.reload.total_interest_saved
    assert_nil @strategy.total_tax_benefit
    assert_nil @strategy.net_benefit
    assert_nil @strategy.months_accelerated
    assert_empty @strategy.chart_series_builder.summary_metrics
    assert_nil @strategy.audit_trail.generate_summary_report
  end

  test "failed rerun rolls back replacement inputs summaries and status" do
    @strategy.update!(simulation_months: 2, status: "active")
    @strategy.run_simulation!
    @strategy.update!(status: "active")
    original = @strategy.attributes
    rows = simulation_rows(@strategy)
    ids = @strategy.ledger_entries.pluck(:id)
    @strategy.simulation_months = 3
    failing_simulator = Object.new
    strategy = @strategy
    failing_simulator.define_singleton_method(:simulate!) do
      BaselineSimulator.new(strategy).simulate!
      raise "simulation failed after baseline insert"
    end
    @strategy.stubs(:simulator).returns(failing_simulator)

    assert_raises(RuntimeError) { @strategy.run_simulation! }

    assert_equal original, @strategy.reload.attributes
    assert_equal rows, simulation_rows(@strategy)
    assert_equal ids.sort, @strategy.ledger_entries.pluck(:id).sort
  end

  test "failed final save rolls back a completed simulation and preserves active status" do
    @strategy.update!(simulation_months: 2)
    @strategy.run_simulation!
    @strategy.update!(status: "active")
    original = @strategy.attributes
    rows = simulation_rows(@strategy)
    ids = @strategy.ledger_entries.pluck(:id)
    @strategy.stubs(:save!).raises(ActiveRecord::RecordInvalid.new(@strategy))

    assert_raises(ActiveRecord::RecordInvalid) { @strategy.run_simulation! }

    assert_equal original, @strategy.reload.attributes
    assert_equal rows, simulation_rows(@strategy)
    assert_equal ids.sort, @strategy.ledger_entries.pluck(:id).sort
  end

  test "for_family scope returns strategies for specific family" do
    strategies = DebtOptimizationStrategy.for_family(@family)
    assert strategies.all? { |s| s.family_id == @family.id }
  end

  # 🇨🇦 Canadian HELOC feature tests

  test "effective_heloc_limit respects max_limit cap" do
    # Create a HELOC account
    heloc_loan = Loan.create!(interest_rate: 7.0, rate_type: "variable", credit_limit: 200_000)
    heloc_account = Account.create!(
      family: @family, name: "Test HELOC", balance: 0, currency: "CAD",
      accountable: heloc_loan, status: "active"
    )

    @strategy.update!(heloc: heloc_account, heloc_max_limit: 150_000)

    # Effective limit should be the lower of the two
    assert_equal 150_000, @strategy.effective_heloc_limit
  end

  test "effective_heloc_limit returns base limit when no max_limit set" do
    heloc_loan = Loan.create!(interest_rate: 7.0, rate_type: "variable", credit_limit: 200_000)
    heloc_account = Account.create!(
      family: @family, name: "Test HELOC", balance: 0, currency: "CAD",
      accountable: heloc_loan, status: "active"
    )

    @strategy.update!(heloc: heloc_account, heloc_max_limit: nil)

    assert_equal 200_000, @strategy.effective_heloc_limit
  end

  test "readvanceable_heloc? returns true when flag is set" do
    @strategy.update!(heloc_readvanceable: true)
    assert @strategy.readvanceable_heloc?
  end

  test "readvanceable_heloc? returns false when flag is not set" do
    @strategy.update!(heloc_readvanceable: false)
    assert_not @strategy.readvanceable_heloc?
  end

  # 🇨🇦 Province and combined tax rate tests

  test "CANADIAN_PROVINCES contains all expected keys" do
    assert_includes DebtOptimizationStrategy::CANADIAN_PROVINCES.keys, "ON"
    assert_includes DebtOptimizationStrategy::CANADIAN_PROVINCES.keys, "BC"
    assert_includes DebtOptimizationStrategy::CANADIAN_PROVINCES.keys, "AB"
    assert_includes DebtOptimizationStrategy::CANADIAN_PROVINCES.keys, "QC"
    assert_equal 13, DebtOptimizationStrategy::CANADIAN_PROVINCES.size
  end

  test "province validation rejects invalid codes" do
    @strategy.province = "ZZ"
    assert_not @strategy.valid?
    assert @strategy.errors[:province].present?
  end

  test "province validation allows blank" do
    @strategy.province = nil
    assert @strategy.valid? || !@strategy.errors[:province].present?
  end

  test "province validation allows valid codes" do
    @strategy.province = "ON"
    @strategy.valid?
    assert_not @strategy.errors[:province].present?
  end

  test "effective_marginal_tax_rate with province ON returns combined rate" do
    @strategy.province = "ON"
    @strategy.jurisdiction = jurisdictions(:canada)
    rate = @strategy.effective_marginal_tax_rate
    # Should be higher than federal-only 20.5%
    assert rate > 0.205, "Expected combined rate > 0.205, got #{rate}"
    assert rate < 1.0
  end

  test "effective_marginal_tax_rate with nil province defaults to Ontario" do
    @strategy.province = nil
    @strategy.jurisdiction = jurisdictions(:canada)
    rate = @strategy.effective_marginal_tax_rate
    # Defaults to ON, so should be same as explicit ON
    @strategy.province = "ON"
    rate_on = @strategy.effective_marginal_tax_rate
    assert_in_delta rate.to_f, rate_on.to_f, 0.0001
  end

  test "effective_marginal_tax_rate falls back to Ontario for province without bracket data" do
    @strategy.province = "MB"
    @strategy.jurisdiction = jurisdictions(:canada)
    rate = @strategy.effective_marginal_tax_rate
    # MB has no bracket data in fixture, should fall back to ON combined rate
    @strategy.province = "ON"
    rate_on = @strategy.effective_marginal_tax_rate
    assert_in_delta rate.to_f, rate_on.to_f, 0.0001,
      "Province without bracket data should fall back to Ontario combined rate"
    assert rate > 0.205, "Expected combined rate > 0.205, got #{rate}"
  end

  test "effective_province falls back to DEFAULT_PROVINCE for province without bracket data" do
    @strategy.province = "MB"
    @strategy.jurisdiction = jurisdictions(:canada)
    assert_equal DebtOptimizationStrategy::DEFAULT_PROVINCE, @strategy.effective_province
  end

  test "effective_province returns selected province when bracket data exists" do
    @strategy.province = "ON"
    @strategy.jurisdiction = jurisdictions(:canada)
    assert_equal "ON", @strategy.effective_province
  end

  test "DEFAULT_PROVINCE constant is ON" do
    assert_equal "ON", DebtOptimizationStrategy::DEFAULT_PROVINCE
  end

  private

    def simulation_rows(strategy)
      DebtOptimizationLedgerEntry.where(debt_optimization_strategy_id: strategy.id).order(:scenario_type, :month_number).map do |entry|
        entry.attributes.except("id", "created_at", "updated_at")
      end
    end
end
