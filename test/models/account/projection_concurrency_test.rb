require "test_helper"

class Account::ProjectionConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @account = accounts(:investment)
    # Clean up any existing future projections
    Account::Projection.where(account: @account, projection_date: Date.current..).delete_all
  end

  teardown do
    Account::Projection.where(account: @account, projection_date: Date.current..).delete_all
  end

  test "concurrent generation produces exactly N projections not 2N" do
    months = 6
    errors = []
    threads = 2.times.map do
      Thread.new do
        Account::Projection.generate_for_account(@account, months: months)
      rescue => e
        errors << e
      end
    end

    threads.each(&:join)

    assert errors.empty?, "Concurrent generation raised errors: #{errors.map(&:message).join(', ')}"

    projection_count = Account::Projection.where(
      account: @account,
      projection_date: Date.current..
    ).count

    assert_equal months, projection_count,
      "Expected exactly #{months} projections but got #{projection_count} (race condition produced duplicates)"
  end
end
