require "test_helper"
require_relative "../../support/stripe_snapshot_webhook_test_helper"

class Provider::StripeSnapshotWebhookTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include StripeSnapshotWebhookTestHelper

  setup do
    @provider = Provider::Stripe.new(secret_key: "sk_test_regression", webhook_secret: STRIPE_TEST_SECRET)
  end

  test "signed v1 snapshot event enqueues only its ID without fetching it" do
    travel_to STRIPE_TEST_TIME do
      body = snapshot_event_body
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
      body = snapshot_event_body
      assert_rejected_webhook(body, stripe_signature(body, secret: "whsec_wrong"))
    end
  end

  test "signature for a different body does not enqueue" do
    travel_to STRIPE_TEST_TIME do
      body = snapshot_event_body
      assert_rejected_webhook(body.sub("evt_regression", "evt_tampered"), stripe_signature(body))
    end
  end

  test "correct signature outside SDK tolerance does not enqueue" do
    travel_to STRIPE_TEST_TIME do
      body = snapshot_event_body
      timestamp = Time.current - Stripe::Webhook::DEFAULT_TOLERANCE - 1
      assert_rejected_webhook(body, stripe_signature(body, timestamp: timestamp))
    end
  end

  test "missing signature does not enqueue" do
    assert_rejected_webhook(snapshot_event_body, nil)
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

  test "blank signing secrets are rejected explicitly" do
    [ nil, "", "  " ].each do |secret|
      assert_no_enqueued_jobs do
        error = assert_raises(Provider::Stripe::Error) do
          Provider::Stripe.new(secret_key: "sk_test_regression", webhook_secret: secret)
        end
        assert_match "webhook secret must be configured", error.message
      end
    end
  end

  test "signed malformed snapshots do not enqueue" do
    travel_to STRIPE_TEST_TIME do
      malformed_snapshot_bodies.each do |body|
        assert_no_enqueued_jobs do
          assert_raises(Provider::Stripe::InvalidWebhookError) do
            @provider.process_webhook_later(body, stripe_signature(body))
          end
        end
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
