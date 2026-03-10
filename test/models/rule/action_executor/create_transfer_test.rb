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

  test "creates transfers using original transactions as outflow side" do
    action = Rule::Action.new(
      rule: @rule,
      action_type: "create_transfer",
      value: @destination_account.id
    )

    assert_difference "Transfer.count", 2 do
      assert_difference "Entry.count", 2 do
        action.apply(@source_account.transactions)
      end
    end

    # Original transactions are now the outflow side
    @txn1.reload
    @txn2.reload
    assert @txn1.transfer_as_outflow.present?
    assert @txn2.transfer_as_outflow.present?

    # Verify destination account received inflow entries
    destination_entries = @destination_account.entries.where(date: Date.current)
    assert_equal 2, destination_entries.count
  end

  test "original transaction kind is updated for transfer analytics" do
    action = Rule::Action.new(
      rule: @rule,
      action_type: "create_transfer",
      value: @destination_account.id
    )

    action.apply(@source_account.transactions)

    @txn1.reload
    assert_equal "funds_movement", @txn1.kind
  end

  test "original transaction name is preserved" do
    action = Rule::Action.new(
      rule: @rule,
      action_type: "create_transfer",
      value: @destination_account.id
    )

    action.apply(@source_account.transactions)

    @txn1.reload
    assert_equal "Salary deposit", @txn1.entry.name
  end

  test "idempotent — running twice creates no duplicates" do
    action = Rule::Action.new(
      rule: @rule,
      action_type: "create_transfer",
      value: @destination_account.id
    )

    action.apply(@source_account.transactions)

    assert_no_difference [ "Transfer.count", "Entry.count" ] do
      action.apply(@source_account.transactions)
    end
  end

  test "corrects negative amount on original entry to positive for outflow" do
    txn_negative = create_transaction(date: Date.current, account: @source_account, amount: -500, name: "Negative amount").transaction

    action = Rule::Action.new(
      rule: @rule,
      action_type: "create_transfer",
      value: @destination_account.id
    )

    action.apply(Transaction.where(id: txn_negative.id))

    txn_negative.entry.reload
    assert txn_negative.entry.amount.positive?, "Original entry amount should be positive (outflow)"
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

  test "sets correct kind for liability destination" do
    cc_account = @family.accounts.create!(name: "Credit Card", balance: 0, currency: "USD", accountable: CreditCard.new)

    action = Rule::Action.new(
      rule: @rule,
      action_type: "create_transfer",
      value: cc_account.id
    )

    action.apply(Transaction.where(id: @txn1.id))

    @txn1.reload
    assert_equal "cc_payment", @txn1.kind
  end

  test "converts currency for cross-currency transfer" do
    cad_account = @family.accounts.create!(name: "CAD savings", balance: 1000, currency: "CAD", accountable: Depository.new)

    ExchangeRate.create!(
      from_currency: "USD",
      to_currency: "CAD",
      rate: 1.35,
      date: Date.current
    )

    txn = create_transaction(date: Date.current, account: @source_account, amount: 100, name: "Cross currency").transaction

    action = Rule::Action.new(
      rule: @rule,
      action_type: "create_transfer",
      value: cad_account.id
    )

    action.apply(Transaction.where(id: txn.id))

    inflow_entry = cad_account.entries.where(date: Date.current).first
    assert_equal "CAD", inflow_entry.currency
    assert_in_delta(-135.0, inflow_entry.amount, 0.01)
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
