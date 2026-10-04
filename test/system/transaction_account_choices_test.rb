require "application_system_test_case"

class TransactionAccountChoicesTest < ApplicationSystemTestCase
  setup do
    impersonation_sessions(:in_progress).complete!
    @viewer = users(:family_member)
    @full = accounts(:depository)
    @balance_only = accounts(:credit_card)
    @hidden = accounts(:loan)
    @balance_only.account_permissions.create!(user: @viewer, visibility: "balance_only")
    @hidden.account_permissions.create!(user: @viewer, visibility: "hidden")
  end

  test "member sees writable choices and completes a manual expense" do
    sign_in @viewer
    visit new_transaction_path

    assert_selectable_accounts
    evidence_screenshot("issue-151-writable-accounts")
    select @full.name, from: "Account"
    fill_in "Description", with: "Synthetic grocery purchase"
    fill_in "entry[amount]", with: "12.00"
    click_button "Add transaction"

    assert_text "Transaction created"
    assert_equal @full.id, Entry.find_by!(name: "Synthetic grocery purchase").account_id
  end

  test "mobile form offers the same writable choices" do
    page.current_window.resize_to(390, 844)
    sign_in @viewer
    visit new_transaction_path
    assert_selectable_accounts
    evidence_screenshot("issue-151-mobile-writable-accounts")
  end

  test "no writable manual accounts gives an actionable setup step" do
    @viewer.family.accounts.manual.active.each do |account|
      account.account_permissions.find_or_initialize_by(user: @viewer).update!(visibility: "hidden")
    end
    sign_in @viewer
    visit new_transaction_path

    assert_selector "[data-testid='transaction-accounts-empty']", text: "Add a manual account or ask its owner for full access"
    assert_link "Add an account", href: new_account_path
    assert_no_button "Add transaction"
    assert_no_selector "select[name='entry[account_id]']"
    evidence_screenshot("issue-151-empty-state")
    click_link "Add an account"
    assert_text "What would you like to add?"
  end

  private
    def assert_selectable_accounts
      assert_selector "select[name='entry[account_id]'] option[value='#{@full.id}']", visible: :all, text: @full.name
      [ @balance_only, @hidden, accounts(:connected) ].each do |account|
        assert_no_selector "select[name='entry[account_id]'] option[value='#{account.id}']", visible: :all
      end
    end

    def evidence_screenshot(name)
      return unless ENV["AUTONOMY_BROWSER_EVIDENCE"] == "true"

      path = Rails.root.join("tmp", "screenshots", "#{name}.png")
      FileUtils.mkdir_p(path.dirname)
      page.save_screenshot(path)
    end
end
