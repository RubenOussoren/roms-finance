# Deterministic Stripe snapshot regression coverage

These tests use fake credentials, SDK-generated HMAC signatures, a fixed clock,
and WebMock HTTP responses. They do not need a Stripe account, Dashboard session,
price IDs, or cassette recording. Customer/checkout creation is intercepted by
WebMock; no live mutations are permitted. Existing Stripe cassettes are retained
but are no longer used by the provider tests.

## Required webhook format

Configure the Stripe webhook destination to send **v1 snapshot events** for
`customer.subscription.*`, not v2 thin event notifications. The application
verifies the raw request body with `Stripe::Webhook.construct_event`, validates
the snapshot envelope, and queues only the event ID. The worker retrieves the
snapshot with `client.v1.events.retrieve` (`/v1/events/:id`) and updates the
subscription from its data. No v2 financial endpoints are used or supported.

Signature verification is not stubbed or bypassed: wrong-secret, tampered-body,
stale, and missing signatures must still be rejected without enqueueing. Blank
webhook secrets are rejected explicitly when constructing the provider, independent
of SDK behavior (Stripe 19.6.2 also hardens empty-secret handling). The registry
continues to disable Stripe when either credential is blank. An unconfigured
webhook returns HTTP 503 without enqueueing; invalid JSON or a malformed snapshot
returns HTTP 400 without enqueueing.

## Run in a prepared Rails test environment (orchestrator)

From the worktree root, with Ruby 3.4, bundled dependencies, and the test database
available:

```sh
RAILS_ENV=test POSTGRES_DB=roms_test REDIS_URL=redis://redis:6379/2 DISABLE_PARALLELIZATION=true bin/rails test \
  test/models/provider/stripe_test.rb \
  test/models/provider/stripe_event_processing_test.rb \
  test/models/provider/stripe_registry_test.rb \
  test/models/provider/stripe_snapshot_webhook_test.rb \
  test/controllers/stripe_snapshot_webhooks_controller_test.rb \
  test/jobs/stripe_event_handler_job_test.rb

RAILS_ENV=test POSTGRES_DB=roms_test REDIS_URL=redis://redis:6379/2 bin/rubocop \
  app/models/provider/stripe.rb \
  app/controllers/webhooks_controller.rb \
  test/models/provider/stripe_test.rb \
  test/models/provider/stripe_event_processing_test.rb \
  test/models/provider/stripe_registry_test.rb \
  test/models/provider/stripe_snapshot_webhook_test.rb \
  test/controllers/stripe_snapshot_webhooks_controller_test.rb \
  test/support/stripe_snapshot_webhook_test_helper.rb
```

Do not re-record cassettes or supply real Stripe credentials to fix a failure.
HTTP contract tests check the SDK's actual routes, encoded checkout parameters,
and response objects rather than mocking the SDK service chain. Subscription
tests check created/updated/deleted snapshots, unknown customers, ignored event
types, and the item-level period end (deliberately different from the
subscription-level value). Checkout tests preserve the current requirement that
status be `complete` **and** payment status be `paid`; `no_payment_required` is
currently rejected.

## Baseline bug reproduction (orchestrator)

The tests-only commit `6a2e4d20` is preserved unchanged for reproduction. In an
isolated worktree at that commit, the orchestrator can run:

```sh
RAILS_ENV=test POSTGRES_DB=roms_test REDIS_URL=redis://redis:6379/2 DISABLE_PARALLELIZATION=true bin/rails test \
  test/models/provider/stripe_webhook_test.rb \
  test/controllers/stripe_webhooks_controller_test.rb
```

The baseline application calls `StripeClient#parse_thin_event`, which is absent
in Stripe 19.0.0, producing `NoMethodError`. The baseline fixtures use v2 thin
notifications. Merely replacing the method with `parse_event_notification` is
not the fix: that parser rejects signed v1 snapshots (`object: "event"`) and
belongs to the v2 event retrieval contract, not the application's v1 subscription
worker. This fix replaces the fixtures/helper with subscription snapshots and
uses the v1 webhook verifier without changing the worker's retrieval path.
The baseline empty-secret acceptance assertion is SDK-version-specific and is
not a requirement: it may also fail under hardened Stripe 19.6.2.

Runtime tests and RuboCop for this fix are left to the orchestrator: the host has
no Ruby, shared test containers must not be written to, and Docker access is
unavailable. Dependencies are unchanged; the orchestrator owns the lockfile.
