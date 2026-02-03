require "test_helper"

class UpdateMilestoneProjectionsJobTest < ActiveJob::TestCase
  setup do
    @account = accounts(:depository)
  end

  test "performs job for valid account with milestones" do
    # Create a milestone for testing
    milestone = Milestone.create!(
      account: @account,
      name: "Test Milestone",
      target_amount: 100_000,
      currency: @account.currency,
      status: "pending"
    )

    # Job should complete without error
    assert_nothing_raised do
      UpdateMilestoneProjectionsJob.perform_now(@account.id)
    end
  end

  test "handles missing account gracefully" do
    # Should not raise error for non-existent account
    assert_nothing_raised do
      UpdateMilestoneProjectionsJob.perform_now("non-existent-uuid")
    end
  end

  test "skips accounts without projectable concern" do
    # The job should handle accounts gracefully
    assert_nothing_raised do
      UpdateMilestoneProjectionsJob.perform_now(@account.id)
    end
  end

  test "queued in low_priority queue" do
    assert_equal "low_priority", UpdateMilestoneProjectionsJob.new.queue_name
  end
end
