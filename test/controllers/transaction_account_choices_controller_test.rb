require "test_helper"

class TransactionAccountChoicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @viewer = users(:family_member)
    @full = accounts(:depository)
    @balance_only = accounts(:credit_card)
    @hidden = accounts(:loan)
    @balance_only.account_permissions.create!(user: @viewer, visibility: "balance_only")
    @hidden.account_permissions.create!(user: @viewer, visibility: "hidden")
    @foreign = users(:empty).family.accounts.create!(
      name: "Foreign manual account", balance: 0, currency: "USD",
      created_by_user: users(:empty), accountable: Depository.new
    )
    sign_in @viewer
  end

  test "picker includes only active manual full access accounts" do
    accounts(:vehicle).update!(status: "disabled")
    get new_transaction_url

    assert_response :success
    expected = %i[other_asset other_liability depository investment property crypto equity_compensation
                  smith_primary_mortgage smith_heloc smith_rental_mortgage].map { |key| accounts(key) }.sort_by(&:name)
    options = css_select("select[name='entry[account_id]'] option[value]").reject { |option| option["value"].blank? }
    assert_equal expected.map { |account| account.id.to_s }, options.map { |option| option["value"] }
    assert_equal expected.map(&:name), options.map(&:text)
    [ @hidden, @balance_only, @foreign, accounts(:connected), accounts(:vehicle) ].each do |account|
      assert_dom "select[name='entry[account_id]'] option[value='#{account.id}']", count: 0
    end
  end

  test "creator joint and explicit full accounts remain eligible" do
    accounts(:vehicle).account_permissions.create!(user: @viewer, visibility: "hidden")
    accounts(:property).account_permissions.create!(user: @viewer, visibility: "balance_only")
    accounts(:vehicle).update!(created_by_user: @viewer)
    accounts(:property).update!(is_joint: true)
    accounts(:investment).account_permissions.create!(user: @viewer, visibility: "full")
    get new_transaction_url

    [ accounts(:vehicle), accounts(:property), accounts(:investment) ].each do |account|
      assert_dom "select[name='entry[account_id]'] option[value='#{account.id}']", text: account.name
    end
  end

  test "accepts transaction for full access account" do
    assert_difference [ "Entry.count", "Transaction.count" ], 1 do
      post transactions_url, params: transaction_params(@full)
    end
    assert_redirected_to account_url(@full)
    assert_equal @full.id, Entry.order(:created_at).last.account_id
  end

  test "denies hidden balance only and foreign account submissions" do
    [ @hidden, @balance_only, @foreign ].each do |account|
      assert_no_difference [ "Entry.count", "Transaction.count" ] do
        post transactions_url, params: transaction_params(account)
      end
      assert_response :not_found
    end
  end

  test "denies restricted and foreign preselected account IDs" do
    [ @hidden, @balance_only, @foreign ].each do |account|
      get new_transaction_url(account_id: account.id)
      assert_response :not_found
      assert_dom "input[name='entry[account_id]']", count: 0
    end
  end

  test "preserves full access account specific form" do
    get new_transaction_url(account_id: @full.id)
    assert_response :success
    assert_dom "input[type='hidden'][name='entry[account_id]'][value='#{@full.id}']"
    assert_dom "select[name='entry[account_id]']", count: 0
  end

  test "no eligible accounts shows setup and access guidance without a submission form" do
    @viewer.family.accounts.manual.active.each do |account|
      account.account_permissions.find_or_initialize_by(user: @viewer).update!(visibility: "hidden")
    end
    get new_transaction_url

    assert_response :success
    assert_dom "[data-testid='transaction-accounts-empty']", text: /Add a manual account or ask its owner for full access/
    assert_dom "[data-testid='transaction-accounts-empty'] a[href='#{new_account_path}']", text: "Add an account"
    assert_dom "form[action='#{transactions_path}']", count: 0
    assert_dom "select[name='entry[account_id]']", count: 0
  end

  test "invalid submission still renders the form with its authorized account" do
    post transactions_url, params: transaction_params(@full).deep_merge(entry: { name: "" })
    assert_response :unprocessable_entity
    assert_dom "input[name='entry[account_id]'][value='#{@full.id}']"
    assert_dom ".text-destructive", text: "Name can't be blank"
    assert_dom "select[name='entry[entryable_attributes][category_id]'] option[value='#{categories(:food_and_drink).id}']", text: "Food & Drink"
  end

  private
    def transaction_params(account)
      { entry: { account_id: account.id, name: "Synthetic manual expense", date: Date.current,
                 amount: 12, currency: "USD", nature: "outflow", entryable_type: "Transaction",
                 entryable_attributes: { category_id: categories(:food_and_drink).id } } }
    end
end
