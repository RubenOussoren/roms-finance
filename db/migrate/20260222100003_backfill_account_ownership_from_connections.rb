class BackfillAccountOwnershipFromConnections < ActiveRecord::Migration[7.2]
  def up
    # Update accounts linked via Plaid
    execute <<~SQL
      UPDATE accounts
      SET created_by_user_id = pi.user_id
      FROM plaid_accounts pa
      INNER JOIN plaid_items pi ON pa.plaid_item_id = pi.id
      WHERE accounts.plaid_account_id = pa.id
        AND pi.user_id IS NOT NULL
    SQL

    # Update accounts linked via SnapTrade
    execute <<~SQL
      UPDATE accounts
      SET created_by_user_id = sc.user_id
      FROM snaptrade_accounts sa
      INNER JOIN snaptrade_connections sc ON sa.snaptrade_connection_id = sc.id
      WHERE accounts.snaptrade_account_id = sa.id
        AND sc.user_id IS NOT NULL
    SQL

    # Update accounts linked via Import
    execute <<~SQL
      UPDATE accounts
      SET created_by_user_id = i.user_id
      FROM imports i
      WHERE accounts.import_id = i.id
        AND i.user_id IS NOT NULL
    SQL
  end

  def down
    # No-op: we can't know the original values
  end
end
