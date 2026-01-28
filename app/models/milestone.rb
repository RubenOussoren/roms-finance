# Financial goal milestones ($100k, $500k, $1M, custom)
# Supports both growth milestones ("reach" target) and debt milestones ("reduce_to" target)
class Milestone < ApplicationRecord
  belongs_to :account

  TARGET_TYPES = %w[reach reduce_to].freeze

  validates :name, presence: true
  validates :target_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true
  validates :status, inclusion: { in: %w[pending in_progress achieved] }
  validates :progress_percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :target_type, inclusion: { in: TARGET_TYPES }

  scope :pending, -> { where(status: "pending") }
  scope :in_progress, -> { where(status: "in_progress") }
  scope :achieved, -> { where(status: "achieved") }
  scope :standard, -> { where(is_custom: false) }
  scope :custom, -> { where(is_custom: true) }
  scope :ordered_by_target, -> { order(:target_amount) }
  scope :growth_milestones, -> { where(target_type: "reach") }
  scope :reduction_milestones, -> { where(target_type: "reduce_to") }

  # Standard growth milestone amounts
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

  # Standard debt reduction milestones (percentage-based)
  DEBT_MILESTONES = [
    { name: "25% Paid Off", percentage: 0.25 },
    { name: "50% Paid Off", percentage: 0.50 },
    { name: "75% Paid Off", percentage: 0.75 },
    { name: "90% Paid Off", percentage: 0.90 },
    { name: "Paid Off!", percentage: 1.00 }
  ].freeze

  def update_progress!(current_balance)
    # Initialize starting_balance for reduction milestones if not set
    if reduction_milestone? && starting_balance.nil?
      update!(starting_balance: current_balance.abs)
    end

    new_progress = calculate_progress(current_balance)
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

  def reduction_milestone?
    target_type == "reduce_to"
  end

  def growth_milestone?
    target_type == "reach"
  end

  # Calculate what percentage this milestone represents (for debt milestones)
  # e.g., if starting_balance = 100000 and target_amount = 50000, that's 50% paid off
  def target_percentage
    return nil unless reduction_milestone? && starting_balance.present? && starting_balance > 0
    ((1 - (target_amount.to_d / starting_balance.to_d)) * 100).round(0).to_i
  end

  private

    def calculate_progress(current_balance)
      if reduction_milestone?
        calculate_reduction_progress(current_balance)
      else
        calculate_growth_progress(current_balance)
      end
    end

    def calculate_growth_progress(current_balance)
      return 0 if target_amount.zero?
      [ (current_balance.to_d / target_amount.to_d * 100), 100 ].min
    end

    def calculate_reduction_progress(current_balance)
      # For debts: progress = (starting - current) / (starting - target) * 100
      starting = starting_balance || current_balance.abs
      return 100 if starting <= target_amount  # Already at or below target

      current_abs = current_balance.abs
      return 100 if current_abs <= target_amount  # Reached or passed target

      total_reduction_needed = starting - target_amount
      return 0 if total_reduction_needed.zero?

      actual_reduction = starting - current_abs
      [ (actual_reduction.to_d / total_reduction_needed.to_d * 100), 100 ].min.clamp(0, 100)
    end

    def calculate_status(progress, current_balance)
      if reduction_milestone?
        # For debts: achieved when balance <= target
        return "achieved" if current_balance.abs <= target_amount
      else
        # For growth: achieved when balance >= target
        return "achieved" if current_balance >= target_amount
      end

      return "in_progress" if progress > 0
      "pending"
    end

    class << self
      def create_standard_milestones_for(account)
        if account.liability?
          create_debt_milestones_for(account)
        else
          create_growth_milestones_for(account)
        end
      end

      def create_growth_milestones_for(account)
        STANDARD_MILESTONES.map do |milestone|
          find_or_create_by!(
            account: account,
            target_amount: milestone[:amount],
            is_custom: false
          ) do |m|
            m.name = milestone[:name]
            m.currency = account.currency
            m.status = "pending"
            m.target_type = "reach"
          end
        end
      end

      def create_debt_milestones_for(account)
        current_balance = account.balance.abs
        return [] if current_balance.zero?

        DEBT_MILESTONES.map do |milestone|
          # Calculate target as a reduction from current balance
          # e.g., 25% paid means target is 75% of starting balance
          target = (current_balance * (1 - milestone[:percentage])).round(2)

          find_or_create_by!(
            account: account,
            target_amount: target,
            is_custom: false
          ) do |m|
            m.name = milestone[:name]
            m.currency = account.currency
            m.status = "pending"
            m.target_type = "reduce_to"
            m.starting_balance = current_balance
          end
        end
      end

      def default_target_type_for(account)
        account&.liability? ? "reduce_to" : "reach"
      end
    end
end
