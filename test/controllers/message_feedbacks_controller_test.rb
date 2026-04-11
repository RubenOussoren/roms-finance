require "test_helper"

class MessageFeedbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @chat = @user.chats.first
    @message = @chat.messages.where(type: "AssistantMessage").first
  end

  test "create feedback responds with turbo_stream" do
    post message_feedback_url(@message), params: {
      message_feedback: { rating: "thumbs_up" }
    }, as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert @message.reload.feedback.present?
    assert_equal "thumbs_up", @message.feedback.rating
  end

  test "create feedback falls back to redirect for html requests" do
    post message_feedback_url(@message), params: {
      message_feedback: { rating: "thumbs_up" }
    }

    assert_redirected_to chat_path(@chat)
  end

  test "toggle removes feedback when same rating submitted" do
    @message.create_feedback!(user: @user, rating: "thumbs_up")

    assert_difference "MessageFeedback.count", -1 do
      post message_feedback_url(@message), params: {
        message_feedback: { rating: "thumbs_up" }
      }, as: :turbo_stream
    end

    assert_response :success
  end

  test "updates feedback when different rating submitted" do
    @message.create_feedback!(user: @user, rating: "thumbs_up")

    assert_no_difference "MessageFeedback.count" do
      post message_feedback_url(@message), params: {
        message_feedback: { rating: "thumbs_down" }
      }, as: :turbo_stream
    end

    assert_equal "thumbs_down", @message.feedback.reload.rating
  end

  test "cannot feedback another user's message" do
    other_user = users(:family_member)
    other_message = other_user.chats.first.messages.first

    post message_feedback_url(other_message), params: {
      message_feedback: { rating: "thumbs_up" }
    }, as: :turbo_stream

    assert_response :not_found
  end

  test "cannot create feedback if AI is disabled" do
    @user.update!(ai_enabled: false)

    post message_feedback_url(@message), params: {
      message_feedback: { rating: "thumbs_up" }
    }

    assert_response :forbidden
  end
end
