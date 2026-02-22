class AddBalanceSplitSupport < ActiveRecord::Migration[7.2]
  def change
    add_reference :accounts, :split_source, type: :uuid,
                  foreign_key: { to_table: :accounts }, index: true

    add_column :loans, :origination_date, :date
    add_column :loans, :calibrated_balance, :decimal, precision: 19, scale: 4
    add_column :loans, :calibrated_at, :date
  end
end
