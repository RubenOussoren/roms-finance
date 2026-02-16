class AddSnaptradeAccountToAccounts < ActiveRecord::Migration[7.2]
  def change
    add_reference :accounts, :snaptrade_account, type: :uuid, foreign_key: true
  end
end
