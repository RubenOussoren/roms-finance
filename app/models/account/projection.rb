# Account projections for adaptive forecasting
class Account::Projection < ApplicationRecord
  self.table_name = "account_projections"

  belongs_to :account
  belongs_to :projection_assumption, optional: true

  validates :projection_date, presence: true, uniqueness: { scope: :account_id }
  validates :projected_balance, presence: true, numericality: true
  validates :currency, presence: true
  validates :contribution, numericality: { allow_nil: true }

  scope :ordered, -> { order(:projection_date) }
  scope :future, -> { where("projection_date > ?", Date.current) }
  scope :past, -> { where("projection_date <= ?", Date.current) }
  scope :adaptive, -> { where(is_adaptive: true) }
  scope :in_range, ->(start_date, end_date) { where(projection_date: start_date..end_date) }

  def variance
    return nil unless actual_balance.present?
    actual_balance - projected_balance
  end

  def variance_percentage
    return nil unless actual_balance.present? && projected_balance != 0
    ((actual_balance - projected_balance) / projected_balance.abs * 100).round(2)
  end

  def absolute_percentage_error
    return nil unless variance_percentage.present?
    variance_percentage.abs
  end

  def on_track?
    return nil unless variance_percentage.present?
    variance_percentage >= -10 # Within 10% below projection
  end

  def percentile(level)
    return nil unless percentiles.present?
    percentiles["p#{level}"]&.to_d
  end

  def confidence_range(level: 90)
    lower_p = (100 - level) / 2
    upper_p = 100 - lower_p

    {
      lower: percentile(lower_p.to_i),
      upper: percentile(upper_p.to_i),
      median: percentile(50)
    }
  end

  def record_actual!(balance)
    update!(actual_balance: balance)
  end

  class << self
    def with_actuals
      where.not(actual_balance: nil)
    end

    def generate_for_account(account, months:, assumption: nil)
      assumption ||= ProjectionAssumption.default_for(account.family)
      calculator = ProjectionCalculator.new(
        principal: account.balance,
        rate: assumption.effective_return,
        contribution: assumption.monthly_contribution,
        currency: account.currency
      )

      # Pessimistic lock on account row prevents concurrent generation races
      # Pattern follows syncable.rb:16 (existing codebase convention)
      account.with_lock do
        where(account: account, projection_date: Date.current..).delete_all

        months.times.map do |month|
          projection_date = Date.current + (month + 1).months
          future_value = calculator.future_value_at_month(month + 1)

          create!(
            account: account,
            projection_assumption: assumption,
            projection_date: projection_date.end_of_month,
            projected_balance: future_value,
            currency: account.currency,
            contribution: assumption.monthly_contribution,
            is_adaptive: false
          )
        end
      end
    end
  end
end
