# Backfill initial_balance for existing loans where NULL.
# Uses the earliest valuation entry amount as the original loan balance.
#
# Business context: Milestone#earliest_known_balance now reads Loan#original_balance,
# which prefers the initial_balance column. Without this backfill, existing loans
# would report nil for their starting balance, breaking milestone progress tracking.
class PopulateLoanInitialBalance < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      UPDATE loans
      SET initial_balance = subquery.earliest_amount
      FROM (
        SELECT accounts.accountable_id,
               ABS(entries.amount) AS earliest_amount
        FROM accounts
        INNER JOIN entries ON entries.account_id = accounts.id
                          AND entries.entryable_type = 'Valuation'
        WHERE accounts.accountable_type = 'Loan'
        AND NOT EXISTS (
          SELECT 1 FROM entries e2
          WHERE e2.account_id = accounts.id
            AND e2.entryable_type = 'Valuation'
            AND e2.date < entries.date
        )
      ) AS subquery
      WHERE loans.id = subquery.accountable_id
        AND loans.initial_balance IS NULL
    SQL
  end

  def down
    # No-op: we cannot reliably determine which rows were backfilled
  end
end
