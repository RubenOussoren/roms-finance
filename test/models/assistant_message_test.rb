require "test_helper"

class AssistantMessageTest < ActiveSupport::TestCase
  test "assistant message starts pending and transitions to complete" do
    msg = claimed_attempt
    assert msg.pending?
    msg.update!(content: "Hello! Here is your response.", status: :complete)
    assert msg.complete?
  end

  test "append_text! batches writes" do
    msg = claimed_attempt
    msg.start_streaming!

    10.times { msg.append_text!("word ") }
    msg.flush_buffer!

    assert_equal "word " * 10, msg.content
  end

  test "flush_buffer! is no-op when buffer is empty" do
    msg = claimed_attempt
    msg.start_streaming!
    msg.flush_buffer!
    assert_equal "", msg.content
  end

  test "calculate_cost uses RubyLLM 2 pricing in cents" do
    model = RubyLLM::Model.new(id: "priced-model", provider: "openai",
      pricing: { text_tokens: { standard: { input_per_million: 2, output_per_million: 8 } } })
    RubyLLM.models.expects(:find).with("priced-model").returns(model)
    msg = AssistantMessage.new(ai_model: "priced-model", input_tokens: 10_000, output_tokens: 5_000)
    assert_equal 6, msg.calculate_cost
  end

  test "calculate_cost returns 0 for unknown model" do
    msg = AssistantMessage.new(ai_model: "nonexistent-model", input_tokens: 1000, output_tokens: 500)
    assert_equal 0, msg.calculate_cost
  end

  test "calculate_cost returns 0 when tokens are nil" do
    msg = AssistantMessage.new(ai_model: "gpt-5.4", input_tokens: nil, output_tokens: nil)
    assert_equal 0, msg.calculate_cost
  end
  private
    def claimed_attempt
      chat = chats(:one)
      prompt = chat.messages.create!(type: "UserMessage", content: "Streaming prompt", ai_model: "gpt-5.4")
      attempt = chat.messages.find_by!(origin_user_message_id: prompt.id, attempt_number: 1)
      assert attempt.claim_execution!
      attempt
    end
end
