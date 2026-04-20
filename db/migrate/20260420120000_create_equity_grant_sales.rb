class CreateEquityGrantSales < ActiveRecord::Migration[8.1]
  def change
    create_table :equity_grant_sales, id: :uuid do |t|
      t.references :equity_grant, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.references :entry, null: true, foreign_key: { on_delete: :nullify }, type: :uuid

      t.date :date, null: false
      t.decimal :units, precision: 19, scale: 4, null: false
      t.decimal :proceeds, precision: 19, scale: 4, null: false, default: 0
      t.string :currency, null: false

      t.timestamps
    end

    add_index :equity_grant_sales, [ :equity_grant_id, :date ]
  end
end
