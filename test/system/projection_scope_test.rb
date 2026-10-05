require "application_system_test_case"
require_relative "../support/projection_scope_scenario"

class ProjectionScopeTest < ApplicationSystemTestCase
  include ProjectionScopeScenario

  setup do
    setup_projection_scope_scenario
    sign_in @viewer
  end

  test "household overview and personal toggle retain authorized chart growth" do
    visit projections_path(projection_years: 1, scope: "household")
    assert_overview(current: 500, projected: 620)
    evidence_screenshot("issue-132-household")

    click_link "Personal"
    assert_overview(current: 200, projected: 320)
    evidence_screenshot("issue-132-personal")

    click_link "Household"
    assert_overview(current: 500, projected: 620)
  end

  test "mobile overview uses the same scoped anchor" do
    page.current_window.resize_to(390, 844)
    visit projections_path(projection_years: 1, scope: "personal")
    assert_overview(current: 200, projected: 320)
    evidence_screenshot("issue-132-mobile-personal")
  end

  private
    def assert_overview(current:, projected:)
      within find("p", text: /\ACurrent Net Worth/).find(:xpath, "..") do
        assert_text Money.new(current, "USD").format
      end
      within find("p", text: "Projected (1y)").find(:xpath, "..") do
        assert_text Money.new(projected, "USD").format
      end
      within find("#net-worth-projection-chart").find(:xpath, "../..") do
        assert_text Money.new(projected, "USD").format
        assert_text "+$120.00 growth"
      end
      assert_no_text @hidden.name
      data = JSON.parse(find("#net-worth-projection-chart")["data-projection-chart-data-value"])
      assert_equal current, data.fetch("historical").last.fetch("value")
      assert_equal projected, data.fetch("projections").last.fetch("p50")
      assert_selector "#net-worth-projection-chart svg"
    end

    def evidence_screenshot(name)
      return unless ENV["AUTONOMY_BROWSER_EVIDENCE"] == "true"

      path = Rails.root.join("tmp", "screenshots", "#{name}.png")
      FileUtils.mkdir_p(path.dirname)
      page.save_screenshot(path)
    end
end
