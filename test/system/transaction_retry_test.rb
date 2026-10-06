require "application_system_test_case"

class TransactionRetrySystemTest < ApplicationSystemTestCase
  setup do
    impersonation_sessions(:in_progress).complete!
    @viewer = users(:family_member)
    @account = accounts(:depository)
    @income = categories(:income)
    @income.update!(classification: "income")
    @expense = categories(:food_and_drink)
    @date = Date.current.prev_month
  end

  test "desktop income repair keeps its amount date category and sign" do
    repair_transaction(nature: "inflow", category: @income, screenshot: "issue-152-desktop-income")
  end

  test "mobile expense repair keeps its amount date category and sign" do
    page.current_window.resize_to(390, 844)
    repair_transaction(nature: "outflow", category: @expense, screenshot: "issue-152-mobile-expense")
  end

  private
    def repair_transaction(nature:, category:, screenshot:)
      sign_in @viewer
      visit new_transaction_path(nature:)
      select @account.name, from: "Account"
      fill_in "Description", with: " " # HTML required accepts whitespace; server rejects it.
      fill_in "entry[amount]", with: "125.25"
      select category.name, from: "Category"
      fill_in "Date", with: @date.iso8601

      2.times do
        assert_no_difference [ "Entry.count", "Transaction.count" ] do
          click_button "Add transaction"
          assert_selector "[role='alert']", text: "Name can't be blank"
        end
        assert_field "entry[amount]", with: "125.25"
        assert_field "Date", with: @date.iso8601
        assert_select "Category", selected: category.name
        assert_selector "input[name='entry[nature]'][value='#{nature}']", visible: :all
        assert_selector "input[name='entry[account_id]'][value='#{@account.id}']", visible: :all
        assert_selector "a.bg-container", text: nature == "inflow" ? "Income" : "Expense"
      end
      evidence_screenshot(screenshot)

      name = "Synthetic repaired #{nature}"
      fill_in "Description", with: name
      click_button "Add transaction"
      assert_text "Transaction created"
      entry = Entry.find_by!(name:)
      assert_equal(nature == "inflow" ? -125.25.to_d : 125.25.to_d, entry.amount)
      assert_equal @date, entry.date
      assert_equal @account.id, entry.account_id
      assert_equal category.id, entry.transaction.category_id
    end

    def evidence_screenshot(name)
      return unless ENV["AUTONOMY_BROWSER_EVIDENCE"] == "true"

      path = Rails.root.join("tmp", "screenshots", "#{name}.png")
      FileUtils.mkdir_p(path.dirname)
      page.save_screenshot(path)
    end
end
