require "test_helper"
require "timeout"

# Separate committed connections are necessary to exercise PostgreSQL row locks.
class DebtOptimizationStrategyConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "concurrent reruns serialize the entire replacement and keep one complete ledger" do
    strategy = debt_optimization_strategies(:smith_manoeuvre).dup
    strategy.update!(name: "Concurrent simulation", simulation_months: 2)
    first_entered = Queue.new
    second_pid = Queue.new
    second_entered = Queue.new
    release_first = Queue.new
    threads = []

    # Start with no ledger rows: locking old ledger rows cannot serialize this case.
    threads << Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        first = DebtOptimizationStrategy.find(strategy.id)
        simulator = first.simulator
        wrapper = Object.new
        wrapper.define_singleton_method(:simulate!) do
          first_entered << true
          release_first.pop
          simulator.simulate!
        end
        first.define_singleton_method(:simulator) { wrapper }
        first.run_simulation!
      end
    end
    Timeout.timeout(10) { first_entered.pop }

    threads << Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        second = DebtOptimizationStrategy.find(strategy.id)
        simulator = second.simulator
        wrapper = Object.new
        wrapper.define_singleton_method(:simulate!) do
          second_entered << second.ledger_entries.count
          simulator.simulate!
        end
        second.define_singleton_method(:simulator) { wrapper }
        second_pid << connection.select_value("SELECT pg_backend_pid()")
        second.run_simulation!
      end
    end
    pid = Timeout.timeout(10) { second_pid.pop }

    Timeout.timeout(10) do
      loop do
        waiting = ActiveRecord::Base.connection_pool.with_connection do |connection|
          connection.select_value(<<~SQL)
            SELECT query FROM pg_stat_activity
            WHERE pid = #{Integer(pid)} AND cardinality(pg_blocking_pids(pid)) > 0
          SQL
        end
        if waiting
          assert_match(/FOR UPDATE/i, waiting)
          break
        end
        assert second_entered.empty?, "Second simulation entered before the first replacement finished"
        sleep 0.01
      end
    end

    release_first << true
    threads.each do |thread|
      assert thread.join(10), "Concurrent simulation did not finish"
      thread.value
    end
    assert_equal 0, Timeout.timeout(10) { second_entered.pop }, "Previous ledger must be removed before simulating"
    strategy.reload
    assert strategy.simulated?
    assert_not_nil strategy.last_simulated_at
    assert_equal 6, strategy.ledger_entries.count
    assert strategy.ledger_entries.group(:month_number, :scenario_type).count.values.all? { |count| count == 1 },
      "Each strategy/month/scenario identity must have exactly one row"
    assert_equal({ "baseline" => 2, "modified_smith" => 2, "prepay_only" => 2 },
      strategy.ledger_entries.group(:scenario_type).count)
    assert_equal strategy.strategy_entries.last.cumulative_tax_benefit, strategy.total_tax_benefit
    expected_net_benefit = strategy.total_interest_saved + strategy.total_tax_benefit - strategy.strategy_entries.sum(:heloc_interest)
    assert_in_delta expected_net_benefit, strategy.net_benefit, 0.0001
  ensure
    release_first << true if release_first
    threads&.each do |thread|
      thread.kill unless thread.join(10)
    end
    strategy&.destroy! if strategy&.persisted?
  end
end
