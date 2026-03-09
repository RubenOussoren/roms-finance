require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @chat = @user.chats.first
  end

  test "create responds with turbo_stream" do
    post chat_messages_url(@chat), params: {
      message: { content: "Hello", ai_model: "gpt-5.4" }
    }, as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
  end

  test "create falls back to redirect for html requests" do
    post chat_messages_url(@chat), params: { message: { content: "Hello", ai_model: "gpt-5.4" } }

    assert_redirected_to chat_path(@chat)
  end

  test "cannot create a message if AI is disabled" do
    @user.update!(ai_enabled: false)

    post chat_messages_url(@chat), params: { message: { content: "Hello", ai_model: "gpt-5.4" } }

    assert_response :forbidden
  end
end
