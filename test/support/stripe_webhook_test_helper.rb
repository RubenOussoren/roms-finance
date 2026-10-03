module StripeWebhookTestHelper
  STRIPE_TEST_SECRET = "whsec_regression_only"
  STRIPE_TEST_TIME = Time.utc(2026, 1, 15, 12)

  def thin_event_body
    {
      id: "evt_regression",
      object: "v2.core.event",
      type: "v2.core.account.updated",
      created: STRIPE_TEST_TIME.iso8601,
      livemode: false
    }.to_json
  end

  def stripe_signature(body, secret: STRIPE_TEST_SECRET, timestamp: Time.current)
    signature = Stripe::Webhook::Signature.compute_signature(timestamp, body, secret)
    Stripe::Webhook::Signature.generate_header(timestamp, signature)
  end
end
