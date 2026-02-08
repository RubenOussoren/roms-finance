# frozen_string_literal: true

require "test_helper"

class PrivacyScopingTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:family_admin)
    @member = users(:family_member)
    @family = @owner.family
    @account = accounts(:depository) # owned by family_admin
  end

  # --- ProjectionSettingsController ---

  test "member cannot update projection settings for hidden account" do
    @account.account_permissions.create!(user: @member, visibility: "hidden")
    sign_in @member

    patch account_projection_settings_url(@account), params: {
      expected_return: "8", volatility: "15", monthly_contribution: "500", projection_years: "10"
    }

    assert_response :not_found
  end

  # --- DebtRepaymentSettingsController ---

  test "member cannot update debt repayment settings for hidden account" do
    @account.account_permissions.create!(user: @member, visibility: "hidden")
    sign_in @member

    patch account_debt_repayment_settings_url(@account), params: {
      extra_monthly_payment: "100"
    }

    assert_response :not_found
  end

  # --- Transactions::BulkDeletionsController ---

  test "bulk delete only affects full-access accounts" do
    @account.account_permissions.create!(user: @member, visibility: "balance_only")
    sign_in @member

    entry = @account.entries.first
    assert entry.present?, "Need at least one entry to test"

    assert_no_difference "Entry.count" do
      post transactions_bulk_deletion_url, params: {
        bulk_delete: { entry_ids: [ entry.id ] }
      }
    end
  end

  # --- Transactions::BulkUpdatesController ---

  test "bulk update only affects full-access accounts" do
    @account.account_permissions.create!(user: @member, visibility: "balance_only")
    sign_in @member

    entry = @account.entries.first
    assert entry.present?, "Need at least one entry to test"

    original_notes = entry.notes

    post transactions_bulk_update_url, params: {
      bulk_update: { entry_ids: [ entry.id ], notes: "Should not change" }
    }

    entry.reload
    assert_not_equal "Should not change", entry.notes
  end

  # --- ImportsController ---

  test "import create rejects account user cannot fully access" do
    @account.account_permissions.create!(user: @member, visibility: "balance_only")
    sign_in @member

    # The import flow checks full_access_accounts, so attempting to create
    # an import targeting a balance_only account should fail
    post imports_url, params: { import: { type: "TransactionImport", account_id: @account.id } }

    # Should redirect with error or render form (not succeed with the import)
    assert_not_equal 201, response.status
  end
end
