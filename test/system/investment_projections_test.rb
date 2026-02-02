require "application_system_test_case"

class InvestmentProjectionsTest < ApplicationSystemTestCase
  setup do
    sign_in @user = users(:family_admin)
    @investment_account = accounts(:investment)
  end

  test "investments tab shows projection chart for account" do
    visit projections_path(tab: "investments")

    # Verify the investments tab is shown
    assert_text "Investment Accounts"

    # Find the account card and expand it
    account_card = find("details", text: @investment_account.name)
    account_card.find("summary").click

    # The projection chart should be rendered within the expanded details
    within account_card do
      assert_selector "[data-controller='projection-chart']"
    end
  end

  test "expanded account card shows projection chart" do
    visit projections_path(tab: "investments")

    # Find and expand the account card
    account_card = find("details", text: @investment_account.name)
    account_card.find("summary").click

    within account_card do
      # Check that the projection chart controller and related content is displayed
      assert_selector "[data-controller='projection-chart']"
      assert_text "Projected Balance"
    end
  end
end
