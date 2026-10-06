require "test_helper"
require_relative "../support/projection_settings_scenario"

class ProjectionSettingsContextControllerTest < ActionDispatch::IntegrationTest
  include ProjectionSettingsScenario

  setup do
    setup_projection_settings_scenario
    sign_in @viewer
  end

  [ :html, :turbo_stream ].each do |format|
    test "#{format} update and reset retain personal twenty-year context and refresh summaries" do
      context = { tab: "investments", scope: "personal", projection_years: "20" }
      patch account_projection_settings_path(@investment), params: context.merge(
        expected_return: "0", volatility: "0", monthly_contribution: "200", use_pag_defaults: "0"
      ), as: format
      assert_response :see_other
      assert_redirected_to projections_path(context)
      follow_redirect!
      assert_investment_summary(48_100)

      delete reset_account_projection_settings_path(@investment), params: context, as: format
      assert_response :see_other
      assert_redirected_to projections_path(context)
      follow_redirect!
      assert_investment_summary(2_500)
      get projections_path(context)
      assert_investment_summary(2_500)
    end
  end

  test "overview cache refreshes on non-latest reset and same-second updates" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @investment.update!(balance: 100)
    # Ensure another row remains latest, so MAX(updated_at) cannot detect reset.
    ProjectionAssumption.create_for_account(@investment, monthly_contribution: 200)
    @family.projection_assumptions.family_default.first.update_columns(updated_at: 1.minute.from_now)
    context = { tab: "overview", scope: "personal", projection_years: 20 }
    get projections_path(context)
    assert_overview_projection(48_800) # 100 + 200*240, plus 25% of shared (400 + 10*240)
    delete reset_account_projection_settings_path(@investment), params: context
    follow_redirect!
    assert_overview_projection(3_200) # Own 100 + 10*240, plus 25% of shared (400 + 10*240)

    frozen = Time.current.change(usec: 100_000)
    travel_to frozen, with_usec: true do
      patch account_projection_settings_path(@investment), params: context.merge(
        expected_return: "0", volatility: "0", monthly_contribution: "200"
      )
      follow_redirect!
      assert_overview_projection(48_800)
      travel_to frozen.change(usec: 200_000), with_usec: true
      patch account_projection_settings_path(@investment), params: context.merge(
        expected_return: "0", volatility: "0", monthly_contribution: "300"
      )
      follow_redirect!
      assert_overview_projection(72_800)
    end
  ensure
    Rails.cache = original_cache
  end

  test "all valid tabs survive update and reset" do
    %w[overview investments debts strategies].each do |tab|
      context = { tab: tab, scope: "personal", projection_years: 20 }
      patch account_projection_settings_path(@investment), params: context.merge(
        expected_return: "0", volatility: "0", monthly_contribution: "200"
      )
      assert_redirected_to projections_path(context)
      delete reset_account_projection_settings_path(@investment), params: context
      assert_redirected_to projections_path(context)
    end
  end

  test "invalid context uses documented defaults without imposing a new horizon cap" do
    [ nil, "", "bogus", "0", "-20", "20junk", "2.5" ].each do |years|
      context = { tab: "external", scope: "external", projection_years: years }
      patch account_projection_settings_path(@investment), params: context.merge(
        expected_return: "0", volatility: "0", monthly_contribution: "200"
      )
      assert_redirected_to projections_path(tab: "investments", scope: "household", projection_years: 10)
      delete reset_account_projection_settings_path(@investment), params: context
      assert_redirected_to projections_path(tab: "investments", scope: "household", projection_years: 10)
      get projections_path(context)
      assert_response :success
      assert_select "input[name='tab'][value='overview']"
      assert_select "input[name='scope'][value='household']"
      assert_select "select[name='projection_years'] option[selected][value='10']"
    end
    patch account_projection_settings_path(@investment), params: { projection_years: 40 }
    assert_redirected_to projections_path(tab: "investments", scope: "household", projection_years: 40)
  end

  test "context cannot bypass hidden or cross-family account access on either action" do
    [ @hidden, accounts(:investment) ].each do |restricted|
      assumption = ProjectionAssumption.create_for_account(restricted,
        expected_return: 0, volatility: 0, monthly_contribution: 75, use_pag_defaults: false)
      original = assumption.attributes
      patch account_projection_settings_path(restricted), params: {
        tab: "investments", scope: "personal", projection_years: 20,
        expected_return: "0", monthly_contribution: "200"
      }
      assert_response :not_found
      assert_equal original, assumption.reload.attributes
      delete reset_account_projection_settings_path(restricted), params: {
        tab: "investments", scope: "personal", projection_years: 20
      }
      assert_response :not_found
      assert_equal assumption.id, restricted.reload.projection_assumption.id
      assert_equal original, assumption.reload.attributes
    end
  end

  private
    def assert_overview_projection(projected)
      assert_response :success
      data = JSON.parse(css_select("#net-worth-projection-chart").sole["data-projection-chart-data-value"])
      assert_equal projected, data.fetch("projections").last.fetch("p50")
      assert_equal 200, data.fetch("historical").last.fetch("value")
    end

    def assert_investment_summary(projected)
      assert_response :success
      assert_select "turbo-frame#projections-content", count: 1
      assert_select "input[name='scope'][value='personal']"
      assert_select "input[name='tab'][value='investments']"
      assert_select "select[name='projection_years'] option[selected][value='20']"
      assert_select "p", text: "$200.00"
      assert_select "p", text: "20y projected"
      assert_select "p.font-medium", text: Money.new(projected, "USD").format
      assert_select "p.text-3xl", text: Money.new(projected, "USD").format
      assert_select "p", text: "+#{Money.new(projected - 100, 'USD').format} growth"
      data = JSON.parse(css_select("#projection_chart_canvas_account_#{@investment.id}").sole["data-projection-chart-data-value"])
      assert_equal projected, data.fetch("projections").last.fetch("p50")
      assert_select "body", text: /Synthetic hidden investment/, count: 0
    end
end
