require "test_helper"

class MilestonesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
    @account = accounts(:investment)
    @milestone = milestones(:first_100k)
  end

  test "index returns milestones for account" do
    get account_milestones_url(@account)
    assert_response :success
  end

  test "new renders form" do
    get new_account_milestone_url(@account)
    assert_response :success
  end

  test "create adds custom milestone" do
    assert_difference "Milestone.count", 1 do
      post account_milestones_url(@account), params: {
        milestone: {
          name: "New Goal",
          target_amount: 50000
        }
      }
    end

    new_milestone = Milestone.order(:created_at).last

    assert_redirected_to account_path(@account)
    assert_equal "New Goal", new_milestone.name
    assert_equal 50000, new_milestone.target_amount
    assert new_milestone.is_custom
    assert_equal @account.currency, new_milestone.currency
  end

  test "create with target date" do
    target_date = 1.year.from_now.to_date

    assert_difference "Milestone.count", 1 do
      post account_milestones_url(@account), params: {
        milestone: {
          name: "With Date",
          target_amount: 25000,
          target_date: target_date
        }
      }
    end

    new_milestone = Milestone.order(:created_at).last
    assert_equal target_date, new_milestone.target_date
  end

  test "create fails without required fields" do
    assert_no_difference "Milestone.count" do
      post account_milestones_url(@account), params: {
        milestone: {
          name: "",
          target_amount: nil
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "update modifies milestone" do
    patch milestone_url(@milestone), params: {
      milestone: {
        name: "Updated Name"
      }
    }

    assert_redirected_to account_path(@account)
    assert_equal "Updated Name", @milestone.reload.name
  end

  test "destroy removes milestone" do
    assert_difference "Milestone.count", -1 do
      delete milestone_url(@milestone)
    end

    assert_redirected_to account_path(@account)
  end
end
