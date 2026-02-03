class AddCanadianMortgageFeaturesToLoans < ActiveRecord::Migration[7.2]
  def change
    # Canadian mortgage renewal (mortgages renew every 5 years with new rates)
    add_column :loans, :renewal_date, :date
    add_column :loans, :renewal_rate, :decimal, precision: 10, scale: 3

    # Canadian annual lump-sum prepayment (10-20% allowed per year)
    add_column :loans, :annual_lump_sum_amount, :decimal, precision: 19, scale: 4
    add_column :loans, :annual_lump_sum_month, :integer  # 1-12
  end
end
