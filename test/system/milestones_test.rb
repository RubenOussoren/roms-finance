require "application_system_test_case"

class MilestonesTest < ApplicationSystemTestCase
  setup do
    sign_in @user = users(:family_admin)
    @investment_account = accounts(:investment)
    @custom_milestone = milestones(:custom_goal)
  end

  test "can create custom milestone" do
    visit projections_path(tab: "investments")

    # Find the account card and expand it to show milestones
    account_card = find("details", text: @investment_account.name)
    account_card.find("summary").click

    # Click the Add button to open the dropdown menu
    within account_card do
      click_button "Add"
    end

    # Click Custom milestone from the dropdown (rendered outside the account card)
    click_link "Custom milestone"

    # Fill in the milestone form in the modal dialog
    within "dialog" do
      fill_in "Name", with: "Test Retirement Goal"
      fill_in "milestone[target_amount]", with: 250000

      click_button "Create Milestone"
    end

    # Verify redirect back to projections page
    assert_current_path projections_path(tab: "investments")
  end

  test "can delete custom milestone" do
    visit projections_path(tab: "investments")

    # Find and expand the account card
    account_card = find("details", text: @investment_account.name)
    account_card.find("summary").click

    # Find the delete button for a milestone (uses Turbo confirm dialog)
    within account_card do
      # Click the delete button - Turbo will show confirmation dialog
      find("button[title='Delete milestone']", match: :first).click
    end

    # Handle the Turbo confirm dialog
    within "#confirm-dialog" do
      click_button "Confirm"
    end

    # Verify we stay on the projections page
    assert_current_path projections_path(tab: "investments")
  end
end
