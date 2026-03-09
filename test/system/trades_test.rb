require "application_system_test_case"

class TradesTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    sign_in @user = users(:family_admin)

    @user.update!(show_sidebar: false, show_ai_sidebar: false)

    @account = accounts(:investment)

    visit_account_portfolio

    # Disable provider to focus on form testing
    Security.stubs(:provider).returns(nil)
  end

  test "can create buy transaction" do
    shares_qty = 25

    open_new_trade_modal

    within "dialog" do
      fill_in "Ticker symbol", with: "AAPL"
      fill_in "Date", with: Date.current.iso8601
      fill_in "Quantity", with: shares_qty
      fill_in "model[price]", with: 214.23

      click_button "Add transaction"
    end

    assert_text "Entry created"

    visit_trades

    within_trades do
      assert_text "Buy #{shares_qty}.0 shares of AAPL"
    end
  end

  test "can create sell transaction" do
    qty = 10
    aapl = @account.holdings.find { |h| h.security.ticker == "AAPL" }

    open_new_trade_modal(type: "sell")

    within "dialog" do
      fill_in "Ticker symbol", with: "AAPL"
      fill_in "Date", with: Date.current.iso8601
      fill_in "Quantity", with: qty
      fill_in "model[price]", with: 215.33

      click_button "Add transaction"
    end

    assert_text "Entry created"

    visit_trades

    within_trades do
      assert_text "Sell #{qty}.0 shares of AAPL"
    end
  end

  private
    def open_new_trade_modal(type: "buy")
      click_on "New transaction"
      assert_selector "dialog[open]"

      if type != "buy"
        within "dialog" do
          select type.capitalize, from: "Type"
        end
        # The type change triggers a Turbo frame reload. Wait for it to complete
        # by checking the frame is no longer busy, then re-verify dialog is open.
        assert_no_selector "turbo-frame#modal[busy]"
        assert_selector "dialog[open]"
      end
    end

    def within_trades(&block)
      within "#" + dom_id(@account, "entries"), &block
    end

    def visit_trades
      visit account_path(@account, tab: "activity")
    end

    def visit_account_portfolio
      visit account_path(@account, tab: "holdings")
    end
end
