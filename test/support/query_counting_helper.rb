module QueryCountingHelper
  def count_queries(&block)
    queries = []
    counter = ->(_name, _start, _finish, _id, payload) {
      queries << payload[:sql] unless payload[:sql].match?(/SCHEMA|BEGIN|COMMIT|SAVEPOINT|RELEASE/)
    }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    queries
  end

  def assert_max_queries(max, message = nil, &block)
    queries = count_queries(&block)
    assert queries.size <= max,
      message || "Expected at most #{max} queries but got #{queries.size}:\n#{queries.join("\n")}"
  end
end
