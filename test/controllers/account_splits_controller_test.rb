require "test_helper"

class AccountSplitsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @family = families(:dylan_family)

    @mortgage_loan = Loan.create!(
      interest_rate: 4.9,
      term_months: 360,
      rate_type: "fixed"
    )

    @mortgage = Account.create!(
      family: @family,
      created_by_user: @user,
      name: "TD Mortgage",
      balance: 707595,
      currency: "CAD",
      subtype: "mortgage",
      accountable: @mortgage_loan,
      plaid_account: plaid_accounts(:one)
    )
  end

  test "new renders split form" do
    get new_account_split_path(@mortgage)
    assert_response :success
  end

  test "create sets up mortgage split with HELOC" do
    assert_difference "Account.count", 1 do
      post account_split_path(@mortgage), params: {
        split: {
          origination_date: "2024-07-01",
          interest_rate: "4.9",
          rate_type: "fixed",
          term_months: "360",
          heloc_name: "TD HELOC",
          heloc_balance: "15110"
        }
      }
    end

    assert_redirected_to account_path(@mortgage)

    @mortgage_loan.reload
    assert_equal Date.new(2024, 7, 1), @mortgage_loan.origination_date
    assert_equal 4.9, @mortgage_loan.interest_rate.to_f
    assert_equal 360, @mortgage_loan.term_months

    heloc = Account.order(created_at: :desc).first
    assert_equal "TD HELOC", heloc.name
    assert_equal "home_equity", heloc.subtype
    assert_equal @mortgage.id, heloc.split_source_id
    assert_equal 15110, heloc.balance.to_f
  end

  test "create uses default HELOC name when none provided" do
    post account_split_path(@mortgage), params: {
      split: {
        origination_date: "2024-07-01",
        interest_rate: "4.9",
        rate_type: "fixed",
        term_months: "360",
        heloc_name: "",
        heloc_balance: "15110"
      }
    }

    heloc = Account.order(created_at: :desc).first
    assert_equal "TD Mortgage HELOC", heloc.name
  end

  test "destroy removes split and merges balances" do
    # Create the HELOC first
    heloc_loan = Loan.create!(rate_type: "variable")
    heloc = @family.accounts.create!(
      name: "TD HELOC",
      accountable: heloc_loan,
      subtype: "home_equity",
      balance: 15000,
      currency: "CAD",
      created_by_user: @user,
      split_source: @mortgage
    )

    assert_difference "Account.count", -1 do
      delete account_split_path(@mortgage)
    end

    assert_redirected_to account_path(@mortgage)
    assert_not Account.exists?(heloc.id)
  end
end
