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

      Transfer::Creator.new(
        family: family,
        source_account_id: txn.entry.account_id,
        destination_account_id: destination_account.id,
        date: txn.entry.date,
        amount: txn.entry.amount.abs
      ).create
    end
  end
end
