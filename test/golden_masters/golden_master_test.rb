require "test_helper"
require "json"
require "yaml"

# Phase 0: Golden Master Baseline Tests
#
# These tests exercise the three core computation paths with specific,
# documented inputs and compare outputs against recorded snapshots.
# They exist to detect ANY change in financial calculation behavior.
#
# Golden master snapshots reflect PARTIALLY-CORRECTED behavior. Remaining issues
# (documented in BASELINE.md) include:
#   - Tax rates are federal-only (missing provincial)
#   - p50 shows mean not median for volatile portfolios
# CORRECTED: Mortgage compounding now uses Canadian semi-annual (Interest Act)
#
# To regenerate snapshots after intentional changes:
#   REGENERATE_GOLDEN_MASTERS=true bin/rails test test/golden_masters/
#
# To run only golden master tests:
#   bin/rails test test/golden_masters/
class GoldenMasterTest < ActiveSupport::TestCase
  GOLDEN_MASTER_DIR = Rails.root.join("test", "golden_masters", "snapshots")
  TOLERANCE = 0.01 # $0.01 tolerance for floating point comparisons

  SAMPLE_MONTHS_SHORT = [0, 11, 59, 119, 299]                    # months 1, 12, 60, 120, 300
  SAMPLE_MONTHS_FULL  = [0, 11, 59, 119, 179, 239, 299]          # adds months 180, 240

  setup do
    @family = families(:dylan_family)
    @jurisdiction = jurisdictions(:canada)
  end

  # ============================================================================
  # SCENARIO A: Mortgage / Debt Simulators
  #
  # Inputs:
  #   - Primary mortgage: $400,000, 5.00% annual, 25-year amortization (300 months)
  #   - Rental mortgage: $200,000, 5.50% annual, 20-year amortization (240 months)
  #   - Rental income: $2,000/month
  #   - Rental expenses: $500/month (no additional prepayments beyond strategy)
  #   - HELOC: $0 balance, 7.00% rate, $100,000 credit limit
  #   - Simulation: 300 months (25 years)
  #   - Jurisdiction: Canada (federal-only tax brackets from fixture)
  # ============================================================================

  test "scenario A: baseline simulator golden master" do
    strategy = build_scenario_a_strategy("baseline")

    simulator = BaselineSimulator.new(strategy)
    simulator.simulate!

    entries = strategy.baseline_entries.order(:month_number).to_a
    snapshot = extract_baseline_snapshot(entries, strategy)

    assert_or_regenerate("scenario_a_baseline", snapshot)
  end

  test "scenario A: smith manoeuvre simulator golden master" do
    strategy = build_scenario_a_strategy("modified_smith")

    simulator = CanadianSmithManoeuvrSimulator.new(strategy)
    simulator.simulate!

    baseline_entries = strategy.baseline_entries.order(:month_number).to_a
    strategy_entries = strategy.strategy_entries.order(:month_number).to_a

    snapshot = extract_smith_snapshot(baseline_entries, strategy_entries, strategy)

    assert_or_regenerate("scenario_a_smith_manoeuvre", snapshot)
  end

  # ============================================================================
  # SCENARIO B: Investment Projection Calculators
  #
  # Inputs:
  #   - Portfolio: $100,000 starting balance
  #   - Expected return: 7% annual (0.07)
  #   - Volatility: 18% annual (0.18)
  #   - Monthly contribution: $500
  #   - Projection horizons: 10 years (120 months) and 25 years (300 months)
  #   - Currency: CAD
  #
  # Uses ProjectionCalculator (pure math, no DB dependency)
  # ============================================================================

  test "scenario B: projection calculator 10-year golden master" do
    calc = ProjectionCalculator.new(
      principal: 100_000,
      rate: 0.07,
      contribution: 500,
      currency: "CAD"
    )

    snapshot = extract_projection_snapshot(calc, months: 120, volatility: 0.18, label: "10_year")

    assert_or_regenerate("scenario_b_projection_10yr", snapshot)
  end

  test "scenario B: projection calculator 25-year golden master" do
    calc = ProjectionCalculator.new(
      principal: 100_000,
      rate: 0.07,
      contribution: 500,
      currency: "CAD"
    )

    snapshot = extract_projection_snapshot(calc, months: 300, volatility: 0.18, label: "25_year")

    assert_or_regenerate("scenario_b_projection_25yr", snapshot)
  end

  test "scenario B: milestone calculator golden master" do
    assumption = OpenStruct.new(
      effective_return: 0.07,
      monthly_contribution: 500,
      effective_volatility: 0.18
    )

    calc = MilestoneCalculator.new(
      current_balance: 100_000,
      assumption: assumption,
      currency: "CAD",
      target_type: "reach"
    )

    snapshot = extract_milestone_snapshot(calc)

    assert_or_regenerate("scenario_b_milestones", snapshot)
  end

  # ============================================================================
  # SCENARIO C: Smith Manoeuvre Tax Optimization
  #
  # Inputs:
  #   - Same mortgage setup as Scenario A
  #   - Household income: $100,000 in Ontario
  #   - Uses DebtOptimizationStrategy.effective_marginal_tax_rate
  #   - Jurisdiction: Canada fixture (federal-only brackets)
  #
  # This scenario captures the tax benefit computation specifically.
  # ============================================================================

  test "scenario C: debt optimization tax benefits golden master" do
    strategy = build_scenario_a_strategy("modified_smith")

    simulator = CanadianSmithManoeuvrSimulator.new(strategy)
    simulator.simulate!

    strategy_entries = strategy.strategy_entries.order(:month_number).to_a

    snapshot = extract_tax_benefit_snapshot(strategy_entries, strategy)

    assert_or_regenerate("scenario_c_tax_benefits", snapshot)
  end

  # ============================================================================
  # SCENARIO B SUPPLEMENT: LoanPayoffCalculator
  #
  # Inputs: Same $400,000 mortgage at 5.00%, 25-year term
  # Exercises the amortization schedule used by FamilyProjectionCalculator
  # ============================================================================

  test "scenario B supplement: loan payoff calculator golden master" do
    primary = create_loan_account(@family, "GoldenMaster LPC Primary", 400_000, 5.0, 300, subtype: "mortgage", with_valuation: true)

    # Clear Rails cache to avoid stale results
    Rails.cache.clear

    calc = LoanPayoffCalculator.new(primary, extra_payment: 0)
    schedule = calc.amortization_schedule
    summary = calc.summary

    snapshot = extract_loan_payoff_snapshot(schedule, summary)

    assert_or_regenerate("scenario_b_loan_payoff", snapshot)
  end

  private

    # ---- Scenario Builders ----

    def build_scenario_a_strategy(strategy_type)
      primary = create_loan_account(@family, "GM Primary #{strategy_type}", 400_000, 5.0, 300, subtype: "mortgage")
      rental = create_loan_account(@family, "GM Rental #{strategy_type}", 200_000, 5.5, 240, subtype: "mortgage")
      heloc = create_loan_account(@family, "GM HELOC #{strategy_type}", 0, 7.0, rate_type: "variable", credit_limit: 100_000)

      DebtOptimizationStrategy.create!(
        family: @family,
        jurisdiction: @jurisdiction,
        name: "Golden Master #{strategy_type}",
        strategy_type: strategy_type,
        province: "ON",
        primary_mortgage: primary,
        rental_mortgage: rental,
        heloc: heloc,
        rental_income: 2000,
        rental_expenses: 500,
        simulation_months: 300,
        heloc_interest_rate: 7.0,
        heloc_max_limit: 100_000,
        heloc_readvanceable: false
      )
    end

    # Unified account helper for loans and HELOCs.
    #   term_months:       nil for HELOCs (open-ended)
    #   rate_type:         "fixed" (default) or "variable"
    #   credit_limit:      set for HELOCs
    #   with_valuation:    creates an opening-balance entry (needed by LoanPayoffCalculator)
    def create_loan_account(family, name, balance, interest_rate, term_months = nil,
                            rate_type: "fixed", credit_limit: nil, subtype: nil, with_valuation: false)
      loan = Loan.create!(
        interest_rate: interest_rate,
        term_months: term_months,
        rate_type: rate_type,
        credit_limit: credit_limit
      )

      account = Account.create!(
        family: family,
        name: name,
        balance: -balance,
        currency: "CAD",
        subtype: subtype,
        accountable: loan,
        status: "active"
      )

      if with_valuation
        valuation = Valuation.create!(kind: "opening_anchor")
        Entry.create!(
          account: account,
          entryable: valuation,
          amount: balance,
          currency: "CAD",
          date: 1.year.ago.to_date,
          name: "Opening balance"
        )
      end

      account
    end

    # ---- Snapshot Extractors ----

    def extract_baseline_snapshot(entries, strategy)
      payment = entries.first&.primary_mortgage_payment
      total_primary_interest = entries.sum(&:primary_mortgage_interest)
      total_rental_interest = entries.sum(&:rental_mortgage_interest)
      payoff_month = entries.index { |e| e.primary_mortgage_balance <= 0.01 }

      sample_months = SAMPLE_MONTHS_SHORT.map { |i| entries[i] }.compact

      {
        "scenario" => "A",
        "simulator" => "BaselineSimulator",
        "pre_correction_note" => "Uses monthly compounding (not Canadian semi-annual). Federal + Ontario provincial rates.",
        "inputs" => {
          "primary_mortgage" => 400_000,
          "primary_rate" => 5.0,
          "primary_term_months" => 300,
          "rental_mortgage" => 200_000,
          "rental_rate" => 5.5,
          "rental_term_months" => 240,
          "rental_income" => 2000,
          "rental_expenses" => 500,
          "simulation_months" => 300
        },
        "outputs" => {
          "monthly_payment_primary" => round_val(payment),
          "total_primary_interest" => round_val(total_primary_interest),
          "total_rental_interest" => round_val(total_rental_interest),
          "primary_payoff_month" => payoff_month,
          "total_entries" => entries.size,
          "effective_tax_rate" => round_val(strategy.effective_marginal_tax_rate),
          "final_cumulative_tax_benefit" => round_val(entries.last&.cumulative_tax_benefit),
          "sample_months" => sample_months.map { |e| extract_entry_sample(e) }
        }
      }
    end

    def extract_smith_snapshot(baseline_entries, strategy_entries, strategy)
      total_baseline_interest = baseline_entries.sum { |e| e.primary_mortgage_interest + e.heloc_interest }
      total_strategy_interest = strategy_entries.sum { |e| e.primary_mortgage_interest + e.heloc_interest }
      interest_saved = total_baseline_interest - total_strategy_interest

      baseline_payoff = baseline_entries.index { |e| e.primary_mortgage_balance <= 0.01 }
      strategy_payoff = strategy_entries.index { |e| e.primary_mortgage_balance <= 0.01 }
      months_accelerated = (baseline_payoff && strategy_payoff) ? baseline_payoff - strategy_payoff : nil

      strategy_sample_months = SAMPLE_MONTHS_SHORT.map { |i| strategy_entries[i] }.compact
      heloc_trajectory = SAMPLE_MONTHS_FULL.map { |i|
        e = strategy_entries[i]
        e ? { "month" => e.month_number, "heloc_balance" => round_val(e.heloc_balance) } : nil
      }.compact

      {
        "scenario" => "A",
        "simulator" => "CanadianSmithManoeuvrSimulator",
        "pre_correction_note" => "Uses monthly compounding (not Canadian semi-annual). Federal + Ontario provincial rates. HELOC interest cash source untracked.",
        "inputs" => {
          "primary_mortgage" => 400_000,
          "primary_rate" => 5.0,
          "primary_term_months" => 300,
          "rental_mortgage" => 200_000,
          "rental_rate" => 5.5,
          "rental_term_months" => 240,
          "rental_income" => 2000,
          "rental_expenses" => 500,
          "heloc_rate" => 7.0,
          "heloc_credit_limit" => 100_000,
          "heloc_readvanceable" => false,
          "simulation_months" => 300
        },
        "outputs" => {
          "total_baseline_interest" => round_val(total_baseline_interest),
          "total_strategy_interest" => round_val(total_strategy_interest),
          "interest_saved" => round_val(interest_saved),
          "baseline_payoff_month" => baseline_payoff,
          "strategy_payoff_month" => strategy_payoff,
          "months_accelerated" => months_accelerated,
          "total_baseline_entries" => baseline_entries.size,
          "total_strategy_entries" => strategy_entries.size,
          "final_cumulative_tax_benefit" => round_val(strategy_entries.last&.cumulative_tax_benefit),
          "final_heloc_balance" => round_val(strategy_entries.last&.heloc_balance),
          "heloc_trajectory" => heloc_trajectory,
          "strategy_sample_months" => strategy_sample_months.map { |e| extract_entry_sample(e) }
        }
      }
    end

    def extract_projection_snapshot(calc, months:, volatility:, label:)
      # Deterministic analytical bands (no Monte Carlo randomness)
      bands = calc.project_with_analytical_bands(months: months, volatility: volatility)

      # Sample at key year boundaries
      year_samples = {}
      [5, 10, 25].each do |year|
        month_idx = (year * 12) - 1
        next if month_idx >= bands.size
        data = bands[month_idx]
        year_samples["year_#{year}"] = {
          "month" => data[:month],
          "p10" => round_val(data[:p10]),
          "p25" => round_val(data[:p25]),
          "p50" => round_val(data[:p50]),
          "p75" => round_val(data[:p75]),
          "p90" => round_val(data[:p90]),
          "mean" => round_val(data[:mean])
        }
      end

      # Key intermediate points
      sample_months = SAMPLE_MONTHS_FULL.map { |i|
        next nil if i >= bands.size
        data = bands[i]
        {
          "month" => data[:month],
          "p50" => round_val(data[:p50]),
          "mean" => round_val(data[:mean])
        }
      }.compact

      # Target calculations
      years_to_200k = calc.years_to_target(target: 200_000)
      years_to_500k = calc.years_to_target(target: 500_000)
      years_to_1m = calc.years_to_target(target: 1_000_000)

      # Required contribution to reach $1M in 25 years
      required_for_1m_25y = calc.required_contribution(target: 1_000_000, months: 300)

      # Real (inflation-adjusted) value at 10 and 25 years
      real_10yr = calc.real_future_value_at_month(120, inflation_rate: 0.021)
      real_25yr = months >= 300 ? calc.real_future_value_at_month(300, inflation_rate: 0.021) : nil

      {
        "scenario" => "B",
        "calculator" => "ProjectionCalculator",
        "label" => label,
        "pre_correction_note" => "p50 shows mean (deterministic), not true median. PAG safety margin not applied.",
        "inputs" => {
          "principal" => 100_000,
          "annual_return" => 0.07,
          "volatility" => 0.18,
          "monthly_contribution" => 500,
          "projection_months" => months
        },
        "outputs" => {
          "year_samples" => year_samples,
          "monthly_samples" => sample_months,
          "years_to_200k" => years_to_200k,
          "years_to_500k" => years_to_500k,
          "years_to_1m" => years_to_1m,
          "required_contribution_for_1m_in_25yr" => round_val(required_for_1m_25y),
          "real_value_10yr" => round_val(real_10yr),
          "real_value_25yr" => real_25yr ? round_val(real_25yr) : nil
        }
      }
    end

    def extract_milestone_snapshot(calc)
      targets = [200_000, 500_000, 1_000_000]

      time_results = targets.map do |target|
        result = calc.time_to_target(target: target)
        {
          "target" => target,
          "achieved" => result[:achieved] || false,
          "achievable" => result[:achievable],
          "months" => result[:months],
          "years" => result[:years]
        }
      end

      # Contribution sensitivity for $500K target
      sensitivity = calc.contribution_sensitivity(target: 500_000)
      sensitivity_data = sensitivity.map do |s|
        {
          "multiplier" => s[:multiplier],
          "contribution" => round_val(s[:contribution]),
          "achievable" => s[:achievable],
          "months" => s[:months],
          "years" => s[:years]
        }
      end

      {
        "scenario" => "B",
        "calculator" => "MilestoneCalculator",
        "pre_correction_note" => "Uses deterministic time-to-target. Probability estimates use Monte Carlo (non-deterministic, excluded from snapshot).",
        "inputs" => {
          "current_balance" => 100_000,
          "expected_return" => 0.07,
          "monthly_contribution" => 500,
          "volatility" => 0.18,
          "target_type" => "reach"
        },
        "outputs" => {
          "time_to_targets" => time_results,
          "contribution_sensitivity_for_500k" => sensitivity_data
        }
      }
    end

    def extract_tax_benefit_snapshot(entries, strategy)
      monthly_tax_samples = SAMPLE_MONTHS_FULL.map { |i|
        e = entries[i]
        next nil unless e
        {
          "month" => e.month_number,
          "deductible_interest" => round_val(e.deductible_interest),
          "non_deductible_interest" => round_val(e.non_deductible_interest),
          "tax_benefit" => round_val(e.tax_benefit),
          "cumulative_tax_benefit" => round_val(e.cumulative_tax_benefit),
          "heloc_interest" => round_val(e.heloc_interest),
          "rental_mortgage_interest" => round_val(e.rental_mortgage_interest)
        }
      }.compact

      total_tax_benefit = entries.sum(&:tax_benefit)
      total_deductible = entries.sum(&:deductible_interest)
      total_non_deductible = entries.sum(&:non_deductible_interest)

      # Year-end cumulative snapshots
      year_end_cumulative = [12, 60, 120, 180, 240, 300].map { |month|
        e = entries.find { |en| en.month_number == month - 1 }
        next nil unless e
        {
          "year" => month / 12,
          "cumulative_tax_benefit" => round_val(e.cumulative_tax_benefit),
          "heloc_balance" => round_val(e.heloc_balance)
        }
      }.compact

      {
        "scenario" => "C",
        "calculator" => "DebtOptimizationStrategy + CanadianSmithManoeuvrSimulator",
        "pre_correction_note" => "Federal + Ontario provincial rates. HELOC interest cash source untracked.",
        "inputs" => {
          "household_income" => 100_000,
          "province" => "ON",
          "jurisdiction" => "Canada (federal + Ontario provincial brackets from fixture)",
          "primary_mortgage" => 400_000,
          "primary_rate" => 5.0,
          "rental_mortgage" => 200_000,
          "rental_rate" => 5.5,
          "heloc_rate" => 7.0,
          "rental_income" => 2000,
          "rental_expenses" => 500
        },
        "outputs" => {
          "effective_marginal_tax_rate" => round_val(strategy.effective_marginal_tax_rate),
          "total_tax_benefit" => round_val(total_tax_benefit),
          "total_deductible_interest" => round_val(total_deductible),
          "total_non_deductible_interest" => round_val(total_non_deductible),
          "monthly_tax_samples" => monthly_tax_samples,
          "year_end_cumulative" => year_end_cumulative
        }
      }
    end

    def extract_loan_payoff_snapshot(schedule, summary)
      sample_entries = SAMPLE_MONTHS_SHORT.map { |i|
        e = schedule[i]
        next nil unless e
        {
          "month" => e[:month],
          "payment" => round_val(e[:payment]),
          "principal" => round_val(e[:principal]),
          "interest" => round_val(e[:interest]),
          "balance" => round_val(e[:balance])
        }
      }.compact

      total_interest = schedule.sum { |e| e[:interest] }

      # monthly_payment from summary may be a Money object or a number
      payment_val = summary[:monthly_payment]
      payment_val = payment_val.respond_to?(:amount) ? payment_val.amount : payment_val

      {
        "scenario" => "B_supplement",
        "calculator" => "LoanPayoffCalculator",
        "pre_correction_note" => "Uses monthly compounding (not Canadian semi-annual).",
        "inputs" => {
          "balance" => 400_000,
          "interest_rate" => 5.0,
          "term_months" => 300,
          "extra_payment" => 0
        },
        "outputs" => {
          "monthly_payment" => round_val(payment_val),
          "months_to_payoff" => summary[:months_to_payoff],
          "total_interest_remaining" => round_val(summary[:total_interest_remaining]),
          "total_amount_remaining" => round_val(summary[:total_amount_remaining]),
          "years_remaining" => summary[:years_remaining],
          "total_interest_calculated" => round_val(total_interest),
          "schedule_length" => schedule.length,
          "sample_entries" => sample_entries
        }
      }
    end

    # ---- Snapshot Helpers ----

    def extract_entry_sample(entry)
      return nil unless entry
      {
        "month" => entry.month_number,
        "primary_mortgage_balance" => round_val(entry.primary_mortgage_balance),
        "primary_mortgage_interest" => round_val(entry.primary_mortgage_interest),
        "primary_mortgage_principal" => round_val(entry.primary_mortgage_principal),
        "primary_mortgage_prepayment" => round_val(entry.primary_mortgage_prepayment),
        "rental_mortgage_balance" => round_val(entry.rental_mortgage_balance),
        "rental_mortgage_interest" => round_val(entry.rental_mortgage_interest),
        "heloc_balance" => round_val(entry.heloc_balance),
        "heloc_interest" => round_val(entry.heloc_interest),
        "deductible_interest" => round_val(entry.deductible_interest),
        "non_deductible_interest" => round_val(entry.non_deductible_interest),
        "tax_benefit" => round_val(entry.tax_benefit),
        "cumulative_tax_benefit" => round_val(entry.cumulative_tax_benefit),
        "total_debt" => round_val(entry.total_debt)
      }
    end

    def round_val(value)
      return nil if value.nil?
      value.to_f.round(4)
    end

    # ---- Assert or Regenerate ----

    def assert_or_regenerate(name, snapshot)
      filepath = GOLDEN_MASTER_DIR.join("#{name}.json")

      if ENV["REGENERATE_GOLDEN_MASTERS"] == "true"
        FileUtils.mkdir_p(GOLDEN_MASTER_DIR)
        File.write(filepath, JSON.pretty_generate(snapshot) + "\n")
        puts "\n  [REGENERATED] #{filepath}"
        pass # Always pass when regenerating
      else
        assert File.exist?(filepath),
               "Golden master snapshot not found: #{filepath}\n" \
               "Run with REGENERATE_GOLDEN_MASTERS=true to generate initial snapshots."

        expected = JSON.parse(File.read(filepath))
        diffs = deep_diff(expected["outputs"], snapshot["outputs"], path: "outputs")

        if diffs.any?
          message = "Golden master mismatch for #{name}:\n"
          diffs.each do |diff|
            message += "  #{diff[:path]}: expected #{diff[:expected]}, got #{diff[:actual]} (delta: #{diff[:delta]})\n"
          end
          flunk message
        end
      end
    end

    # Recursively compare two hashes/arrays, returning diffs that exceed TOLERANCE
    def deep_diff(expected, actual, path: "")
      diffs = []

      case expected
      when Hash
        expected.each_key do |key|
          child_path = "#{path}.#{key}"
          if actual.is_a?(Hash) && actual.key?(key)
            diffs.concat(deep_diff(expected[key], actual[key], path: child_path))
          else
            diffs << { path: child_path, expected: expected[key], actual: "(missing)", delta: "N/A" }
          end
        end
      when Array
        expected.each_with_index do |item, i|
          child_path = "#{path}[#{i}]"
          if actual.is_a?(Array) && i < actual.size
            diffs.concat(deep_diff(item, actual[i], path: child_path))
          else
            diffs << { path: child_path, expected: item, actual: "(missing)", delta: "N/A" }
          end
        end
      when Numeric
        if actual.is_a?(Numeric)
          delta = (expected.to_f - actual.to_f).abs
          if delta > TOLERANCE
            diffs << { path: path, expected: expected, actual: actual, delta: delta.round(6) }
          end
        else
          diffs << { path: path, expected: expected, actual: actual, delta: "type mismatch" }
        end
      else
        if expected != actual
          diffs << { path: path, expected: expected, actual: actual, delta: "value mismatch" }
        end
      end

      diffs
    end
end
