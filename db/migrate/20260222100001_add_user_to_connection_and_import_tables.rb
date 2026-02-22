class AddUserToConnectionAndImportTables < ActiveRecord::Migration[7.2]
  def change
    add_reference :plaid_items, :user, type: :uuid, null: true, foreign_key: true, index: true
    add_reference :snaptrade_connections, :user, type: :uuid, null: true, foreign_key: true, index: true
    add_reference :imports, :user, type: :uuid, null: true, foreign_key: true, index: true
  end
end
