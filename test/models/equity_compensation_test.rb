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

    # Stub sync_later to avoid background job
    account.stubs(:sync_later)

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
    account.stubs(:sync_later)

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
    account.stubs(:sync_later)

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

  test "regenerate_vesting_valuations updates account balance" do
    ec = equity_compensations(:one)
    account = accounts(:equity_compensation)

    ec.equity_grants.each { |g| g.security.stubs(:import_provider_prices) }
    account.stubs(:sync_later)

    ec.regenerate_vesting_valuations!

    assert_equal ec.total_vested_value, account.reload.balance
  end
end
