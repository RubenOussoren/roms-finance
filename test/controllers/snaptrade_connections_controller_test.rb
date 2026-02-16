require "test_helper"

class SnapTradeConnectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
    @snaptrade_connection = snaptrade_connections(:one)
    @snaptrade_provider = mock
    Provider::Registry.stubs(:snaptrade_provider).returns(@snaptrade_provider)
  end

  test "new redirects to snaptrade portal" do
    family = families(:dylan_family)
    family.update!(snaptrade_user_id: "test_user", snaptrade_user_secret: "test_secret")

    login_response = OpenStruct.new(redirect_uri: "https://app.snaptrade.com/connect?token=abc123")
    @snaptrade_provider.expects(:login_user).returns(
      Provider::Response.new(success?: true, data: login_response, error: nil)
    )

    get new_snaptrade_connection_path
    assert_response :redirect
  end

  test "new redirects to accounts on failure" do
    family = families(:dylan_family)
    family.update!(snaptrade_user_id: nil, snaptrade_user_secret: nil)

    @snaptrade_provider.expects(:register_user).returns(
      Provider::Response.new(success?: false, data: nil, error: Provider::SnapTrade::Error.new("Failed"))
    )

    get new_snaptrade_connection_path
    assert_redirected_to accounts_path
  end

  test "callback creates connection and redirects" do
    family = families(:dylan_family)
    family.update!(snaptrade_user_id: "test_user", snaptrade_user_secret: "test_secret")

    connection_data = OpenStruct.new(
      id: "new_auth_123",
      brokerage: OpenStruct.new(name: "Questrade", slug: "QUESTRADE")
    )

    @snaptrade_provider.expects(:list_connections).returns(
      Provider::Response.new(success?: true, data: [ connection_data ], error: nil)
    )

    assert_difference "SnapTradeConnection.count", 1 do
      get callback_snaptrade_connections_path(authorizationId: "new_auth_123")
    end

    assert_redirected_to accounts_path
  end

  test "callback handles missing authorization_id" do
    get callback_snaptrade_connections_path
    assert_redirected_to accounts_path
    assert_equal "Brokerage connection was cancelled or failed.", flash[:alert]
  end

  test "destroy schedules deletion" do
    assert_enqueued_with(job: DestroyJob) do
      delete snaptrade_connection_path(@snaptrade_connection)
    end

    assert_redirected_to accounts_path
    assert @snaptrade_connection.reload.scheduled_for_deletion?
  end

  test "sync triggers sync_later" do
    post sync_snaptrade_connection_path(@snaptrade_connection)
    assert_redirected_to accounts_path
  end
end
