require "test_helper"

class DemoSeedsTest < ActiveSupport::TestCase
  SEED_FILES = %w[11_accounts 12_debt_optimization 13_transactions 14a_equity_compensation 15_projections].freeze
  SEEDED_MODELS = [
    Account, Property, Loan, Depository, CreditCard, Investment, Crypto, EquityCompensation, EquityGrant,
    AccountPermission, Entry, Valuation, Transaction, Transfer,
    DebtOptimizationStrategy, DebtOptimizationStrategy::AutoStopRule,
    DebtOptimizationLedgerEntry, ProjectionAssumption, Account::Projection
  ].freeze

  test "demo financial seeds create data once and skip repeated loads" do
    travel_to Time.zone.local(2026, 2, 28) do
      capture_io { load Rails.root.join("db/seeds/10_family.rb") }
      family = Family.find_by!(currency: "CAD")

      # Other families' fixture data must not prevent this family's first load.
      assert_not family.accounts.exists?
      assert_not family.entries.exists?
      assert_not family.debt_optimization_strategies.exists?
      assert_not family.projection_assumptions.exists?

      # Provide deterministic demo equity prices without external providers.
      Security.any_instance.stubs(:import_provider_prices)
      [ securities(:goog), securities(:aapl) ].each do |security|
        (Date.new(2023, 1, 1)..Date.current).each do |date|
          next unless [ 1, 15 ].include?(date.day)

          security.prices.find_or_create_by!(date: date) do |price|
            price.price = 200
            price.currency = "USD"
          end
        end
      end

      capture_io { load_financial_seeds }

      assert_equal 23, family.accounts.count
      assert_equal 20, family.entries.where(entryable_type: "Valuation")
        .joins("INNER JOIN valuations ON valuations.id = entries.entryable_id")
        .where(valuations: { kind: "opening_anchor" }).count
      %w[rsu stock_option].each do |subtype|
        account = family.accounts.find_by!(accountable_type: "EquityCompensation", subtype: subtype)
        assert account.balance.positive?, "Seeded vested equity should have a nonzero balance"
        assert account.valuations.exists?, "Seeded equity should have chart valuations"
      end
      assert family.entries.where(entryable_type: "Transaction").exists?,
        "Opening valuations must not prevent transactions from being seeded"
      assert_equal 1, family.debt_optimization_strategies.count
      assert_equal 3, family.debt_optimization_strategies.first.auto_stop_rules.count
      assert_equal 3, family.projection_assumptions.count
      assert_equal 6 * 60, Account::Projection.joins(:account).where(accounts: { family_id: family.id }).count

      records = seeded_records
      output, = capture_io { load_financial_seeds }

      assert_equal records, seeded_records, "Repeated seeds must not create or modify financial records"
      assert_equal 5, output.scan("already exists, skipping...").count
    end
  end

  private

    def load_financial_seeds
      SEED_FILES.each { |name| load Rails.root.join("db/seeds/#{name}.rb") }
    end

    def seeded_records
      SEEDED_MODELS.to_h do |model|
        [ model.name, model.order(:id).pluck(:id, :updated_at) ]
      end
    end
end
