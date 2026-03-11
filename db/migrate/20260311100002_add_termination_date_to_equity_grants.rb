class AddTerminationDateToEquityGrants < ActiveRecord::Migration[7.2]
  def change
    add_column :equity_grants, :termination_date, :date
  end
end
