require "application_system_test_case"

class MilestonesTest < ApplicationSystemTestCase
  setup do
    sign_in @user = users(:family_admin)
    @investment_account = accounts(:investment)
    @custom_milestone = milestones(:custom_goal)
  end

  test "can create custom milestone" do
    visit account_path(@investment_account)

    # Navigate to milestones section and click new
    within "[id*='milestones']" do
      click_link "New Milestone"
    end

    # Fill in the milestone form
    within "dialog" do
      fill_in "Name", with: "Test Retirement Goal"
      fill_in "milestone[target_amount]", with: 250000

      click_button "Create Milestone"
    end

    # Verify redirect back to account page
    assert_current_path account_path(@investment_account)
  end

  test "can delete custom milestone" do
    visit account_path(@investment_account)

    # Find the custom milestone and its delete button
    within "[id*='milestones']" do
      # Click the delete button for the custom milestone
      accept_confirm do
        find("button[title='Delete milestone']", match: :first).click
      end
    end

    # Verify the milestone is deleted
    assert_current_path account_path(@investment_account)
  end
end
