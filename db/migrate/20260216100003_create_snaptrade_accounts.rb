class CreateSnaptradeAccounts < ActiveRecord::Migration[7.2]
  def change
    create_table :snaptrade_accounts, id: :uuid do |t|
      t.references :snaptrade_connection, null: false, foreign_key: true, type: :uuid
      t.string :snaptrade_account_id, null: false
      t.string :snaptrade_type
      t.string :snaptrade_number
      t.string :name, null: false
      t.string :currency, null: false
      t.decimal :current_balance, precision: 19, scale: 4
      t.jsonb :raw_payload, default: {}
      t.jsonb :raw_positions_payload, default: {}
      t.jsonb :raw_balances_payload, default: {}
      t.jsonb :raw_activities_payload, default: {}

      t.timestamps
    end

    add_index :snaptrade_accounts, :snaptrade_account_id, unique: true
  end
end
