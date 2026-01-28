# Add support for debt milestones with "reduce_to" target type
class AddDebtSupportToMilestones < ActiveRecord::Migration[7.2]
  def change
    add_column :milestones, :target_type, :string, default: "reach", null: false
    add_column :milestones, :starting_balance, :decimal, precision: 19, scale: 4

    add_index :milestones, :target_type
  end
end
