require "test_helper"

class Provider::StripeTest < ActiveSupport::TestCase
  include WebMock::API
  teardown do
    WebMock.reset!
  end

  setup do
    @stripe = Provider::Stripe.new(secret_key: "sk_test_regression", webhook_secret: "whsec_regression")
  end

  %w[monthly annual].each do |plan|
    test "creates #{plan} checkout with the configured price and customer metadata" do
      with_env_overrides STRIPE_MONTHLY_PRICE_ID: "price_monthly", STRIPE_ANNUAL_PRICE_ID: "price_annual" do
        customer_request = stripe_request(:post, "/customers").with do |request|
          URI.decode_www_form(request.body).to_h == {
            "email" => "test@example.com", "metadata[family_id]" => "123"
          }
        end.to_return(**stripe_response(id: "cus_regression", object: "customer"))

        checkout_request = stripe_request(:post, "/checkout/sessions").with do |request|
          URI.decode_www_form(request.body).to_h == {
            "customer" => "cus_regression",
            "line_items[0][price]" => "price_#{plan}",
            "line_items[0][quantity]" => "1",
            "mode" => "subscription",
            "allow_promotion_codes" => "true",
            "success_url" => "https://example.com/success?session_id={CHECKOUT_SESSION_ID}",
            "cancel_url" => "https://example.com/cancel"
          }
        end.to_return(**stripe_response(id: "cs_regression", object: "checkout.session", url: "https://checkout.stripe.com/regression"))

        session = @stripe.create_checkout_session(
          plan: plan, family_id: 123, family_email: "test@example.com",
          success_url: "https://example.com/success?session_id={CHECKOUT_SESSION_ID}",
          cancel_url: "https://example.com/cancel"
        )

        assert_equal "https://checkout.stripe.com/regression", session.url
        assert_equal "cus_regression", session.customer_id
        assert_requested customer_request, times: 1
        assert_requested checkout_request, times: 1
      end
    end
  end

  test "complete paid checkout returns the subscription ID" do
    request = stub_checkout(status: "complete", payment_status: "paid")

    result = @stripe.get_checkout_result("cs_regression")

    assert result.success?
    assert_equal "sub_regression", result.subscription_id
    assert_requested request, times: 1
  end

  [ [ "open", "paid" ], [ "complete", "unpaid" ], [ "complete", "no_payment_required" ] ].each do |status, payment_status|
    test "checkout with #{status} status and #{payment_status} payment does not return a subscription ID" do
      request = stub_checkout(status: status, payment_status: payment_status)
      Sentry.expects(:capture_exception).with(instance_of(Provider::Stripe::Error))

      result = @stripe.get_checkout_result("cs_regression")

      assert_not result.success?
      assert_nil result.subscription_id
      assert_requested request, times: 1
    end
  end

  test "SDK retrieval failure returns an unsuccessful checkout result" do
    request = stripe_request(:get, "/checkout/sessions/cs_regression").to_return(
      status: 404, headers: { "Content-Type" => "application/json" },
      body: { error: { type: "invalid_request_error", message: "No such checkout session" } }.to_json
    )
    Sentry.expects(:capture_exception).with(instance_of(Stripe::InvalidRequestError))

    result = @stripe.get_checkout_result("cs_regression")

    assert_not result.success?
    assert_nil result.subscription_id
    assert_requested request, times: 1
  end

  private
    def stripe_request(method, path)
      stub_request(method, "https://api.stripe.com/v1#{path}")
        .with(headers: { "Authorization" => "Bearer sk_test_regression" })
    end

    def stripe_response(**attributes)
      { status: 200, headers: { "Content-Type" => "application/json" }, body: attributes.to_json }
    end

    def stub_checkout(status:, payment_status:)
      stripe_request(:get, "/checkout/sessions/cs_regression").to_return(**stripe_response(
        id: "cs_regression", object: "checkout.session", status: status,
        payment_status: payment_status, subscription: "sub_regression"
      ))
    end
end
