require "test_helper"

class LoanTest < ActiveSupport::TestCase
  test "calculates correct monthly payment for fixed rate loan using Canadian semi-annual compounding" do
    loan_account = Account.create! \
      family: families(:dylan_family),
      name: "Mortgage Loan",
      balance: 500000,
      currency: "USD",
      accountable: Loan.create!(
        interest_rate: 3.5,
        term_months: 360,
        rate_type: "fixed"
      )

    # Canadian semi-annual compounding: (1 + 0.035/2)^(1/6) - 1 yields ~$2,238/month
    # Previously was $2,245 under US monthly compounding (0.035/12)
    assert_equal 2238, loan_account.loan.monthly_payment.amount
  end

  # 🇨🇦 Canadian mortgage feature tests

  test "canadian_mortgage? returns true when renewal_date is present" do
    loan = Loan.create!(
      interest_rate: 5.0,
      term_months: 300,
      rate_type: "fixed",
      renewal_date: 5.years.from_now
    )

    assert loan.canadian_mortgage?
  end

  test "canadian_mortgage? returns false when renewal_date is absent" do
    loan = Loan.create!(
      interest_rate: 5.0,
      term_months: 300,
      rate_type: "fixed"
    )

    assert_not loan.canadian_mortgage?
  end

  test "renewal_due? returns true when renewal date is past" do
    loan = Loan.create!(
      interest_rate: 5.0,
      term_months: 300,
      rate_type: "fixed",
      renewal_date: 1.day.ago
    )

    assert loan.renewal_due?
  end

  test "renewal_due? returns false when renewal date is future" do
    loan = Loan.create!(
      interest_rate: 5.0,
      term_months: 300,
      rate_type: "fixed",
      renewal_date: 1.year.from_now
    )

    assert_not loan.renewal_due?
  end

  test "next_renewal_date adds 5 years to current renewal_date" do
    renewal = Date.current + 1.year
    loan = Loan.create!(
      interest_rate: 5.0,
      term_months: 300,
      rate_type: "fixed",
      renewal_date: renewal
    )

    assert_equal renewal + 5.years, loan.next_renewal_date
  end

  test "effective_interest_rate returns renewal_rate when renewal is due" do
    loan = Loan.create!(
      interest_rate: 5.0,
      term_months: 300,
      rate_type: "fixed",
      renewal_date: 1.day.ago,
      renewal_rate: 6.5
    )

    assert_equal 6.5, loan.effective_interest_rate
  end

  test "effective_interest_rate returns interest_rate when renewal not due" do
    loan = Loan.create!(
      interest_rate: 5.0,
      term_months: 300,
      rate_type: "fixed",
      renewal_date: 1.year.from_now,
      renewal_rate: 6.5
    )

    assert_equal 5.0, loan.effective_interest_rate
  end

  test "validates renewal_rate is between 0 and 100" do
    loan = Loan.new(
      interest_rate: 5.0,
      rate_type: "fixed",
      renewal_rate: 150
    )

    assert_not loan.valid?
    assert_includes loan.errors[:renewal_rate], "must be less than or equal to 100"
  end

  test "validates annual_lump_sum_month is between 1 and 12" do
    loan = Loan.new(
      interest_rate: 5.0,
      rate_type: "fixed",
      annual_lump_sum_month: 13
    )

    assert_not loan.valid?
    assert_includes loan.errors[:annual_lump_sum_month], "is not included in the list"
  end

  test "accepts valid annual_lump_sum_month" do
    loan = Loan.new(
      interest_rate: 5.0,
      rate_type: "fixed",
      annual_lump_sum_month: 6,
      annual_lump_sum_amount: 10000
    )

    assert loan.valid?
  end
end
