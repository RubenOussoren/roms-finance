require "test_helper"

class AssistantResponseJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ProviderTestHelper

  setup do
    @chat = chats(:one)
    @prompt = @chat.messages.create!(type: "UserMessage", content: "Explicit intent", ai_model: "gpt-5.4")
    @attempt = @chat.messages.find_by!(origin_user_message_id: @prompt.id, attempt_number: 1)
    @assistant = Assistant.new(@chat)
    @chat.stubs(:assistant).returns(@assistant)
  end

  test "legacy queued user message safely does nothing" do
    legacy = messages(:chat1_user)
    legacy.expects(:request_response).never
    assert_no_difference "AssistantMessage.count" do
      AssistantResponseJob.perform_now(legacy)
    end
    assert_nil legacy.reload.conversation_turn
  end

  test "new user message job also cannot infer intent" do
    @prompt.expects(:request_response).never
    AssistantResponseJob.perform_now(@prompt)
    assert_nil @attempt.reload.execution_claimed_at
  end

  test "claim excludes competing delivery during provider work and terminal redelivery" do
    provider = mock
    @assistant.expects(:get_model_provider).returns(provider).once
    provider.expects(:chat_response).with do |prompt, **options|
      assert_equal "Explicit intent", prompt
      assert @attempt.reload.execution_claimed_at, "claim must be persisted before provider work"
      competing_copy = AssistantMessage.find(@attempt.id)
      assert_no_difference "AssistantMessage.count" do
        AssistantResponseJob.perform_now(competing_copy)
      end
      assert competing_copy.reload.pending?
      options[:streamer].call(Provider::LlmConcept::ChatStreamChunk.new(type: "output_text", data: "Done"))
      true
    end.returns(provider_success_response(nil)).once
    assert_no_difference "AssistantMessage.count" do
      AssistantResponseJob.perform_now(@attempt)
      AssistantResponseJob.perform_now(AssistantMessage.find(@attempt.id))
      @assistant.respond_to(@prompt)
    end
    assert @attempt.reload.complete?
    assert_equal "Done", @attempt.content
  end

  test "separate persisted instances contend for a single claim and claim cannot be reset" do
    other_delivery = AssistantMessage.find(@attempt.id)
    assert @attempt.claim_execution!
    claimed_at = @attempt.reload.execution_claimed_at
    refute other_delivery.claim_execution!
    assert_equal claimed_at, other_delivery.reload.execution_claimed_at
    other_delivery.execution_claimed_at = nil
    assert_raises(ActiveRecord::RecordInvalid) { other_delivery.save! }
    assert_equal claimed_at, @attempt.reload.execution_claimed_at
  end

  test "failed attempt redelivery never invokes provider or creates a row" do
    @attempt.update!(status: :failed)
    @assistant.expects(:get_model_provider).never
    assert_no_difference "AssistantMessage.count" do
      AssistantResponseJob.perform_now(@attempt)
    end
    assert @attempt.reload.failed?
    assert_nil @attempt.execution_claimed_at
  end

  test "queued unclaimed stale attempt can be explicitly abandoned and its old job cannot invoke provider" do
    travel AssistantMessage::STALL_AFTER + 1.second
    assert @attempt.reload.stalled?
    replacement = nil
    assert_enqueued_jobs 1, only: AssistantResponseJob do
      replacement = @chat.retry_last_message!(message_id: @attempt.id, recover_interrupted: true)
      assert_equal replacement.id, @chat.retry_last_message!(message_id: @attempt.id, recover_interrupted: true).id
    end
    assert @attempt.reload.failed?
    assert_nil @attempt.execution_claimed_at
    assert_equal @attempt.id, replacement.replaces_message_id
    assert_equal @prompt.id, replacement.origin_user_message_id
    assert_equal 2, replacement.attempt_number
    assert_equal 2, @chat.messages.where(origin_user_message_id: @prompt.id).count
    @assistant.expects(:get_model_provider).never
    assert_no_difference "AssistantMessage.count" do
      AssistantResponseJob.perform_now(AssistantMessage.find(@attempt.id))
    end
    assert replacement.reload.pending?
  end

  test "stale claimed pending redelivery never takes over execution" do
    assert @attempt.claim_execution!
    claimed_at = @attempt.reload.execution_claimed_at
    travel AssistantMessage::STALL_AFTER + 1.second
    assert @attempt.reload.stalled?
    @assistant.expects(:get_model_provider).never
    assert_no_difference "AssistantMessage.count" do
      AssistantResponseJob.perform_now(AssistantMessage.find(@attempt.id))
    end
    assert @attempt.reload.pending?
    assert_equal claimed_at, @attempt.execution_claimed_at
  end
end
