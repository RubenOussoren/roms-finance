# 🇨🇦 PAG 2025 and CFP Board projection standards
class CreateProjectionStandards < ActiveRecord::Migration[7.2]
  def change
    create_table :projection_standards, id: :uuid do |t|
      t.references :jurisdiction, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.string :code, null: false
      t.integer :effective_year, null: false
      t.decimal :equity_return, precision: 6, scale: 4
      t.decimal :fixed_income_return, precision: 6, scale: 4
      t.decimal :cash_return, precision: 6, scale: 4
      t.decimal :inflation_rate, precision: 6, scale: 4
      t.decimal :volatility_equity, precision: 6, scale: 4
      t.decimal :volatility_fixed_income, precision: 6, scale: 4
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :projection_standards, [ :jurisdiction_id, :code ], unique: true
    add_index :projection_standards, :effective_year
  end
end
