class AddAccountIdToProjectionAssumptions < ActiveRecord::Migration[7.2]
  def change
    add_reference :projection_assumptions, :account, foreign_key: true, type: :uuid, null: true
    add_index :projection_assumptions, [ :account_id ],
              unique: true,
              where: "account_id IS NOT NULL",
              name: "index_projection_assumptions_unique_account"
  end
end
