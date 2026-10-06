# frozen_string_literal: true

require "test_helper"

class Api::V1::MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @user.update!(ai_enabled: true)

    @oauth_app = Doorkeeper::Application.create!(
      name: "Test API App",
      redirect_uri: "https://example.com/callback",
      scopes: "read write read_write"
    )

    @write_token = Doorkeeper::AccessToken.create!(
      application: @oauth_app,
      resource_owner_id: @user.id,
      scopes: "read_write"
    )

    @chat = chats(:one)
  end

  test "should require authentication" do
    post "/api/v1/chats/#{@chat.id}/messages"
    assert_response :unauthorized
  end

  test "should require AI to be enabled" do
    @user.update!(ai_enabled: false)

    post "/api/v1/chats/#{@chat.id}/messages",
      params: { content: "Hello" },
      headers: bearer_auth_header(@write_token)
    assert_response :forbidden
  end

  test "should create message with write scope" do
    assert_difference "Message.count", 2 do
      post "/api/v1/chats/#{@chat.id}/messages",
        params: { content: "Test message", model: "gpt-5.4" },
        headers: bearer_auth_header(@write_token)
    end

    assert_response :created
    response_body = JSON.parse(response.body)
    assert_equal "Test message", response_body["content"]
    assert_equal "user_message", response_body["type"]
    assert_equal "pending", response_body["ai_response_status"]
  end

  test "create reserves one attempt and enqueues it only once" do
    assert_enqueued_jobs 1, only: AssistantResponseJob do
      post "/api/v1/chats/#{@chat.id}/messages",
        params: { content: "Test message" },
        headers: bearer_auth_header(@write_token)
    end
    assert_response :created
    prompt = @chat.messages.find(JSON.parse(response.body).fetch("id"))
    attempt = initial_attempt(prompt)
    assert_equal "Test message", prompt.content
    assert attempt.pending?
    assert_equal 1, attempt.attempt_number
    assert_enqueued_with(job: AssistantResponseJob, args: [ attempt ])
  end

  test "retry returns durable identity and synthetic execution uses original prompt context" do
    earlier = create_prompt("Earlier question")
    initial_attempt(earlier).update!(status: :complete, content: "Earlier answer")
    prompt = create_prompt("Retry this original question")
    source = initial_attempt(prompt)
    source.update!(status: :failed, content: "Partial response")
    later = create_prompt("Later question must not leak")
    initial_attempt(later).update!(status: :complete, content: "Later answer must not leak")

    assert_difference "AssistantMessage.count", 1 do
      assert_enqueued_jobs 1, only: AssistantResponseJob do
        retry_message(source.id)
      end
    end
    assert_response :accepted
    body = JSON.parse(response.body)
    attempt = @chat.messages.find(body.fetch("attempt_id"))
    assert_equal attempt.id, body.fetch("message_id")
    assert_equal prompt.id, body.fetch("origin_user_message_id")
    assert_equal "pending", body.fetch("status")
    assert_equal source.id, attempt.replaces_message_id
    assert_equal "", attempt.content
    assert_enqueued_with(job: AssistantResponseJob, args: [ attempt ])

    calls = []
    provider = Object.new
    provider.define_singleton_method(:chat_response) do |content, **options|
      calls << { prompt: content, messages: options.fetch(:messages) }
      options.fetch(:streamer).call(Provider::LlmConcept::ChatStreamChunk.new(type: "output_text", data: "Recovered answer"))
      data = Provider::LlmConcept::ChatResponse.new(id: "synthetic", model: "gpt-5.4",
        messages: [ Provider::LlmConcept::ChatMessage.new(id: "1", output_text: "Recovered answer") ], function_requests: [])
      options.fetch(:streamer).call(Provider::LlmConcept::ChatStreamChunk.new(type: "response", data: data))
      Provider::Response.new(success?: true, data: data, error: nil)
    end
    Assistant.any_instance.stubs(:get_model_provider).returns(provider)
    attempt.request_response
    assert attempt.reload.complete?
    assert_equal "Recovered answer", attempt.content
    assert_equal [ { prompt: "Retry this original question", messages: [
      { role: "user", content: "Earlier question" },
      { role: "assistant", content: "Earlier answer" }
    ] } ], calls
    assert_equal "Partial response", source.reload.content
    assert source.failed?

    assert_no_difference "AssistantMessage.count" do
      assert_enqueued_jobs 0, only: AssistantResponseJob do
        retry_message(source.id)
      end
    end
    assert_response :accepted
    duplicate = JSON.parse(response.body)
    assert_equal attempt.id, duplicate.fetch("attempt_id")
    assert_equal attempt.id, duplicate.fetch("message_id")
    assert_equal prompt.id, duplicate.fetch("origin_user_message_id")
    assert_equal "complete", duplicate.fetch("status")
  end

  test "retry without message id uses latest explicitly ordered prompt" do
    prompt = create_prompt("Latest explicit prompt")
    source = initial_attempt(prompt)
    source.update!(status: :failed, content: "")
    @chat.messages.create!(type: "AssistantMessage", content: "Later legacy answer", ai_model: "gpt-5.4")
    retry_message
    assert_response :accepted
    body = JSON.parse(response.body)
    assert_equal prompt.id, body.fetch("origin_user_message_id")
    assert_equal source.id, @chat.messages.find(body.fetch("attempt_id")).replaces_message_id
  end

  test "legacy or invalid retry source requires a new explicit prompt" do
    [ messages(:chat1_assistant_response).id, messages(:chat1_user).id, nil ].each do |source_id|
      assert_no_difference "Message.count" do
        assert_enqueued_jobs 0, only: AssistantResponseJob do
          retry_message(source_id)
        end
      end
      assert_response :unprocessable_entity
      assert_includes JSON.parse(response.body).fetch("error"), "Send a new prompt"
    end
  end

  test "foreign and unknown message ids return not found without reserving an attempt" do
    own_other_chat = @user.chats.create!(title: "Another chat")
    foreign = own_other_chat.messages.create!(type: "UserMessage", content: "Foreign prompt", ai_model: "gpt-5.4")
    [ initial_attempt(foreign, own_other_chat).id, SecureRandom.uuid ].each do |source_id|
      assert_no_difference "Message.count" do
        assert_enqueued_jobs 0, only: AssistantResponseJob do
          retry_message(source_id)
        end
      end
      assert_response :not_found
      assert_equal "Message not found", JSON.parse(response.body).fetch("error")
    end
  end

  test "retry preserves AI and write scope requirements" do
    token = Doorkeeper::AccessToken.create!(application: @oauth_app, resource_owner_id: @user.id, scopes: "read")
    post "/api/v1/chats/#{@chat.id}/messages/retry", headers: bearer_auth_header(token)
    assert_response :forbidden
    @user.update!(ai_enabled: false)
    retry_message
    assert_response :forbidden
  end

  test "retry cannot access another user chat in the same family" do
    other_chat = chats(:two)
    assert_equal @user.family_id, other_chat.user.family_id
    assert_no_difference "Message.count" do
      assert_enqueued_jobs 0, only: AssistantResponseJob do
        post "/api/v1/chats/#{other_chat.id}/messages/retry",
          params: { message_id: messages(:chat1_assistant_response).id },
          headers: bearer_auth_header(@write_token)
      end
    end
    assert_response :not_found
  end

  test "should not access messages in other user's chat" do
    other_user = users(:family_member)
    other_user.update!(family: families(:empty))
    other_chat = chats(:two)
    other_chat.update!(user: other_user)

    post "/api/v1/chats/#{other_chat.id}/messages",
      params: { content: "Test" },
      headers: bearer_auth_header(@write_token)

    assert_response :not_found

    post "/api/v1/chats/#{other_chat.id}/messages/retry",
      params: { message_id: messages(:chat1_assistant_response).id },
      headers: bearer_auth_header(@write_token)
    assert_response :not_found
  end

  test "explicit interrupted recovery preserves claim and returns one replacement" do
    prompt = @chat.messages.create!(type: "UserMessage", content: "Interrupted API prompt", ai_model: "gpt-5.4")
    source = @chat.messages.find_by!(origin_user_message_id: prompt.id, attempt_number: 1)
    assert source.claim_execution!
    claim = source.execution_claimed_at
    source.update_columns(updated_at: 6.minutes.ago)
    assert_enqueued_jobs 1, only: AssistantResponseJob do
      post "/api/v1/chats/#{@chat.id}/messages/retry", params: { message_id: source.id, recover_interrupted: true },
        headers: bearer_auth_header(@write_token)
    end
    assert_response :accepted
    replacement_id = JSON.parse(response.body).fetch("attempt_id")
    assert source.reload.failed?
    assert_equal claim, source.execution_claimed_at
    assert_equal source.id, AssistantMessage.find(replacement_id).replaces_message_id
    assert_enqueued_jobs 0, only: AssistantResponseJob do
      post "/api/v1/chats/#{@chat.id}/messages/retry", params: { message_id: source.id, recover_interrupted: true },
        headers: bearer_auth_header(@write_token)
    end
    assert_response :accepted
    assert_equal replacement_id, JSON.parse(response.body).fetch("attempt_id")
  end

  private

    def create_prompt(content)
      @chat.messages.create!(type: "UserMessage", content: content, ai_model: "gpt-5.4")
    end

    def initial_attempt(prompt, chat = @chat)
      chat.messages.find_by!(origin_user_message_id: prompt.id, attempt_number: 1)
    end

    def retry_message(message_id = nil)
      post "/api/v1/chats/#{@chat.id}/messages/retry",
        params: { message_id: message_id }, headers: bearer_auth_header(@write_token)
    end

    def bearer_auth_header(token)
      { "Authorization" => "Bearer #{token.token}" }
    end
end
