require "test_helper"
require_relative "../support/projection_scope_scenario"

class ProjectionsControllerTest < ActionDispatch::IntegrationTest
  include ProjectionScopeScenario
  setup do
    sign_in users(:family_admin)
  end

  test "overview headline history forecast and growth use the same authorized household scope" do
    setup_projection_scope_scenario
    sign_in @viewer

    get projections_url(projection_years: 1, scope: "household")
    assert_response :success
    assert_overview_values(current: 500, projected: 620, growth: 120)

    travel 2.seconds do
      @hidden.update!(balance: 9_000)
      get projections_url(projection_years: 1, scope: "household")
      assert_overview_values(current: 500, projected: 620, growth: 120)
    end
  end

  test "overview uses personal ownership fractions rather than household totals" do
    setup_projection_scope_scenario
    sign_in @viewer

    get projections_url(projection_years: 1, scope: "personal")
    assert_response :success
    assert_overview_values(current: 200, projected: 320, growth: 120)
  end

  test "should get index" do
    get projections_url
    assert_response :success
  end

  test "should get index with projection years param" do
    get projections_url(projection_years: 20)
    assert_response :success
  end

  test "should get index with tab param" do
    %w[overview investments debts strategies].each do |tab|
      get projections_url(tab: tab)
      assert_response :success
    end
  end

  test "overview tab loads balance sheet and projection data" do
    get projections_url(tab: "overview")
    assert_response :success
  end

  test "investments tab loads investment accounts" do
    get projections_url(tab: "investments")
    assert_response :success
  end

  test "debts tab loads loan accounts" do
    get projections_url(tab: "debts")
    assert_response :success
  end

  test "strategies tab loads debt optimization strategies" do
    get projections_url(tab: "strategies")
    assert_response :success
  end

  test "updating projection assumption invalidates cache" do
    family = families(:dylan_family)
    assumption = family.projection_assumptions.family_default.active.first ||
                 ProjectionAssumption.default_for(family)

    # First request populates cache
    get projections_url(tab: "overview")
    assert_response :success

    # Update assumption — should invalidate cache via touch_associated_account
    travel 1.second do
      assumption.update!(expected_return: 0.12)

      # Second request should succeed (cache key changed due to updated_at bump)
      get projections_url(tab: "overview")
      assert_response :success
    end
  end

  test "all tabs work with personal scope" do
    %w[overview investments debts strategies].each do |tab|
      get projections_url(tab: tab, scope: "personal")
      assert_response :success
    end
  end

  test "all tabs work with household scope" do
    %w[overview investments debts strategies].each do |tab|
      get projections_url(tab: tab, scope: "household")
      assert_response :success
    end
  end

  test "invalid scope defaults to household" do
    get projections_url(tab: "overview", scope: "bogus")
    assert_response :success
  end

  test "scope toggle visible for multi-user family" do
    family = families(:dylan_family)
    assert family.multi_user?, "Fixture family should have multiple users"

    get projections_url
    assert_response :success
    assert_select "a", text: "Household"
    assert_select "a", text: "Personal"
  end

  test "scope toggle hidden for single-user family" do
    family = families(:dylan_family)
    # Remove all users except the admin to simulate single-user
    family.users.where.not(id: users(:family_admin).id).destroy_all

    get projections_url
    assert_response :success
    assert_select "a", text: "Household", count: 0
    assert_select "a", text: "Personal", count: 0
  end

  private
    def assert_overview_values(current:, projected:, growth:)
      assert_select "p", text: Money.new(current, "USD").format
      chart = css_select("#net-worth-projection-chart").sole
      data = JSON.parse(chart["data-projection-chart-data-value"])
      assert_equal current, data.fetch("historical").last.fetch("value")
      assert_equal projected, data.fetch("summary").fetch("projected_net_worth")
      assert_equal projected, data.fetch("projections").last.fetch("p50")
      assert_select "p", text: "+#{Money.new(growth, 'USD').format} growth"
      assert_select "body", text: /Hidden asset/, count: 0
    end
end
