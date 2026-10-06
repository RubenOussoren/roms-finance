require "test_helper"

class ResponseAttemptTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ProviderTestHelper

  setup do
    @chat = chats(:one)
    @assistant = Assistant.new(@chat)
    @chat.stubs(:assistant).returns(@assistant)
    @calls = []
    @scripts = []
    calls, scripts = @calls, @scripts
    @provider = Object.new
    @provider.define_singleton_method(:chat_response) do |prompt, **options|
      calls << { prompt: prompt, messages: options[:messages] }
      scripts.shift.call(options[:streamer])
    end
    @assistant.stubs(:get_model_provider).returns(@provider)
  end

  test "initial reservation is durable and repeated requests enqueue only once" do
    prompt = nil
    assert_enqueued_jobs 1, only: AssistantResponseJob do
      prompt = create_prompt("Original prompt")
      2.times { @chat.ask_assistant_later(prompt) }
    end
    attempt = initial_attempt(prompt)
    assert attempt.persisted?
    assert attempt.pending?
    assert_equal prompt.id, attempt.origin_user_message_id
    assert_equal 1, attempt.attempt_number
    assert_equal 1, prompt.conversation_turn
    assert_nil attempt.execution_claimed_at
    assert_equal 1, @chat.messages.where(origin_user_message_id: prompt.id).count
  end

  test "two persisted chunks timeout and retry uses a new durable replacement" do
    prompt = create_prompt("Original prompt")
    attempt = initial_attempt(prompt)
    @scripts << lambda do |streamer|
      %w[first second].each do |text|
        streamer.call(text_chunk(text))
        attempt.flush_buffer!
        expected = text == "first" ? "first" : "firstsecond"
        assert_equal expected, attempt.reload.content
      end
      raise Faraday::TimeoutError, "secret request body"
    end
    assert_no_difference "AssistantMessage.count" do
      attempt.request_response
    end
    assert attempt.reload.failed?
    assert_equal "firstsecond", attempt.content
    assert attempt.execution_claimed_at
    refute_includes @chat.reload.error, "secret request body"

    replacement = nil
    assert_enqueued_jobs 1, only: AssistantResponseJob do
      replacement = @chat.retry_last_message!(message_id: attempt.id)
    end
    assert_equal attempt.id, replacement.replaces_message_id
    assert_equal prompt.id, replacement.origin_user_message_id
    assert_equal 2, replacement.attempt_number
    assert_equal "", replacement.content
    succeed_with("Recovered")
    replacement.request_response
    assert replacement.reload.complete?
    assert_equal "Recovered", replacement.content
    assert_equal [ "Original prompt", "Original prompt" ], @calls.map { |call| call[:prompt] }
    assert_equal [ [], [] ], @calls.map { |call| call[:messages] }
    assert_equal "firstsecond", attempt.reload.content
  end

  test "regeneration uses original ordered context and only newest successful prior version" do
    previous_prompt = create_prompt("Earlier question")
    previous = initial_attempt(previous_prompt)
    succeed_with("Earlier old answer")
    previous.request_response
    previous_replacement = @chat.retry_last_message!(message_id: previous.id)
    succeed_with("Earlier authoritative answer")
    previous_replacement.request_response
    assert previous.reload.previous_version?

    prompt = create_prompt("Question being regenerated")
    original = initial_attempt(prompt)
    succeed_with("Original answer")
    original.request_response
    later = create_prompt("Later question must not leak")
    succeed_with("Later answer must not leak")
    initial_attempt(later).request_response

    replacement = @chat.retry_last_message!(message_id: original.id)
    refute original.reload.previous_version?, "pending replacement must not displace success"
    succeed_with("Regenerated answer")
    assert_no_difference "AssistantMessage.count" do
      replacement.request_response
    end
    assert_equal "Question being regenerated", @calls.last[:prompt]
    assert_equal [
      { role: "user", content: "Earlier question" },
      { role: "assistant", content: "Earlier authoritative answer" }
    ], @calls.last[:messages]
    assert original.reload.previous_version?
    refute replacement.reload.previous_version?
    assert_equal replacement.id, @chat.authoritative_response_for(prompt).id
    assert @chat.legacy_context?
    assert @chat.messages.exists?(messages(:chat1_assistant_response).id), "legacy remains visible"
  end

  test "failed regeneration preserves authoritative success and excludes partial reply from later context" do
    prompt = create_prompt("Question")
    original = initial_attempt(prompt)
    succeed_with("Good answer")
    original.request_response
    replacement = @chat.retry_last_message!(message_id: original.id)
    @scripts << lambda do |streamer|
      streamer.call(text_chunk("Failed partial"))
      raise Faraday::TimeoutError
    end
    replacement.request_response
    assert replacement.reload.failed?
    refute original.reload.previous_version?
    assert_equal original.id, @chat.authoritative_response_for(prompt).id
    next_prompt = create_prompt("Next question")
    succeed_with("Next answer")
    initial_attempt(next_prompt).request_response
    assert_equal [
      { role: "user", content: "Question" },
      { role: "assistant", content: "Good answer" }
    ], @calls.last[:messages]
  end

  test "same base click returns immediate replacement even after completion without enqueue" do
    prompt = create_prompt("Question")
    original = initial_attempt(prompt)
    original.update!(status: :failed)
    replacement = @chat.retry_last_message!(message_id: original.id)
    succeed_with("Done")
    replacement.request_response
    assert_no_enqueued_jobs only: AssistantResponseJob do
      assert_equal replacement.id, @chat.retry_last_message!(message_id: original.id).id
    end
    assert_equal 2, @chat.messages.where(origin_user_message_id: prompt.id).count
  end

  test "fallback selects latest numbered prompt and pending source is returned without enqueue" do
    create_prompt("Earlier")
    latest = create_prompt("Latest")
    attempt = initial_attempt(latest)
    assert_no_enqueued_jobs only: AssistantResponseJob do
      assert_equal attempt.id, @chat.retry_last_message!.id
      assert_equal attempt.id, @chat.retry_last_message!(message_id: attempt.id).id
    end
    assert @chat.response_in_progress?
  end

  test "retry rejects foreign chat user messages and unlinked legacy replies" do
    assert_raises(ActiveRecord::RecordNotFound) do
      @chat.retry_last_message!(message_id: messages(:chat2_user).id)
    end
    assert_raises(Chat::RetryUnavailable) do
      @chat.retry_last_message!(message_id: messages(:chat1_user).id)
    end
    error = assert_raises(Chat::RetryUnavailable) do
      @chat.retry_last_message!(message_id: messages(:chat1_assistant_response).id)
    end
    assert_includes error.message, "Send a new prompt"
  end

  test "no provider and enqueue failure leave durable empty failed attempts" do
    @assistant.stubs(:get_model_provider).returns(nil)
    prompt = create_prompt("Question")
    attempt = initial_attempt(prompt)
    attempt.request_response
    assert attempt.reload.failed?
    assert_equal "", attempt.content
    assert_includes @chat.reload.error, "Settings"

    AssistantResponseJob.stubs(:perform_later).raises(StandardError, "secret enqueue details")
    next_prompt = create_prompt("Another question")
    failed = initial_attempt(next_prompt)
    assert failed.failed?
    assert_nil failed.execution_claimed_at
    assert_equal "", failed.content
    refute_includes @chat.reload.error, "secret enqueue details"
  end

  test "empty successful provider response becomes a recoverable failed attempt" do
    prompt = create_prompt("Question")
    attempt = initial_attempt(prompt)
    @scripts << ->(_streamer) { provider_success_response(nil) }
    assert_equal attempt.id, attempt.request_response.id
    assert attempt.reload.failed?
    assert_equal "", attempt.content
    assert attempt.execution_claimed_at
    assert_includes @chat.reload.error, "Please retry"
    replacement = @chat.retry_last_message!(message_id: attempt.id)
    succeed_with("Recovered")
    replacement.request_response
    assert replacement.reload.complete?
    assert_equal "Recovered", replacement.content
  end

  test "summary provider context excludes legacy partial and superseded answers" do
    first_prompt = create_prompt("First question")
    first = initial_attempt(first_prompt)
    first.update!(content: "Superseded answer", status: :complete)
    replacement = @chat.retry_last_message!(message_id: first.id)
    replacement.update!(content: "Authoritative answer", status: :complete)
    second_prompt = create_prompt("Second question")
    initial_attempt(second_prompt).update!(content: "Second answer", status: :complete)
    registry = mock
    registry.expects(:providers).returns([ @provider ])
    Provider::Registry.expects(:for_concept).with(:llm).returns(registry)
    @scripts << lambda do |_streamer|
      response = Provider::LlmConcept::ChatResponse.new(id: "summary", model: "gpt-5.4",
        messages: [ Provider::LlmConcept::ChatMessage.new(id: "summary", output_text: "Summary") ], function_requests: [])
      provider_success_response(response)
    end
    @chat.update!(summary: nil)
    @chat.generate_summary
    assert_equal "Summary", @chat.reload.summary
    assert_includes @calls.last[:prompt], "Authoritative answer"
    refute_includes @calls.last[:prompt], "Superseded answer"
    refute_includes @calls.last[:prompt], messages(:chat1_assistant_response).content
  end

  test "failed and pending preceding attempts are excluded from context" do
    failed_prompt = create_prompt("Failed question")
    failed = initial_attempt(failed_prompt)
    failed.update!(content: "Failed text", status: :failed)
    create_prompt("Pending question")
    next_prompt = create_prompt("Current question")
    succeed_with("Current answer")
    initial_attempt(next_prompt).request_response
    assert_equal [
      { role: "user", content: "Failed question" },
      { role: "user", content: "Pending question" }
    ], @calls.last[:messages]
  end

  test "origin replacement and persisted identity are validated" do
    prompt = create_prompt("Question")
    attempt = initial_attempt(prompt)
    foreign_prompt = messages(:chat2_user)
    invalid = AssistantMessage.new(chat: @chat, content: "", status: :pending,
      ai_model: "gpt-5.4", origin_user_message: foreign_prompt, attempt_number: 1)
    refute invalid.valid?
    assert invalid.errors[:origin_user_message].present?
    invalid.origin_user_message_id = attempt.id
    refute invalid.valid?, "assistant cannot serve as origin"
    invalid.origin_user_message = prompt
    invalid.attempt_number = 2
    invalid.replaces_message = AssistantMessage.new(chat: chats(:two), content: "Foreign", ai_model: "gpt-5.4")
    refute invalid.valid?, "replacement must be persisted in the same chat"
    invalid.replaces_message = messages(:chat1_assistant_response)
    refute invalid.valid?, "legacy answer cannot serve as replacement source"
    attempt.attempt_number = 9
    refute attempt.valid?
    assert_includes attempt.errors[:attempt_number], "cannot be changed"
    attempt.reload
    assert attempt.claim_execution!
    attempt.execution_claimed_at = nil
    refute attempt.valid?
    assert_includes attempt.errors[:execution_claimed_at], "cannot be changed once claimed"
  end

  test "explicit recovery fences a live stalled regeneration after its replacement succeeds" do
    prompt = create_prompt("Question")
    original = initial_attempt(prompt)
    succeed_with("Authoritative answer")
    original.request_response
    interrupted = @chat.retry_last_message!(message_id: original.id)
    interrupted.stubs(:should_flush?).returns(false)
    replacement = nil
    claimed_at = nil
    @scripts << lambda do |streamer|
      streamer.call(text_chunk("Persisted partial"))
      interrupted.flush_buffer!
      streamer.call(text_chunk("Buffered abandoned text"))
      claimed_at = interrupted.execution_claimed_at
      travel AssistantMessage::STALL_AFTER + 1.second
      assert interrupted.reload.stalled?
      assert_enqueued_jobs 1, only: AssistantResponseJob do
        replacement = @chat.retry_last_message!(message_id: interrupted.id, recover_interrupted: true)
        assert_equal replacement.id, @chat.retry_last_message!(message_id: interrupted.id, recover_interrupted: true).id
      end
      assert interrupted.reload.failed?
      assert_equal original.id, @chat.authoritative_response_for(prompt).id
      refute original.reload.previous_version?
      succeed_with("Recovered answer")
      replacement.request_response
      assert_no_enqueued_jobs only: AssistantResponseJob do
        assert_equal replacement.id, @chat.retry_last_message!(message_id: interrupted.id, recover_interrupted: true).id
      end
      streamer.call(text_chunk("Late abandoned text"))
      response = Provider::LlmConcept::ChatResponse.new(id: "late", model: "gpt-5.4",
        messages: [], function_requests: [], input_tokens: 123, output_tokens: 456,
        tool_calls_log: [ { function_name: "late_tool", arguments: {}, result: "late result" } ])
      streamer.call(Provider::LlmConcept::ChatStreamChunk.new(type: "response", data: response))
      provider_success_response(response)
    end
    assert_equal interrupted.id, interrupted.request_response.id
    assert interrupted.reload.failed?
    assert_equal "Persisted partial", interrupted.content
    assert_equal claimed_at, interrupted.execution_claimed_at
    assert_nil interrupted.input_tokens
    assert_nil interrupted.output_tokens
    assert_nil interrupted.cost_cents
    assert_empty interrupted.tool_calls
    assert replacement.reload.complete?
    assert_equal "Recovered answer", replacement.content
    assert_equal replacement.id, @chat.authoritative_response_for(prompt).id
    assert_equal 3, @chat.messages.where(origin_user_message_id: prompt.id).count
    assert_equal 3, @calls.size
    @assistant.expects(:get_model_provider).never
    interrupted.request_response
    assert_equal claimed_at, interrupted.reload.execution_claimed_at
  end

  test "late provider failure after explicit abandonment cannot overwrite status or emit error" do
    prompt = create_prompt("Question")
    interrupted = initial_attempt(prompt)
    @scripts << lambda do |streamer|
      streamer.call(text_chunk("Partial"))
      interrupted.flush_buffer!
      travel AssistantMessage::STALL_AFTER + 1.second
      replacement = @chat.retry_last_message!(message_id: interrupted.id, recover_interrupted: true)
      succeed_with("Recovered")
      replacement.request_response
      @chat.expects(:add_error).never
      raise Faraday::TimeoutError, "late error"
    end
    assert_equal interrupted.id, interrupted.request_response.id
    assert interrupted.reload.failed?
    assert_equal "Partial", interrupted.content
    assert_nil @chat.reload.error
    assert_equal "Recovered", @chat.authoritative_response_for(prompt).content
  end

  test "abandoned first token cannot remove replacement thinking indicator" do
    prompt = create_prompt("Question")
    interrupted = initial_attempt(prompt)
    replacement = nil
    @scripts << lambda do |streamer|
      travel AssistantMessage::STALL_AFTER + 1.second
      replacement = @chat.retry_last_message!(message_id: interrupted.id, recover_interrupted: true)
      @assistant.expects(:stop_thinking).never
      streamer.call(text_chunk("Late first token"))
      response = Provider::LlmConcept::ChatResponse.new(id: "late", model: "gpt-5.4",
        messages: [], function_requests: [])
      streamer.call(Provider::LlmConcept::ChatStreamChunk.new(type: "response", data: response))
      provider_success_response(response)
    end
    interrupted.request_response
    assert interrupted.reload.failed?
    assert_equal "", interrupted.content
    assert replacement.reload.pending?
    assert_nil replacement.execution_claimed_at
  end

  test "pending recovery requires explicit consent and more than five minutes without persisted activity" do
    prompt = create_prompt("Question")
    attempt = initial_attempt(prompt)
    assert_no_enqueued_jobs only: AssistantResponseJob do
      refute attempt.stalled?
      assert_equal attempt.id, @chat.retry_last_message!(message_id: attempt.id, recover_interrupted: true).id
      travel AssistantMessage::STALL_AFTER
      refute attempt.reload.stalled?, "exact threshold is not older than five minutes"
      assert_equal attempt.id, @chat.retry_last_message!(message_id: attempt.id, recover_interrupted: true).id
      travel 1.second
      assert attempt.reload.stalled?
      assert_equal attempt.id, @chat.retry_last_message!(message_id: attempt.id).id
      assert_equal attempt.id, @chat.retry_last_message!.id
    end
    assert attempt.reload.pending?
    assert_equal 1, @chat.messages.where(origin_user_message_id: prompt.id).count
    attempt.update!(content: "Recent persisted activity")
    refute attempt.reload.stalled?
    assert_no_enqueued_jobs only: AssistantResponseJob do
      assert_equal attempt.id, @chat.retry_last_message!(message_id: attempt.id, recover_interrupted: true).id
    end
  end

  test "chat error replaces singleton wrapper contents rather than appending banners" do
    @chat.expects(:broadcast_append).never
    @chat.expects(:broadcast_update).with(target: "chat-error-container", partial: "chats/error", locals: { chat: @chat }).twice
    2.times { @chat.add_error(Provider::Error.new("Failed reply")) }
    @chat.expects(:broadcast_remove).with(target: "chat-error")
    @chat.clear_error
    assert_nil @chat.reload.error
  end

  private
    def create_prompt(content)
      @chat.messages.create!(type: "UserMessage", content: content, ai_model: "gpt-5.4")
    end

    def initial_attempt(prompt)
      @chat.messages.find_by!(origin_user_message_id: prompt.id, attempt_number: 1)
    end

    def text_chunk(text)
      Provider::LlmConcept::ChatStreamChunk.new(type: "output_text", data: text)
    end

    def succeed_with(text)
      @scripts << lambda do |streamer|
        streamer.call(text_chunk(text))
        response = Provider::LlmConcept::ChatResponse.new(id: SecureRandom.uuid, model: "gpt-5.4",
          messages: [ Provider::LlmConcept::ChatMessage.new(id: "1", output_text: text) ], function_requests: [])
        streamer.call(Provider::LlmConcept::ChatStreamChunk.new(type: "response", data: response))
        provider_success_response(response)
      end
    end
end
