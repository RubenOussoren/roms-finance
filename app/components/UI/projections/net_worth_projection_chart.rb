# Net worth projection chart for family-level projections
class UI::Projections::NetWorthProjectionChart < ApplicationComponent
  attr_reader :projection_data, :years, :family

  def initialize(projection_data:, years:, family:)
    @projection_data = projection_data
    @years = years
    @family = family
  end

  def chart_data
    projection_data.to_json
  end

  def projected_net_worth_formatted
    summary = projection_data[:summary]
    return "--" unless summary && summary[:projected_net_worth]

    Money.new(summary[:projected_net_worth], family.currency).format
  end

  def current_net_worth_formatted
    family.balance_sheet.net_worth_money.format
  end

  def growth_amount
    summary = projection_data[:summary]
    return nil unless summary && summary[:projected_net_worth]

    current = family.balance_sheet.net_worth
    projected = summary[:projected_net_worth]
    projected - current
  end

  def growth_formatted
    amount = growth_amount
    return "--" unless amount

    Money.new(amount, family.currency).format
  end

  def growth_positive?
    growth_amount && growth_amount > 0
  end
end
