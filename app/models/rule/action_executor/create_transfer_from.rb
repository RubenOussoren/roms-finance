class Rule::ActionExecutor::CreateTransferFrom < Rule::ActionExecutor
  def type
    "select"
  end

  def label
    "Create transfer"
  end

  def preposition
    "from"
  end

  def options
    family.accounts.alphabetically.map { |a| [ a.name, a.id ] }
  end

  def execute(transaction_scope, value: nil, ignore_attribute_locks: false)
    source_account = family.accounts.find_by_id(value)
    return if source_account.nil?

    transaction_scope.find_each do |txn|
      next if txn.transfer.present?
      next if txn.entry.account_id == source_account.id

      ActiveRecord::Base.transaction do
        entry = txn.entry

        # Ensure amount is negative (inflow convention)
        entry.update!(amount: -entry.amount.abs) if entry.amount.positive?

        # Update the original transaction's kind for transfer analytics
        txn.update!(kind: "funds_movement")

        # Create only the outflow counterpart in the source account
        outflow_amount = Money.new(entry.amount.abs, entry.currency)
                              .exchange_to(source_account.currency, date: entry.date, fallback_rate: 1.0)

        outflow_txn = Transaction.new(
          kind: Transfer.kind_for_account(entry.account),
          entry: source_account.entries.build(
            amount: outflow_amount.amount.abs,
            currency: source_account.currency,
            date: entry.date,
            name: outflow_entry_name(entry)
          )
        )

        Transfer.create!(
          inflow_transaction: txn,
          outflow_transaction: outflow_txn,
          status: "confirmed"
        )
      end

      source_account.sync_later
      txn.entry.account.sync_later
    end
  end

  private

    def outflow_entry_name(entry)
      prefix = entry.account.liability? ? "Payment" : "Transfer"
      "#{prefix} to #{entry.account.name}"
    end
end
