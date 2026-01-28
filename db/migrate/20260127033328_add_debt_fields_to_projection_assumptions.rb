class AddDebtFieldsToProjectionAssumptions < ActiveRecord::Migration[7.2]
  def change
    add_column :projection_assumptions, :extra_monthly_payment, :decimal, precision: 19, scale: 4, default: 0
    add_column :projection_assumptions, :target_payoff_date, :date
  end
end
