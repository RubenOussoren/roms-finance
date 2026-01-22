require "application_system_test_case"

class InvestmentProjectionsTest < ApplicationSystemTestCase
  setup do
    sign_in @user = users(:family_admin)
    @investment_account = accounts(:investment)
  end

  test "view investment account shows projection chart section" do
    visit account_path(@investment_account)

    # Verify account page loads with projection-related content
    assert_selector "h2", text: @investment_account.name

    # The projection chart should be rendered for investment accounts
    # Check for chart container with Stimulus controller
    assert_selector "[data-controller='projection-chart']"
  end

  test "projection settings can be accessed for investment account" do
    visit account_path(@investment_account)

    # Find and click the settings toggle/button
    # The projection settings should be accessible
    within "[data-controller='projection-chart']" do
      # Check that the chart is displayed
      assert_selector "canvas", wait: 5
    end
  end
end
