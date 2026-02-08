class AddOwnershipToAccounts < ActiveRecord::Migration[7.2]
  def change
    add_column :accounts, :created_by_user_id, :uuid
    add_column :accounts, :is_joint, :boolean, default: false, null: false
    add_foreign_key :accounts, :users, column: :created_by_user_id
    add_index :accounts, [ :family_id, :created_by_user_id ]
  end
end
