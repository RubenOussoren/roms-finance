class AddCompositeIndexesForPerformance < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    # Optimizes ProjectionsController#prepare_overview_data which queries
    # milestones by account family and filters by status (WHERE status != 'achieved')
    add_index :milestones, [:account_id, :status],
              name: "index_milestones_on_account_id_and_status",
              algorithm: :concurrently

    # Optimizes ProjectionAssumption.for_account which looks up account-specific
    # assumptions and falls back to family defaults (WHERE family_id = ? AND account_id = ?)
    add_index :projection_assumptions, [:family_id, :account_id],
              name: "index_projection_assumptions_on_family_and_account",
              algorithm: :concurrently
  end
end
