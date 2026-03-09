require "test_helper"

class AssistantMessageTest < ActiveSupport::TestCase
  test "assistant message starts pending and transitions to complete" do
    msg = AssistantMessage.create!(chat: chats(:one), content: "", ai_model: "gpt-4.1", status: :pending)
    assert msg.pending?
    msg.update!(content: "Hello! Here is your response.", status: :complete)
    assert msg.complete?
  end
end
