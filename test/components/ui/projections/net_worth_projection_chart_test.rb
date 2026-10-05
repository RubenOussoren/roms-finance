require "test_helper"

class UI::Projections::NetWorthProjectionChartTest < ActiveSupport::TestCase
  test "growth uses the supplied authorized anchor, not a family-wide total" do
    component = build_chart(projected: 200, current: 100)
    assert_equal "$100.00", component.current_net_worth_formatted
    assert_equal "$200.00", component.projected_net_worth_formatted
    assert_equal 100, component.growth_amount
    assert_equal "$100.00", component.growth_formatted
    assert component.growth_positive?
  end

  test "negative and zero growth retain numeric semantics" do
    component = build_chart(projected: 0, current: 100)
    assert_equal(-100, component.growth_amount)
    assert_equal "-$100.00", component.growth_formatted
    assert_not component.growth_positive?

    component = build_chart(projected: 100, current: 100)
    assert_equal 0, component.growth_amount
    assert_not component.growth_positive?
  end

  test "missing projection is not interpreted as zero" do
    component = build_chart(projected: nil, current: 100)
    assert_nil component.growth_amount
    assert_equal "--", component.growth_formatted
    assert_equal "--", component.projected_net_worth_formatted
  end

  test "formatting follows the supplied anchor currency" do
    component = build_chart(projected: 200, current: 100, currency: "EUR")
    assert_equal Money.new(200, "EUR").format, component.projected_net_worth_formatted
    assert_equal Money.new(100, "EUR").format, component.growth_formatted
  end

  private
    def build_chart(projected:, current:, currency: "USD")
      UI::Projections::NetWorthProjectionChart.new(
        projection_data: { summary: { projected_net_worth: projected } }, years: 1,
        current_net_worth_money: Money.new(current, currency)
      )
    end
end
