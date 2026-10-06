require "test_helper"

class ChatsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @family = families(:dylan_family)
    sign_in @user
  end

  test "gets index" do
    get chats_url
    assert_response :success
  end

  test "creates chat" do
    assert_difference("Chat.count") do
      post chats_url, params: { chat: { content: "Hello", ai_model: "gpt-5.4" } }
    end

    assert_redirected_to chat_path(Chat.order(created_at: :desc).first)
  end

  test "shows chat" do
    get chat_url(chats(:one))
    assert_response :success
  end

  test "destroys chat" do
    assert_difference("Chat.count", -1) do
      delete chat_url(chats(:one))
    end

    assert_redirected_to chats_url
  end

  test "retries explicit source once and stale duplicate preserves attempt identity" do
    chat = chats(:one)
    prompt, source = create_attempt(chat)
    source.update!(status: :failed, content: "Partial answer")

    assert_difference "AssistantMessage.count", 1 do
      assert_enqueued_jobs 1, only: AssistantResponseJob do
        post retry_chat_url(chat), params: { message_id: source.id }
      end
    end
    assert_redirected_to chat_path(chat)
    replacement = source.reload.replacement
    assert_equal prompt.id, replacement.origin_user_message_id
    assert_equal source.id, replacement.replaces_message_id
    assert replacement.pending?
    assert_enqueued_with(job: AssistantResponseJob, args: [ replacement ])

    assert_no_difference "AssistantMessage.count" do
      assert_enqueued_jobs 0, only: AssistantResponseJob do
        post retry_chat_url(chat), params: { message_id: source.id }
      end
    end
    assert_redirected_to chat_path(chat)
    assert_equal replacement.id, source.reload.replacement.id
    assert_equal "Partial answer", source.content
  end

  test "failed replies including empty attempts remain visibly failed after retry and reload" do
    chat = chats(:one)
    prompt, source = create_attempt(chat)
    source.update!(status: :failed, content: "Partial answer")
    chat.update!(error: "private provider exception")
    get chat_url(chat)
    assert_response :success
    assert_select "#chat-error", text: /Failed to generate response/
    refute_includes response.body, "private provider exception"
    assert_select "#chat-error form", count: 0
    assert_select "#assistant_message_#{source.id}", text: /FAILED/
    assert_retry_form("#assistant_message_#{source.id}", chat, source)
    assert_includes response.body, prompt.content

    post retry_chat_url(chat), params: { message_id: source.id }
    replacement = source.reload.replacement
    follow_redirect!
    assert_select "#chat-error", count: 0
    assert_select "#assistant_message_#{source.id}", text: /FAILED/
    assert_select "#assistant_message_#{replacement.id}", text: /Generating response/
    assert_select "form[action='#{retry_chat_path(chat)}']", count: 0

    replacement.update!(status: :failed, content: "")
    get chat_url(chat)
    assert_select "#assistant_message_#{replacement.id}", text: /FAILED/
    assert_retry_form("#assistant_message_#{replacement.id}", chat, replacement)
    assert_includes response.body, prompt.content
  end

  test "previous version label requires newer success and regeneration targets actual answer" do
    chat = chats(:one)
    prompt, source = create_attempt(chat)
    source.update!(status: :complete, content: "Successful original")
    get chat_url(chat)
    assert_retry_form("#assistant_message_#{source.id}", chat, source)

    replacement = chat.retry_last_message!(message_id: source.id)
    get chat_url(chat)
    assert_select "#assistant_message_#{source.id}", text: /Successful original/
    assert_select "#assistant_message_#{source.id} p[role='status']", count: 0
    assert_select "#assistant_message_#{source.id} form[action='#{retry_chat_path(chat)}']", count: 0
    assert_select "#assistant_message_#{replacement.id}", text: /Generating response/

    replacement.update!(status: :failed, content: "Failed regeneration")
    chat.update!(error: "private regeneration failure")
    get chat_url(chat)
    assert_select "#chat-error", text: /Failed to generate response/
    assert_select "#chat-error form", count: 0
    refute_includes response.body, "private regeneration failure"
    assert_select "#assistant_message_#{source.id} p[role='status']", count: 0
    assert_equal source.id, chat.authoritative_response_for(prompt).id
    assert_retry_form("#assistant_message_#{replacement.id}", chat, replacement)

    successful = chat.retry_last_message!(message_id: replacement.id)
    successful.update!(status: :complete, content: "New authoritative answer")
    get chat_url(chat)
    assert_select "#assistant_message_#{source.id}", text: /Previous version/
    assert_select "#assistant_message_#{replacement.id}", text: /FAILED/
    assert_select "#assistant_message_#{successful.id} p[role='status']", count: 0
    assert_retry_form("#assistant_message_#{successful.id}", chat, successful)
    assert_includes response.body, prompt.content
  end

  test "legacy history is disclosed and retry requires an explicit new prompt" do
    chat = chats(:one)
    legacy = messages(:chat1_assistant_response)
    chat.update!(error: "private legacy error")
    get chat_url(chat)
    assert_select "p[role='note']", text: /excluded from AI context/
    assert_includes response.body, legacy.content
    assert_select "#assistant_message_#{legacy.id} form[action='#{retry_chat_path(chat)}']", count: 0
    assert_select "#chat-error", text: /Send a new prompt/
    assert_select "#chat-error form", count: 0
    refute_includes response.body, "private legacy error"

    assert_no_difference "Message.count" do
      assert_enqueued_jobs 0, only: AssistantResponseJob do
        post retry_chat_url(chat), params: { message_id: legacy.id }
      end
    end
    assert_redirected_to chat_path(chat)
    assert_includes flash[:alert], "Send a new prompt"
  end

  test "global error never targets the newer successful prompt" do
    chat = chats(:one)
    _, earlier = create_attempt(chat)
    _, later = create_attempt(chat)
    later.update!(status: :complete, content: "Later successful answer")
    earlier.update!(status: :failed, content: "Earlier failed partial")
    chat.add_error(Provider::Error.new("Earlier attempt failed"))
    get chat_url(chat)
    assert_select "#chat-error-container #chat-error", count: 1
    assert_select "#chat-error form", count: 0
    assert_retry_form("#assistant_message_#{earlier.id}", chat, earlier)
    assert_select "#chat-error", text: /Use Retry on the failed response/
    assert_equal "Later successful answer", later.reload.content
  end

  test "stalled queued attempt offers explicit stop and retry after reload" do
    chat = chats(:one)
    prompt, source = create_attempt(chat)
    source.update_columns(updated_at: 6.minutes.ago)
    get chat_url(chat)
    assert_select "#assistant_message_#{source.id}", text: /No response update for five minutes/
    assert_select "#assistant_message_#{source.id} input[name='recover_interrupted'][value='true']", count: 1
    assert_enqueued_jobs 1, only: AssistantResponseJob do
      post retry_chat_url(chat), params: { message_id: source.id, recover_interrupted: "true" }
    end
    replacement = source.reload.replacement
    assert source.failed?
    assert_equal prompt.id, replacement.origin_user_message_id
    assert_redirected_to chat_path(chat)
    follow_redirect!
    assert_select "#assistant_message_#{source.id}", text: /FAILED/
    assert_select "#assistant_message_#{replacement.id}", text: /Generating response/
  end

  test "foreign message source cannot be retried through an owned chat" do
    chat = chats(:one)
    other_chat = @user.chats.create!(title: "Another owned chat")
    _, source = create_attempt(other_chat)
    source.update!(status: :failed, content: "")
    assert_no_difference "Message.count" do
      assert_enqueued_jobs 0, only: AssistantResponseJob do
        post retry_chat_url(chat), params: { message_id: source.id }
      end
    end
    assert_response :not_found
  end

  test "should not allow access to other user's chats" do
    other_user = users(:family_member)
    other_chat = Chat.create!(user: other_user, title: "Other User's Chat")

    get chat_url(other_chat)
    assert_response :not_found

    post retry_chat_url(other_chat), params: { message_id: messages(:chat1_assistant_response).id }
    assert_response :not_found

    delete chat_url(other_chat)
    assert_response :not_found
  end

  private
    def create_attempt(chat)
      prompt = chat.messages.create!(type: "UserMessage", content: "Original explicit prompt", ai_model: "gpt-5.4")
      [ prompt, chat.messages.find_by!(origin_user_message_id: prompt.id, attempt_number: 1) ]
    end

    def assert_retry_form(selector, chat, source)
      assert_select "#{selector} form[action='#{retry_chat_path(chat)}'][method='post']", count: 1 do
        assert_select "input[name='message_id'][value='#{source.id}']", count: 1
        assert_select "button[data-turbo-submits-with]", count: 1
      end
    end
end
