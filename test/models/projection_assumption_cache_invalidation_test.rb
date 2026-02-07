require "test_helper"

class ProjectionAssumptionCacheInvalidationTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
  end

  test "saving account-specific assumption touches the account" do
    account = accounts(:investment)
    assumption = ProjectionAssumption.create_for_account(account, expected_return: 0.07)
    original_updated_at = account.reload.updated_at

    travel 1.second do
      assumption.update!(expected_return: 0.08)
      assert account.reload.updated_at > original_updated_at,
        "Expected account updated_at to change after assumption save"
    end
  end

  test "saving family default assumption touches a family account" do
    assumption = @family.projection_assumptions.family_default.active.first ||
                 ProjectionAssumption.default_for(@family)
    first_account = @family.accounts.first
    original_updated_at = first_account.reload.updated_at

    travel 1.second do
      assumption.update!(expected_return: 0.09)
      assert first_account.reload.updated_at > original_updated_at,
        "Expected a family account updated_at to change after family default assumption save"
    end
  end
end
