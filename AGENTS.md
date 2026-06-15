# Repository Guidelines

## Project Structure & Module Organization

ROMS Finance is a Rails 8 application. Core domain code lives in `app/models/`, financial math in `app/calculators/`, and multi-step debt simulations in `app/services/`. Controllers, views, jobs, mailers, and ViewComponents follow standard Rails paths under `app/`. JavaScript is in `app/javascript/`, Tailwind tokens are in `app/assets/tailwind/`, and assets are in `public/` or `app/assets/images/`. Tests mirror the app structure in `test/`, with fixtures in `test/fixtures/`, VCR cassettes in `test/vcr_cassettes/`, and snapshots in `test/golden_masters/`. Documentation belongs in `docs/`.

## Build, Test, and Development Commands

- `bin/setup`: install dependencies and prepare local development.
- `bin/dev`: start Rails, Sidekiq, and the Tailwind watcher.
- `bin/rails db:prepare`: create, migrate, and seed the database as needed.
- `rake demo_data:default`: reload realistic demo data for manual testing.
- `bin/rails test`: run the Minitest suite.
- `bin/rails test test/models/account_test.rb:42`: run a single test by line.
- `bin/rubocop`: lint Ruby.
- `npm run lint` / `npm run lint:fix`: check or fix JavaScript with Biome.
- `bin/brakeman`: run Rails security analysis.

## Coding Style & Naming Conventions

Use Ruby 3.4 and standard Rails naming: snake_case files, CamelCase classes, and tests ending in `_test.rb`. Keep business logic in models unless it is a multi-step process with external state. Use `Current.user` and `Current.family` for request context. Prefer Hotwire, Turbo frames, native HTML, and server-side formatting over client-heavy JavaScript. For UI styling, use tokens from `app/assets/tailwind/roms-design-system.css`, such as `text-primary`, `bg-container`, and `border-primary`. Biome formats JavaScript with double quotes.

## Testing Guidelines

Use Minitest. Place tests in the matching `test/` directory, and prefer focused unit coverage for calculators, models, providers, and financial edge cases. Use fixtures and VCR cassettes for deterministic provider behavior. Run `bin/rails test` before opening a PR; use `bin/rails test:system` only for UI flows that need browser coverage.

## Commit & Pull Request Guidelines

Recent commits use concise, imperative summaries such as `Fix equity compensation balance overestimation`. Keep commits scoped to one change. PRs should target `main`, describe the behavior change, link issues with `fixes #123` when relevant, and pass GitHub checks before review. Include screenshots for visible UI changes and note migrations, new env vars, or provider behavior changes.

## Security & Configuration Tips

Copy `.env.local.example` to `.env.local` and keep secrets out of git. Optional integrations auto-disable when unconfigured; document any new required env var in `README.md` or `docs/hosting/docker.md`. Run `bin/brakeman` for security-sensitive changes.
