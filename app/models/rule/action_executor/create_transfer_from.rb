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

      Transfer::Creator.new(
        family: family,
        source_account_id: source_account.id,
        destination_account_id: txn.entry.account_id,
        date: txn.entry.date,
        amount: txn.entry.amount.abs
      ).create
    end
  end
end
