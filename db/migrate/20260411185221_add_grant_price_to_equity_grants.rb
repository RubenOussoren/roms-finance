class AddGrantPriceToEquityGrants < ActiveRecord::Migration[8.1]
  def change
    add_column :equity_grants, :grant_price, :decimal, precision: 19, scale: 4
  end
end
