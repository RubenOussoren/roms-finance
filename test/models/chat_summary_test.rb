require "test_helper"

class ChatSummaryTest < ActiveSupport::TestCase
  test "generate_summary skips if summary already present" do
    chat = chats(:one)
    chat.update!(summary: "Already summarized")
    chat.generate_summary
    assert_equal "Already summarized", chat.reload.summary
  end

  test "generate_summary skips if fewer than 4 messages" do
    chat = chats(:one)
    # The fixture chat likely has few messages
    chat.conversation_messages.where.not(id: chat.conversation_messages.ordered.limit(3).pluck(:id)).destroy_all
    chat.generate_summary
    assert_nil chat.reload.summary
  end
end
