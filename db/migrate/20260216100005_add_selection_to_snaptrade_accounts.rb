class AddSelectionToSnapTradeAccounts < ActiveRecord::Migration[7.2]
  def change
    add_column :snaptrade_accounts, :selected_for_import, :boolean, default: false, null: false
    add_column :snaptrade_accounts, :custom_name, :string

    reversible do |dir|
      dir.up do
        # Mark existing imported accounts as selected for backward compatibility
        execute <<-SQL
          UPDATE snaptrade_accounts
          SET selected_for_import = TRUE
          WHERE id IN (SELECT snaptrade_account_id FROM accounts WHERE snaptrade_account_id IS NOT NULL)
        SQL
      end
    end
  end
end
