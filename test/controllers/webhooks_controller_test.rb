require "test_helper"

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  test "snaptrade webhook triggers sync on ACCOUNT_UPDATED" do
    connection = snaptrade_connections(:one)

    webhook_body = {
      type: "ACCOUNT_UPDATED",
      authorizationId: connection.authorization_id,
      userId: connection.family.snaptrade_user_id
    }.to_json

    Provider::Registry.stubs(:snaptrade_provider).returns(mock(validate_webhook!: true))

    assert_enqueued_with(job: SyncJob) do
      post webhooks_snaptrade_path,
        params: webhook_body,
        headers: { "Content-Type" => "application/json", "X-Signature" => "test_sig" }
    end

    assert_response :ok
  end

  test "snaptrade webhook marks connection as requires_update on CONNECTION_ERROR" do
    connection = snaptrade_connections(:one)

    webhook_body = {
      type: "CONNECTION_ERROR",
      authorizationId: connection.authorization_id
    }.to_json

    Provider::Registry.stubs(:snaptrade_provider).returns(mock(validate_webhook!: true))

    post webhooks_snaptrade_path,
      params: webhook_body,
      headers: { "Content-Type" => "application/json", "X-Signature" => "test_sig" }

    assert_response :ok
    assert connection.reload.requires_update?
  end

  test "snaptrade webhook enqueues destroy on CONNECTION_DELETED" do
    connection = snaptrade_connections(:one)

    webhook_body = {
      type: "CONNECTION_DELETED",
      authorizationId: connection.authorization_id
    }.to_json

    Provider::Registry.stubs(:snaptrade_provider).returns(mock(validate_webhook!: true))

    assert_enqueued_with(job: DestroyJob) do
      post webhooks_snaptrade_path,
        params: webhook_body,
        headers: { "Content-Type" => "application/json", "X-Signature" => "test_sig" }
    end

    assert_response :ok
    assert connection.reload.scheduled_for_deletion?
  end

  test "snaptrade webhook CONNECTION_DELETED is idempotent" do
    connection = snaptrade_connections(:one)
    connection.update!(scheduled_for_deletion: true)

    webhook_body = {
      type: "CONNECTION_DELETED",
      authorizationId: connection.authorization_id
    }.to_json

    Provider::Registry.stubs(:snaptrade_provider).returns(mock(validate_webhook!: true))

    assert_no_enqueued_jobs(only: DestroyJob) do
      post webhooks_snaptrade_path,
        params: webhook_body,
        headers: { "Content-Type" => "application/json", "X-Signature" => "test_sig" }
    end

    assert_response :ok
  end

  test "snaptrade webhook returns ok for unknown event types" do
    webhook_body = {
      type: "UNKNOWN_EVENT",
      authorizationId: "unknown_auth"
    }.to_json

    Provider::Registry.stubs(:snaptrade_provider).returns(mock(validate_webhook!: true))

    post webhooks_snaptrade_path,
      params: webhook_body,
      headers: { "Content-Type" => "application/json", "X-Signature" => "test_sig" }

    assert_response :ok
  end
end
