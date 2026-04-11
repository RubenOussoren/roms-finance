require "test_helper"

class EquityGrantsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @account = accounts(:equity_compensation)
    @grant = equity_grants(:rsu_grant)
  end

  test "shows new grant form" do
    get new_account_equity_grant_path(@account)
    assert_response :success
  end

  test "creates rsu grant" do
    assert_difference -> { EquityGrant.count } => 1 do
      post account_equity_grants_path(@account), params: {
        equity_grant: {
          grant_type: "rsu",
          name: "2025 Refresh",
          security_id: securities(:goog).id,
          grant_date: "2025-03-01",
          total_units: 500,
          cliff_months: 12,
          vesting_period_months: 48,
          vesting_frequency: "monthly"
        }
      }
    end

    assert_redirected_to account_path(@account, tab: :grants)
    assert_equal @account.accountable.reload.total_vested_value, @account.reload.balance
  end

  test "creates stock option grant" do
    assert_difference -> { EquityGrant.count } => 1 do
      post account_equity_grants_path(@account), params: {
        equity_grant: {
          grant_type: "stock_option",
          name: "2025 Options",
          security_id: securities(:goog).id,
          grant_date: "2025-03-01",
          total_units: 1000,
          cliff_months: 12,
          vesting_period_months: 48,
          vesting_frequency: "monthly",
          strike_price: 200.00,
          expiration_date: "2035-03-01",
          option_type: "iso"
        }
      }
    end

    assert_redirected_to account_path(@account, tab: :grants)
  end

  test "shows edit grant form" do
    get edit_account_equity_grant_path(@account, @grant)
    assert_response :success
  end

  test "updates grant" do
    patch account_equity_grant_path(@account, @grant), params: {
      equity_grant: { name: "Updated Grant Name" }
    }

    assert_redirected_to account_path(@account, tab: :grants)
    assert_equal "Updated Grant Name", @grant.reload.name
    assert_equal @account.accountable.reload.total_vested_value, @account.reload.balance
  end

  test "destroys grant" do
    assert_difference -> { EquityGrant.count } => -1 do
      delete account_equity_grant_path(@account, @grant)
    end

    assert_redirected_to account_path(@account, tab: :grants)
    assert_equal @account.accountable.reload.total_vested_value, @account.reload.balance
  end

  test "creates grant with combobox composite security_id" do
    assert_difference -> { EquityGrant.count } => 1 do
      post account_equity_grants_path(@account), params: {
        equity_grant: {
          grant_type: "rsu",
          name: "Combobox Grant",
          security_id: "GOOG|XNAS",
          grant_date: "2025-03-01",
          total_units: 100,
          cliff_months: 12,
          vesting_period_months: 48,
          vesting_frequency: "monthly"
        }
      }
    end

    grant = EquityGrant.order(:created_at).last
    assert_equal securities(:goog).id, grant.security_id
    assert_redirected_to account_path(@account, tab: :grants)
  end

  test "creates new security from combobox composite key when not in database" do
    assert_difference [ -> { EquityGrant.count }, -> { Security.count } ], 1 do
      post account_equity_grants_path(@account), params: {
        equity_grant: {
          grant_type: "rsu",
          name: "New Security Grant",
          security_id: "NVDA|XNAS",
          grant_date: "2025-03-01",
          total_units: 200,
          cliff_months: 12,
          vesting_period_months: 48,
          vesting_frequency: "monthly"
        }
      }
    end

    grant = EquityGrant.order(:created_at).last
    assert_equal "NVDA", grant.security.ticker
    assert_equal "XNAS", grant.security.exchange_operating_mic
    assert_redirected_to account_path(@account, tab: :grants)
  end

  test "rejects invalid grant" do
    post account_equity_grants_path(@account), params: {
      equity_grant: {
        grant_type: "rsu",
        security_id: securities(:goog).id,
        grant_date: "2025-03-01",
        total_units: 0,  # Invalid: must be > 0
        vesting_period_months: 48,
        vesting_frequency: "monthly"
      }
    }

    assert_response :unprocessable_entity
  end
end
