require "test_helper"

class Provider::StripeEventProcessingTest < ActiveSupport::TestCase
  include WebMock::API
  teardown do
    WebMock.reset!
  end

  setup do
    @provider = Provider::Stripe.new(secret_key: "sk_test_regression", webhook_secret: "whsec_regression")
    @family = families(:dylan_family)
    @family.update!(stripe_customer_id: "cus_regression")
    @period_end = Time.utc(2026, 2, 15, 12).to_i
  end

  {
    "created" => "active",
    "updated" => "past_due",
    "deleted" => "canceled"
  }.each do |event_name, status|
    test "subscription #{event_name} maps SDK subscription item fields" do
      request = stub_event("customer.subscription.#{event_name}", status: status)
      @provider.process_event("evt_regression")
      subscription = @family.subscription.reload

      assert_equal "sub_regression", subscription.stripe_id
      assert_equal status, subscription.status
      assert_equal "month", subscription.interval
      assert_equal BigDecimal("9.99"), subscription.amount
      assert_equal "USD", subscription.currency
      assert_equal Time.at(@period_end), subscription.current_period_ends_at
      assert_requested request, times: 1
    end
  end

  test "subscription for an unknown customer raises without updating an existing subscription" do
    before = @family.subscription.attributes
    request = stub_event("customer.subscription.updated", customer: "cus_unknown")

    error = assert_raises(Provider::Stripe::Error) { @provider.process_event("evt_regression") }

    assert_match "cus_unknown", error.message
    assert_equal before, @family.subscription.reload.attributes
    assert_requested request, times: 1
  end

  test "unhandled event leaves subscription unchanged" do
    before = @family.subscription.attributes
    request = stub_event("invoice.paid")

    @provider.process_event("evt_regression")

    assert_equal before, @family.subscription.reload.attributes
    assert_requested request, times: 1
  end

  private
    def stub_event(type, status: "active", customer: "cus_regression")
      stub_request(:get, "https://api.stripe.com/v1/events/evt_regression")
        .with(headers: { "Authorization" => "Bearer sk_test_regression" })
        .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: {
          id: "evt_regression", object: "event", type: type,
          data: {
            object: {
              id: "sub_regression", object: "subscription", status: status, customer: customer,
              # Deliberately different: period end must come from the subscription item.
              current_period_end: @period_end - 1.day.to_i,
              items: {
                object: "list",
                data: [ {
                  id: "si_regression", object: "subscription_item", current_period_end: @period_end,
                  plan: { id: "price_monthly", object: "plan", interval: "month", amount: 999, currency: "usd" }
                } ]
              }
            }
          }
        }.to_json)
    end
end
