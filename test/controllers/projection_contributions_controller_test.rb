require "test_helper"
require_relative "../support/projection_contribution_scenario"

class ProjectionContributionsControllerTest < ActionDispatch::IntegrationTest
  include ProjectionContributionScenario

  setup do
    setup_projection_contribution_scenario
    sign_in @viewer
  end

  [ :html, :turbo_stream ].each do |format|
    test "#{format} guideline settings persist contributions, explicit zero and repeat submissions" do
      family_before = @family_assumption.attributes
      [ 500, 500, 0 ].each do |contribution|
        patch account_projection_settings_path(@investment), params: {
          tab: "investments", scope: "personal", projection_years: "5",
          use_pag_defaults: "1", monthly_contribution: contribution.to_s,
          expected_return: "29", volatility: "49"
        }, as: format
        assert_response :see_other
        assert_redirected_to projections_path(tab: "investments", scope: "personal", projection_years: 5)
        @assumption.reload
        assert_equal contribution, @assumption.monthly_contribution
        assert @assumption.use_pag_defaults
        assert_equal @standard.blended_return, @assumption.expected_return
        assert_equal @standard.volatility_equity, @assumption.volatility
        assert_equal @standard.inflation_rate, @assumption.inflation_rate
        assert_equal 25, @assumption.extra_monthly_payment
        assert_equal family_before, @family_assumption.reload.attributes
        follow_redirect!
        assert_saved_projection(contribution)
        get projections_path(tab: "investments", scope: "personal", projection_years: 5)
        assert_saved_projection(contribution)
      end
      assert_equal 1, ProjectionAssumption.where(account: @investment).count
    end
  end

  test "omitted contribution preserves existing cash flow while enabling guidelines" do
    patch account_projection_settings_path(@investment), params: { use_pag_defaults: "1" }
    assert_response :see_other
    assert_equal 100, @assumption.reload.monthly_contribution
    assert @assumption.use_pag_defaults
  end

  test "guideline submission preserves omission and saves zero without a configured standard" do
    @assumption.update!(projection_standard: nil, expected_return: 0.08, volatility: 0.2)
    [ nil, "500", "0" ].each do |contribution|
      settings = { use_pag_defaults: "1" }
      settings[:monthly_contribution] = contribution unless contribution.nil?
      patch account_projection_settings_path(@investment), params: settings
      assert_response :see_other
      expected_contribution = contribution.nil? ? 100 : contribution.to_i
      assert_equal expected_contribution, @assumption.reload.monthly_contribution
      assert_equal 0.08, @assumption.expected_return
      assert_equal 0.2, @assumption.volatility
      assert_not @assumption.use_pag_defaults
    end
  end

  test "first account-specific guideline submission saves its contribution" do
    @assumption.destroy!
    assert_difference "ProjectionAssumption.where(account: @investment).count", 1 do
      patch account_projection_settings_path(@investment), params: {
        use_pag_defaults: "1", monthly_contribution: "500"
      }
    end
    assert_response :see_other
    created = @investment.reload.projection_assumption
    assert_equal 500, created.monthly_contribution
    assert created.use_pag_defaults
    assert_equal @standard, created.projection_standard
    assert_equal 100, @family_assumption.reload.monthly_contribution
  end

  test "invalid guideline contribution cannot partially persist market changes" do
    before = @assumption.attributes
    patch account_projection_settings_path(@investment), params: {
      use_pag_defaults: "1", monthly_contribution: "-1"
    }
    assert_response :unprocessable_entity
    assert_equal before, @assumption.reload.attributes
  end

  test "guideline contribution cannot mutate hidden or cross-family settings" do
    [ @hidden, accounts(:investment) ].each do |restricted|
      assumption = ProjectionAssumption.create_for_account(restricted, monthly_contribution: 75)
      before = assumption.attributes
      patch account_projection_settings_path(restricted), params: {
        use_pag_defaults: "1", monthly_contribution: "500"
      }
      assert_response :not_found
      assert_equal before, assumption.reload.attributes
    end
  end

  private
    def assert_saved_projection(contribution)
      assert_response :success
      settings = "#projection_settings_account_#{@investment.id}"
      assert_select "#{settings} input[name='monthly_contribution'][value='#{contribution}']"
      assert_select "#{settings} input[name='use_pag_defaults'][checked]"
      assert_select "#{settings} input[name='expected_return'][disabled]"
      assert_select "#{settings} input[name='volatility'][disabled]"
      chart = css_select("#projection_chart_canvas_account_#{@investment.id}").sole
      data = JSON.parse(chart["data-projection-chart-data-value"])
      # Principal 100 plus 60 end-of-month contributions, zero return/volatility.
      data.fetch("projections").each_with_index do |point, month|
        %w[p10 p25 p50 p75 p90].each do |percentile|
          assert_equal 100 + contribution * month, point.fetch(percentile)
        end
      end
      assert_equal 61, data.fetch("projections").length
      assert_select "p.font-medium", text: Money.new(100 + contribution * 60, "USD").format
      assert_select "body", text: /Synthetic hidden investment/, count: 0
    end
end
