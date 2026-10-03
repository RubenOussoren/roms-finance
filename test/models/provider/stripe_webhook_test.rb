require "test_helper"
require_relative "../../support/stripe_webhook_test_helper"

class Provider::StripeWebhookTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include StripeWebhookTestHelper

  setup do
    @provider = Provider::Stripe.new(secret_key: "sk_test_regression", webhook_secret: STRIPE_TEST_SECRET)
  end

  test "signed thin event enqueues only its ID without fetching it" do
    travel_to STRIPE_TEST_TIME do
      body = thin_event_body
      @provider.expects(:process_event).never

      assert_enqueued_with(job: StripeEventHandlerJob, args: [ "evt_regression" ]) do
        assert_enqueued_jobs 1 do
          @provider.process_webhook_later(body, stripe_signature(body))
        end
      end
    end
  end

  test "invalid signature does not enqueue" do
    travel_to STRIPE_TEST_TIME do
      body = thin_event_body
      assert_rejected_webhook(body, stripe_signature(body, secret: "whsec_wrong"))
    end
  end

  test "signature for a different body does not enqueue" do
    travel_to STRIPE_TEST_TIME do
      body = thin_event_body
      assert_rejected_webhook(body.sub("evt_regression", "evt_tampered"), stripe_signature(body))
    end
  end

  test "correct signature outside SDK tolerance does not enqueue" do
    travel_to STRIPE_TEST_TIME do
      body = thin_event_body
      timestamp = Time.current - Stripe::Webhook::DEFAULT_TOLERANCE - 1
      assert_rejected_webhook(body, stripe_signature(body, timestamp: timestamp))
    end
  end

  test "missing signature does not enqueue" do
    assert_rejected_webhook(thin_event_body, nil)
  end

  test "signed invalid JSON does not enqueue" do
    travel_to STRIPE_TEST_TIME do
      body = "{"
      assert_no_enqueued_jobs do
        assert_raises(JSON::ParserError) do
          @provider.process_webhook_later(body, stripe_signature(body))
        end
      end
    end
  end

  test "installed SDK parses real signed thin notifications" do
    travel_to STRIPE_TEST_TIME do
      body = thin_event_body
      client = Stripe::StripeClient.new("sk_test_regression")
      event = client.parse_event_notification(body, stripe_signature(body), STRIPE_TEST_SECRET)

      assert_equal "evt_regression", event.id
      assert_equal "v2.core.account.updated", event.type
    end
  end

  test "installed SDK rejects invalid and stale signatures for thin notifications" do
    travel_to STRIPE_TEST_TIME do
      body = thin_event_body
      client = Stripe::StripeClient.new("sk_test_regression")
      signatures = [
        stripe_signature(body, secret: "whsec_wrong"),
        stripe_signature(body, timestamp: Time.current - Stripe::Webhook::DEFAULT_TOLERANCE - 1)
      ]

      signatures.each do |signature|
        assert_raises(Stripe::SignatureVerificationError) do
          client.parse_event_notification(body, signature, STRIPE_TEST_SECRET)
        end
      end
    end
  end

  test "installed SDK accepts an empty signing secret so the registry must reject it" do
    travel_to STRIPE_TEST_TIME do
      body = thin_event_body
      client = Stripe::StripeClient.new("sk_test_regression")
      event = client.parse_event_notification(body, stripe_signature(body, secret: ""), "")

      assert_equal "evt_regression", event.id
    end
  end

  test "installed SDK rejects snapshot payloads at the thin notification boundary" do
    travel_to STRIPE_TEST_TIME do
      body = { id: "evt_snapshot", object: "event", type: "customer.subscription.updated" }.to_json
      client = Stripe::StripeClient.new("sk_test_regression")

      assert_raises(ArgumentError) do
        client.parse_event_notification(body, stripe_signature(body), STRIPE_TEST_SECRET)
      end
    end
  end

  private
    def assert_rejected_webhook(body, signature)
      assert_no_enqueued_jobs do
        assert_raises(Stripe::SignatureVerificationError) do
          @provider.process_webhook_later(body, signature)
        end
      end
    end
end
