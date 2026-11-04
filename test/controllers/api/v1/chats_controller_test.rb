# frozen_string_literal: true

require "test_helper"

class Api::V1::ChatsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @user.update!(ai_enabled: true)

    @oauth_app = Doorkeeper::Application.create!(
      name: "Test API App",
      redirect_uri: "https://example.com/callback",
      scopes: "read write read_write"
    )

    @read_token = Doorkeeper::AccessToken.create!(
      application: @oauth_app,
      resource_owner_id: @user.id,
      scopes: "read"
    )

    @write_token = Doorkeeper::AccessToken.create!(
      application: @oauth_app,
      resource_owner_id: @user.id,
      scopes: "read_write"
    )

    @chat = chats(:one)
  end

  test "history exposes requested and effective response models" do
    prompt = @chat.messages.create!(type: "UserMessage", content: "Fallback prompt", ai_model: "unavailable-request")
    attempt = @chat.reserve_initial_attempt(prompt).first
    attempt.update!(ai_model: "gpt-5-mini", status: :complete, content: "Fallback answer")

    get "/api/v1/chats/#{@chat.id}", headers: bearer_auth_header(@read_token)

    assert_response :success
    reply = JSON.parse(response.body).fetch("messages").find { |message| message["id"] == attempt.id }
    assert_equal "unavailable-request", reply.fetch("requested_model")
    assert_equal "gpt-5-mini", reply.fetch("model")
  end

  test "history exposes null requested model for an unlinked legacy assistant reply" do
    legacy_reply = messages(:chat1_assistant_response)
    assert_nil legacy_reply.origin_user_message_id

    get "/api/v1/chats/#{@chat.id}", headers: bearer_auth_header(@read_token)

    assert_response :success
    reply = JSON.parse(response.body).fetch("messages").find { |message| message["id"] == legacy_reply.id }
    assert_nil reply.fetch("requested_model")
    assert_equal legacy_reply.ai_model, reply.fetch("model")
  end

  test "history preloads requested models for assistant replies" do
    attempts = 3.times.map do |index|
      prompt = @chat.messages.create!(type: "UserMessage", content: "Prompt #{index}", ai_model: "gpt-5-mini")
      @chat.reserve_initial_attempt(prompt).first
    end
    origin_queries = []
    subscriber = ->(*args) do
      payload = args.last
      origin_queries << payload[:sql] if payload[:name] == "UserMessage Load"
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      get "/api/v1/chats/#{@chat.id}", headers: bearer_auth_header(@read_token)
    end

    assert_response :success
    replies = JSON.parse(response.body).fetch("messages").index_by { |message| message.fetch("id") }
    attempts.each do |attempt|
      assert_equal "gpt-5-mini", replies.fetch(attempt.id).fetch("requested_model")
    end
    assert_equal 1, origin_queries.size, "Expected one batched origin lookup, not one lookup per reply"
  end

  test "omitted and blank models use the configured default" do
    Setting.stubs(:default_ai_model).returns("gpt-5.4")
    [ nil, "" ].each do |model|
      post "/api/v1/chats", params: { title: "Default test", message: "Default test", model: model }.compact, headers: bearer_auth_header(@write_token)
      assert_response :created
      prompt = Chat.find(JSON.parse(response.body).fetch("id")).messages.find_by!(type: "UserMessage")
      assert_equal "gpt-5.4", prompt.ai_model
      assert_equal "gpt-5.4", prompt.chat.reserve_initial_attempt(prompt).first.ai_model
    end
  end

  test "should require authentication" do
    get "/api/v1/chats"
    assert_response :unauthorized
  end

  test "should require AI to be enabled" do
    @user.update!(ai_enabled: false)

    get "/api/v1/chats", headers: bearer_auth_header(@read_token)
    assert_response :forbidden

    response_body = JSON.parse(response.body)
    assert_equal "feature_disabled", response_body["error"]
  end

  test "should list chats with read scope" do
    get "/api/v1/chats", headers: bearer_auth_header(@read_token)
    assert_response :success

    response_body = JSON.parse(response.body)
    assert response_body["chats"].is_a?(Array)
    assert response_body["pagination"].present?
  end

  test "should show chat with messages" do
    get "/api/v1/chats/#{@chat.id}", headers: bearer_auth_header(@read_token)
    assert_response :success

    response_body = JSON.parse(response.body)
    assert_equal @chat.id, response_body["id"]
    assert response_body["messages"].is_a?(Array)
  end

  test "should create chat with write scope" do
    assert_difference "Chat.count" do
      post "/api/v1/chats",
        params: { title: "New chat", message: "Hello AI" },
        headers: bearer_auth_header(@write_token)
    end

    assert_response :created
    response_body = JSON.parse(response.body)
    assert_equal "New chat", response_body["title"]
  end

  test "should not create chat with read scope" do
    post "/api/v1/chats",
      params: { title: "New chat" },
      headers: bearer_auth_header(@read_token)

    assert_response :forbidden
  end

  test "should update chat" do
    patch "/api/v1/chats/#{@chat.id}",
      params: { title: "Updated title" },
      headers: bearer_auth_header(@write_token)

    assert_response :success
    response_body = JSON.parse(response.body)
    assert_equal "Updated title", response_body["title"]
  end

  test "should delete chat" do
    assert_difference "Chat.count", -1 do
      delete "/api/v1/chats/#{@chat.id}", headers: bearer_auth_header(@write_token)
    end

    assert_response :no_content
  end

  test "should not access other user's chat" do
    other_user = users(:family_member)
    other_user.update!(family: families(:empty))
    other_chat = chats(:two)
    other_chat.update!(user: other_user)

    get "/api/v1/chats/#{other_chat.id}", headers: bearer_auth_header(@read_token)
    assert_response :not_found
  end

  test "should support API key authentication" do
    # Remove any existing API keys for this user
    @user.api_keys.destroy_all

    plain_key = ApiKey.generate_secure_key
    api_key = @user.api_keys.build(
      name: "Test API Key",
      scopes: [ "read_write" ]
    )
    api_key.key = plain_key
    api_key.save!

    get "/api/v1/chats", headers: { "X-Api-Key" => plain_key }
    assert_response :success
  end

  private

    def bearer_auth_header(token)
      { "Authorization" => "Bearer #{token.token}" }
    end
end
