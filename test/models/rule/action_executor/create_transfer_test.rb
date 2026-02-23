require "test_helper"

class Rule::ActionExecutor::CreateTransferTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:dylan_family)
    @rule = rules(:one)
    @source_account = @family.accounts.create!(name: "Source checking", balance: 5000, currency: "USD", accountable: Depository.new)
    @destination_account = @family.accounts.create!(name: "Destination savings", balance: 1000, currency: "USD", accountable: Depository.new)

    @txn1 = create_transaction(date: Date.current, account: @source_account, amount: 100, name: "Salary deposit").transaction
    @txn2 = create_transaction(date: Date.current, account: @source_account, amount: 200, name: "Bonus deposit").transaction
  end

  test "creates transfers for matched transactions" do
    action = Rule::Action.new(
      rule: @rule,
      action_type: "create_transfer",
      value: @destination_account.id
    )

    assert_difference "Transfer.count", 2 do
      action.apply(@source_account.transactions)
    end

    # Verify destination account received inflow entries
    destination_entries = @destination_account.entries.where(date: Date.current)
    assert_equal 2, destination_entries.count
  end

  test "skips transactions that already have a transfer" do
    # Create a pre-existing transfer from source to destination
    Transfer::Creator.new(
      family: @family,
      source_account_id: @source_account.id,
      destination_account_id: @destination_account.id,
      date: @txn1.entry.date,
      amount: @txn1.entry.amount.abs
    ).create

    initial_transfer_count = Transfer.count

    # Now the source account has txn1, txn2, AND the outflow transaction from the transfer above.
    # The outflow transaction already has a transfer, so it should be skipped.
    # txn1 and txn2 don't have transfers, so they should get new ones.
    action = Rule::Action.new(
      rule: @rule,
      action_type: "create_transfer",
      value: @destination_account.id
    )

    action.apply(@source_account.transactions)

    # txn1 and txn2 get transfers, but the existing outflow transaction is skipped
    assert_equal initial_transfer_count + 2, Transfer.count
  end

  test "skips when source account equals destination account" do
    action = Rule::Action.new(
      rule: @rule,
      action_type: "create_transfer",
      value: @source_account.id
    )

    assert_no_difference "Transfer.count" do
      action.apply(@source_account.transactions)
    end
  end

  test "does nothing when destination account does not exist" do
    action = Rule::Action.new(
      rule: @rule,
      action_type: "create_transfer",
      value: "nonexistent-id"
    )

    assert_no_difference "Transfer.count" do
      action.apply(@source_account.transactions)
    end
  end

  test "handles multiple matched transactions" do
    txn3 = create_transaction(date: 1.day.ago.to_date, account: @source_account, amount: 300, name: "Third deposit").transaction

    action = Rule::Action.new(
      rule: @rule,
      action_type: "create_transfer",
      value: @destination_account.id
    )

    assert_difference "Transfer.count", 3 do
      action.apply(@source_account.transactions)
    end
  end

  test "executor appears in transaction resource action executors" do
    executor_keys = @rule.registry.action_executors.map(&:key)
    assert_includes executor_keys, "create_transfer"
  end

  test "executor type is select with account options" do
    executor = Rule::ActionExecutor::CreateTransfer.new(@rule)
    assert_equal "select", executor.type
    assert_equal "Create transfer", executor.label

    options = executor.options
    assert options.is_a?(Array)
    assert options.any? { |name, _id| name == @source_account.name }
    assert options.any? { |name, _id| name == @destination_account.name }
  end
end
