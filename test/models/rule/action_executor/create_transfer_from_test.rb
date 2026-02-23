require "test_helper"

class Rule::ActionExecutor::CreateTransferFromTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:dylan_family)
    @rule = rules(:one)
    @source_account = @family.accounts.create!(name: "Morgan Stanley", balance: 50000, currency: "USD", accountable: Investment.new)
    @destination_account = @family.accounts.create!(name: "Checking", balance: 5000, currency: "USD", accountable: Depository.new)

    @txn1 = create_transaction(date: Date.current, account: @destination_account, amount: -1000, name: "Transfer from MS").transaction
    @txn2 = create_transaction(date: Date.current, account: @destination_account, amount: -2000, name: "Another transfer from MS").transaction
  end

  test "creates transfers with selected account as source" do
    action = Rule::Action.new(
      rule: @rule,
      action_type: "create_transfer_from",
      value: @source_account.id
    )

    assert_difference "Transfer.count", 2 do
      action.apply(@destination_account.transactions)
    end

    # Verify source account has outflow entries
    source_entries = @source_account.entries.where(date: Date.current)
    assert_equal 2, source_entries.count
  end

  test "skips transactions that already have a transfer" do
    Transfer::Creator.new(
      family: @family,
      source_account_id: @source_account.id,
      destination_account_id: @destination_account.id,
      date: @txn1.entry.date,
      amount: @txn1.entry.amount.abs
    ).create

    initial_transfer_count = Transfer.count

    action = Rule::Action.new(
      rule: @rule,
      action_type: "create_transfer_from",
      value: @source_account.id
    )

    action.apply(@destination_account.transactions)

    # txn1 and txn2 get transfers, but the existing inflow transaction is skipped
    assert_equal initial_transfer_count + 2, Transfer.count
  end

  test "skips when source account equals matched transaction account" do
    action = Rule::Action.new(
      rule: @rule,
      action_type: "create_transfer_from",
      value: @destination_account.id
    )

    assert_no_difference "Transfer.count" do
      action.apply(@destination_account.transactions)
    end
  end

  test "does nothing when source account does not exist" do
    action = Rule::Action.new(
      rule: @rule,
      action_type: "create_transfer_from",
      value: "nonexistent-id"
    )

    assert_no_difference "Transfer.count" do
      action.apply(@destination_account.transactions)
    end
  end

  test "handles multiple matched transactions" do
    txn3 = create_transaction(date: 1.day.ago.to_date, account: @destination_account, amount: -500, name: "Third transfer").transaction

    action = Rule::Action.new(
      rule: @rule,
      action_type: "create_transfer_from",
      value: @source_account.id
    )

    assert_difference "Transfer.count", 3 do
      action.apply(@destination_account.transactions)
    end
  end

  test "executor appears in transaction resource action executors" do
    executor_keys = @rule.registry.action_executors.map(&:key)
    assert_includes executor_keys, "create_transfer_from"
  end

  test "executor type is select with correct label and preposition" do
    executor = Rule::ActionExecutor::CreateTransferFrom.new(@rule)
    assert_equal "select", executor.type
    assert_equal "Create transfer", executor.label
    assert_equal "from", executor.preposition

    options = executor.options
    assert options.is_a?(Array)
    assert options.any? { |name, _id| name == @source_account.name }
    assert options.any? { |name, _id| name == @destination_account.name }
  end
end
