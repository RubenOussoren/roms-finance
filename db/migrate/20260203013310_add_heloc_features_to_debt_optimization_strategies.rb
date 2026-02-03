class AddHelocFeaturesToDebtOptimizationStrategies < ActiveRecord::Migration[7.2]
  def change
    # Readvanceable HELOC: credit limit grows as mortgage principal repays
    add_column :debt_optimization_strategies, :heloc_max_limit, :decimal, precision: 19, scale: 4
    add_column :debt_optimization_strategies, :heloc_readvanceable, :boolean, default: false
  end
end
