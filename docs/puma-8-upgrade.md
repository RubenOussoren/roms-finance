# Puma 8 runtime compatibility

Puma 7.2.1 → 8.0.2 is a one-entry lockfile update. No Rack, Rails, networking,
worker-count, timeout, or application configuration was changed.

The [Puma 8 upgrade guide](https://github.com/puma/puma/blob/v8.0.2/docs/8.0-Upgrade.md)
was checked against `config/puma.rb` and the container configuration:

- Default binds may prefer IPv6 wildcard on hosts with usable IPv6. This isolated
  Linux Docker environment selected `0.0.0.0`; IPv4 requests succeeded. Other
  IPv6/proxy platforms should verify ingress/address-family behavior on rollout.
- ROMS has no changed thread hooks, custom supported-HTTP-method configuration,
  request body size limit, `fork_worker`, or `SIGPWR` lifecycle integration.
- Production uses configurable workers and preloading. A production-equivalent
  **two-worker + preload** test boot used the Rails **test** environment and test
  database/Redis, never development data. It is not a claim of live-production
  ingress testing.
- `tmp_restart` remains enabled. Hot restart successfully inherited the listener
  and resumed health requests. No phased restart was asserted with preloading.

## Local evidence

All probes ran in the isolated validation container with explicit
`RAILS_ENV=test POSTGRES_DB=roms_test REDIS_URL=redis://redis:6379/2`:

1. Boot using the application's Puma configuration: IPv4 `/up` returned 200,
   unauthenticated `/api/v1/accounts` returned 401, and `/cable` completed a real
   HTTP 101 WebSocket upgrade and sent the Action Cable welcome frame.
2. Touch `tmp/restart.txt`: hot restart inherited the listener and `/up` resumed.
3. Boot with `bundle exec puma -C config/puma.rb -w 2 --preload`: the same HTTP,
   API, and WebSocket checks passed; both workers booted and shut down cleanly.
4. An isolated slow Rack request was started, then SIGTERM delivered: the request
   completed with HTTP 200 and its full response body before Puma exited.
5. Full candidate suite: 1,987 tests / 9,464 assertions, zero failures/errors,
   16 unchanged skips; all 72 Chromium system tests / 253 assertions passed.
   Browser tests also started Puma 8 as Capybara's HTTP server.
6. Ruby/JavaScript lint, Brakeman, current Ruby/importmap/npm audits, and Zeitwerk
   passed. Fresh current-main CI is required before merge.

Normal single-process test server reproduction (inside the isolated container):

```sh
RAILS_ENV=test POSTGRES_DB=roms_test REDIS_URL=redis://redis:6379/2 PORT=3210 \
  bundle exec puma -C config/puma.rb
# From another shell in the same container:
curl -fsS http://127.0.0.1:3210/up
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3210/api/v1/accounts
# Expected: 401. Send TERM to the Puma PID to stop without deleting volumes.
```
