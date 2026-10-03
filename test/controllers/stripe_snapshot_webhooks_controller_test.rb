require "test_helper"
require_relative "../support/stripe_snapshot_webhook_test_helper"

class StripeSnapshotWebhooksControllerTest < ActionDispatch::IntegrationTest
  include StripeSnapshotWebhookTestHelper

  test "valid signed v1 snapshot event returns OK and enqueues its ID" do
    with_stripe do
      body = snapshot_event_body
      assert_enqueued_with(job: StripeEventHandlerJob, args: [ "evt_regression" ]) do
        assert_enqueued_jobs 1 do
          post_webhook(body, stripe_signature(body))
        end
      end
      assert_response :ok
    end
  end

  test "invalid stale and missing signatures return bad request without enqueueing" do
    with_stripe do
      body = snapshot_event_body
      signatures = [
        stripe_signature(body, secret: "whsec_wrong"),
        stripe_signature(body, timestamp: Time.current - Stripe::Webhook::DEFAULT_TOLERANCE - 1),
        nil
      ]

      signatures.each do |signature|
        Sentry.expects(:capture_exception).with(instance_of(Stripe::SignatureVerificationError))
        assert_no_enqueued_jobs { post_webhook(body, signature) }
        assert_response :bad_request
      end
    end
  end

  test "signed invalid JSON returns bad request without enqueueing" do
    with_stripe do
      body = "{"
      Sentry.expects(:capture_exception).with(instance_of(JSON::ParserError))
      assert_no_enqueued_jobs { post_webhook(body, stripe_signature(body)) }
      assert_response :bad_request
    end
  end

  test "unconfigured Stripe returns service unavailable without enqueueing" do
    with_env_overrides STRIPE_SECRET_KEY: nil, STRIPE_WEBHOOK_SECRET: nil do
      body = snapshot_event_body
      assert_no_enqueued_jobs { post_webhook(body, stripe_signature(body)) }
      assert_response :service_unavailable
    end
  end

  test "signed malformed snapshots return bad request without enqueueing" do
    with_stripe do
      malformed_snapshot_bodies.each do |body|
        Sentry.expects(:capture_exception).with(instance_of(Provider::Stripe::InvalidWebhookError))
        assert_no_enqueued_jobs { post_webhook(body, stripe_signature(body)) }
        assert_response :bad_request
      end
    end
  end

  private
    def with_stripe(&block)
      with_env_overrides STRIPE_SECRET_KEY: "sk_test_regression", STRIPE_WEBHOOK_SECRET: STRIPE_TEST_SECRET do
        travel_to(STRIPE_TEST_TIME, &block)
      end
    end

    def post_webhook(body, signature)
      post webhooks_stripe_path, params: body,
        headers: { "Content-Type" => "application/json", "Stripe-Signature" => signature }.compact
    end
end
