class CreateSnaptradeConnections < ActiveRecord::Migration[7.2]
  def change
    create_table :snaptrade_connections, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.string :authorization_id, null: false
      t.string :brokerage_name
      t.string :brokerage_slug
      t.string :status, null: false, default: "good"
      t.boolean :scheduled_for_deletion, default: false
      t.jsonb :raw_payload, default: {}

      t.timestamps
    end

    add_index :snaptrade_connections, :authorization_id, unique: true
  end
end
