require "test_helper"
require "ostruct"

class PlaidItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
  end

  test "create" do
    @plaid_provider = mock
    Provider::Registry.expects(:plaid_provider_for_region).with("us").returns(@plaid_provider)

    public_token = "public-sandbox-1234"

    @plaid_provider.expects(:exchange_public_token).with(public_token).returns(
      OpenStruct.new(access_token: "access-sandbox-1234", item_id: "item-sandbox-1234")
    )

    assert_difference "PlaidItem.count", 1 do
      post plaid_items_url, params: {
        plaid_item: {
          public_token: public_token,
          region: "us",
          metadata: { institution: { name: "Plaid Item Name" } }
        }
      }
    end

    plaid_item = PlaidItem.order(:created_at).last
    assert_equal "Account linked successfully.  Please wait for accounts to sync.", flash[:notice]
    assert_redirected_to plaid_item_path(plaid_item)
  end

  test "show" do
    plaid_item = plaid_items(:one)

    get plaid_item_url(plaid_item)

    assert_response :success
    assert_select "h1", text: "Review Discovered Accounts"
  end

  test "show displays plaid accounts" do
    plaid_item = plaid_items(:one)
    plaid_account = plaid_accounts(:one)

    get plaid_item_url(plaid_item)

    assert_response :success
    assert_select "input[value=?]", plaid_account.name
  end

  test "import_accounts selects accounts and triggers sync" do
    plaid_item = plaid_items(:one)
    plaid_account = plaid_accounts(:one)

    PlaidItem.any_instance.expects(:sync_later).once

    patch import_accounts_plaid_item_url(plaid_item), params: {
      plaid_accounts: {
        "0" => { id: plaid_account.id, selected: "1", custom_name: "My Chequing" }
      }
    }

    plaid_account.reload
    assert plaid_account.selected_for_import?
    assert_equal "My Chequing", plaid_account.custom_name
    assert_redirected_to accounts_path
  end

  test "import_accounts with no selection redirects back" do
    plaid_item = plaid_items(:one)
    plaid_account = plaid_accounts(:one)

    patch import_accounts_plaid_item_url(plaid_item), params: {
      plaid_accounts: {
        "0" => { id: plaid_account.id, selected: "0", custom_name: "" }
      }
    }

    plaid_account.reload
    assert_not plaid_account.selected_for_import?
    assert_redirected_to plaid_item_path(plaid_item)
    assert_equal "No accounts selected for import.", flash[:alert]
  end

  test "destroy" do
    delete plaid_item_url(plaid_items(:one))

    assert_equal "Accounts scheduled for deletion.", flash[:notice]
    assert_enqueued_with job: DestroyJob
    assert_redirected_to accounts_path
  end

  test "sync" do
    plaid_item = plaid_items(:one)
    PlaidItem.any_instance.expects(:sync_later).once

    post sync_plaid_item_url(plaid_item)

    assert_redirected_to accounts_path
  end
end
