require "application_system_test_case"
require_relative "../support/equity_regeneration_scenario"

class EquityGrantRegenerationTest < ApplicationSystemTestCase
  include EquityRegenerationScenario

  setup do
    impersonation_sessions(:in_progress).complete!
  end

  test "deleting the last vested grant removes its value from the account chart" do
    setup_equity_regeneration_scenario
    sign_in users(:family_admin)
    visit account_path(@account, tab: :grants)
    assert_chart_balance("$1,000.00")
    assert_text "Synthetic vested RSU"
    evidence_screenshot("issue-122-before-delete")

    find("form[action='#{account_equity_grant_path(@account, @grant)}'] button").click
    assert_text "Delete this grant?"
    click_button "Confirm"

    assert_text "No equity grants yet"
    assert_chart_balance("$0.00")
    assert_empty generated_vesting_entries
    assert_materialized_equity_balance(0)
    evidence_screenshot("issue-122-after-delete")
    visit account_path(@account, tab: :grants)
    assert_chart_balance("$0.00")
  end

  test "mobile future-only edit preserves the legitimate starting balance" do
    setup_equity_regeneration_scenario(opening: 200)
    page.current_window.resize_to(390, 844)
    sign_in users(:family_admin)
    visit account_path(@account, tab: :grants)
    assert_chart_balance("$1,200.00")
    find("a[href='#{edit_account_equity_grant_path(@account, @grant)}']").click
    fill_in "Grant date", with: (Date.current + 1.year).iso8601
    click_button "Update grant"

    assert_text "Grant updated successfully."
    assert_text "Synthetic vested RSU"
    assert_chart_balance("$200.00")
    assert_empty generated_vesting_entries
    assert_equal 200, @anchor.reload.amount
    assert_materialized_equity_balance(200)
    evidence_screenshot("issue-122-mobile-future-only")
    visit account_path(@account, tab: :grants)
    assert_chart_balance("$200.00")
  end

  private
    def assert_chart_balance(text)
      within "#chart_account_#{@account.id}" do
        assert_selector "p.text-3xl", text: text, exact_text: true
      end
    end

    def evidence_screenshot(name)
      return unless ENV["AUTONOMY_BROWSER_EVIDENCE"] == "true"

      path = Rails.root.join("tmp", "screenshots", "#{name}.png")
      FileUtils.mkdir_p(path.dirname)
      page.save_screenshot(path)
    end
end
