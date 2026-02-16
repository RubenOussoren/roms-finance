require "test_helper"

class SnapTradeAccount::ProcessorTest < ActiveSupport::TestCase
  setup do
    @snaptrade_account = snaptrade_accounts(:one)
    @family = @snaptrade_account.snaptrade_connection.family
    @processor = SnapTradeAccount::Processor.new(@snaptrade_account)
  end

  test "creates account from snaptrade account" do
    assert_difference "Account.count", 1 do
      @processor.process
    end

    account = @snaptrade_account.reload.account
    assert_not_nil account
    assert_equal @snaptrade_account.name, account.name
    assert_equal @snaptrade_account.currency, account.currency
    assert_equal @family, account.family
    assert_equal "Investment", account.accountable_type
    assert_equal "tfsa", account.subtype
  end

  test "updates existing account on subsequent process" do
    @processor.process

    assert_no_difference "Account.count" do
      @snaptrade_account.update!(name: "Updated TFSA", current_balance: 30000)
      SnapTradeAccount::Processor.new(@snaptrade_account).process
    end

    account = @snaptrade_account.reload.account
    assert_equal "Updated TFSA", account.name
  end

  test "account is linked via snaptrade_account_id" do
    @processor.process

    account = @snaptrade_account.reload.account
    assert account.linked?
    assert_equal @snaptrade_account.id, account.snaptrade_account_id
  end

  test "continues processing if positions fail" do
    SnapTradeAccount::PositionsProcessor.any_instance
      .stubs(:process).raises(StandardError.new("positions error"))

    Sentry.expects(:capture_exception).at_least_once

    assert_nothing_raised do
      @processor.process
    end

    assert_not_nil @snaptrade_account.reload.account
  end

  test "continues processing if activities fail" do
    SnapTradeAccount::ActivitiesProcessor.any_instance
      .stubs(:process).raises(StandardError.new("activities error"))

    Sentry.expects(:capture_exception).at_least_once

    assert_nothing_raised do
      @processor.process
    end

    assert_not_nil @snaptrade_account.reload.account
  end
end
