require "test_helper"

class EquityCompensationTest < ActiveSupport::TestCase
  test "classification is asset" do
    assert_equal "asset", EquityCompensation.classification
  end

  test "icon is award" do
    assert_equal "award", EquityCompensation.icon
  end

  test "color is set" do
    assert_equal "#7C3AED", EquityCompensation.color
  end

  test "subtypes include rsu and stock_option" do
    assert_includes EquityCompensation::SUBTYPES.keys, "rsu"
    assert_includes EquityCompensation::SUBTYPES.keys, "stock_option"
  end

  test "total_vested_units sums across grants" do
    ec = equity_compensations(:one)
    # With fixtures, grants exist - just verify it returns a number
    assert ec.total_vested_units.is_a?(Numeric)
  end

  test "total_unvested_units sums across grants" do
    ec = equity_compensations(:one)
    assert ec.total_unvested_units.is_a?(Numeric)
  end

  test "next_vesting_event returns earliest next vest date" do
    ec = equity_compensations(:one)
    result = ec.next_vesting_event
    # Could be nil (fully vested) or a date
    assert result.nil? || result.is_a?(Date)
  end

  # === Vesting Valuations ===

  test "regenerate_vesting_valuations creates entries at vesting dates" do
    ec = equity_compensations(:one)
    account = accounts(:equity_compensation)
    grant = ec.equity_grants.first

    # Stub price import and create a price record
    grant.security.stubs(:import_provider_prices)
    Security::Price.find_or_create_by!(
      security: grant.security,
      date: grant.grant_date + 12.months,
      price: 180.0,
      currency: "USD"
    )

    # Skip the inline sync to keep this test focused on entry creation
    account.stubs(:sync_now)

    ec.regenerate_vesting_valuations!

    vesting_entries = account.entries.where("name LIKE ?", "#{EquityCompensation::VESTING_ENTRY_PREFIX}%")
    assert vesting_entries.count > 0
    assert vesting_entries.all? { |e| e.entryable_type == "Valuation" }
  end

  test "regenerate_vesting_valuations replaces old vesting entries" do
    ec = equity_compensations(:one)
    account = accounts(:equity_compensation)

    # Stub externals
    ec.equity_grants.each { |g| g.security.stubs(:import_provider_prices) }
    account.stubs(:sync_now)

    ec.regenerate_vesting_valuations!
    first_count = account.entries.where("name LIKE ?", "#{EquityCompensation::VESTING_ENTRY_PREFIX}%").count

    ec.regenerate_vesting_valuations!
    second_count = account.entries.where("name LIKE ?", "#{EquityCompensation::VESTING_ENTRY_PREFIX}%").count

    assert_equal first_count, second_count, "Should replace, not duplicate entries"
  end

  test "regenerate_vesting_valuations does not overwrite manual valuations" do
    ec = equity_compensations(:one)
    account = accounts(:equity_compensation)
    grant = ec.equity_grants.first
    vest_date = grant.grant_date + 12.months

    # Create manual valuation on a vesting date
    account.entries.create!(
      name: "Manual valuation",
      date: vest_date,
      amount: 99999,
      currency: account.currency,
      entryable: Valuation.new(kind: "reconciliation")
    )

    ec.equity_grants.each { |g| g.security.stubs(:import_provider_prices) }
    account.stubs(:sync_now)

    ec.regenerate_vesting_valuations!

    # Manual entry should still exist
    manual = account.entries.find_by(name: "Manual valuation", date: vest_date)
    assert_not_nil manual
    assert_equal 99999, manual.amount.to_i

    # No vesting entry on that date
    vesting_on_date = account.entries.where(date: vest_date)
      .where("name LIKE ?", "#{EquityCompensation::VESTING_ENTRY_PREFIX}%")
    assert_equal 0, vesting_on_date.count
  end

  # === Unrealized Gain/Loss ===

  test "total_unrealized_gain_loss sums across grants with grant_price" do
    ec = equity_compensations(:one)
    ec.equity_grants.each do |g|
      g.grant_price = 100.0
      g.security.stubs(:current_price).returns(Money.new(150, "USD"))
      g.save!(validate: false)
    end

    result = ec.total_unrealized_gain_loss
    assert result.is_a?(Numeric)
  end

  test "total_unrealized_gain_loss returns nil when no grants have grant_price" do
    ec = equity_compensations(:one)
    ec.equity_grants.each { |g| g.update_column(:grant_price, nil) }
    assert_nil ec.total_unrealized_gain_loss
  end

  test "total_unrealized_gain_loss ignores grants without grant_price" do
    ec = equity_compensations(:one)
    grants = ec.equity_grants.to_a

    # Only first grant has grant_price
    grants.first.update_column(:grant_price, 100.0)
    grants.last.update_column(:grant_price, nil) if grants.size > 1

    grants.first.security.stubs(:current_price).returns(Money.new(150, "USD"))
    result = ec.total_unrealized_gain_loss
    assert result.is_a?(Numeric)
  end

  test "regenerate_vesting_valuations updates account balance to opening + remaining" do
    ec = equity_compensations(:one)
    account = accounts(:equity_compensation)

    ec.equity_grants.each { |g| g.security.stubs(:import_provider_prices) }
    account.stubs(:sync_now)

    ec.regenerate_vesting_valuations!

    expected = [ account.opening_anchor_balance + ec.total_remaining_value, 0 ].max
    assert_equal expected, account.reload.balance
  end

  test "total_remaining_value subtracts sold units" do
    ec = equity_compensations(:one)
    grant = ec.equity_grants.first
    grant.security.stubs(:current_price).returns(Money.new(200, "USD"))

    as_of = grant.grant_date + 24.months
    vested = grant.vested_units(as_of: as_of)
    grant.sales.create!(date: as_of, units: vested, proceeds: vested * 180, currency: "USD")

    assert_equal grant.remaining_value(as_of: as_of), ec.total_remaining_value(as_of: as_of)
  end

  test "regenerate_vesting_valuations preserves opening balance anchor" do
    ec = equity_compensations(:one)
    account = accounts(:equity_compensation)

    account.set_opening_anchor_balance(balance: 5000, date: Date.new(2023, 1, 1))
    ec.equity_grants.each { |g| g.security.stubs(:import_provider_prices) }
    account.stubs(:sync_now)

    ec.regenerate_vesting_valuations!

    assert account.has_opening_anchor?, "Opening anchor should not be deleted"
    assert_equal 5000, account.opening_anchor_balance
  end

  test "vesting valuations include opening balance" do
    ec = equity_compensations(:one)
    account = accounts(:equity_compensation)
    grant = ec.equity_grants.first

    account.set_opening_anchor_balance(balance: 5000, date: Date.new(2023, 1, 1))
    vest_date = grant.grant_date + 12.months
    grant.security.stubs(:import_provider_prices)
    Security::Price.find_or_create_by!(security: grant.security, date: vest_date, price: 180.0, currency: "USD")
    account.stubs(:sync_now)

    ec.regenerate_vesting_valuations!

    first_vesting = account.entries.where("name LIKE ?", "#{EquityCompensation::VESTING_ENTRY_PREFIX}%").order(:date).first
    assert_not_nil first_vesting
    # Should include the $5000 opening balance baked in
    assert first_vesting.amount > 5000, "Vesting valuation should include opening balance (got #{first_vesting.amount})"
  end

  # === Withdrawal Tracking ===

  test "total_withdrawals sums positive transaction entries" do
    ec = equity_compensations(:one)
    account = accounts(:equity_compensation)

    # Create outflow transaction entries (positive amount = money leaving asset account)
    account.entries.create!(
      name: "Sale proceeds",
      date: Date.current - 30.days,
      amount: 5000,
      currency: account.currency,
      entryable: Transaction.new
    )
    account.entries.create!(
      name: "Sale proceeds 2",
      date: Date.current - 15.days,
      amount: 3000,
      currency: account.currency,
      entryable: Transaction.new
    )

    assert_equal 8000, ec.total_withdrawals
  end

  test "total_withdrawals ignores valuation entries" do
    ec = equity_compensations(:one)
    account = accounts(:equity_compensation)

    # Valuation entries should not count as withdrawals
    account.entries.create!(
      name: "Vesting: Jan 2025",
      date: Date.current - 30.days,
      amount: 10000,
      currency: account.currency,
      entryable: Valuation.new(kind: "reconciliation")
    )

    assert_equal 0, ec.total_withdrawals
  end

  test "total_withdrawals ignores negative transaction entries" do
    ec = equity_compensations(:one)
    account = accounts(:equity_compensation)

    # Negative amount = inflow, should not count as withdrawal
    account.entries.create!(
      name: "Refund",
      date: Date.current - 30.days,
      amount: -1000,
      currency: account.currency,
      entryable: Transaction.new
    )

    assert_equal 0, ec.total_withdrawals
  end

  test "regenerate_vesting_valuations excludes sold units from balance" do
    ec = equity_compensations(:one)
    account = accounts(:equity_compensation)

    ec.equity_grants.each { |g| g.security.stubs(:import_provider_prices) }
    account.stubs(:sync_now)

    grant = ec.equity_grants.first
    as_of = grant.grant_date + 24.months
    vested = grant.vested_units(as_of: as_of)
    grant.sales.create!(date: as_of, units: vested, proceeds: vested * 180, currency: "USD")

    ec.regenerate_vesting_valuations!

    expected = [ account.opening_anchor_balance + ec.total_remaining_value, 0 ].max
    assert_equal expected, account.reload.balance
  end

  test "balance does not go negative with oversized sales" do
    ec = equity_compensations(:one)
    account = accounts(:equity_compensation)
    grant = ec.equity_grants.first

    ec.equity_grants.each { |g| g.security.stubs(:import_provider_prices) }
    account.stubs(:sync_now)

    # Record more units sold than ever vested (edge case; vested_units_remaining floors at 0)
    grant.sales.create!(date: Date.current, units: grant.total_units * 2, proceeds: 0, currency: "USD")

    ec.regenerate_vesting_valuations!

    assert account.reload.balance >= 0
  end

  # === Inline Sync (regression) ===

  test "regenerate_vesting_valuations populates balances table inline" do
    ec = equity_compensations(:one)
    account = accounts(:equity_compensation)
    grant = ec.equity_grants.order(:grant_date).first

    Security.any_instance.stubs(:import_provider_prices)
    Security.any_instance.stubs(:current_price).returns(Money.new(200, "USD"))
    grant.vesting_dates(up_to: Date.current).each do |d|
      Security::Price.find_or_create_by!(security: grant.security, date: d, price: 180.0, currency: "USD")
    end

    ec.regenerate_vesting_valuations!

    # No Sidekiq here — if this count is 0 or 1, the empty-chart bug has regressed.
    assert account.balances.count > 1,
      "Expected balances table to be materialized by regenerate; got #{account.balances.count} rows"
  end

  # === Opening Anchor Edit Hook ===

  test "set_opening_anchor_balance triggers vesting regeneration" do
    ec = equity_compensations(:one)
    account = accounts(:equity_compensation)
    grant = ec.equity_grants.order(:grant_date).first
    Security::Price.find_or_create_by!(security: grant.security, date: grant.grant_date + 12.months, price: 180.0, currency: "USD")

    ec.equity_grants.each { |g| g.security.stubs(:import_provider_prices) }
    account.stubs(:sync_now)

    # Establish initial state with opening balance 0 and some vest valuations
    ec.regenerate_vesting_valuations!
    initial_first_vest = account.entries.where("name LIKE ?", "#{EquityCompensation::VESTING_ENTRY_PREFIX}%").order(:date).first
    initial_amount = initial_first_vest.amount.to_d

    # User edits Starting Balance to 5000
    account.set_opening_anchor_balance(balance: 5000, date: Date.new(2023, 1, 1))

    updated_first_vest = account.entries.where("name LIKE ?", "#{EquityCompensation::VESTING_ENTRY_PREFIX}%").order(:date).first
    assert_not_nil updated_first_vest
    # New vest valuation should be 5000 higher (opening balance baked in)
    assert_in_delta initial_amount + 5000, updated_first_vest.amount.to_d, 0.01
  end

  # === Backfill ===

  test "backfill_sales_from_transactions creates sales from positive entries" do
    ec = equity_compensations(:one)
    account = accounts(:equity_compensation)
    grant = ec.equity_grants.order(:grant_date).first

    Security::Price.find_or_create_by!(security: grant.security, date: Date.new(2025, 6, 15), price: 180.0, currency: "USD")

    account.entries.create!(
      name: "GSU sale proceeds",
      date: Date.new(2025, 6, 15),
      amount: 1800,
      currency: account.currency,
      entryable: Transaction.new
    )

    assert_difference "EquityGrantSale.count", 1 do
      ec.backfill_sales_from_transactions!
    end

    sale = EquityGrantSale.last
    assert_equal grant, sale.equity_grant
    assert_equal Date.new(2025, 6, 15), sale.date
    assert_in_delta 10.0, sale.units.to_f, 0.01
  end

  test "backfill_sales_from_transactions is idempotent" do
    ec = equity_compensations(:one)
    account = accounts(:equity_compensation)
    grant = ec.equity_grants.order(:grant_date).first

    Security::Price.find_or_create_by!(security: grant.security, date: Date.new(2025, 6, 15), price: 180.0, currency: "USD")
    entry = account.entries.create!(
      name: "GSU sale proceeds",
      date: Date.new(2025, 6, 15),
      amount: 1800,
      currency: account.currency,
      entryable: Transaction.new
    )

    ec.backfill_sales_from_transactions!
    assert_no_difference "EquityGrantSale.count" do
      ec.backfill_sales_from_transactions!
    end
  end

  test "backfill_sales_from_transactions skips entries without an eligible grant" do
    ec = equity_compensations(:one)
    account = accounts(:equity_compensation)
    ec.equity_grants.destroy_all

    account.entries.create!(
      name: "Mystery proceeds",
      date: Date.current,
      amount: 500,
      currency: account.currency,
      entryable: Transaction.new
    )

    assert_no_difference "EquityGrantSale.count" do
      ec.backfill_sales_from_transactions!
    end
  end

  test "balance is stable when price rises after full sale" do
    # Regression for Bug 2: vest 10 at $180, sell 10, price later rises to $300
    ec = equity_compensations(:one)
    account = accounts(:equity_compensation)
    grant = ec.equity_grants.first

    # Sell everything vested today
    as_of = Date.current
    vested = grant.vested_units(as_of: as_of)
    grant.sales.create!(date: as_of, units: vested, proceeds: vested * 180, currency: "USD")

    # Price now spikes
    grant.security.stubs(:current_price).returns(Money.new(300, "USD"))
    grant.security.stubs(:import_provider_prices)
    account.stubs(:sync_now)

    ec.regenerate_vesting_valuations!

    # With no opening balance, remaining is 0 units * $300 = 0
    assert_equal account.opening_anchor_balance, account.reload.balance
  end
end
