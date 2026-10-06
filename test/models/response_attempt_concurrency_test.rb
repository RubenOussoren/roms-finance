require "test_helper"
require "timeout"

# Committed rows and distinct PostgreSQL backends are essential: transactional
# fixtures would hide the rows from workers and never exercise these locks.
class ResponseAttemptConcurrencyTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  self.use_transactional_tests = false

  setup do
    @threads = []
    @releases = []
    @chats = []
    @users = []
    @fixture_user = users(:empty)
    @fixture_user_attributes = @fixture_user.attributes
    @chat = synthetic_chat
  end

  teardown do
    # Unblock first, supervise all workers, then destroy only our own records.
    @releases.each { |queue| queue << true }
    worker_errors = []
    terminated = []
    @threads.each do |thread|
      begin
        unless thread.join(10)
          terminated << thread
          thread.kill
          thread.join
        end
      rescue StandardError => error
        worker_errors << error
      ensure
        if thread.alive?
          thread.kill
          thread.join
        end
      end
    end
    @chats.each { |chat| chat.destroy! if Chat.exists?(chat.id) }
    @users.each { |user| user.destroy! if User.exists?(user.id) }
    assert_equal @fixture_user_attributes, @fixture_user.reload.attributes
    assert_empty terminated, "Concurrency workers required termination"
    raise worker_errors.first if worker_errors.any?
  end

  test "concurrent retries of the same source serialize and enqueue one pending replacement" do
    prompt, source = create_prompt(@chat, "Original intent")
    source.update!(content: "Partial output", status: :failed)
    contend_for_replacement(prompt, source)
    assert_equal "Partial output", source.reload.content
    assert source.failed?
  end

  test "concurrent explicit recovery of an orphan reserves one replacement" do
    prompt, source = create_prompt(@chat, "Interrupted intent")
    source.update_columns(updated_at: AssistantMessage::STALL_AFTER.ago - 1.minute)
    assert source.reload.stalled?
    contend_for_replacement(prompt, source, recover_interrupted: true)
    assert source.reload.failed?
    assert_nil source.execution_claimed_at
  end

  test "concurrent redelivery returns while the first provider is blocked and persists exactly one response" do
    earlier, previous = create_prompt(@chat, "Earlier intent")
    previous.update!(status: :complete, content: "Earlier answer")
    prompt, attempt = create_prompt(@chat, "Current intent")
    later, = create_prompt(@chat, "Later intent must not leak")
    entered = Queue.new
    calls = Queue.new
    release = release_queue
    ready = Queue.new
    returned = Queue.new
    provider = Object.new
    provider.define_singleton_method(:chat_response) do |text, **options|
      calls << { prompt: text, model: options[:model], messages: options[:messages] }
      entered << true
      release.pop
      options[:streamer].call(Provider::LlmConcept::ChatStreamChunk.new(type: "output_text", data: "Synthetic final answer"))
      Provider::Response.new(success?: true, data: nil, error: nil)
    end

    first = delivery_worker(attempt.id, provider, ready)
    first_pid = await(ready)
    await(entered)
    assert attempt.reload.pending?
    assert_not_nil attempt.execution_claimed_at
    claimed_at = attempt.execution_claimed_at

    second = delivery_worker(attempt.id, provider, ready, returned)
    second_pid = await(ready)
    refute_equal first_pid, second_pid, "Deliveries must use distinct PostgreSQL backends"
    assert_equal attempt.id, await(returned)
    join_worker(second)
    assert first.alive?, "First delivery must remain blocked in the synthetic provider"
    assert_equal 1, calls.size
    assert attempt.reload.pending?
    assert_equal "", attempt.content
    assert_equal claimed_at, attempt.execution_claimed_at

    release << true
    join_worker(first)
    assert_equal 1, calls.size
    assert_equal({ prompt: "Current intent", model: "gpt-5.4", messages: [
      { role: "user", content: earlier.content },
      { role: "assistant", content: previous.content }
    ] }, await(calls))
    assert attempt.reload.complete?
    assert_equal "Synthetic final answer", attempt.content
    assert_equal prompt.id, attempt.origin_user_message_id
    assert_equal 1, attempt.attempt_number
    assert_nil attempt.replaces_message_id
    assert_equal claimed_at, attempt.execution_claimed_at
    assert_equal attempt.id, @chat.authoritative_response_for(prompt).id
    assert_equal [ attempt.id ], @chat.messages.where(origin_user_message_id: prompt.id).pluck(:id)
    assert @chat.messages.find_by!(origin_user_message_id: later.id).pending?
  end

  test "database rejects duplicate origin attempt identities" do
    prompt, source = create_prompt(@chat, "Unique attempt")
    legacy = @chat.messages.create!(type: "AssistantMessage", content: "Legacy", ai_model: "gpt-5.4")
    assert_database_rejects(ActiveRecord::RecordNotUnique, "index_messages_on_origin_and_attempt") do
      Message.where(id: legacy.id).update_all(origin_user_message_id: prompt.id, attempt_number: source.attempt_number)
    end
  end

  test "database rejects duplicate replacement links independently of attempt identity" do
    prompt, source = create_prompt(@chat, "Unique replacement")
    source.update!(status: :failed)
    @chat.retry_last_message!(message_id: source.id)
    legacy = @chat.messages.create!(type: "AssistantMessage", content: "Legacy", ai_model: "gpt-5.4")
    assert_database_rejects(ActiveRecord::RecordNotUnique, "index_messages_on_replaced_attempt") do
      Message.where(id: legacy.id).update_all(origin_user_message_id: prompt.id, attempt_number: 3, replaces_message_id: source.id)
    end
  end

  test "database rejects duplicate ordered prompt turns" do
    prompt, = create_prompt(@chat, "First turn")
    other, = create_prompt(@chat, "Second turn")
    assert_database_rejects(ActiveRecord::RecordNotUnique, "index_messages_on_chat_and_turn") do
      Message.where(id: other.id).update_all(conversation_turn: prompt.conversation_turn)
    end
  end

  test "database checks reject malformed attempt and conversation shapes" do
    _prompt, source = create_prompt(@chat, "Shape checks")
    assert_database_rejects(ActiveRecord::StatementInvalid, "messages_response_attempt_shape") do
      Message.where(id: source.id).update_all(attempt_number: 0)
    end
    legacy = @chat.messages.create!(type: "AssistantMessage", content: "Legacy", ai_model: "gpt-5.4")
    assert_database_rejects(ActiveRecord::StatementInvalid, "messages_conversation_turn_shape") do
      Message.where(id: legacy.id).update_all(conversation_turn: 99)
    end
  end

  test "deferred origin foreign key rejects a cross chat link at commit" do
    _prompt, source = create_prompt(@chat, "Local intent")
    foreign_prompt, foreign_source = create_prompt(synthetic_chat, "Foreign intent")
    # Leave the foreign origin unreserved so its unique attempt key cannot mask
    # the composite in-chat FK failure we intend to exercise.
    foreign_source.destroy!
    assert_database_rejects(ActiveRecord::InvalidForeignKey, "fk_messages_origin_in_chat", deferred: true) do
      Message.where(id: source.id).update_all(origin_user_message_id: foreign_prompt.id)
    end
  end

  test "deferred replacement foreign key rejects a cross chat link at commit" do
    _prompt, source = create_prompt(@chat, "Local intent")
    source.update!(status: :failed)
    replacement = @chat.retry_last_message!(message_id: source.id)
    _foreign_prompt, foreign_source = create_prompt(synthetic_chat, "Foreign intent")
    assert_database_rejects(ActiveRecord::InvalidForeignKey, "fk_messages_replacement_in_chat", deferred: true) do
      Message.where(id: replacement.id).update_all(replaces_message_id: foreign_source.id)
    end
  end

  test "chat destruction callbacks remove a linked replacement chain with deferred foreign keys" do
    ids = replacement_chain(@chat)
    @chat.destroy!
    refute Chat.exists?(@chat.id)
    assert_empty Message.where(id: ids)
  end

  test "user destruction callbacks remove chats and their linked replacement chains" do
    user = @fixture_user.dup
    user.email = "response-concurrency-#{SecureRandom.uuid}@example.test"
    user.save!
    @users << user
    chat = synthetic_chat(user)
    ids = replacement_chain(chat)
    user.destroy!
    refute User.exists?(user.id)
    refute Chat.exists?(chat.id)
    assert_empty Message.where(id: ids)
  end

  private
    def synthetic_chat(user = @fixture_user)
      Chat.create!(user: user, title: "Synthetic response concurrency").tap { |chat| @chats << chat }
    end

    def create_prompt(chat, content)
      prompt = chat.messages.create!(type: "UserMessage", content: content, ai_model: "gpt-5.4")
      [ prompt, chat.messages.find_by!(origin_user_message_id: prompt.id, attempt_number: 1) ]
    end

    def replacement_chain(chat)
      prompt, source = create_prompt(chat, "Destruction intent")
      source.update!(status: :failed)
      replacement = chat.retry_last_message!(message_id: source.id)
      [ prompt.id, source.id, replacement.id ]
    end

    def release_queue
      Queue.new.tap { |queue| @releases << queue }
    end

    def await(queue)
      Timeout.timeout(10) { queue.pop }
    end

    def worker(&block)
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection(&block)
      end.tap { |thread| @threads << thread }
    end

    def join_worker(thread)
      assert thread.join(10), "Concurrency worker did not finish"
      thread.value # Propagate worker exceptions to the test, never silently lose them.
    end

    def delivery_worker(id, provider, ready, returned = nil)
      worker do |connection|
        attempt = AssistantMessage.find(id)
        chat = attempt.chat
        assistant = Assistant.new(chat)
        assistant.define_singleton_method(:get_model_provider) { |_model| provider }
        chat.define_singleton_method(:assistant) { assistant }
        ready << connection.select_value("SELECT pg_backend_pid()")
        AssistantResponseJob.perform_now(attempt)
        returned << attempt.id if returned
      end
    end

    def contend_for_replacement(prompt, source, recover_interrupted: false)
      ready = Queue.new
      locked = Queue.new
      results = Queue.new
      release = release_queue
      assert_enqueued_jobs 1, only: AssistantResponseJob do
        first = worker do |connection|
          chat = Chat.find(@chat.id)
          chat.define_singleton_method(:with_lock) do |&block|
            super() do
              locked << true
              release.pop
              block.call
            end
          end
          ready << connection.select_value("SELECT pg_backend_pid()")
          results << chat.retry_last_message!(message_id: source.id, recover_interrupted: recover_interrupted).id
        end
        first_pid = await(ready)
        await(locked)
        second = worker do |connection|
          chat = Chat.find(@chat.id)
          ready << connection.select_value("SELECT pg_backend_pid()")
          results << chat.retry_last_message!(message_id: source.id, recover_interrupted: recover_interrupted).id
        end
        second_pid = await(ready)
        refute_equal first_pid, second_pid, "Retries must use distinct PostgreSQL backends"
        Timeout.timeout(10) do
          loop do
            waiting = ActiveRecord::Base.connection_pool.with_connection do |connection|
              # Other integration tests can leave the pool query cache enabled.
              # Lock observation must be live, never a cached initial nil result.
              connection.uncached do
                connection.execute("SELECT pg_stat_clear_snapshot()")
                connection.select_value(<<~SQL)
                  SELECT query FROM pg_stat_activity
                  WHERE pid = #{Integer(second_pid)}
                    AND #{Integer(first_pid)} = ANY(pg_blocking_pids(pid))
                SQL
              end
            end
            if waiting
              assert_match(/FOR UPDATE/i, waiting)
              break
            end
            raise "Retry worker exited before contending for the chat lock" unless second.alive?
            Thread.pass
          end
        end
        assert_empty results
        release << true
        join_worker(first)
        join_worker(second)
      end
      ids = 2.times.map { await(results) }
      assert_equal 1, ids.uniq.size
      replacement = AssistantMessage.find(ids.first)
      assert replacement.pending?
      assert_equal "", replacement.content
      assert_nil replacement.execution_claimed_at
      assert_equal @chat.id, replacement.chat_id
      assert_equal prompt.id, replacement.origin_user_message_id
      assert_equal source.id, replacement.replaces_message_id
      assert_equal 2, replacement.attempt_number
      assert_equal prompt.ai_model, replacement.ai_model
      assert_equal [ replacement.id ], @chat.messages.where(origin_user_message_id: prompt.id, status: :pending).pluck(:id)
      assert_equal 2, @chat.messages.where(origin_user_message_id: prompt.id).count
      assert_equal replacement.id, source.reload.replacement.id
      job = enqueued_jobs.select { |entry| entry[:job] == AssistantResponseJob }.last
      assert_equal replacement, ActiveJob::Arguments.deserialize(job[:args]).first
    end

    def assert_database_rejects(error_class, constraint, deferred: false)
      statement_finished = false
      error = assert_raises(error_class) do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          connection.transaction(requires_new: true) do
            yield
            statement_finished = true
          end
        end
      end
      assert statement_finished, "Deferred foreign key must reject at commit, not at the write" if deferred
      assert_includes error.message, constraint
    end
end
