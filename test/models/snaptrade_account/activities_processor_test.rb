require "test_helper"

class SnapTradeAccount::ActivitiesProcessorTest < ActiveSupport::TestCase
  setup do
    @snaptrade_account = snaptrade_accounts(:one)
    # Ensure account exists (created by processor in real flow)
    SnapTradeAccount::Processor.new(@snaptrade_account).process
    @account = @snaptrade_account.reload.account

    @security_resolver = mock("security_resolver")
  end

  test "deposit is stored as negative (inflow)" do
    activities = [ cash_activity("DEPOSIT", 500.0) ]
    @snaptrade_account.update!(raw_activities_payload: activities)

    processor = SnapTradeAccount::ActivitiesProcessor.new(@snaptrade_account, security_resolver: @security_resolver)
    processor.process

    entry = @account.entries.find_by(plaid_id: "act_deposit_1")
    assert_not_nil entry
    assert_equal(-500.0, entry.amount.to_f)
  end

  test "contribution is stored as negative (inflow)" do
    activities = [ cash_activity("CONTRIBUTION", 1000.0) ]
    @snaptrade_account.update!(raw_activities_payload: activities)

    processor = SnapTradeAccount::ActivitiesProcessor.new(@snaptrade_account, security_resolver: @security_resolver)
    processor.process

    entry = @account.entries.find_by(plaid_id: "act_contribution_1")
    assert_not_nil entry
    assert_equal(-1000.0, entry.amount.to_f)
  end

  test "dividend is stored as negative (inflow)" do
    activities = [ cash_activity("DIVIDEND", 25.50) ]
    @snaptrade_account.update!(raw_activities_payload: activities)

    processor = SnapTradeAccount::ActivitiesProcessor.new(@snaptrade_account, security_resolver: @security_resolver)
    processor.process

    entry = @account.entries.find_by(plaid_id: "act_dividend_1")
    assert_not_nil entry
    assert_equal(-25.50, entry.amount.to_f)
  end

  test "interest is stored as negative (inflow)" do
    activities = [ cash_activity("INTEREST", 10.0) ]
    @snaptrade_account.update!(raw_activities_payload: activities)

    processor = SnapTradeAccount::ActivitiesProcessor.new(@snaptrade_account, security_resolver: @security_resolver)
    processor.process

    entry = @account.entries.find_by(plaid_id: "act_interest_1")
    assert_not_nil entry
    assert_equal(-10.0, entry.amount.to_f)
  end

  test "withdrawal is stored as positive (outflow)" do
    activities = [ cash_activity("WITHDRAWAL", 200.0) ]
    @snaptrade_account.update!(raw_activities_payload: activities)

    processor = SnapTradeAccount::ActivitiesProcessor.new(@snaptrade_account, security_resolver: @security_resolver)
    processor.process

    entry = @account.entries.find_by(plaid_id: "act_withdrawal_1")
    assert_not_nil entry
    assert_equal(200.0, entry.amount.to_f)
  end

  test "fee is stored as positive (outflow)" do
    activities = [ cash_activity("FEE", 15.0) ]
    @snaptrade_account.update!(raw_activities_payload: activities)

    processor = SnapTradeAccount::ActivitiesProcessor.new(@snaptrade_account, security_resolver: @security_resolver)
    processor.process

    entry = @account.entries.find_by(plaid_id: "act_fee_1")
    assert_not_nil entry
    assert_equal(15.0, entry.amount.to_f)
  end

  test "inflow type with negative API amount still stores as negative" do
    activities = [ cash_activity("DEPOSIT", -300.0) ]
    @snaptrade_account.update!(raw_activities_payload: activities)

    processor = SnapTradeAccount::ActivitiesProcessor.new(@snaptrade_account, security_resolver: @security_resolver)
    processor.process

    entry = @account.entries.find_by(plaid_id: "act_deposit_1")
    assert_not_nil entry
    assert_equal(-300.0, entry.amount.to_f)
  end

  private
    def cash_activity(type, amount)
      {
        "id" => "act_#{type.downcase}_1",
        "type" => type,
        "amount" => amount,
        "description" => "Test #{type}",
        "trade_date" => "2025-01-15",
        "currency" => { "code" => "CAD" }
      }
    end
end
