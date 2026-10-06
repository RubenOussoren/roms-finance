require "application_system_test_case"
require_relative "../support/projection_contribution_scenario"

class ProjectionContributionsTest < ApplicationSystemTestCase
  include ProjectionContributionScenario

  setup do
    setup_projection_contribution_scenario
  end

  test "guideline contributions persist through Turbo and reload on desktop" do
    contribution_journey("desktop")
  end

  test "guideline contributions persist through Turbo and reload on mobile" do
    page.current_window.resize_to(390, 844)
    contribution_journey("mobile")
  end

  private
    def contribution_journey(viewport)
      sign_in @viewer
      visit projections_path(tab: "investments", scope: "personal", projection_years: 5)
      open_settings
      assert_unchecked_field "use_pag_defaults"
      mark_before_submission
      within settings_form do
        find("input[type='checkbox'][name='use_pag_defaults']").check
      end
      assert_frame_refreshed
      assert_saved_state(100)
      mark_before_submission
      within settings_form do
        fill_in "monthly_contribution", with: "500"
        find("input[name='monthly_contribution']").send_keys(:tab)
      end
      assert_frame_refreshed
      assert_saved_state(500)
      screenshot("issue-136-#{viewport}-guidelines-500")
      page.refresh
      assert_saved_state(500)

      mark_before_submission
      within settings_form do
        fill_in "monthly_contribution", with: "0"
        find("input[name='monthly_contribution']").send_keys(:tab)
      end
      assert_frame_refreshed
      assert_saved_state(0)
      screenshot("issue-136-#{viewport}-guidelines-zero")
      page.refresh
      assert_saved_state(0)
    end

    def assert_saved_state(contribution)
      assert_current_path projections_path(tab: "investments", scope: "personal", projection_years: 5)
      open_settings
      # Verify the dependent card/chart as well as the settings form refreshed.
      assert_selector "#projection_chart_account_#{@investment.id} p.text-3xl",
        text: Money.new(100 + contribution * 60, "USD").format, exact_text: true
      within settings_form do
        assert_checked_field "use_pag_defaults"
        assert_field "monthly_contribution", with: contribution.to_s, disabled: false
        assert_field "expected_return", with: "0.0", disabled: true
        assert_field "volatility", with: "0.0", disabled: true
      end
      @assumption.reload
      assert_equal contribution, @assumption.monthly_contribution
      assert @assumption.use_pag_defaults
      assert_equal 25, @assumption.extra_monthly_payment
      assert_equal 100, @family_assumption.reload.monthly_contribution
      chart = find("#projection_chart_canvas_account_#{@investment.id}")
      points = JSON.parse(chart["data-projection-chart-data-value"]).fetch("projections")
      assert_equal 61, points.length
      points.each_with_index do |point, month|
        %w[p10 p25 p50 p75 p90].each do |percentile|
          assert_equal 100 + contribution * month, point.fetch(percentile)
        end
      end
      assert_no_text @hidden.name
    end

    def settings_selector
      "#projection_settings_account_#{@investment.id}"
    end

    def settings_form
      find("#{settings_selector} form[action='#{account_projection_settings_path(@investment)}']")
    end

    def open_settings
      card = find("details", text: @investment.name)
      card.find("summary p", text: "5y projected", exact_text: true).click unless card["open"]
      settings = find("#{settings_selector} details")
      settings.find("summary").click unless settings["open"]
    end

    def mark_before_submission
      page.execute_script("document.querySelector('#projections-content > div').setAttribute('data-contribution-before', 'true')")
    end

    def assert_frame_refreshed
      assert_no_selector "[data-contribution-before]", visible: :all
    end

    def screenshot(name)
      return unless ENV["AUTONOMY_BROWSER_EVIDENCE"] == "true"

      path = Rails.root.join("tmp", "screenshots", "#{name}.png")
      FileUtils.mkdir_p(path.dirname)
      find(settings_selector).scroll_to(:center)
      page.save_screenshot(path)
    end
end
