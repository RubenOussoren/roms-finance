require "test_helper"

class EquityGrantSaleTest < ActiveSupport::TestCase
  setup do
    @grant = equity_grants(:rsu_grant)
  end

  test "belongs to equity_grant" do
    sale = EquityGrantSale.new(
      equity_grant: @grant,
      date: Date.current,
      units: 10,
      proceeds: 1800,
      currency: "USD"
    )
    assert sale.valid?
    assert_equal @grant, sale.equity_grant
  end

  test "requires equity_grant" do
    sale = EquityGrantSale.new(date: Date.current, units: 10, proceeds: 1800, currency: "USD")
    assert_not sale.valid?
    assert sale.errors[:equity_grant].any?
  end

  test "requires date" do
    sale = EquityGrantSale.new(equity_grant: @grant, units: 10, proceeds: 1800, currency: "USD")
    assert_not sale.valid?
    assert sale.errors[:date].any?
  end

  test "requires positive units" do
    sale = EquityGrantSale.new(equity_grant: @grant, date: Date.current, units: 0, proceeds: 1800, currency: "USD")
    assert_not sale.valid?
    assert sale.errors[:units].any?

    sale.units = -1
    assert_not sale.valid?
  end

  test "requires non-negative proceeds" do
    sale = EquityGrantSale.new(equity_grant: @grant, date: Date.current, units: 10, proceeds: -1, currency: "USD")
    assert_not sale.valid?
    assert sale.errors[:proceeds].any?
  end

  test "requires currency" do
    sale = EquityGrantSale.new(equity_grant: @grant, date: Date.current, units: 10, proceeds: 1800)
    assert_not sale.valid?
    assert sale.errors[:currency].any?
  end

  test "optionally belongs to transaction entry" do
    sale = EquityGrantSale.new(
      equity_grant: @grant,
      date: Date.current,
      units: 10,
      proceeds: 1800,
      currency: "USD"
    )
    assert sale.valid?, "entry_id should be optional"
  end

  test "grant has many sales" do
    @grant.sales.create!(date: Date.current, units: 5, proceeds: 900, currency: "USD")
    @grant.sales.create!(date: Date.current + 1.day, units: 3, proceeds: 540, currency: "USD")
    assert_equal 2, @grant.sales.count
  end

  test "destroying grant destroys sales" do
    @grant.sales.create!(date: Date.current, units: 5, proceeds: 900, currency: "USD")
    sale_id = @grant.sales.first.id
    @grant.destroy
    assert_nil EquityGrantSale.find_by(id: sale_id)
  end
end
