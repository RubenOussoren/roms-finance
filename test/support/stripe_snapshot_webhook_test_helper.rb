module StripeSnapshotWebhookTestHelper
  STRIPE_TEST_SECRET = "whsec_regression_only"
  STRIPE_TEST_TIME = Time.utc(2026, 1, 15, 12)

  def snapshot_event_body
    {
      id: "evt_regression",
      object: "event",
      type: "customer.subscription.updated",
      created: STRIPE_TEST_TIME.to_i,
      data: { object: { id: "sub_regression", object: "subscription", customer: "cus_regression", status: "active" } },
      livemode: false
    }.to_json
  end

  def malformed_snapshot_bodies
    snapshot = JSON.parse(snapshot_event_body)
    [
      snapshot.merge("object" => "v2.core.event"),
      snapshot.except("id"),
      snapshot.merge("id" => ""),
      snapshot.except("type"),
      snapshot.merge("data" => { "object" => nil })
    ].map(&:to_json)
  end

  def stripe_signature(body, secret: STRIPE_TEST_SECRET, timestamp: Time.current)
    signature = Stripe::Webhook::Signature.compute_signature(timestamp, body, secret)
    Stripe::Webhook::Signature.generate_header(timestamp, signature)
  end
end
