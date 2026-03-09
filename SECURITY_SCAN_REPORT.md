# Security Scan Report — ROMS Finance

**Date:** 2026-03-07 (updated 2026-03-08)
**Branch:** `security-hardening-consolidation`

---

## Executive Summary

The project has a **solid security foundation** with proper authentication, rate limiting, webhook validation, encryption, and MFA. The original scan identified 2 critical, 3 high, 3 medium, and 3 low-priority items. **All actionable items have been resolved** in the `security-hardening-consolidation` branch.

---

## CRITICAL — Requires Immediate Action

### 1. ~~Rails 7.2.2.1 — Known CVEs (Upgrade to 7.2.2.2+)~~ RESOLVED

**Current version:** `7.2.2.1`
**Recommended version:** `7.2.2.2` or later

| CVE | Severity | Description |
|-----|----------|-------------|
| CVE-2025-24293 | **Critical (CVSS 9.2)** | Active Storage command injection via `image_processing` + `mini_magick`. Allows circumvention of safe transformation defaults, enabling command injection when user-supplied input is accepted as transformation parameters. |
| CVE-2025-55193 | Medium | ANSI escape injection in Active Record logging. IDs passed to `find` may be logged without escaping ANSI sequences. |

**Action:** Update `Gemfile` to `gem "rails", "~> 7.2.2.2"` and run `bundle update rails`.

> **Note:** CVE-2025-24293 is especially relevant since this project uses Active Storage with `image_processing` (Gemfile line 48).

> **Resolution:** Upgraded to Rails 7.2.3 via `bundle update`.

---

## HIGH — Should Be Addressed Soon

### 2. ~~Content Security Policy (CSP) — Disabled~~ RESOLVED

**File:** `config/initializers/content_security_policy.rb`
**Status:** Entirely commented out

CSP is the strongest defense against XSS attacks. Without it, any XSS vulnerability can execute arbitrary JavaScript, steal session cookies, and exfiltrate user financial data.

**Recommendation:** Enable CSP in report-only mode first, then enforce:
```ruby
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data
    policy.img_src     :self, :https, :data
    policy.object_src  :none
    policy.script_src  :self
    policy.style_src   :self, :unsafe_inline  # needed for Tailwind
    policy.connect_src :self
    policy.frame_ancestors :none
  end

  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w[script-src]
end
```

> **Resolution:** Enabled in report-only mode with nonces, Plaid CDN, and SnapTrade iframe allowlists. Doorkeeper form_post script tag has CSP nonce.

### 3. ~~DNS Rebinding / Host Authorization — Disabled~~ RESOLVED

**File:** `config/environments/production.rb` (lines 102-108)
**Status:** `config.hosts` is commented out

Without host authorization, the app is vulnerable to DNS rebinding attacks where an attacker's domain resolves to your server's IP and can bypass same-origin policy.

**Recommendation:** Configure `config.hosts` with your production domain(s).

> **Resolution:** Enabled conditionally when `APP_DOMAIN` env var is set. Health check endpoint excluded.

### 4. ~~Permissions Policy — Disabled~~ RESOLVED

**File:** `config/initializers/permissions_policy.rb`
**Status:** Entirely commented out

**Recommendation:** Enable to restrict browser features:
```ruby
Rails.application.config.permissions_policy do |policy|
  policy.camera      :none
  policy.gyroscope   :none
  policy.microphone  :none
  policy.usb         :none
  policy.fullscreen  :self
  policy.payment     :self
end
```

> **Resolution:** Enabled with camera, gyroscope, microphone, USB restricted to none; fullscreen and payment to self.

---

## MEDIUM — Recommended Improvements

### 5. ~~OAuth Access Token Expiration — 1 Year~~ RESOLVED

**File:** `config/initializers/doorkeeper.rb` (line 111)
**Current:** Access tokens expire after 1 year

For a financial application handling sensitive data, 1 year is excessive. If a token is compromised, the attacker has a long window of access.

**Recommendation:** Reduce to 1-4 hours with refresh token rotation.

> **Resolution:** Reduced to 4 hours. Refresh tokens already enabled.

### 6. ~~SMTP Configuration Missing `authentication` and `enable_starttls_auto`~~ RESOLVED

