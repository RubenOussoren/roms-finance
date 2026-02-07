module DebtSimulatorTestHelper
  def create_loan_account(family, name, balance, interest_rate, term_months)
    loan = Loan.create!(
      interest_rate: interest_rate,
      term_months: term_months,
      rate_type: "fixed"
    )

    Account.create!(
      family: family,
      name: name,
      balance: -balance,
      currency: "CAD",
      accountable: loan,
      status: "active"
    )
  end

  def create_heloc_account(family, name, balance, interest_rate, credit_limit)
    loan = Loan.create!(
      interest_rate: interest_rate,
      rate_type: "variable",
      credit_limit: credit_limit
    )

    Account.create!(
      family: family,
      name: name,
      balance: -balance,
      currency: "CAD",
      accountable: loan,
      status: "active"
    )
  end
end
