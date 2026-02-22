require "test_helper"

class Account::BalanceSplittableTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @user = users(:family_admin)

    # Create a mortgage account with amortization data
    @mortgage_loan = Loan.create!(
      interest_rate: 4.9,
      term_months: 360,
      rate_type: "fixed",
      origination_date: Date.new(2024, 7, 1)
    )

    @mortgage = Account.create!(
      family: @family,
      created_by_user: @user,
      name: "TD Mortgage",
      balance: 800000,
      currency: "CAD",
      subtype: "mortgage",
      accountable: @mortgage_loan
    )
  end

  test "split_source? returns false when no split targets exist" do
    assert_not @mortgage.split_source?
  end

  test "split_target? returns false when split_source_id is nil" do
    assert_not @mortgage.split_target?
  end

  test "split_source? returns true when split targets exist" do
    heloc = create_heloc_for(@mortgage)
    assert @mortgage.split_source?
    assert heloc.split_target?
  end

  test "compute_balance_split returns nil when no split targets" do
    assert_nil @mortgage.compute_balance_split(707595)
  end

  test "compute_balance_split returns split result with valid amortization" do
    heloc = create_heloc_for(@mortgage)

    # Use a combined balance larger than expected mortgage to ensure
    # amortization isn't capped and HELOC gets a positive remainder
    expected_mortgage = @mortgage_loan.expected_balance_at(Date.current)
    combined = expected_mortgage + 15000

    result = @mortgage.compute_balance_split(combined)
    assert_not_nil result

    # Source balance should be the expected mortgage balance at today
    assert_equal expected_mortgage, result.source_balance

    # Target gets the remainder
    assert_equal 1, result.target_adjustments.length
    assert_equal heloc, result.target_adjustments.first[:account]
    assert_in_delta(15000, result.target_adjustments.first[:balance], 0.01)
  end

  test "compute_balance_split caps source balance at combined balance" do
    # If amortization says mortgage is more than combined (shouldn't happen in practice),
    # it caps at combined and HELOC gets 0
    heloc = create_heloc_for(@mortgage)

    # Use a very small combined balance
    result = @mortgage.compute_balance_split(100)
    assert_not_nil result
    assert_equal 100, result.source_balance
    assert_equal 0, result.target_adjustments.first[:balance]
  end

  test "compute_balance_split returns nil when amortization cannot be computed" do
    # Remove interest_rate so amortization can't be computed
    @mortgage_loan.update_columns(interest_rate: nil)
    create_heloc_for(@mortgage)

    assert_nil @mortgage.compute_balance_split(707595)
  end

  test "split targets are nullified when source is destroyed" do
    heloc = create_heloc_for(@mortgage)
    assert_equal @mortgage.id, heloc.split_source_id

    @mortgage.destroy!
    heloc.reload
    assert_nil heloc.split_source_id
  end

  private

    def create_heloc_for(mortgage)
      heloc_loan = Loan.create!(rate_type: "variable")
      @family.accounts.create!(
        name: "TD HELOC",
        accountable: heloc_loan,
        subtype: "home_equity",
        balance: 15000,
        currency: "CAD",
        created_by_user: @user,
        split_source: mortgage
      )
    end
end
