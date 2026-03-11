class CreateEquityGrants < ActiveRecord::Migration[7.2]
  def change
    create_table :equity_grants, id: :uuid do |t|
      t.references :equity_compensation, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.references :security, null: false, foreign_key: { on_delete: :cascade }, type: :uuid

      # Core
      t.string :grant_type, null: false
      t.string :name
      t.date :grant_date, null: false
      t.decimal :total_units, precision: 19, scale: 4, null: false

      # Vesting schedule
      t.integer :cliff_months, null: false, default: 12
      t.integer :vesting_period_months, null: false
      t.string :vesting_frequency, default: "monthly"

      # Stock option specific (NULL for RSUs)
      t.decimal :strike_price, precision: 19, scale: 4
      t.date :expiration_date
      t.string :option_type

      # Tax
      t.decimal :estimated_tax_rate, precision: 5, scale: 2

      t.timestamps
    end
  end
end
