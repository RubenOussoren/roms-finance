class BackfillUserOnConnectionsAndImports < ActiveRecord::Migration[7.2]
  def up
    # Backfill plaid_items: set user_id to the family's first (admin) user
    execute <<~SQL
      UPDATE plaid_items
      SET user_id = (
        SELECT u.id FROM users u
        WHERE u.family_id = plaid_items.family_id
        ORDER BY u.created_at ASC
        LIMIT 1
      )
      WHERE user_id IS NULL
    SQL

    # Backfill snaptrade_connections
    execute <<~SQL
      UPDATE snaptrade_connections
      SET user_id = (
        SELECT u.id FROM users u
        WHERE u.family_id = snaptrade_connections.family_id
        ORDER BY u.created_at ASC
        LIMIT 1
      )
      WHERE user_id IS NULL
    SQL

    # Backfill imports
    execute <<~SQL
      UPDATE imports
      SET user_id = (
        SELECT u.id FROM users u
        WHERE u.family_id = imports.family_id
        ORDER BY u.created_at ASC
        LIMIT 1
      )
      WHERE user_id IS NULL
    SQL
  end

  def down
    # No-op: removing the columns is handled by the previous migration's rollback
  end
end
