# JWT 3 compatibility verification

ROMS upgrades JWT 2.10.3 to 3.3.0. Its only direct JWT integration is Plaid
webhook verification: ES256 is explicitly allowlisted, the public EC JWK is
fetched by `kid`, keys are filtered to signing use, and signature verification
precedes the application's five-minute age and raw-body hash checks.

The [upstream upgrade notes](https://github.com/jwt/ruby-jwt/blob/v3.3.0/UPGRADING.md)
were mapped against this usage. Removed HS512256, HMAC JWK encoding changes, and
unverified `EncodedToken#payload` access do not apply. Strict token/base64 parsing
is desirable. OAuth/API tokens remain opaque Doorkeeper tokens, not JWTs.

Eighteen deterministic tests use local EC keys, a frozen clock, and a stubbed key
endpoint. They cover real signatures, wrong keys, unsupported/unsigned algorithms,
body hashes, age boundaries, malformed claims, `kid` validation, and JWK filtering.
The exact same tests passed on unchanged JWT 2.10.3 (40 assertions) before the
upgrade. JWT 3.3.0 passed the full integrated suite: 1,976 tests, 9,348 assertions,
16 existing skips; all 72 Chromium tests (253 assertions), lint, Brakeman, refreshed
Ruby/importmap/npm audits, and Zeitwerk. No skips or gate suppressions were added.

Run focused checks in an isolated configured test environment:

```sh
RAILS_ENV=test POSTGRES_DB=roms_test REDIS_URL=redis://redis:6379/2 \
  bin/rails test test/models/provider/plaid_webhook_test.rb \
  test/controllers/api/v1/auth_controller_test.rb \
  test/controllers/api/v1/base_controller_test.rb \
  test/integration/oauth_basic_test.rb test/integration/oauth_mobile_test.rb
```

Existing application behavior is characterized rather than silently changed:
expiration is disabled for Plaid's token protocol; age is checked via `iat`.
Malformed application claims fail closed at the webhook controller, though their
native Ruby errors are not normalized. Future `iat` timestamps are not explicitly
rejected; hardening that application policy is a separate follow-up, not a
JWT-version regression.
