class AddSnaptradeCredentialsToFamilies < ActiveRecord::Migration[7.2]
  def change
    add_column :families, :snaptrade_user_id, :string
    add_column :families, :snaptrade_user_secret, :string
  end
end
