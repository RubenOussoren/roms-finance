require "test_helper"

class Rule::ActionExecutor::CreateEquitySaleTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:dylan_family)
    @rule = rules(:one)
    @equity_account = accounts(:equity_compensation)
    @bank = @family.accounts.create!(name: "Checking", balance: 5000, currency: "USD", accountable: Depository.new)

    @grant = @equity_account.accountable.equity_grants.first
    @sale_date = Date.current
    @sale_amount = 1800  # 10 units at $180

    Security::Price.find_or_create_by!(security: @grant.security, date: @sale_date, price: 180.0, currency: "USD")
    Security.any_instance.stubs(:current_price).returns(Money.new(200, "USD"))
    Security.any_instance.stubs(:import_provider_prices)

    @bank_txn = create_transaction(date: @sale_date, account: @bank, amount: -@sale_amount, name: "GSU sale").transaction
  end

  test "executor registered with correct metadata" do
    executor = Rule::ActionExecutor::CreateEquitySale.new(@rule)
    assert_equal "select", executor.type
    assert_equal "create_equity_sale", executor.key
    assert_equal "Create equity sale", executor.label
    assert_equal "from", executor.preposition
  end

  test "executor appears in transaction resource action executors" do
    executor_keys = @rule.registry.action_executors.map(&:key)
    assert_includes executor_keys, "create_equity_sale"
  end

  test "options include equity compensation accounts" do
    executor = Rule::ActionExecutor::CreateEquitySale.new(@rule)
    options = executor.options
    assert options.any? { |name, id| id == @equity_account.id }
  end

  test "options exclude non-equity-compensation accounts" do
    executor = Rule::ActionExecutor::CreateEquitySale.new(@rule)
    options = executor.options
    assert_not options.any? { |name, id| id == @bank.id }
  end

  test "execute creates transfer and outflow entry in equity account" do
    action = Rule::Action.new(rule: @rule, action_type: "create_equity_sale", value: @equity_account.id)

    assert_difference "Transfer.count", 1 do
      action.apply(Transaction.where(id: @bank_txn.id))
    end

    outflow = @equity_account.entries.where(date: @sale_date, entryable_type: "Transaction").first
    assert_not_nil outflow
    assert outflow.amount.positive?, "Outflow from equity account should be positive (asset outflow convention)"
    assert_equal @sale_amount, outflow.amount
  end

  test "execute creates EquityGrantSale with derived units" do
    action = Rule::Action.new(rule: @rule, action_type: "create_equity_sale", value: @equity_account.id)

    assert_difference "EquityGrantSale.count", 1 do
      action.apply(Transaction.where(id: @bank_txn.id))
    end

    sale = EquityGrantSale.last
    assert_equal @grant, sale.equity_grant
    assert_equal @sale_date, sale.date
    assert_equal @sale_amount, sale.proceeds
    # 1800 / 180 = 10 units
    assert_equal 10.0, sale.units.to_f
  end

  test "execute links sale to outflow entry" do
    action = Rule::Action.new(rule: @rule, action_type: "create_equity_sale", value: @equity_account.id)
    action.apply(Transaction.where(id: @bank_txn.id))

    outflow = @equity_account.entries.where(date: @sale_date).first
    sale = EquityGrantSale.last
    assert_equal outflow.id, sale.entry_id
  end

  test "execute updates account balance via regenerate" do
    # Pre-sale total remaining value (FIFO hasn't allocated yet).
    before_remaining = @equity_account.accountable.total_remaining_value

    action = Rule::Action.new(rule: @rule, action_type: "create_equity_sale", value: @equity_account.id)
    action.apply(Transaction.where(id: @bank_txn.id))

    @equity_account.reload
    after_remaining = @equity_account.accountable.total_remaining_value
    assert after_remaining < before_remaining,
      "Expected total_remaining_value to drop after sale (before=#{before_remaining}, after=#{after_remaining})"

    # Walker-computed expected balance. Only the seeded price date (Date.current) falls
    # inside the 7-day price-lookup window, so the last reachable vesting valuation is
    # 2026-04-15 (5 days before @sale_date). The walker anchors balance to that valuation
    # and then applies the +sale_amount outflow on 2026-04-20.
    last_vest = Date.current - 5.days
    rsu = @equity_account.accountable.equity_grants.find(&:rsu?)
    opt = @equity_account.accountable.equity_grants.find(&:stock_option?)
    rsu_val = rsu.vested_units(as_of: last_vest) * 180
    opt_val = opt.vested_units(as_of: last_vest) * [ 180 - opt.strike_price, 0 ].max
    expected_balance = rsu_val + opt_val - @sale_amount
    assert_in_delta expected_balance, @equity_account.balance, 0.01
  end

  test "skips when target account is not equity compensation" do
    investment_acct = @family.accounts.create!(name: "Investment", balance: 100, currency: "USD", accountable: Investment.new)
    action = Rule::Action.new(rule: @rule, action_type: "create_equity_sale", value: investment_acct.id)

    assert_no_difference [ "Transfer.count", "EquityGrantSale.count" ] do
      action.apply(Transaction.where(id: @bank_txn.id))
    end
  end

  test "does nothing when no eligible grant found" do
    # Destroy all grants
    @equity_account.accountable.equity_grants.destroy_all

    action = Rule::Action.new(rule: @rule, action_type: "create_equity_sale", value: @equity_account.id)

    assert_no_difference [ "Transfer.count", "EquityGrantSale.count" ] do
      action.apply(Transaction.where(id: @bank_txn.id))
    end
  end

  test "cross-currency: derives units from FX-converted proceeds and price" do
    # Scenario: CAD bank account, USD-priced security, USD equity account.
    # Bank txn is CAD 2,430 for a sale at USD $180/unit (10 units). FX USD->CAD = 1.35.
    cad_bank = @family.accounts.create!(name: "CAD Checking", balance: 0, currency: "CAD", accountable: Depository.new)
    ExchangeRate.create!(from_currency: "CAD", to_currency: "USD", rate: (1.0 / 1.35), date: @sale_date)
    ExchangeRate.create!(from_currency: "USD", to_currency: "CAD", rate: 1.35, date: @sale_date)

    cad_txn = create_transaction(date: @sale_date, account: cad_bank, amount: -2430, currency: "CAD", name: "GSU sale CAD").transaction

    action = Rule::Action.new(rule: @rule, action_type: "create_equity_sale", value: @equity_account.id)
    action.apply(Transaction.where(id: cad_txn.id))

    sale = EquityGrantSale.last
    assert_not_nil sale
    # CAD 2430 -> USD 1800. Units = 1800/180 = 10.
    assert_in_delta 10.0, sale.units.to_f, 0.05
    assert_equal "USD", sale.currency
  end

  test "FIFO picks oldest vested grant when multiple exist" do
    older = EquityGrant.create!(
      equity_compensation: @equity_account.accountable,
      security: @grant.security,
      grant_type: "rsu",
      total_units: 500,
      grant_date: Date.new(2022, 1, 1),
      cliff_months: 0,
      vesting_period_months: 12,
      vesting_frequency: "monthly",
      grant_price: 100
    )

    action = Rule::Action.new(rule: @rule, action_type: "create_equity_sale", value: @equity_account.id)
    action.apply(Transaction.where(id: @bank_txn.id))

    sale = EquityGrantSale.last
    assert_equal older.id, sale.equity_grant_id
  end
end
