# Plaid Ruby 46 → 51 upgrade contract assessment

## Scope and sources

This focused upgrade moves Plaid **46.0.0 → 51.0.0** with deterministic wire-contract tests. Production integration and existing credential-dependent skips are unchanged. No live Plaid mutations or database migration are required. Unrelated JSON resolver updates were excluded.

The mapping below uses the **entire upstream changelog**, including individual OpenAPI entries, not PR excerpts or only the “Breaking changes in this version” headings. In particular, v49 and v50 have breaking entries without that heading.

- [Immutable changelog snapshot](https://github.com/plaid/plaid-ruby/blob/61ca726e37dedf7c3d0f5320de871815443fc867/CHANGELOG.md): v47, v48, v49, v50, v51 sections.
- [Upstream OpenAPI changelog](https://github.com/plaid/plaid-openapi/blob/master/CHANGELOG.md).
- [Target SDK v51](https://github.com/plaid/plaid-ruby/tree/v51.0.0), especially `TransactionsSyncRequest`, `ItemGetResponse`, and `StudentRepaymentPlan`.

OAS boundaries: v46.0.0 = `1.686.0`; v47 = `1.698.7`; v48 = `1.706.1`; v49 = `1.708.0`; v50 = `1.729.1`; v51 = `1.740.1` (all prefixed `2020-09-14_`). v46.1/v46.2 intermediary notes were also inspected; they contain no explicitly marked breaking notes. v52 is outside this upgrade.

## Actual ROMS endpoint surface

`app/models/provider/plaid.rb` owns every production SDK endpoint call. `config/initializers/plaid.rb` and `Provider::Registry` configure/select US and EU clients; both regions use the same generated SDK. The table distinguishes exact endpoints: calling `/item/get` does **not** imply use of `/item/products/terminate`, and `/link/token/create` does **not** imply use of `/link/token/get`.

| Provider method | Actual endpoint(s) | Contract coverage in `test/models/provider/plaid_contract_test.rb` |
| --- | --- | --- |
| `get_link_token` | `/link/token/create` | Exact JSON and fake credential headers; US primary product selection for nil/depository/investment/credit card/loan and additional consent products; EU transactions-only and all 15 country enums; update mode omits both product lists in US/EU and retains access token/OAuth redirect; history = 730 days in test. |
| `get_transactions` | `/transactions/sync` | Saved cursor → next cursor → final cursor, all added/modified/removed arrays accumulated in order, typed transaction/date/description decoding; omitted initial cursor and empty final page. SDK default `count: 100` is asserted, not silently ignored. |
| `get_item_investments` | `/investments/holdings/get`, `/investments/transactions/get` | Fixed ISO dates, offset 0 → 1, total-count termination, typed holdings/transactions/securities, deduplication by security ID across holdings and both transaction pages, holding-first winner, empty result termination. |
| `get_institution` | `/institutions/get_by_id` | US/EU countries, optional metadata flag, institution/product/logo decoding. |
| `get_item_liabilities` | `/liabilities/get` | Credit/mortgage/student typed data, nullable fields and mortgage date; actual `interest only` wire value with explicit baseline incompatibility assertion. |
| `exchange_public_token` | `/item/public_token/exchange` | Public token JSON and access token response. |
| `get_item` | `/item/get` | Access token JSON; `ItemWithConsentFields`, institution and product fields. |
| `get_item_accounts` | `/accounts/get` | Account ID/subtype and nullable balance decoding. |
| `remove_item` | `/item/remove` | Access token JSON and request ID response. |
| `validate_webhook!` | `/webhook_verification_key/get` | Inventoried; signature/JWK cryptographic validation is not part of this HTTP contract suite. No v47–51 breaking entry targets this endpoint. |

Consumers inspected: `PlaidItem`, `PlaidItem::AccountsSnapshot`, `PlaidItem::Importer`, `PlaidAccount` and its import concerns, `WebhooksController`, and `PlaidItem::WebhookProcessor`. The snapshot scopes liabilities to credit/mortgage/student and rescues `Plaid::ApiError`. Webhooks are parsed as plain JSON, not generated `LinkEventsWebhook` or credit webhook models. Test-only `test/support/plaid_sandbox.rb` calls `/sandbox/public_token/create`, `/sandbox/item/fire_webhook`, and `/sandbox/item/reset_login`; none has a breaking note in this range.

## Complete breaking-note mapping

“Unused” below means no endpoint/model reference in this app's production integration or sandbox support, based on the endpoint inventory and source search. It does not mean the upstream change is safe for every Plaid customer. OAS IDs omit the common prefix. Repeated release-summary and schema-entry notes are consolidated; separate schema effects are retained.

### v47 (OAS through 1.698.7)

| OAS | Upstream breaking change | ROMS impact / action |
| --- | --- | --- |
| 1.697.0 | Remove `LinkSessionResults.protect_results` from `/link/token/get`. | Unused: ROMS creates Link tokens; it never retrieves Link sessions or reads Protect results. No code change. |
| 1.695.0 | `Recaptcha_RequiredError.http_code`: string → integer. | Documentation-only error schema, not constructed/read by ROMS. Generic SDK failures are handled as `Plaid::ApiError`, not this model. No code change. |
| 1.691.0 | `/cra/check_report/verification/pdf/get`: `report_requested` → `reports_requested` array. | Unused CRA PDF endpoint/model. No code change. |
| 1.688.9 | Remove `/item/handle_fraud_report` and `ItemHandleFraudReportRequest/Response`. | Unused. ROMS's item get/remove/exchange/accounts calls are different endpoints. No code change. |

### v48 (OAS through 1.706.1)

| OAS | Upstream breaking change | ROMS impact / action |
| --- | --- | --- |
| 1.700.0 | `/cra/check_report/create` options renamed: `CraCheckReportCashflowInsightsGetOptions`, `CraCheckReportIncomeInsightsGetOptions`, `CraCheckReportLendScoreGetOptions`, `CraCheckReportNetworkInsightsGetOptions`, `CraCheckReportVerificationGetEmploymentRefreshOptions` → corresponding `CraCheckReportCreate*Options`. Wire JSON unchanged; old classes remain for deprecated `/get` options. | No CRA report creation or options objects in ROMS. No code change. |
| 1.701.1 | Item/user product termination `reason_code`: remove `ItemProductsTerminateReasonCode` and `UserProductsTerminateReasonCode` wrappers; use `ProductsTerminateReasonCode`. Wire values unchanged. | `/item/products/terminate` and `/user/products/terminate` unused. ROMS removes items using `/item/remove`, which is unaffected. |
| 1.699.5 | Manually constructed `CreditSessionDocumentIncomeResult` now requires `num_i20s_uploaded`. | No credit sessions or model construction in ROMS. No code change. |
| 1.703.0 | Manually constructed `LinkEventsWebhook` now requires `environment`. | Webhook processor uses `JSON.parse` and does not instantiate this model. No code change. |
| 1.699.0 | Manually constructed `PayrollIncomeObject` now requires `i20s`. | No payroll income endpoint or model construction in ROMS. No code change. |
| 1.699.1 | `StudentRepaymentPlan.type`: `interest-only` → `interest only`, correcting the emitted wire value. | **Directly relevant** to `/liabilities/get`. Real SDK v46 rejects `interest only` during deserialization. Baseline reproduction demonstrated that `ArgumentError`; the final contract requires successful typed decoding. No app literal needs renaming; do not sanitize back to the wrong hyphenated value. Existing standard plans have separate cross-version coverage. |
| 1.703.0 | `FDXInitiatorFiAttribute.value`: `FDXPartyType` enum → string; constants still hold strings. This schema has no endpoint reference. | No FDX usage or model construction. No code change. Included even though the summary bullet is not marked `[BREAKING]`. |

### v49 (OAS through 1.708.0)

| OAS | Upstream breaking change | ROMS impact / action |
| --- | --- | --- |
| 1.708.0 | Preserve arbitrary JSON types in `/cra/report/get` product `metadata`/`attributes` and scalar values in `/cra/credit_profile/report/get` cash-flow/network-insight attribute maps. | Neither CRA endpoint/map is used. No code change; do not confuse these maps with ordinary item/investment responses. |

### v50 (OAS through 1.729.1)

There is no release-level breaking summary. **All seven marked entries in the schema section must still be considered.**

| OAS | Upstream breaking change | ROMS impact / action |
| --- | --- | --- |
| 1.712.0 | Identity Match score objects non-null, with nullable inner fields when data unavailable. | `/identity/match` and Identity Match score models unused. No code change. |
| 1.713.0 | Remove legacy nested `subscores` from Protect `TrustIndex`; per-amount-bucket `/protect/compute` subscores unaffected. | Protect unused. Also **restored by 1.713.2 in the same release**, including private Cognito responses: no net removal at v50/v51. |
| 1.714.0 | Allow `user_id` instead of `user_token` on `/credit/sessions/get`, `/credit/bank_income/get`, `/credit/bank_income/pdf/get`, `/credit/bank_statements/uploads/get`, `/credit/payroll_income/get`, `/credit/payroll_income/risk_signals/get`, `/credit/payroll_income/parsing_config/update`. Existing `user_token` remains supported. | All seven endpoints unused. Not ROMS's access-token-based item or transaction requests. No code change. |
| 1.716.0 | `/beta/issues/v1/get`: `affected_new_connection_count` / `affected_existing_connection_count` → `affected_new_item_count` / `affected_existing_item_count`. | Beta issues unused. Institution metadata lookup is `/institutions/get_by_id`, not this endpoint. No code change. |
| 1.717.0 | **Breaking for Go**: allow `user_id` instead of `user_token` on `/credit/payroll_income/refresh`, `/credit/employment/get`; old tokens still work. | Both endpoints unused, and ROMS is Ruby. Included rather than dropped as language-specific. |
| 1.726.0 | Replace `CraProductConfig` union with `CraSubscriptionProductConfig`, discriminated on `product` over the same per-product models. | No `/cra/servicing/subscription/*` endpoints or config models. No code change. |
| 1.728.0 | Remove `access_token` from `/protect/cash_advance/decision/create` and `/protect/cash_advance/repayment/create` request bodies. | Neither Protect endpoint used. Does not remove `access_token` from ROMS's transactions, investments, liabilities, or item requests. |

### v51 (OAS through 1.740.1)

| OAS | Upstream breaking change | ROMS impact / action |
| --- | --- | --- |
| 1.738.0 | `/processor/token/create`: `paynote` → `seamlessach` (rebrand); transition accepts old value, issued processor tokens remain valid. | ROMS exchanges **public** tokens with `/item/public_token/exchange`; it does not create processor tokens. No code/token migration. |
| 1.736.2 | `/protect/compute`: remove generic `cash-advance-onboarding-1.0` / `cash-advance-ongoing-1.0`; use client-scoped `cash-advance-onboarding-<client>-1.0` / `cash-advance-ongoing-<client>-1.0`. | Protect models unused. No code change. |
| 1.735.0, 1.736.0 | `/protect/cash_advance/repayment/create`: `DELIVERED` → `PARTIAL_PAYMENT`; `amount_paid` becomes nullable and required only for `REPAID` / `PARTIAL_PAYMENT`. | Endpoint/status fields unused. No code change. |
| 1.735.0, 1.736.0 | `/protect/cash_advance/decision/create`: move `is_taken` to top level; rename `CashAdvanceDetails` → `CashAdvanceInfo`; add `advance_type` (`FIRST`/`REPEAT`) and optional non-negative `previous_advance_count`. `advance_type` initially required, then required only when `is_taken=true`; declined decisions require `is_taken=false`, taken advances require `client_advance_id` and `cash_advance`. | Endpoint/models unused. Document final v51 conditional requirement, not only the earlier unconditional note. No code change. |
| 1.730.0 | Deprecated `/protect/event/send`: `protect_session_id` → `device_session_id` at top level and inside `event`. | Endpoint unused; not the ROMS webhook verification flow. No code change. |
| 1.730.0 | `/protect/compute`: input object `sdk` → `device`, `sdk_session_id` → `device_session_id`, `ProtectSDKModelInputs` → `ProtectDeviceModelInputs`. | Endpoint/models unused. No code change. |

## Other compatibility notes checked

These are not additional explicitly marked breaking entries, but prevent overstating the assessment:

- v47 `1.692.0`: required CRA `income_streams` with empty arrays; `1.695.0`: income risk-signals webhook required-field correction and nullable/relaxed Recaptcha documentation fields. Those CRA/credit/generated-error models are unused.
- v48 `1.700.0`: request-time config on CRA `/get` endpoints deprecated and unavailable to new clients created on/after 2026-07-01. ROMS has no CRA `/get` requests. Deprecations of Beacon, Bank Transfer, employer search, and cash-flow webhooks likewise do not target the inventory.
- v50 `1.719.0`: relaxed `/item/import` fields and deprecations; endpoint unused. This is not ROMS's `PlaidItem::Importer`, which imports data locally from the listed read endpoints.
- v50 `1.727.0`: new `loan`/`line_of_credit` liability objects and account subtypes, plus `penalty_apr`; existing credit/mortgage/student remain. ROMS does not automatically import the new liability branches; adding support is a separate feature, not a blocker for SDK compatibility.
- v47 holding tax lots, transaction-code additions, v50 merchant category codes/APY, and investment datetime documentation are additive. Contracts deliberately use cross-version fields and fixed dates; they do not claim coverage of every new optional field.

## Deterministic test design

Each case constructs `Plaid::Configuration` locally with **fake keys only**, creates the real `Provider::Plaid`/`PlaidApi`/`ApiClient`, and stubs HTTP using `WebMock::API`. The tests never depend on `Rails.application.config.plaid`, live credentials, or VCR cassettes. Exact parsed JSON equality catches extra/missing fields, including absent update-mode product lists. SDK response model/date conversion and setter enum validation remain real. Response fixtures contain the fields under test, not exhaustive API sample payloads.

All network connections, including localhost, are disabled for each case. Teardown explicitly calls `WebMock.reset!` and restores prior connection settings so existing VCR tests/skips retain their behavior. Repeated regional/product cases also reset stubs between iterations. There are no new skips. The final enum assertion requires successful decoding of the corrected API value; the baseline defect was reproduced before the upgrade.

Limitations: no live Link/OAuth interaction, provider pagination mutation/retry simulation, JWK signature verification, exhaustive new enum/product coverage, or production rollout validation. This is deterministic SDK wire-contract coverage, not a Sandbox integration replacement.

## Verification and upgrade gate

Every test invocation must set the test environment, dedicated Postgres database, and Redis DB explicitly (even when `DISABLE_PARALLELIZATION` is used):

```sh
RAILS_ENV=test POSTGRES_DB=roms_test REDIS_URL=redis://redis:6379/2 DISABLE_PARALLELIZATION=true bin/rails test test/models/provider/plaid_contract_test.rb
RAILS_ENV=test POSTGRES_DB=roms_test REDIS_URL=redis://redis:6379/2 DISABLE_PARALLELIZATION=true bin/rails test test/models/provider/plaid_test.rb test/models/provider/plaid_contract_test.rb
RAILS_ENV=test POSTGRES_DB=roms_test REDIS_URL=redis://redis:6379/2 bin/rails test
```

Verified in the isolated `roms-dependency-validation` project:

- Original Plaid 46 contract suite: 11 tests, 97 assertions passed using a
  characterization assertion for its incorrect `interest only` enum rejection.
  Six existing VCR provider tests replayed with fake credentials: 11 assertions,
  zero failures/errors/skips. No cassette was recorded or modified.
- Plaid 51 focused contracts plus the same VCR replay: 17 tests, 111 assertions,
  zero failures/errors/skips. The final test now requires successful enum decoding.
- Full integrated candidate: 1,987 unit/integration tests, 9,448 assertions,
  16 unchanged skips; all 72 Chromium tests (253 assertions), zero failures/errors.
- Ruby/JavaScript lint, Brakeman, refreshed Ruby/importmap/npm audits, and
  Zeitwerk passed. JWT 3 ES256 webhook coverage runs in the integrated suite.

Fresh current-main GitHub CI is required before merging. These results validate
the SDK changes for the app's deterministic endpoint contracts, not every new
Plaid feature or a live banking/OAuth flow.
