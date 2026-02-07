class AddCompositeIndexesForPerformance < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :milestones, [:account_id, :status],
              name: "index_milestones_on_account_id_and_status",
              algorithm: :concurrently

    add_index :projection_assumptions, [:family_id, :account_id],
              name: "index_projection_assumptions_on_family_and_account",
              algorithm: :concurrently
  end
end
