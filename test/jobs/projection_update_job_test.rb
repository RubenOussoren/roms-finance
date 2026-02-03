require "test_helper"

class ProjectionUpdateJobTest < ActiveJob::TestCase
  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
  end

  test "records actual balance for projections in current month" do
    # Create a projection for current month
    projection = Account::Projection.create!(
      account: @account,
      projection_date: Date.current.end_of_month,
      projected_balance: 10000,
      currency: @account.currency
    )

    assert_nil projection.actual_balance

    ProjectionUpdateJob.perform_now(family_id: @family.id)

    projection.reload
    assert_equal @account.balance, projection.actual_balance
  end

  test "skips projections that already have actual balance" do
    projection = Account::Projection.create!(
      account: @account,
      projection_date: Date.current.end_of_month,
      projected_balance: 10000,
      actual_balance: 9500,
      currency: @account.currency
    )

    ProjectionUpdateJob.perform_now(family_id: @family.id)

    projection.reload
    assert_equal 9500, projection.actual_balance
  end

  test "handles accounts without projections" do
    assert_nothing_raised do
      ProjectionUpdateJob.perform_now(family_id: @family.id)
    end
  end

  test "works without family_id parameter" do
    assert_nothing_raised do
      ProjectionUpdateJob.perform_now
    end
  end

  test "queued in low_priority queue" do
    assert_equal "low_priority", ProjectionUpdateJob.new.queue_name
  end
end
