# Financial goal milestones ($100k, $500k, $1M, custom)
class Milestone < ApplicationRecord
  belongs_to :account

  validates :name, presence: true
  validates :target_amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :status, inclusion: { in: %w[pending in_progress achieved] }
  validates :progress_percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  scope :pending, -> { where(status: "pending") }
  scope :in_progress, -> { where(status: "in_progress") }
  scope :achieved, -> { where(status: "achieved") }
  scope :standard, -> { where(is_custom: false) }
  scope :custom, -> { where(is_custom: true) }
  scope :ordered_by_target, -> { order(:target_amount) }

  # Standard milestone amounts
  STANDARD_MILESTONES = [
    { name: "$10K", amount: 10_000 },
    { name: "$25K", amount: 25_000 },
    { name: "$50K", amount: 50_000 },
    { name: "$100K", amount: 100_000 },
    { name: "$250K", amount: 250_000 },
    { name: "$500K", amount: 500_000 },
    { name: "$750K", amount: 750_000 },
    { name: "$1M", amount: 1_000_000 },
    { name: "$2M", amount: 2_000_000 },
    { name: "$5M", amount: 5_000_000 }
  ].freeze

  def update_progress!(current_balance)
    new_progress = [ (current_balance.to_d / target_amount.to_d * 100), 100 ].min
    new_status = calculate_status(new_progress, current_balance)

    update!(
      progress_percentage: new_progress.round(2),
      status: new_status,
      achieved_date: new_status == "achieved" ? Date.current : achieved_date
    )
  end

  def achieved?
    status == "achieved"
  end

  def days_to_target
    return nil unless projected_date.present?
    return 0 if achieved?
    (projected_date - Date.current).to_i
  end

  def on_track?
    return true if achieved?
    return nil unless target_date.present? && projected_date.present?
    projected_date <= target_date
  end

  private

    def calculate_status(progress, current_balance)
      return "achieved" if current_balance >= target_amount
      return "in_progress" if progress > 0
      "pending"
    end

    class << self
      def create_standard_milestones_for(account)
        STANDARD_MILESTONES.map do |milestone|
          find_or_create_by!(
            account: account,
            target_amount: milestone[:amount],
            is_custom: false
          ) do |m|
            m.name = milestone[:name]
            m.currency = account.currency
            m.status = "pending"
          end
        end
      end
    end
end
