require "application_system_test_case"
require_relative "../support/projection_settings_scenario"

class ProjectionSettingsContextTest < ApplicationSystemTestCase
  include ProjectionSettingsScenario

  setup do
    setup_projection_settings_scenario
  end

  test "desktop settings update and reset preserve personal twenty-year context" do
    settings_context_journey("desktop")
  end

  test "mobile settings update and reset preserve personal twenty-year context" do
    page.current_window.resize_to(390, 844)
    settings_context_journey("mobile")
  end

  private
    def settings_context_journey(viewport)
      @viewport = viewport
      sign_in @viewer
      visit projections_path(tab: "investments", scope: "household", projection_years: 20)
      assert_settings_context(scope: "household", portfolio: "$500.00")
      within "#projections-content" do
        click_link "Personal"
      end
      assert_investment_state(projected: 2_500, contribution: 10, custom: false)
      evidence_screenshot("issue-137-#{viewport}-personal-before-update")

      # Leave a pre-mutation projection in history. Back must fetch new numbers,
      # not restore this snapshot after the update in a separate local browser tab.
      original_window = current_window
      click_link "Home", match: :first
      assert_current_path root_path
      editing_window = open_new_window
      within_window editing_window do
        page.current_window.resize_to(390, 844) if viewport == "mobile"
        visit projections_path(tab: "investments", scope: "personal", projection_years: 20)
        assert_investment_state(projected: 2_500, contribution: 10, custom: false)
      end
      switch_to_window editing_window
      mark_content_before_mutation
      within settings_form do
        fill_in "monthly_contribution", with: "200"
        # Number fields auto-submit on change, which fires when focus leaves the field.
        find("input[name='monthly_contribution']").send_keys(:tab)
      end
      assert_content_refreshed
      # Independent zero-return oracle: 100 + 200 * (20 * 12) = 48,100.
      assert_investment_state(projected: 48_100, contribution: 200, custom: true)
      assert_equal 200, @investment.reload.projection_assumption.monthly_contribution
      evidence_screenshot("issue-137-#{viewport}-after-update")
      switch_to_window original_window
      page.go_back
      assert_investment_state(projected: 48_100, contribution: 200, custom: true)
      editing_window.close
      switch_to_window original_window
      evidence_screenshot("issue-137-#{viewport}-stale-back-refetched")
      assert_reload_and_back(projected: 48_100, contribution: 200, custom: true)

      reset_button = find("##{settings_id} button", text: "Reset to family defaults")
      reset_form = reset_button.find(:xpath, "ancestor::form[1]")
      assert_equal reset_account_projection_settings_path(@investment), URI.parse(reset_form["action"]).path
      assert_selector "##{settings_id} form input[name='_method'][value='delete']", visible: :all
      assert_equal "projections-content", reset_form["data-turbo-frame"]
      assert_equal "replace", reset_form["data-turbo-action"]
      assert_submitted_context(reset_form)
      mark_content_before_mutation
      reset_button.click
      assert_content_refreshed
      # Reset must restore the family default: 100 + 10 * 240 = 2,500.
      assert_investment_state(projected: 2_500, contribution: 10, custom: false)
      assert_nil @investment.reload.projection_assumption
      evidence_screenshot("issue-137-#{viewport}-after-reset")
      assert_reload_and_back(projected: 2_500, contribution: 10, custom: false)
      evidence_screenshot("issue-137-#{viewport}-after-back")

      within "#projections-content" do
        click_link "Household"
      end
      assert_settings_context(scope: "household", portfolio: "$500.00")
      within "#projections-content" do
        click_link "Personal"
      end
      assert_investment_state(projected: 2_500, contribution: 10, custom: false)
    end

    def assert_reload_and_back(projected:, contribution:, custom:)
      page.refresh
      assert_investment_state(projected: projected, contribution: contribution, custom: custom)

      # Use a real Turbo navigation so Back exercises snapshot restoration, not just visit().
      click_link "Home", match: :first
      assert_current_path root_path
      assert_text "Welcome back, #{@viewer.first_name}"
      page.go_back
      assert_investment_state(projected: projected, contribution: contribution, custom: custom)
    end

    def assert_settings_context(scope: "personal", portfolio: "$200.00")
      assert_current_path projections_path(tab: "investments", scope: scope, projection_years: 20)
      assert_equal({ "tab" => "investments", "scope" => scope, "projection_years" => "20" },
        Rack::Utils.parse_query(URI.parse(page.current_url).query))
      assert_selector "head meta[name='turbo-cache-control'][content='no-cache']", visible: :all
      within "#projections-content" do
        assert_selector "a.bg-container", text: scope.capitalize, exact_text: true
        assert_selector "nav a.shadow-sm", text: "Investments", exact_text: true
        within "form[action='#{projections_path}']" do
          assert_select "projection_years", selected: "20 years"
          assert_selector "input[name='scope'][value='#{scope}']", visible: :all
          assert_selector "input[name='tab'][value='investments']", visible: :all
        end
        within find("p", text: "Total Portfolio Value", exact_text: true).find(:xpath, "..") do
          assert_selector "p", text: portfolio, exact_text: true
        end
        assert_text @shared.name
        assert_no_text @hidden.name
        assert_no_selector "a[href='#{account_path(@hidden)}']", visible: :all
        assert_no_selector "#projection_chart_canvas_account_#{@hidden.id}", visible: :all
      end
    end

    def assert_investment_state(projected:, contribution:, custom:)
      assert_equal [ 390, 844 ], page.evaluate_script("[window.innerWidth, window.innerHeight]") if @viewport == "mobile"
      assert_settings_context
      card = find("details", text: @investment.name)
      within card.find("summary", match: :first) do
        assert_selector "p", text: "20y projected", exact_text: true
        assert_selector "p", text: Money.new(projected, "USD").format, exact_text: true
      end
      card.find("summary p", text: "20y projected", exact_text: true).click unless card["open"]

      within "#projection_chart_account_#{@investment.id}" do
        assert_selector "p.text-3xl", text: Money.new(projected, "USD").format, exact_text: true
        assert_selector "p", text: "in 20 years", exact_text: true
        assert_selector "p", text: "+#{Money.new(projected - 100, 'USD').format} growth", exact_text: true
        assert_selector "p", text: "0.0% return, $#{contribution}/mo", exact_text: true
        chart = find("#projection_chart_canvas_account_#{@investment.id}")
        data = JSON.parse(chart["data-projection-chart-data-value"])
        assert_equal "USD", data.fetch("currency")
        assert_equal 100, data.fetch("historical").last.fetch("value")
        points = data.fetch("projections")
        assert_equal 241, points.length
        assert_equal Date.current.iso8601, points.first.fetch("date")
        assert_equal (Date.current + 240.months).iso8601, points.last.fetch("date")
        # With zero volatility every monthly percentile must equal principal + contributions.
        points.each_with_index do |point, month|
          %w[p10 p25 p50 p75 p90].each do |percentile|
            assert_equal 100 + contribution * month, point.fetch(percentile),
              "#{percentile} at month #{month}"
          end
        end
        assert_selector "svg"
      end

      panel = find("##{settings_id} details")
      panel.find("summary").click unless panel["open"]
      within "##{settings_id}" do
        if custom
          assert_selector "summary span", text: "Custom", exact_text: true
          assert_button "Reset to family defaults"
        else
          assert_no_selector "summary span", text: "Custom", exact_text: true
          assert_no_button "Reset to family defaults"
        end
      end
      form = settings_form
      assert_equal "projections-content", form["data-turbo-frame"]
      assert_equal "replace", form["data-turbo-action"]
      assert_submitted_context(form)
      within form do
        assert_field "monthly_contribution", with: contribution.to_s
        assert_field "expected_return", with: "0.0"
        assert_field "volatility", with: "0.0"
        assert_unchecked_field "use_pag_defaults"
        assert_select "projection_years", selected: "20 years"
      end
    end

    def assert_submitted_context(form)
      # Context may be carried by URL parameters or hidden controls (button_to uses both).
      params = Rack::Utils.parse_query(URI.parse(form["action"]).query)
      form.all("input[type='hidden']", visible: :all).each do |input|
        params[input["name"]] = input["value"]
      end
      form.all("select[name]", visible: :all).each do |select|
        params[select["name"]] = select.value
      end
      assert_equal "investments", params.fetch("tab")
      assert_equal "personal", params.fetch("scope")
      assert_equal "20", params.fetch("projection_years")
    end

    def settings_id
      "projection_settings_account_#{@investment.id}"
    end

    def settings_form
      find("##{settings_id} form[action='#{account_projection_settings_path(@investment)}']")
    end

    def mark_content_before_mutation
      # A chart/settings-only stream patch leaves this sibling behind. The entire
      # enclosing frame must be replaced, including the collapsed summary and toolbar.
      page.execute_script(<<~JS)
        document.querySelector("#projections-content > div")
          .setAttribute("data-issue-137-before-mutation", "true");
      JS
    end

    def assert_content_refreshed
      assert_no_selector "[data-issue-137-before-mutation]", visible: :all
      assert_selector "#projections-content", count: 1
    end

    def evidence_screenshot(name)
      return unless ENV["AUTONOMY_BROWSER_EVIDENCE"] == "true"

      path = Rails.root.join("tmp", "screenshots", "#{name}.png")
      FileUtils.mkdir_p(path.dirname)
      if @viewport == "mobile"
        page.execute_script("document.querySelector('main').scrollTop = 0")
        page.save_screenshot(path.sub_ext(".context.png"))
        page.execute_script("document.querySelector('#projection_chart_account_#{@investment.id}').scrollIntoView({block: 'start'})")
      end
      page.save_screenshot(path)
    end
end
