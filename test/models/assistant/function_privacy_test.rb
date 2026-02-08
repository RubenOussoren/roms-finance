# frozen_string_literal: true

require "test_helper"

class Assistant::FunctionPrivacyTest < ActiveSupport::TestCase
  setup do
    @owner = users(:family_admin)
    @member = users(:family_member)
    @family = @owner.family
    @account = accounts(:depository)
  end

  test "GetAccounts excludes hidden accounts for member" do
    @account.account_permissions.create!(user: @member, visibility: "hidden")

    fn = Assistant::Function::GetAccounts.new(@member)
    result = fn.call

    account_names = result[:accounts].map { |a| a[:name] }
    assert_not_includes account_names, @account.name
  end

  test "GetAccounts shows all accounts for owner" do
    @account.account_permissions.create!(user: @member, visibility: "hidden")

    fn = Assistant::Function::GetAccounts.new(@owner)
    result = fn.call

    account_names = result[:accounts].map { |a| a[:name] }
    assert_includes account_names, @account.name
  end

  test "GetAccounts omits historical data for balance-only accounts" do
    @account.account_permissions.create!(user: @member, visibility: "balance_only")

    fn = Assistant::Function::GetAccounts.new(@member)
    result = fn.call

    balance_only_account = result[:accounts].find { |a| a[:name] == @account.name }
    assert balance_only_account.present?, "Balance-only account should be visible"
    assert_nil balance_only_account[:historical_balances]
    assert_nil balance_only_account[:is_plaid_linked]
  end

  test "GetTransactions excludes transactions from hidden accounts" do
    @account.account_permissions.create!(user: @member, visibility: "hidden")

    fn = Assistant::Function::GetTransactions.new(@member)
    result = fn.call("page" => 1, "order" => "desc")

    account_names = result[:transactions].map { |t| t[:account] }.uniq
    assert_not_includes account_names, @account.name
  end

  test "GetTransactions excludes transactions from balance-only accounts" do
    @account.account_permissions.create!(user: @member, visibility: "balance_only")

    fn = Assistant::Function::GetTransactions.new(@member)
    result = fn.call("page" => 1, "order" => "desc")

    account_names = result[:transactions].map { |t| t[:account] }.uniq
    assert_not_includes account_names, @account.name
  end

  test "base function family_account_names respects visibility" do
    @account.account_permissions.create!(user: @member, visibility: "hidden")

    fn = Assistant::Function::GetAccounts.new(@member)
    schema = fn.params_schema

    # The schema should not include the hidden account name in the account enum
    # We test indirectly via the family_account_names helper
    assert_not_includes fn.send(:family_account_names), @account.name
  end
end