**File:** `config/environments/production.rb` (lines 80-86)
**Current:**
```ruby
config.action_mailer.smtp_settings = {
  address:   ENV["SMTP_ADDRESS"],
  port:      ENV["SMTP_PORT"],
  user_name: ENV["SMTP_USERNAME"],
  password:  ENV["SMTP_PASSWORD"],
  tls:       ENV["SMTP_TLS_ENABLED"] == "true"
}
```

**Missing:** `authentication: :plain` (or `:login`) and `enable_starttls_auto: true` (when not using direct TLS). Without explicit authentication type, Rails defaults to no authentication if the server doesn't advertise it.

> **Resolution:** Added `authentication` (defaulting to "plain") and `enable_starttls_auto` to SMTP settings.

### 7. Ruby Version Mismatch (scanner environment only)

**Expected:** Ruby 3.4.4 (per `.ruby-version`)
**Runtime:** Ruby 3.3.6

This prevented Brakeman from running. While not a direct vulnerability, running on an older Ruby version means missing security patches.

---

## LOW — Nice to Have

### 8. ~~`require_master_key` Not Enforced~~ RESOLVED

**File:** `config/environments/production.rb` (line 21)
`config.require_master_key = true` is commented out. If a deployment accidentally lacks the master key, credentials silently fall back rather than failing fast.

> **Resolution:** Uncommented `config.require_master_key = true`.

### 9. Brakeman Could Not Run (scanner environment only)

Due to the Ruby version mismatch, the static analysis tool `brakeman` could not execute. This is the primary Rails security scanner and should be part of CI.

**Recommendation:** Ensure CI runs Brakeman on every PR with the correct Ruby version.

---

## Scan Results — What Passed

| Area | Status | Details |
|------|--------|---------|
| **npm audit** | PASS | 0 vulnerabilities found |
| **Rack gem** | PASS | v3.1.16 — all 2025 CVEs patched (fixed in 3.1.12) |
| **Puma gem** | PASS | v6.6.0 — all known CVEs patched |
| **Doorkeeper gem** | PASS | v5.8.2 — no known CVEs since 5.6.6 |
| **Nokogiri gem** | PASS | v1.18.8 — up to date |
| **Force SSL** | PASS | Enabled by default in production |
| **CSRF protection** | PASS | Active with appropriate exceptions for API/webhooks |
| **Session security** | PASS | Signed httponly cookies, DB-backed sessions |
| **Rate limiting** | PASS | Rack::Attack properly configured with multiple throttle rules |
| **Webhook validation** | PASS | Signature verification for Plaid, SnapTrade, Stripe |
| **File upload restrictions** | PASS | Content type (JPEG/PNG only) and size (10MB) limits |
| **API key security** | PASS | Encrypted, scoped, expirable, revocable |
| **MFA support** | PASS | TOTP with backup codes |
| **Parameter filtering** | PASS | Sensitive params filtered from logs |
| **Data encryption** | PASS | Active Record encryption for sensitive fields |
| **Multi-tenant isolation** | PASS | Family-based access control on all API requests |
| **Sidekiq admin** | PASS | Basic auth with timing-safe comparison in production |
| **CORS** | PASS | No permissive `Access-Control-Allow-Origin: *` |
| **Hardcoded secrets** | PASS | No API keys, passwords, or tokens found in source code |
| **SQL injection** | PASS | Uses Rails parameterized queries throughout |
| **Impersonation audit trail** | PASS | All support sessions logged with IP, user agent, action |

---

## Priority Action Items

| Priority | Action | Status |
|----------|--------|--------|
| **P0** | Upgrade Rails to 7.2.2.2+ (CVE-2025-24293 command injection) | RESOLVED — upgraded to 7.2.3 |
| **P1** | Enable Content Security Policy | RESOLVED — report-only mode |
| **P1** | Configure `config.hosts` for DNS rebinding protection | RESOLVED — conditional on APP_DOMAIN |
| **P2** | Enable Permissions Policy | RESOLVED |
| **P2** | Reduce OAuth token expiration from 1 year | RESOLVED — reduced to 4 hours |
| **P2** | Add SMTP authentication config | RESOLVED |
| **P3** | Upgrade Ruby to 3.4.4 | N/A — scanner env issue only |
| **P3** | Enable `require_master_key` | RESOLVED |
| **P3** | Ensure Brakeman runs in CI | N/A — already runs in CI |
