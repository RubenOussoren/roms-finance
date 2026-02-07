class AddProvinceToDebtOptimizationStrategies < ActiveRecord::Migration[7.2]
  def change
    add_column :debt_optimization_strategies, :province, :string, limit: 2
  end
end
