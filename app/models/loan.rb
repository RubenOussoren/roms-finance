class Loan < ApplicationRecord
  include Accountable

  SUBTYPES = {
    "mortgage" => { short: "Mortgage", long: "Mortgage" },
    "student" => { short: "Student", long: "Student Loan" },
    "auto" => { short: "Auto", long: "Auto Loan" },
    "other" => { short: "Other", long: "Other Loan" }
  }.freeze

  # 🇨🇦 Canadian mortgage renewal validation
  validates :renewal_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :annual_lump_sum_month, inclusion: { in: 1..12 }, allow_nil: true

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

  private

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
    @original_balance ||= Money.new(account.first_valuation_amount, account.currency)
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
