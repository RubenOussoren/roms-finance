require "test_helper"

class MessageFeedbackTest < ActiveSupport::TestCase
  test "validates rating presence" do
    feedback = MessageFeedback.new(message: messages(:chat1_assistant_response), user: users(:family_admin))
    assert_not feedback.valid?
  end

  test "enforces one feedback per user per message" do
    MessageFeedback.create!(message: messages(:chat1_assistant_response), user: users(:family_admin), rating: :thumbs_up)
    duplicate = MessageFeedback.new(message: messages(:chat1_assistant_response), user: users(:family_admin), rating: :thumbs_down)
    assert_not duplicate.valid?
  end

  test "allows different users to feedback same message" do
    MessageFeedback.create!(message: messages(:chat1_assistant_response), user: users(:family_admin), rating: :thumbs_up)
    other = MessageFeedback.new(message: messages(:chat1_assistant_response), user: users(:family_member), rating: :thumbs_down)
    assert other.valid?
  end
end
