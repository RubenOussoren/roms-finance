# Synthetic 100-unit RSU at USD 10; real forward materialization, no market network.
module EquityRegenerationScenario
  def setup_equity_regeneration_scenario(opening: nil)
    travel_to Time.utc(2026, 10, 5, 12)
    @account = accounts(:equity_compensation)
    @equity = @account.accountable
    @equity.equity_grants.destroy_all
    @account.entries.destroy_all
    @account.balances.delete_all
    Security.any_instance.stubs(:import_provider_prices)
    Security.any_instance.stubs(:current_price).returns(Money.new(10, "USD"))
    Account::MarketDataImporter.any_instance.stubs(:import_all)
    @grant = @equity.equity_grants.create!(security: securities(:goog), name: "Synthetic vested RSU",
      grant_type: "rsu", grant_date: Date.current - 2.months, total_units: 100,
      cliff_months: 0, vesting_period_months: 1, vesting_frequency: "monthly")
    Security::Price.create!(security: @grant.security, date: @grant.grant_date + 1.month,
      price: 10, currency: "USD")
    if opening
      @anchor = @account.entries.create!(name: "Opening balance", date: @grant.grant_date - 1.day,
        amount: opening, currency: "USD", entryable: Valuation.new(kind: "opening_anchor"))
    end
    @equity.regenerate_vesting_valuations!
  end

  def generated_vesting_entries
    @account.entries.where(entryable_type: "Valuation").where("name LIKE ?", "#{EquityCompensation::VESTING_ENTRY_PREFIX}%")
  end

  def assert_materialized_equity_balance(expected)
    assert_equal expected.to_d, @account.reload.balance
    assert_equal expected.to_d, @account.balances.where(currency: "USD").order(:date).last.end_balance
    assert_equal "completed", @account.syncs.ordered.first.status
  end
end
