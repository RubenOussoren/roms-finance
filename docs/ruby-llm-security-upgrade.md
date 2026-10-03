# RubyLLM 2.0 security upgrade

ROMS uses `ruby_llm` 2.0.0, constrained to `~> 2.0.0` to accept patch releases
without automatically taking another minor-version API change. This is the stable
2.x release published on RubyGems at the time of the upgrade.

## Advisory

[GHSA-42r3-x6vx-x49x / CVE-2026-67991](https://github.com/advisories/GHSA-42r3-x6vx-x49x)
covers polynomial-time regular-expression behavior when underscoring long class,
agent, or tool names on Ruby 3.1.x. The ruby-advisory-db patched range is
`>= 2.0.0.rc1`; **1.16.0 (Dependabot PR #69) does not fix it**.
The stable 2.0.0 gem includes the
[boundary-based underscore fix](https://github.com/crmne/ruby_llm/commit/9d75b033d7d00c4e1baa9b0afb4828faa8bd6602).
ROMS runs Ruby 3.4, but upgrades rather than relying on that runtime's regex
behavior to mitigate a vulnerable dependency.

## Integration and deployment

The [upstream migration guide](https://rubyllm.com/upgrading/) and
[2.0.0 release notes](https://github.com/crmne/ruby_llm/releases/tag/v2.0.0)
were checked against the application's actual usage:

- ROMS uses in-memory `RubyLLM.chat` and its own chat/message/tool-call models.
  It does **not** use RubyLLM `acts_as_*` persistence. No RubyLLM schema migration,
  historical data conversion, or new environment variable is required.
- Remove obsolete `use_new_acts_as` configuration and disable the Rails registry
  store after ActiveRecord has loaded. This keeps the plain Ruby registry rather
  than requiring RubyLLM-owned database tables.
- Keep `openai_protocol = :chat_completions` explicitly. Version 2 otherwise
  defaults to the OpenAI Responses API; this upgrade does not switch protocols.
- Use `models.refresh`, `with_tools`, and `parameter(..., description: ...)`.
- Read response `model` and `tokens.input` / `tokens.output`; keep the existing
  application provider response interface and default missing counts to zero.
- Estimate persisted message cost via `Model#cost_for(Tokens).total`, retaining
  the application's integer-cent output and zero fallback for unknown pricing.

Regression tests use real RubyLLM chat/tool/protocol objects with stubbed HTTP,
covering OpenAI history/instructions, synchronous and streaming replies, the tool
loop and execution log, empty/optional tool parameters, Anthropic replies,
missing token counts, error wrapping, category/merchant JSON parsing, pricing,
and a long acronym tool name through the patched helper.

## Verification isolation

Local checks run in the dedicated `roms-dependency-ai` Compose project, using
`RAILS_ENV=test POSTGRES_DB=roms_test REDIS_URL=redis://redis:6379/2` and two
parallel workers. The project bundle cache is copied from a read-only mount of
the sandbox cache; live sandbox services and volumes are not modified. CI also
explicitly selects `roms_test` and Redis database 2.

The initial Ruby dependency audit also reported unrelated advisories in
concurrent-ruby, crass, css_parser, faraday, loofah, mail, msgpack, nokogiri, pagy,
rails-html-sanitizer, rubyzip, view_component, websocket-driver, and yard. Those
were resolved in the preceding focused security batches. The refreshed audit on
the integrated security baseline reports no vulnerable dependencies.
