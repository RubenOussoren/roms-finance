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

  test "creates transfers using original transactions as inflow side" do
    action = Rule::Action.new(
      rule: @rule,
      action_type: "create_transfer_from",
      value: @source_account.id
    )

    assert_difference "Transfer.count", 2 do
      assert_difference "Entry.count", 2 do
        action.apply(@destination_account.transactions)
      end
    end

    # Original transactions are now the inflow side
    @txn1.reload
    @txn2.reload
    assert @txn1.transfer_as_inflow.present?
    assert @txn2.transfer_as_inflow.present?

    # Verify source account has outflow entries
    source_entries = @source_account.entries.where(date: Date.current)
    assert_equal 2, source_entries.count
  end

  test "original transaction kind is updated to funds_movement" do
    action = Rule::Action.new(
      rule: @rule,
      action_type: "create_transfer_from",
      value: @source_account.id
    )

    action.apply(@destination_account.transactions)

    @txn1.reload
    assert_equal "funds_movement", @txn1.kind
  end

  test "original transaction name is preserved" do
    action = Rule::Action.new(
      rule: @rule,
      action_type: "create_transfer_from",
      value: @source_account.id
    )

    action.apply(@destination_account.transactions)

    @txn1.reload
    assert_equal "Transfer from MS", @txn1.entry.name
  end

  test "idempotent — running twice creates no duplicates" do
    action = Rule::Action.new(
      rule: @rule,
      action_type: "create_transfer_from",
      value: @source_account.id
    )

    action.apply(@destination_account.transactions)

    assert_no_difference [ "Transfer.count", "Entry.count" ] do
      action.apply(@destination_account.transactions)
    end
  end

  test "corrects positive amount on original entry to negative for inflow" do
    txn_positive = create_transaction(date: Date.current, account: @destination_account, amount: 500, name: "Positive amount").transaction

    action = Rule::Action.new(
      rule: @rule,
      action_type: "create_transfer_from",
      value: @source_account.id
    )

    action.apply(Transaction.where(id: txn_positive.id))

    txn_positive.entry.reload
    assert txn_positive.entry.amount.negative?, "Original entry amount should be negative (inflow)"
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

  test "converts currency for cross-currency transfer" do
    cad_account = @family.accounts.create!(name: "CAD investment", balance: 50000, currency: "CAD", accountable: Investment.new)

    ExchangeRate.create!(
      from_currency: "USD",
      to_currency: "CAD",
      rate: 1.35,
      date: Date.current
    )

    txn = create_transaction(date: Date.current, account: @destination_account, amount: -1000, name: "Cross currency inflow").transaction

    action = Rule::Action.new(
      rule: @rule,
      action_type: "create_transfer_from",
      value: cad_account.id
    )

    action.apply(Transaction.where(id: txn.id))

    outflow_entry = cad_account.entries.where(date: Date.current).first
    assert_equal "CAD", outflow_entry.currency
    assert_in_delta(1350.0, outflow_entry.amount, 0.01)
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
