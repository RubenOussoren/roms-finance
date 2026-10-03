require "test_helper"
require "webmock/minitest"

# Exercise the real generated SDK, not mocked PlaidApi methods or live Sandbox.
class Provider::PlaidContractTest < ActiveSupport::TestCase
  include WebMock::API

  BASE_URL = "https://sandbox.plaid.com"
  ACCESS_TOKEN = "access-contract-fake"
  EU_COUNTRIES = %w[ES NL FR IE DE IT PL DK NO SE EE LT LV PT BE].freeze

  setup do
    @network_settings = WebMock::Config.instance.then do |config|
      [ config.allow_net_connect, config.allow_localhost, config.allow ]
    end
    WebMock.disable_net_connect!
    @plaid = provider(:us)
  end

  teardown do
    WebMock.reset!
    config = WebMock::Config.instance
    config.allow_net_connect, config.allow_localhost, config.allow = @network_settings
  end

  test "US Link serializes primary and additional product enums for each account type" do
    with_env_overrides("PLAID_REDIRECT_URI" => nil) do
      { nil => "transactions", "Depository" => "transactions", "Investment" => "investments",
        "CreditCard" => "liabilities", "Loan" => "liabilities" }.each do |accountable_type, primary|
        expected = link_request([ "US", "CA" ]).merge(
          products: [ primary ],
          additional_consented_products: %w[transactions investments liabilities] - [ primary ]
        )
        stub = stub_endpoint("/link/token/create", expected, link_response)
        response = @plaid.get_link_token(user_id: "contract-user", webhooks_url: "https://example.test/webhooks", accountable_type: accountable_type)

        assert_instance_of Plaid::LinkTokenCreateResponse, response
        assert_equal "link-contract-fake", response.link_token
        assert_requested stub, times: 1
        WebMock.reset!
      end
    end
  end

  test "EU Link uses only transactions and EU country enums regardless of account type" do
    with_env_overrides("PLAID_REDIRECT_URI" => nil) do
      [ nil, "Investment", "CreditCard", "Loan" ].each do |accountable_type|
        stub = stub_endpoint("/link/token/create", link_request(EU_COUNTRIES).merge(
          products: [ "transactions" ], additional_consented_products: []
        ), link_response)
        response = provider(:eu).get_link_token(user_id: "contract-user", webhooks_url: "https://example.test/webhooks", accountable_type: accountable_type)

        assert_equal "link-contract-fake", response.link_token
        assert_requested stub, times: 1
        WebMock.reset!
      end
    end
  end

  test "US and EU Link update mode omit both product lists and preserve OAuth redirect" do
    with_env_overrides("PLAID_REDIRECT_URI" => "https://example.test/plaid/callback") do
      { us: [ "US", "CA" ], eu: EU_COUNTRIES }.each do |region, countries|
        stub = stub_endpoint("/link/token/create", link_request(countries).merge(
          access_token: ACCESS_TOKEN, redirect_uri: "https://example.test/plaid/callback"
        ), link_response)
        response = provider(region).get_link_token(user_id: "contract-user", webhooks_url: "https://example.test/webhooks", accountable_type: "Investment", access_token: ACCESS_TOKEN)

        assert_equal "link-contract-fake", response.link_token
        assert_requested stub, times: 1
        WebMock.reset!
      end
    end
  end

  test "transaction sync serializes cursors and aggregates all pages in order" do
    first = stub_endpoint("/transactions/sync", sync_request("saved-cursor"), {
      added: [ transaction("added-1") ], modified: [ transaction("modified-1") ],
      removed: [ { transaction_id: "removed-1", account_id: "account-1" } ],
      has_more: true, next_cursor: "page-2", request_id: "request-1"
    })
    second = stub_endpoint("/transactions/sync", sync_request("page-2"), {
      added: [ transaction("added-2") ], modified: [ transaction("modified-2") ],
      removed: [ { transaction_id: "removed-2", account_id: "account-1" } ],
      has_more: false, next_cursor: "final-cursor", request_id: "request-2"
    })

    response = @plaid.get_transactions(ACCESS_TOKEN, next_cursor: "saved-cursor")

    assert_equal %w[added-1 added-2], response.added.map(&:transaction_id)
    assert_equal %w[modified-1 modified-2], response.modified.map(&:transaction_id)
    assert_equal %w[removed-1 removed-2], response.removed.map(&:transaction_id)
    assert_instance_of Plaid::Transaction, response.added.first
    assert_instance_of Plaid::RemovedTransaction, response.removed.first
    assert_equal Date.new(2026, 1, 2), response.added.first.date
    assert_equal "Original description", response.added.first.original_description
    assert_equal "final-cursor", response.cursor
    assert_requested first, times: 1
    assert_requested second, times: 1
  end

  test "initial transaction sync omits absent cursor and handles an empty final page" do
    stub = stub_endpoint("/transactions/sync", sync_request(nil).except(:cursor), {
      added: [], modified: [], removed: [], has_more: false, next_cursor: "empty-cursor", request_id: "request-empty"
    })

    response = @plaid.get_transactions(ACCESS_TOKEN)

    assert_empty response.added
    assert_empty response.modified
    assert_empty response.removed
    assert_equal "empty-cursor", response.cursor
    assert_requested stub, times: 1
  end

  test "investment pagination uses accumulated offset and merges securities holding first" do
    holdings = stub_endpoint("/investments/holdings/get", { access_token: ACCESS_TOKEN }, {
      accounts: [], item: item, request_id: "holdings-request",
      holdings: [ { account_id: "account-1", security_id: "shared", quantity: 2, institution_price: 10, institution_value: 20 } ],
      securities: [ { security_id: "shared", name: "Holding version", ticker_symbol: "SHARED" } ]
    })
    pages = [
      stub_endpoint("/investments/transactions/get", investment_request(0), {
        accounts: [], item: item, request_id: "investment-1", total_investment_transactions: 2,
        investment_transactions: [ investment_transaction("investment-1") ],
        securities: [ { security_id: "shared", name: "Transaction version" }, { security_id: "other", name: "Other security" } ]
      }),
      stub_endpoint("/investments/transactions/get", investment_request(1), {
        accounts: [], item: item, request_id: "investment-2", total_investment_transactions: 2,
        investment_transactions: [ investment_transaction("investment-2") ],
        securities: [ { security_id: "other", name: "Duplicate other" }, { security_id: "last", name: "Last security" } ]
      })
    ]

    response = @plaid.get_item_investments(ACCESS_TOKEN, start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 1, 31))

    assert_instance_of Plaid::Holding, response.holdings.first
    assert_instance_of Plaid::InvestmentTransaction, response.transactions.first
    assert_instance_of Plaid::Security, response.securities.first
    assert_equal %w[investment-1 investment-2], response.transactions.map(&:investment_transaction_id)
    assert_equal %w[shared other last], response.securities.map(&:security_id)
    assert_equal [ "Holding version", "Other security", "Last security" ], response.securities.map(&:name)
    assert_equal Date.new(2026, 1, 2), response.transactions.first.date
    [ holdings, *pages ].each { |stub| assert_requested stub, times: 1 }
  end

  test "empty investments stop after the first page" do
    holdings = stub_endpoint("/investments/holdings/get", { access_token: ACCESS_TOKEN }, {
      accounts: [], item: item, holdings: [], securities: [], request_id: "empty-holdings"
    })
    transactions = stub_endpoint("/investments/transactions/get", investment_request(0), {
      accounts: [], item: item, investment_transactions: [], securities: [], total_investment_transactions: 0, request_id: "empty-investments"
    })

    response = @plaid.get_item_investments(ACCESS_TOKEN, start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 1, 31))

    assert_empty response.holdings
    assert_empty response.transactions
    assert_empty response.securities
    [ holdings, transactions ].each { |stub| assert_requested stub, times: 1 }
  end

  test "institution lookup serializes regional country codes and optional metadata" do
    { us: [ "US", "CA" ], eu: EU_COUNTRIES }.each do |region, countries|
      stub = stub_endpoint("/institutions/get_by_id", {
        institution_id: "ins_contract", country_codes: countries, options: { include_optional_metadata: true }
      }, { institution: { institution_id: "ins_contract", name: "Contract Bank", country_codes: countries,
        products: %w[transactions investments liabilities], oauth: true, logo: "fake-logo", primary_color: "#123456" }, request_id: "institution-request" })

      response = provider(region).get_institution("ins_contract")

      assert_instance_of Plaid::Institution, response.institution
      assert_equal "Contract Bank", response.institution.name
      assert_equal "fake-logo", response.institution.logo
      assert_equal %w[transactions investments liabilities], response.institution.products
      assert_requested stub, times: 1
      WebMock.reset!
    end
  end

  test "liabilities retain credit mortgage and student objects and nullable fields" do
    stub = stub_endpoint("/liabilities/get", { access_token: ACCESS_TOKEN }, {
      accounts: [], item: item, request_id: "liabilities-request",
      liabilities: { credit: [ { account_id: "credit-1", is_overdue: false, last_payment_amount: nil } ],
        mortgage: [ { account_id: "mortgage-1", origination_date: "2020-01-01" } ],
        student: [ { account_id: "student-1", repayment_plan: { type: "standard", description: nil } } ] }
    })

    response = @plaid.get_item_liabilities(ACCESS_TOKEN)

    assert_instance_of Plaid::LiabilitiesObject, response
    assert_equal "credit-1", response.credit.first.account_id
    assert_nil response.credit.first.last_payment_amount
    assert_equal "mortgage-1", response.mortgage.first.account_id
    assert_equal Date.new(2020, 1, 1), response.mortgage.first.origination_date
    assert_equal "standard", response.student.first.repayment_plan.type
    assert_requested stub, times: 1
  end

  test "liabilities deserialize the actual interest only repayment plan wire value" do
    stub = stub_endpoint("/liabilities/get", { access_token: ACCESS_TOKEN }, {
      accounts: [], item: item, request_id: "liabilities-request",
      liabilities: { credit: [ { account_id: "credit-1", is_overdue: false } ], mortgage: [],
        student: [ { account_id: "student-1", repayment_plan: { type: "interest only", description: "Interest only plan" } } ] }
    })

    # v48 corrects the generated enum to the value the API actually emits.
    # Keep the baseline incompatibility explicit rather than skipping coverage.
    if Gem.loaded_specs.fetch("plaid").version < Gem::Version.new("48.0.0")
      error = assert_raises(ArgumentError) { @plaid.get_item_liabilities(ACCESS_TOKEN) }
      assert_match(/invalid value for "type"/, error.message)
      assert_requested stub, times: 1
      return
    end

    response = @plaid.get_item_liabilities(ACCESS_TOKEN)

    assert_instance_of Plaid::LiabilitiesObject, response
    assert_equal "credit-1", response.credit.first.account_id
    assert_empty response.mortgage
    assert_instance_of Plaid::StudentRepaymentPlan, response.student.first.repayment_plan
    assert_equal "interest only", response.student.first.repayment_plan.type
    assert_requested stub, times: 1
  end

  test "item exchange get accounts and removal preserve request and response contracts" do
    exchange = stub_endpoint("/item/public_token/exchange", { public_token: "public-contract-fake" }, {
      access_token: ACCESS_TOKEN, item_id: "item-1", request_id: "exchange-request"
    })
    get = stub_endpoint("/item/get", { access_token: ACCESS_TOKEN }, { item: item, status: {}, request_id: "item-request" })
    accounts = stub_endpoint("/accounts/get", { access_token: ACCESS_TOKEN }, {
      item: item, request_id: "accounts-request", accounts: [ { account_id: "account-1", name: "Checking",
        type: "depository", subtype: "checking", balances: { current: 100.25, available: nil, iso_currency_code: "USD" } } ]
    })
    remove = stub_endpoint("/item/remove", { access_token: ACCESS_TOKEN }, { request_id: "remove-request" })

    assert_equal ACCESS_TOKEN, @plaid.exchange_public_token("public-contract-fake").access_token
    response = @plaid.get_item(ACCESS_TOKEN)
    assert_instance_of Plaid::ItemWithConsentFields, response.item
    assert_equal "ins_contract", response.item.institution_id
    assert_equal %w[transactions investments liabilities], response.item.products
    account = @plaid.get_item_accounts(ACCESS_TOKEN).accounts.first
    assert_equal "account-1", account.account_id
    assert_equal "checking", account.subtype
    assert_equal 100.25, account.balances.current
    assert_nil account.balances.available
    assert_equal "remove-request", @plaid.remove_item(ACCESS_TOKEN).request_id
    [ exchange, get, accounts, remove ].each { |stub| assert_requested stub, times: 1 }
  end

  private
    def provider(region)
      config = Plaid::Configuration.new
      config.server_index = Plaid::Configuration::Environment["sandbox"]
      config.api_key["PLAID-CLIENT-ID"] = "contract-client-fake"
      config.api_key["PLAID-SECRET"] = "contract-secret-fake"
      Provider::Plaid.new(config, region: region)
    end

    def stub_endpoint(path, request, response)
      stub_request(:post, "#{BASE_URL}#{path}").with(
        headers: { "Content-Type" => "application/json", "PLAID-CLIENT-ID" => "contract-client-fake", "PLAID-SECRET" => "contract-secret-fake" }
      ) { |http| JSON.parse(http.body) == request.deep_stringify_keys }.to_return(
        status: 200, headers: { "Content-Type" => "application/json" }, body: response.to_json
      )
    end

    def link_request(countries)
      { user: { client_user_id: "contract-user" }, client_name: "ROMS Finance", country_codes: countries,
        language: "en", webhook: "https://example.test/webhooks", transactions: { days_requested: 730 } }
    end

    def link_response
      { link_token: "link-contract-fake", expiration: "2026-01-01T12:00:00Z", request_id: "link-request" }
    end

    def sync_request(cursor)
      { access_token: ACCESS_TOKEN, cursor: cursor, count: 100, options: { include_original_description: true } }
    end

    def transaction(id)
      { transaction_id: id, account_id: "account-1", amount: 12.5, date: "2026-01-02", name: "Contract purchase",
        pending: false, original_description: "Original description", iso_currency_code: "USD" }
    end

    def investment_request(offset)
      { access_token: ACCESS_TOKEN, start_date: "2026-01-01", end_date: "2026-01-31", options: { offset: offset } }
    end

    def investment_transaction(id)
      { investment_transaction_id: id, account_id: "account-1", security_id: "shared", date: "2026-01-02",
        name: "Buy shares", amount: 10, quantity: 1, price: 10, type: "buy", subtype: "buy" }
    end

    def item
      { item_id: "item-1", institution_id: "ins_contract", institution_name: "Contract Bank",
        available_products: %w[transactions investments liabilities], billed_products: [ "transactions" ],
        products: %w[transactions investments liabilities], consented_products: %w[transactions investments liabilities],
        error: nil, webhook: "https://example.test/webhooks", update_type: "background" }
    end
end
