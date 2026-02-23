class CreateAccountOwnerships < ActiveRecord::Migration[7.2]
  def change
    create_table :account_ownerships, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.decimal :percentage, precision: 5, scale: 2, null: false
      t.timestamps
    end

    add_index :account_ownerships, [ :account_id, :user_id ], unique: true
  end
end
