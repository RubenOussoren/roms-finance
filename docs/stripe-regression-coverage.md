# Deterministic Stripe regression coverage

These tests use fake credentials, SDK-generated HMAC signatures, a fixed clock,
and WebMock HTTP responses. They do not need a Stripe account, Dashboard session,
price IDs, or cassette recording. Customer/checkout creation is intercepted by
WebMock; no live mutations are permitted. Existing Stripe cassettes are retained
but are no longer used by the provider tests.

## Run in a prepared Rails test environment

From the repository root, with Ruby 3.4, bundled dependencies, and the test database
available:

```sh
RAILS_ENV=test DISABLE_PARALLELIZATION=true bin/rails test \
  test/models/provider/stripe_test.rb \
  test/models/provider/stripe_event_processing_test.rb \
  test/models/provider/stripe_registry_test.rb \
  test/models/provider/stripe_webhook_test.rb \
  test/controllers/stripe_webhooks_controller_test.rb

bin/rubocop \
  test/models/provider/stripe_test.rb \
  test/models/provider/stripe_event_processing_test.rb \
  test/models/provider/stripe_registry_test.rb \
  test/models/provider/stripe_webhook_test.rb \
  test/controllers/stripe_webhooks_controller_test.rb \
  test/support/stripe_webhook_test_helper.rb
```

Do not re-record cassettes or supply real Stripe credentials to fix a failure.
HTTP contract tests check the SDK's actual routes, encoded checkout parameters,
and response objects rather than mocking the SDK service chain. Signature tests
never stub the SDK parser or signature verification. Subscription tests check
created/updated/deleted events, unknown customers, ignored event types, and the
item-level period end (deliberately different from the subscription-level value).
Checkout tests preserve the current requirement that status be `complete` **and**
payment status be `paid`; `no_payment_required` is currently rejected.

## Baseline API concerns (Stripe 19.0.0)

Read-only inspection of the installed SDK and the locked version found:

- `Provider::Stripe#process_webhook_later` calls `StripeClient#parse_thin_event`.
  Stripe 19.0.0 has no such method; it exposes `parse_event_notification`.
  The provider/controller webhook regression tests therefore expose an existing
  `NoMethodError` until production integration is fixed. There is intentionally
  no compatibility shim, skip, or SDK parser mock in these tests. The direct SDK
  tests exercise valid, invalid, stale, empty-secret, and snapshot inputs
  independently of that application bug.
- `parse_event_notification` rejects signed v1 snapshot payloads (`object:
  "event"`) with `ArgumentError`. Merely renaming the parser is not sufficient
  to establish subscription webhook compatibility: the worker currently fetches
  `/v1/events/:id` and expects a v1 subscription snapshot, whereas SDK thin
  notification `fetch_event` retrieves `/v2/core/events/:id`. Confirm the actual
  Dashboard destination/event format before choosing the parser and fetch path.
  The subscription contract tests cover v1 snapshots separately; they do not
  claim that a v2 account notification produces a subscription snapshot.
- An empty signing secret is accepted by the SDK if the HMAC is also computed
  with an empty secret. Registry tests ensure missing, empty, and whitespace
  credentials disable the provider instead of constructing it. Direct provider
  construction bypasses this protection.
- The controller rescues JSON and signature errors only. A disabled registry
  returns `nil`, so an incoming webhook when Stripe is unconfigured currently
  raises `NoMethodError`; snapshot-parser `ArgumentError` is also unhandled.
  HTTP behavior for disabled providers needs a production decision rather than
  a test-only change.

This tests-only change does not upgrade dependencies or alter production behavior.
Runtime tests and RuboCop were not run by the author: the host has no Ruby, and the
shared validation container was authorized for SDK inspection only. Run the
commands above in the orchestrator's prepared test environment after integration;
expect the documented webhook incompatibility to be reported on this baseline.
