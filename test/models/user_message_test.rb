require "test_helper"

class UserMessageTest < ActiveSupport::TestCase
  setup do
    @chat = chats(:one)
  end

  test "requests assistant response after creation" do
    @chat.expects(:ask_assistant_later).once

    message = UserMessage.create!(chat: @chat, content: "Hello from user", ai_model: "gpt-5.4")
    message.update!(content: "updated")

    streams = capture_turbo_stream_broadcasts(@chat)
    assert_equal 2, streams.size
    assert_equal "append", streams.first["action"]
    assert_equal "messages", streams.first["target"]
    assert_equal "update", streams.last["action"]
    assert_equal "user_message_#{message.id}", streams.last["target"]
  end

  test "new prompts receive positive ordered turns without numbering legacy history" do
    first = @chat.messages.create!(type: "UserMessage", content: "First", ai_model: "gpt-5.4")
    second = @chat.messages.create!(type: "UserMessage", content: "Second", ai_model: "gpt-5.4")
    assert_equal 1, first.conversation_turn
    assert_equal 2, second.conversation_turn
    assert_nil messages(:chat1_user).reload.conversation_turn
    assert_equal 1, @chat.messages.where(origin_user_message_id: first.id).count
    assert_equal 1, @chat.messages.where(origin_user_message_id: second.id).count
    first.conversation_turn = 3
    refute first.valid?
    assert_includes first.errors[:conversation_turn], "cannot be changed"
  end
end
