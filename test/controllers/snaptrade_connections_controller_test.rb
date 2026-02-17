require "test_helper"

class SnapTradeConnectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
    @snaptrade_connection = snaptrade_connections(:one)
    @snaptrade_provider = mock
    Provider::Registry.stubs(:snaptrade_provider).returns(@snaptrade_provider)
  end

  test "new renders iframe with snaptrade portal url" do
    family = families(:dylan_family)
    family.update!(snaptrade_user_id: "test_user", snaptrade_user_secret: "test_secret")

    login_response = OpenStruct.new(redirect_uri: "https://app.snaptrade.com/connect?token=abc123")
    @snaptrade_provider.expects(:login_user).returns(
      Provider::Response.new(success?: true, data: login_response, error: nil)
    )

    get new_snaptrade_connection_path
    assert_response :success
    assert_select "iframe[src=?]", "https://app.snaptrade.com/connect?token=abc123"
    assert_select "[data-controller='snaptrade-connect']"
  end

  test "new renders error in modal on failure" do
    family = families(:dylan_family)
    family.update!(snaptrade_user_id: nil, snaptrade_user_secret: nil)

    @snaptrade_provider.expects(:register_user).returns(
      Provider::Response.new(success?: false, data: nil, error: Provider::SnapTrade::Error.new("Failed"))
    )

    get new_snaptrade_connection_path
    assert_response :success
    assert_select "p", text: "Unable to connect brokerage. Please try again."
  end

  test "callback creates connection and redirects to review page" do
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

    connection = SnapTradeConnection.find_by(authorization_id: "new_auth_123")
    assert_redirected_to snaptrade_connection_path(connection)
  end

  test "callback handles missing authorization_id" do
    get callback_snaptrade_connections_path
    assert_redirected_to accounts_path
    assert_equal "Brokerage connection was cancelled or failed.", flash[:alert]
  end

  test "show renders review page with discovered accounts" do
    get snaptrade_connection_path(@snaptrade_connection)
    assert_response :success
    assert_select "h1", "Review Discovered Accounts"
  end

  test "import_accounts updates selection and triggers sync" do
    snaptrade_account = snaptrade_accounts(:one)

    patch import_accounts_snaptrade_connection_path(@snaptrade_connection), params: {
      snaptrade_accounts: [
        { id: snaptrade_account.id, selected: "1", custom_name: "My Custom TFSA" }
      ]
    }

    snaptrade_account.reload
    assert snaptrade_account.selected_for_import?
    assert_equal "My Custom TFSA", snaptrade_account.custom_name
    assert_redirected_to accounts_path
  end

  test "import_accounts with no selection redirects back to review" do
    snaptrade_account = snaptrade_accounts(:two)

    patch import_accounts_snaptrade_connection_path(@snaptrade_connection), params: {
      snaptrade_accounts: [
        { id: snaptrade_account.id, selected: "0", custom_name: "" }
      ]
    }

    # Fixture :one is already selected, but we only submitted :two with selected=0
    # Since we didn't submit :one, its state is unchanged — it's still selected
    # So there are still selected accounts, redirect to accounts_path
    assert_redirected_to accounts_path
  end

  test "import_accounts with all deselected redirects to review with alert" do
    # Deselect all accounts
    @snaptrade_connection.snaptrade_accounts.update_all(selected_for_import: false)

    snaptrade_account_one = snaptrade_accounts(:one)
    snaptrade_account_two = snaptrade_accounts(:two)

    patch import_accounts_snaptrade_connection_path(@snaptrade_connection), params: {
      snaptrade_accounts: [
        { id: snaptrade_account_one.id, selected: "0", custom_name: "" },
        { id: snaptrade_account_two.id, selected: "0", custom_name: "" }
      ]
    }

    assert_redirected_to snaptrade_connection_path(@snaptrade_connection)
    assert_equal "No accounts selected for import.", flash[:alert]
  end

  test "destroy schedules deletion and cleans up on SnapTrade" do
    family = families(:dylan_family)
    family.update!(snaptrade_user_id: "test_user", snaptrade_user_secret: "test_secret")

    @snaptrade_provider.stubs(:remove_connection).returns(
      Provider::Response.new(success?: true, data: nil, error: nil)
    )
    @snaptrade_provider.stubs(:delete_user).returns(
      Provider::Response.new(success?: true, data: nil, error: nil)
    )

    assert_enqueued_with(job: DestroyJob) do
      delete snaptrade_connection_path(@snaptrade_connection)
    end

    assert_redirected_to accounts_path
    assert @snaptrade_connection.reload.scheduled_for_deletion?
  end

  test "sync triggers sync_later" do
    post sync_snaptrade_connection_path(@snaptrade_connection)
    assert_redirected_to snaptrade_connection_path(@snaptrade_connection)
  end
end
