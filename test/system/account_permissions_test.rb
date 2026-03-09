require "application_system_test_case"

class AccountPermissionsTest < ApplicationSystemTestCase
  setup do
    sign_in @user = users(:family_admin)
    @member = users(:family_member)
    @account = accounts(:depository)
  end

  test "can change account visibility for family member" do
    visit account_path(@account)

    # Open account menu and click Privacy settings
    within_testid("account-menu") do
      find("button").click
      click_on "Privacy settings"
    end

    # Assert dialog opens
    assert_text "Sharing & Ownership"
    assert_text @member.display_name

    # Change visibility to "Balance only"
    select "Balance only", from: "permissions[#{@member.id}]"

    click_button "Save settings"

    assert_text "Settings updated"

    # Verify the permission record was created
    permission = @account.account_permissions.find_by(user_id: @member.id)
    assert_not_nil permission
    assert_equal "balance_only", permission.visibility
  end

  test "can set ownership split percentages" do
    visit account_path(@account)

    within_testid("account-menu") do
      find("button").click
      click_on "Privacy settings"
    end

    assert_text "Ownership split"

    # Fill ownership percentages
    all("input[name^='ownerships']").each do |input|
      if input["name"].include?(@user.id.to_s)
        input.fill_in with: "60"
      elsif input["name"].include?(@member.id.to_s)
        input.fill_in with: "40"
      end
    end

    click_button "Save settings"

    assert_text "Settings updated"

    # Verify ownership records
    @account.reload
    admin_ownership = @account.account_ownerships.find_by(user_id: @user.id)
    member_ownership = @account.account_ownerships.find_by(user_id: @member.id)

    assert_not_nil admin_ownership
    assert_equal 60, admin_ownership.percentage.to_i

    assert_not_nil member_ownership
    assert_equal 40, member_ownership.percentage.to_i
  end

  test "joint account disables visibility controls" do
    @account.update!(is_joint: true)

    visit account_path(@account)

    within_testid("account-menu") do
      find("button").click
      click_on "Privacy settings"
    end

    assert_text "Sharing & Ownership"
    assert_text "joint account"

    # Verify dropdowns are disabled
    assert_selector "select[disabled]"
  end
end
