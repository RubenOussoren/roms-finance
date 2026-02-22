module Account::BalanceSplittable
  extend ActiveSupport::Concern

  included do
    has_many :split_targets, class_name: "Account",
             foreign_key: :split_source_id, dependent: :nullify
    belongs_to :split_source, class_name: "Account", optional: true
  end

  def split_source?
    if split_targets.loaded?
      split_targets.any?
    else
      split_targets.exists?
    end
  end

  def split_target?
    split_source_id.present?
  end

  def create_balance_split!(origination_date:, interest_rate:, rate_type:, term_months:, heloc_name:, heloc_balance:)
    Account.transaction do
      accountable.update!(
        origination_date: origination_date,
        interest_rate: interest_rate,
        rate_type: rate_type.presence || "fixed",
        term_months: term_months.to_i
      )

      heloc_loan = Loan.create!(rate_type: "variable")
      heloc = family.accounts.create!(
        name: heloc_name.presence || "#{name} HELOC",
        accountable: heloc_loan,
        subtype: "home_equity",
        balance: heloc_balance.to_d,
        currency: currency,
        created_by_user_id: created_by_user_id,
        split_source: self
      )

      Account::CurrentBalanceManager.new(heloc).set_current_balance(heloc_balance.to_d)

      if accountable.can_compute_amortization?
        mortgage_balance = accountable.expected_balance_at(Date.current)
        Account::CurrentBalanceManager.new(self).set_current_balance(mortgage_balance) if mortgage_balance
      end

      heloc
    end
  end

  def remove_balance_split!
    Account.transaction do
      split_targets.each do |target|
        combined = balance + target.balance
        target.destroy!
        Account::CurrentBalanceManager.new(self).set_current_balance(combined)
      end
    end
  end

  def compute_balance_split(combined_balance)
    return nil unless split_source?
    return nil unless accountable.respond_to?(:can_compute_amortization?) &&
                      accountable.can_compute_amortization?

    source_balance = accountable.expected_balance_at(Date.current)
    return nil if source_balance.nil?
    source_balance = [ source_balance, combined_balance.abs ].min

    target_adjustments = split_targets.map do |target|
      { account: target, balance: combined_balance.abs - source_balance }
    end

    OpenStruct.new(source_balance: source_balance, target_adjustments: target_adjustments)
  end
end
