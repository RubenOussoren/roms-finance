class CreateAccountPermissions < ActiveRecord::Migration[7.2]
  def change
    create_table :account_permissions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :visibility, null: false, default: "full"
      t.timestamps
    end

    add_index :account_permissions, [ :account_id, :user_id ], unique: true
    add_index :account_permissions, [ :user_id, :visibility ]
  end
end
