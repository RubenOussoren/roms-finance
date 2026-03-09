require "test_helper"

class AssistantMessageTest < ActiveSupport::TestCase
  test "assistant message starts pending and transitions to complete" do
    msg = AssistantMessage.create!(chat: chats(:one), content: "", ai_model: "gpt-4.1", status: :pending)
    assert msg.pending?
    msg.update!(content: "Hello! Here is your response.", status: :complete)
    assert msg.complete?
  end

  test "append_text! batches writes" do
    msg = AssistantMessage.create!(chat: chats(:one), content: "", ai_model: "gpt-4.1", status: :pending)
    msg.start_streaming!

    10.times { msg.append_text!("word ") }
    msg.flush_buffer!

    assert_equal "word " * 10, msg.content
  end

  test "flush_buffer! is no-op when buffer is empty" do
    msg = AssistantMessage.create!(chat: chats(:one), content: "", ai_model: "gpt-4.1", status: :pending)
    msg.start_streaming!
    msg.flush_buffer!
    assert_equal "", msg.content
  end
end
