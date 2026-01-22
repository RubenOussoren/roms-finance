# Summary card for debt optimization strategy list
class UI::DebtOptimization::StrategyCard < ApplicationComponent
  attr_reader :strategy

  def initialize(strategy:)
    @strategy = strategy
  end

  def strategy_type_label
    case strategy.strategy_type
    when "baseline"
      "Baseline (No Optimization)"
    when "modified_smith"
      "Modified Smith Manoeuvre"
    else
      strategy.strategy_type.titleize
    end
  end

  def status_badge_classes
    case strategy.status
    when "simulated"
      "bg-blue-100 text-blue-700"
    when "active"
      "bg-green-100 text-green-700"
    when "completed"
      "bg-gray-100 text-secondary"
    else
      "bg-yellow-100 text-yellow-700"
    end
  end

  def status_label
    strategy.status.titleize
  end

  def formatted_tax_benefit
    return "—" unless strategy.total_tax_benefit.present?
    helpers.format_money(Money.new(strategy.total_tax_benefit, strategy.currency))
  end

  def formatted_interest_saved
    return "—" unless strategy.total_interest_saved.present?
    helpers.format_money(Money.new(strategy.total_interest_saved, strategy.currency))
  end

  def months_accelerated_text
    return "—" unless strategy.months_accelerated.present?
    months = strategy.months_accelerated
    years = months / 12
    remaining_months = months % 12

    if years > 0 && remaining_months > 0
      "#{years}y #{remaining_months}m"
    elsif years > 0
      "#{years} years"
    else
      "#{months} months"
    end
  end

  def last_simulated_text
    return "Not simulated" unless strategy.last_simulated_at.present?
    helpers.time_ago_in_words(strategy.last_simulated_at) + " ago"
  end

  def primary_mortgage_name
    strategy.primary_mortgage&.name || "Not set"
  end

  def heloc_name
    strategy.heloc&.name || "Not set"
  end

  def rental_mortgage_name
    strategy.rental_mortgage&.name || "Not set"
  end
end
