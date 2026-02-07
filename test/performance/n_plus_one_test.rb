require "test_helper"

class NPlusOneTest < ActiveSupport::TestCase
  include QueryCountingHelper

  setup do
    @family = families(:dylan_family)
  end

  test "aggregate_volatility uses cached assumptions (no N+1)" do
    calculator = FamilyProjectionCalculator.new(@family)
    asset_accounts = @family.accounts.where(classification: "asset").active.includes(:accountable, :projection_assumption)

    # Prime the assumption cache by calling project_account_balance for each account
    asset_accounts.each do |account|
      calculator.send(:assumption_for, account)
    end

    # Now aggregate_volatility should hit zero ProjectionAssumption queries
    pa_queries = count_queries {
      calculator.send(:aggregate_volatility, asset_accounts)
    }.select { |sql| sql.include?("projection_assumptions") }

    assert_equal 0, pa_queries.size,
      "Expected 0 ProjectionAssumption queries after cache priming but got #{pa_queries.size}:\n#{pa_queries.join("\n")}"
  end

  test "calculate_summary_metrics uses SQL SUM not bulk loads" do
    strategy = debt_optimization_strategies(:smith_manoeuvre_strategy) if fixture_exists?(:smith_manoeuvre_strategy)
    skip "No debt optimization strategy fixture available" unless strategy

    queries = count_queries {
      strategy.send(:calculate_summary_metrics!)
    }

    sum_queries = queries.select { |sql| sql.include?("SUM") }
    select_all_queries = queries.select { |sql| sql.match?(/SELECT\s+"debt_optimization_ledger_entries"\.\*/) }

    assert sum_queries.any?, "Expected SQL SUM queries but found none"
    assert_equal 0, select_all_queries.size,
      "Expected no SELECT * bulk loads but got #{select_all_queries.size}"
  end

  private

    def fixture_exists?(name)
      begin
        debt_optimization_strategies(name)
        true
      rescue StandardError
        false
      end
    end
end
