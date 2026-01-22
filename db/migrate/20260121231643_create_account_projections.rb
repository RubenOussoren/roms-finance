# Account projections for adaptive forecasting
class CreateAccountProjections < ActiveRecord::Migration[7.2]
  def change
    create_table :account_projections, id: :uuid do |t|
      t.references :account, type: :uuid, null: false, foreign_key: true
      t.references :projection_assumption, type: :uuid, foreign_key: true
      t.date :projection_date, null: false
      t.decimal :projected_balance, precision: 19, scale: 4, null: false
      t.decimal :actual_balance, precision: 19, scale: 4
      t.decimal :contribution, precision: 19, scale: 4, default: 0
      t.string :currency, null: false
      t.boolean :is_adaptive, default: false
      t.jsonb :percentiles, default: {}
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :account_projections, [ :account_id, :projection_date ], unique: true
    add_index :account_projections, :projection_date
  end
end
