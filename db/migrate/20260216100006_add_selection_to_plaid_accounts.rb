class AddSelectionToPlaidAccounts < ActiveRecord::Migration[7.2]
  def change
    add_column :plaid_accounts, :selected_for_import, :boolean, default: false, null: false
    add_column :plaid_accounts, :custom_name, :string
  end
end
