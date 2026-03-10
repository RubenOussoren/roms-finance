class Rule::ActionExecutor::CreateTransfer < Rule::ActionExecutor
  def type
    "select"
  end

  def label
    "Create transfer"
  end

  def options
    family.accounts.alphabetically.map { |a| [ a.name, a.id ] }
  end

  def execute(transaction_scope, value: nil, ignore_attribute_locks: false)
    destination_account = family.accounts.find_by_id(value)
    return if destination_account.nil?

    transaction_scope.find_each do |txn|
      next if txn.transfer.present?
      next if txn.entry.account_id == destination_account.id

      ActiveRecord::Base.transaction do
        entry = txn.entry

        # Ensure amount is positive (outflow convention)
        entry.update!(amount: entry.amount.abs) if entry.amount.negative?

        # Update the original transaction's kind for transfer analytics
        txn.update!(kind: Transfer.kind_for_account(destination_account))

        # Create only the inflow counterpart in the destination account
        inflow_amount = Money.new(entry.amount.abs, entry.currency)
                             .exchange_to(destination_account.currency, date: entry.date, fallback_rate: 1.0)

        inflow_txn = Transaction.new(
          kind: "funds_movement",
          entry: destination_account.entries.build(
            amount: -inflow_amount.amount.abs,
            currency: destination_account.currency,
            date: entry.date,
            name: inflow_entry_name(entry)
          )
        )

        Transfer.create!(
          inflow_transaction: inflow_txn,
          outflow_transaction: txn,
          status: "confirmed"
        )
      end

      txn.entry.account.sync_later
      destination_account.sync_later
    end
  end

  private

    def inflow_entry_name(entry)
      prefix = entry.account.liability? ? "Payment" : "Transfer"
      "#{prefix} from #{entry.account.name}"
    end
end
