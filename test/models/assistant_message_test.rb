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

  test "calculate_cost returns nil for unknown models instead of false zero" do
    msg = AssistantMessage.new(ai_model: "nonexistent-model", input_tokens: 1000, output_tokens: 500)
    assert_nil msg.calculate_cost(dispatched_model: "also-unknown")
  end

  test "calculate_cost falls back when returned catalog entry has no pricing" do
    unpriced = RubyLLM::Model.new(id: "unpriced", provider: "openai")
    priced = RubyLLM.models.find("gpt-5-mini")
    RubyLLM.models.stubs(:find).with("unpriced").returns(unpriced)
    RubyLLM.models.stubs(:find).with("gpt-5-mini").returns(priced)
    msg = AssistantMessage.new(ai_model: "unpriced", input_tokens: 1_000_000, output_tokens: 1_000_000)
    # gpt-5-mini: $0.25 input + $2.00 output per million, in cents.
    assert_equal 225, msg.calculate_cost(dispatched_model: "gpt-5-mini")
    assert_nil msg.calculate_cost
  end

  test "base model names remove only terminal dated snapshot suffixes" do
    assert_equal "gpt-5-mini", AssistantMessage.base_model_name("gpt-5-mini-2025-08-07")
    assert_equal "claude-sonnet-4", AssistantMessage.base_model_name("claude-sonnet-4-20250514")
    assert_equal "gpt-4.1", AssistantMessage.base_model_name("gpt-4.1")
    assert_equal "model-2025-08-07-preview", AssistantMessage.base_model_name("model-2025-08-07-preview")
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
