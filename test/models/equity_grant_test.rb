require "test_helper"

class EquityGrantTest < ActiveSupport::TestCase
  setup do
    @rsu_grant = equity_grants(:rsu_grant)
    @option_grant = equity_grants(:option_grant)
  end

  # === Validations ===

  test "valid rsu grant" do
    assert @rsu_grant.valid?
  end

  test "valid stock option grant" do
    assert @option_grant.valid?
  end

  test "requires grant_type" do
    @rsu_grant.grant_type = nil
    assert_not @rsu_grant.valid?
  end

  test "requires total_units greater than 0" do
    @rsu_grant.total_units = 0
    assert_not @rsu_grant.valid?

    @rsu_grant.total_units = -1
    assert_not @rsu_grant.valid?
  end

  test "requires vesting_period_months" do
    @rsu_grant.vesting_period_months = nil
    assert_not @rsu_grant.valid?
  end

  test "requires grant_date" do
    @rsu_grant.grant_date = nil
    assert_not @rsu_grant.valid?
  end

  test "stock option requires strike_price" do
    @option_grant.strike_price = nil
    assert_not @option_grant.valid?
  end

  test "stock option requires expiration_date" do
    @option_grant.expiration_date = nil
    assert_not @option_grant.valid?
  end

  test "stock option requires option_type" do
    @option_grant.option_type = nil
    assert_not @option_grant.valid?
  end

  test "rsu does not require strike_price" do
    @rsu_grant.strike_price = nil
    assert @rsu_grant.valid?
  end

  # === Vesting Logic ===

  test "vested_units is 0 before grant date" do
    assert_equal 0, @rsu_grant.vested_units(as_of: @rsu_grant.grant_date - 1.day)
  end

  test "vested_units is 0 during cliff period" do
    # Grant date + 6 months (still within 12 month cliff)
    assert_equal 0, @rsu_grant.vested_units(as_of: @rsu_grant.grant_date + 6.months)
  end

  test "vested_units after cliff" do
    # Grant date + 12 months = past cliff, 12/48 periods elapsed with monthly vesting
    vested = @rsu_grant.vested_units(as_of: @rsu_grant.grant_date + 12.months)
    expected = (1000.0 * 12 / 48).floor(4)
    assert_equal expected, vested
  end

  test "vested_units at halfway" do
    vested = @rsu_grant.vested_units(as_of: @rsu_grant.grant_date + 24.months)
    expected = (1000.0 * 24 / 48).floor(4)
    assert_equal expected, vested
  end

  test "vested_units fully vested at end" do
    vested = @rsu_grant.vested_units(as_of: @rsu_grant.grant_date + 48.months)
    assert_equal 1000.0, vested.to_f
  end

  test "vested_units capped at total after vesting period" do
    vested = @rsu_grant.vested_units(as_of: @rsu_grant.grant_date + 60.months)
    assert_equal 1000.0, vested.to_f
  end

  test "unvested_units is complement of vested" do
    as_of = @rsu_grant.grant_date + 24.months
    vested = @rsu_grant.vested_units(as_of: as_of)
    unvested = @rsu_grant.unvested_units(as_of: as_of)
    assert_equal @rsu_grant.total_units, vested + unvested
  end

  # === Quarterly Vesting ===

  test "quarterly vesting calculates correctly" do
    grant = EquityGrant.new(
      grant_type: "rsu",
      grant_date: Date.new(2024, 1, 1),
      total_units: 1200,
      cliff_months: 0,
      vesting_period_months: 48,
      vesting_frequency: "quarterly",
      equity_compensation: equity_compensations(:one),
      security: securities(:goog)
    )

    # 3 months = 1 quarterly period, 16 total periods (48/3)
    vested = grant.vested_units(as_of: Date.new(2024, 4, 1))
    expected = (1200.0 * 1 / 16).floor(4)
    assert_equal expected, vested
  end

  # === Annual Vesting ===

  test "annual vesting calculates correctly" do
    grant = EquityGrant.new(
      grant_type: "rsu",
      grant_date: Date.new(2024, 1, 1),
      total_units: 400,
      cliff_months: 0,
      vesting_period_months: 48,
      vesting_frequency: "annually",
      equity_compensation: equity_compensations(:one),
      security: securities(:goog)
    )

    # 12 months = 1 annual period, 4 total periods (48/12)
    vested = grant.vested_units(as_of: Date.new(2025, 1, 1))
    expected = (400.0 * 1 / 4).floor(4)
    assert_equal expected, vested
  end

  # === Stock Option Methods ===

  test "intrinsic_value_per_unit for stock option" do
    @option_grant.security.stubs(:current_price).returns(Money.new(200, "USD"))
    assert_equal 50, @option_grant.intrinsic_value_per_unit
  end

  test "intrinsic_value_per_unit is 0 when underwater" do
    @option_grant.security.stubs(:current_price).returns(Money.new(100, "USD"))
    assert_equal 0, @option_grant.intrinsic_value_per_unit
  end

  test "intrinsic_value_per_unit is nil for rsu" do
    assert_nil @rsu_grant.intrinsic_value_per_unit
  end

  test "exercise_cost for stock option" do
    # exercise_cost uses current vested_units (as_of: Date.current)
    expected = @option_grant.vested_units * @option_grant.strike_price
    assert_equal expected, @option_grant.exercise_cost
  end

  # === Vesting Progress ===

  test "vesting_progress returns percentage" do
    progress = @rsu_grant.vesting_progress(as_of: @rsu_grant.grant_date + 24.months)
    assert_equal 50.0, progress
  end

  test "vesting_progress is 0 before cliff" do
    progress = @rsu_grant.vesting_progress(as_of: @rsu_grant.grant_date + 6.months)
    assert_equal 0.0, progress
  end

  # === Next Vest Date ===

  test "next_vest_date returns next vesting date" do
    as_of = @rsu_grant.grant_date + 13.months
    next_date = @rsu_grant.next_vest_date(as_of: as_of)
    assert_not_nil next_date
    assert next_date > as_of
  end

  test "next_vest_date is nil when fully vested" do
    next_date = @rsu_grant.next_vest_date(as_of: @rsu_grant.grant_date + 60.months)
    assert_nil next_date
  end

  # === Tax Estimation ===

  test "estimated_tax with rate override" do
    @rsu_grant.estimated_tax_rate = 30.0
    @rsu_grant.security.stubs(:current_price).returns(Money.new(200, "USD"))
    as_of = @rsu_grant.grant_date + 24.months
    tax = @rsu_grant.estimated_tax(as_of: as_of)
    vested_val = @rsu_grant.vested_value(as_of: as_of)
    assert_in_delta vested_val * 0.30, tax, 0.01
  end

  test "estimated_tax is 0 when no rate" do
    @rsu_grant.estimated_tax_rate = nil
    assert_equal 0, @rsu_grant.estimated_tax
  end

  test "net_proceeds is vested_value minus tax" do
    @rsu_grant.estimated_tax_rate = 25.0
    @rsu_grant.security.stubs(:current_price).returns(Money.new(200, "USD"))
    as_of = @rsu_grant.grant_date + 24.months
    expected = @rsu_grant.vested_value(as_of: as_of) * 0.75
    assert_in_delta expected, @rsu_grant.net_proceeds(as_of: as_of), 0.01
  end

  # === Expiration ===

  test "expired stock option returns 0 vested_value" do
    @option_grant.expiration_date = Date.new(2025, 1, 1)
    @option_grant.security.stubs(:current_price).returns(Money.new(200, "USD"))
    assert_equal 0, @option_grant.vested_value(as_of: Date.new(2025, 6, 1))
  end

  test "expired stock option returns 0 unvested_value" do
    @option_grant.expiration_date = Date.new(2025, 1, 1)
    @option_grant.security.stubs(:current_price).returns(Money.new(200, "USD"))
    assert_equal 0, @option_grant.unvested_value(as_of: Date.new(2025, 6, 1))
  end

  test "non-expired stock option returns positive vested_value" do
    @option_grant.security.stubs(:current_price).returns(Money.new(200, "USD"))
    as_of = @option_grant.grant_date + 24.months
    assert @option_grant.vested_value(as_of: as_of) > 0
  end

  # === Termination ===

  test "termination caps vested units at termination date" do
    @rsu_grant.termination_date = @rsu_grant.grant_date + 24.months
    # After termination, vesting should be capped at 24 months
    vested_at_36 = @rsu_grant.vested_units(as_of: @rsu_grant.grant_date + 36.months)
    vested_at_24 = @rsu_grant.vested_units(as_of: @rsu_grant.grant_date + 24.months)
    assert_equal vested_at_24, vested_at_36
  end

  test "termination does not affect vesting before termination date" do
    @rsu_grant.termination_date = @rsu_grant.grant_date + 24.months
    vested = @rsu_grant.vested_units(as_of: @rsu_grant.grant_date + 18.months)
    expected = (1000.0 * 18 / 48).floor(4)
    assert_equal expected, vested
  end

  test "terminated? returns true when termination_date is set" do
    @rsu_grant.termination_date = Date.current
    assert @rsu_grant.terminated?
  end

  test "terminated? returns false when termination_date is nil" do
    assert_not @rsu_grant.terminated?
  end

  test "exercise_deadline is 90 days after termination for stock options" do
    @option_grant.termination_date = Date.new(2025, 6, 1)
    assert_equal Date.new(2025, 6, 1) + 90.days, @option_grant.exercise_deadline
  end

  test "exercise_deadline is nil for RSUs" do
    @rsu_grant.termination_date = Date.new(2025, 6, 1)
    assert_nil @rsu_grant.exercise_deadline
  end

  test "terminated stock option returns 0 vested_value after exercise deadline" do
    @option_grant.termination_date = Date.new(2025, 6, 1)
    @option_grant.security.stubs(:current_price).returns(Money.new(200, "USD"))
    assert_equal 0, @option_grant.vested_value(as_of: Date.new(2025, 6, 1) + 91.days)
  end

  test "terminated stock option returns positive vested_value before exercise deadline" do
    @option_grant.termination_date = @option_grant.grant_date + 24.months
    @option_grant.security.stubs(:current_price).returns(Money.new(200, "USD"))
    as_of = @option_grant.termination_date + 30.days
    assert @option_grant.vested_value(as_of: as_of) > 0
  end

  test "next_vest_date is nil after termination date" do
    @rsu_grant.termination_date = @rsu_grant.grant_date + 18.months
    assert_nil @rsu_grant.next_vest_date(as_of: @rsu_grant.grant_date + 19.months)
  end

  # === Fully Vested ===

  test "fully_vested? returns true when all units vested" do
    assert @rsu_grant.fully_vested?(as_of: @rsu_grant.grant_date + 48.months)
  end

  test "fully_vested? returns false during vesting" do
    assert_not @rsu_grant.fully_vested?(as_of: @rsu_grant.grant_date + 24.months)
  end

  # === Vesting Dates ===

  test "vesting_dates returns dates after cliff" do
    dates = @rsu_grant.vesting_dates(up_to: @rsu_grant.grant_date + 24.months)
    # Monthly vesting, 12-month cliff: first vest at 12 months, then 13..24
    assert_equal 13, dates.length
    assert_equal @rsu_grant.grant_date + 12.months, dates.first
    assert_equal @rsu_grant.grant_date + 24.months, dates.last
  end

  test "vesting_dates is empty before cliff" do
    dates = @rsu_grant.vesting_dates(up_to: @rsu_grant.grant_date + 6.months)
    assert_empty dates
  end

  test "vesting_dates respects termination" do
    @rsu_grant.termination_date = @rsu_grant.grant_date + 18.months
    dates = @rsu_grant.vesting_dates(up_to: @rsu_grant.grant_date + 36.months)
    assert dates.all? { |d| d <= @rsu_grant.termination_date }
  end

  test "vesting_dates for quarterly vesting" do
    grant = EquityGrant.new(
      grant_type: "rsu",
      grant_date: Date.new(2024, 1, 1),
      total_units: 1200,
      cliff_months: 0,
      vesting_period_months: 12,
      vesting_frequency: "quarterly",
      equity_compensation: equity_compensations(:one),
      security: securities(:goog)
    )
    dates = grant.vesting_dates(up_to: Date.new(2025, 1, 1))
    assert_equal 4, dates.length
    assert_equal Date.new(2024, 4, 1), dates.first
  end

  # === Price parameter ===

  test "vested_value uses provided price when given" do
    as_of = @rsu_grant.grant_date + 24.months
    value = @rsu_grant.vested_value(as_of: as_of, price: 100)
    units = @rsu_grant.vested_units(as_of: as_of)
    assert_equal units * 100, value
  end

  test "unvested_value uses provided price when given" do
    as_of = @rsu_grant.grant_date + 24.months
    value = @rsu_grant.unvested_value(as_of: as_of, price: 100)
    units = @rsu_grant.unvested_units(as_of: as_of)
    assert_equal units * 100, value
  end

  test "stock option vested_value with price param respects strike_price" do
    @option_grant.strike_price = 150
    as_of = @option_grant.grant_date + 24.months
    value = @option_grant.vested_value(as_of: as_of, price: 200)
    units = @option_grant.vested_units(as_of: as_of)
    assert_equal units * 50, value
  end
end
