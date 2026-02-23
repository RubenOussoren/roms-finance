class Loan < ApplicationRecord
  include Accountable

  SUBTYPES = {
    "mortgage" => { short: "Mortgage", long: "Mortgage" },
    "student" => { short: "Student", long: "Student Loan" },
    "auto" => { short: "Auto", long: "Auto Loan" },
    "home_equity" => { short: "HELOC", long: "Home Equity Line of Credit" },
    "other" => { short: "Other", long: "Other Loan" }
  }.freeze

  # 🇨🇦 Canadian mortgage renewal validation
  validates :renewal_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :annual_lump_sum_month, inclusion: { in: 1..12 }, allow_nil: true
  validates :renewal_term_months, numericality: { greater_than: 0 }, allow_nil: true
  validates :prepayment_privilege_percent, numericality: { greater_than: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validate :initial_balance_immutable, on: :update

  # Check if this is a Canadian-style mortgage with renewal
  def canadian_mortgage?
    renewal_date.present?
  end

  # Check if mortgage is due for renewal
  def renewal_due?
    canadian_mortgage? && renewal_date <= Date.current
  end

  # Calculate next renewal date (typically 5 years from current renewal)
  def next_renewal_date
    return nil unless canadian_mortgage?
    renewal_date + 5.years
  end

  # Get the effective interest rate (accounts for pending renewals)
  def effective_interest_rate
    return interest_rate unless canadian_mortgage? && renewal_due?
    renewal_rate || interest_rate
  end

  def monthly_payment
    @monthly_payment ||= calculate_monthly_payment
  end

  def expected_balance_at(date)
    return nil unless can_compute_amortization?

    start_balance = calibrated_balance || original_balance.amount.to_f
    start_date = calibrated_at || origination_date

    months_elapsed = (date.year * 12 + date.month) -
                     (start_date.year * 12 + start_date.month)
    remaining = remaining_term_from(start_date)
    months_elapsed = months_elapsed.clamp(0, remaining)

    annual_rate = interest_rate / 100.0
    r = account.subtype == "mortgage" ?
          CanadianMortgage.monthly_rate(annual_rate) :
          annual_rate / 12.0

    if r.zero?
      (start_balance * (1.0 - months_elapsed.to_f / remaining)).round(2)
    else
      n = remaining
      compound_total = (1 + r)**n
      compound_elapsed = (1 + r)**months_elapsed
      (start_balance * (compound_total - compound_elapsed) / (compound_total - 1)).round(2)
    end
  end

  def can_compute_amortization?
    interest_rate.present? && term_months.present? && term_months > 0 &&
      rate_type == "fixed" &&
      (calibrated_balance.present? || original_balance.amount.to_f > 0) &&
      (calibrated_at.present? || origination_date.present?)
  end

  def recalibrate!(balance, date = Date.current)
    update!(calibrated_balance: balance, calibrated_at: date)

    if account.present? && can_compute_amortization?
      new_balance = expected_balance_at(Date.current)
      Account::CurrentBalanceManager.new(account).set_current_balance(new_balance) if new_balance
    end
  end

  private

    def remaining_term_from(start_date)
      return term_months unless origination_date.present? && start_date != origination_date
      months_used = (start_date.year * 12 + start_date.month) -
                    (origination_date.year * 12 + origination_date.month)
      [ term_months - months_used, 1 ].max
    end

    def initial_balance_immutable
      if initial_balance_changed? && initial_balance_was.present?
        errors.add(:initial_balance, "cannot be changed once set")
      end
    end

    def calculate_monthly_payment
      return nil if term_months.nil? || interest_rate.nil? || rate_type.nil? || rate_type != "fixed"
      return Money.new(0, account.currency) if original_balance.amount.zero? || term_months.zero?

      annual_rate = interest_rate / 100.0

      payment = if account.subtype == "mortgage"
        CanadianMortgage.monthly_payment(original_balance.amount, annual_rate, term_months)
      else
        r = annual_rate / 12.0
        if r.zero?
          original_balance.amount.to_f / term_months
        else
          (original_balance.amount * r * (1 + r)**term_months) / ((1 + r)**term_months - 1)
        end
      end

      Money.new(payment.round, account.currency)
    end

  public

  def original_balance
    @original_balance ||= begin
      amount = initial_balance.presence || account.first_valuation_amount
      Money.new(amount, account.currency)
    end
  end

  class << self
    def color
      "#D444F1"
    end

    def icon
      "hand-coins"
    end

    def classification
      "liability"
    end
  end
end
