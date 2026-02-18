# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Development Commands

### Development Server
- `bin/dev` - Start development server (Rails, Sidekiq, Tailwind CSS watcher)
- `bin/rails server` - Start Rails server only
- `bin/rails console` - Open Rails console

### Testing
- `bin/rails test` - Run all tests
- `bin/rails test:db` - Run tests with database reset
- `bin/rails test:system` - Run system tests only (use sparingly)
- `bin/rails test test/models/account_test.rb` - Run specific test file
- `bin/rails test test/models/account_test.rb:42` - Run specific test at line

### Linting & Formatting
- `bin/rubocop` - Run Ruby linter
- `npm run lint` - Check JavaScript/TypeScript code (uses Biome)
- `npm run lint:fix` - Fix JavaScript/TypeScript issues
- `bin/brakeman` - Run security analysis

### Database
- `bin/rails db:prepare` - Create and migrate database
- `bin/rails db:migrate` - Run pending migrations
- `bin/rails db:seed` - Load seed data
- `rake demo_data:default` - Load demo data for development

### Setup
- `bin/setup` - Initial project setup

## Development Rules

### Authentication Context
- Use `Current.user` for the current user. Do NOT use `current_user`.
- Use `Current.family` for the current family. Do NOT use `current_family`.

### Prohibited Actions
- Do not run `rails server` in your responses
- Do not run `touch tmp/restart.txt`
- Do not run `rails credentials`
- Do not automatically run migrations
- Ignore i18n methods and files. Hardcode strings in English.

## Project Structure

### Investment & Debt Features
- **Calculators**: `app/calculators/` - Pure financial math (ProjectionCalculator, MilestoneCalculator)
- **Simulators**: `app/services/` - Multi-step processes with state (CanadianSmithManoeuvrSimulator)
- **Concerns**: `app/models/concerns/` - JurisdictionAware, PagCompliant, DataQualityCheckable, MortgageRenewalSupport

The `investment-dashboard/` directory is a Python prototype for reference only. Never integrate it with Rails.

**Test seed data**: Login as `admin@roms.local` / `password` (admin) or `member@roms.local` / `password` (member)

## Architecture Overview

### Application Modes
- **Managed**: ROMS Finance team operates servers (`app_mode = "managed"`)
- **Self Hosted**: Users host via Docker Compose (`app_mode = "self_hosted"`)

### Core Domain Model
- **User** → has many **Accounts** → has many **Transactions**
- **Account** types: checking, savings, credit cards, investments, crypto, loans, properties
- **Investment accounts** → have **Holdings** → track **Securities** via **Trades**
- **PlaidItem** → has many **PlaidAccounts** → each linked to an **Account** (banking connectivity)
- **SnapTradeConnection** → has many **SnapTradeAccounts** → each linked to an **Account** (brokerage connectivity)

### Frontend Architecture
- **Hotwire Stack**: Turbo + Stimulus for reactive UI
- **ViewComponents**: Reusable UI components in `app/components/`
- **Charts**: D3.js for financial visualizations
- **Styling**: Tailwind CSS v4.x - always use functional tokens from `maybe-design-system.css`
- **Icons**: Always use `icon` helper, never `lucide_icon` directly

### Background Processing
Sidekiq handles async tasks: account syncing, import processing, AI chat responses.

### Data Provider Architecture
- Providers configured via `Provider::Registry`
- Domain models use `Provided` concerns for data fetching
- Inherit from `Provider` base class and return `with_provider_response`

### Account Connectivity Providers
- **Plaid** (`Provider::Plaid`): Banking accounts (chequing, savings, credit cards, loans). US + EU regions. OAuth flow via Plaid Link with account selection/review before import. `PlaidItem` → `PlaidAccount` → `Account`.
- **SnapTrade** (`Provider::SnapTrade`): Canadian investment/crypto brokerage accounts. `SnapTradeConnection` → `SnapTradeAccount` → `Account`. OAuth flow with account selection before import.
- Provider routing: `AccountableResource#set_link_options` routes brokerage types (Investment, Crypto) to SnapTrade; banking types to Plaid.
- Both providers use `Syncable` concern and `selected_for_import` gating on discovered accounts.

## Project Conventions

### Convention 1: Minimize Dependencies
- Push Rails to its limits before adding new dependencies
- Strong technical/business reason required for new dependencies
- Favor old and reliable over new and flashy

### Convention 2: Skinny Controllers, Fat Models
- Business logic in `app/models/`, avoid `app/services/`. **Exception:** Debt simulators live in `app/services/` as they are multi-step processes with external state (see `AbstractDebtSimulator`).
- Use Rails concerns and POROs for organization
- Models should answer questions about themselves: `account.balance_series` not `AccountSeries.new(account).call`

### Convention 3: Hotwire-First Frontend
- Native HTML preferred: `<dialog>` for modals, `<details><summary>` for disclosures
- Leverage Turbo frames for page sections
- Query params for state over localStorage/sessions
- Server-side formatting for currencies, numbers, dates

### Convention 4: Optimize for Simplicity
- Prioritize good OOP domain design over performance
- Focus performance on critical/global areas (avoid N+1 queries)

### Convention 5: Database vs ActiveRecord Validations
- Simple validations (null checks, unique indexes) in DB
- Complex validations and business logic in ActiveRecord

## Design System

Reference `app/assets/tailwind/maybe-design-system.css` for tokens:
- `text-primary` not `text-white`
- `bg-container` not `bg-white`
- `border border-primary` not `border border-gray-200`

## Detailed Guidelines

For detailed patterns, refer to:
- `.cursor/rules/testing.mdc` - Testing patterns (Minitest, fixtures, financial calculations)
- `.cursor/rules/view_conventions.mdc` - ViewComponents, Stimulus controllers, UI/UX design
- `.cursor/rules/financial-architecture.mdc` - Calculators, simulators, concerns, multi-jurisdiction
- `.cursor/rules/project-design.mdc` - Core data model (accountables, entries, syncs, providers)
- `.cursor/rules/debt-optimization.mdc` - Debt strategies and Smith Manoeuvre
- `.cursor/rules/investment-projections.mdc` - Investment projections and PAG 2025

## Available Skills

Skills are slash commands (e.g. `/commit`, `/test`) that trigger predefined workflows. Use them in the AI chat to run common tasks.

**Workflow**: `/commit`, `/pr`, `/pre-pr`, `/test`, `/setup`, `/db`
**Code review**: `/review`, `/phase-review`, `/pag-check`
**Domain scaffolding**: `/calculator`, `/simulator`

See `docs/DEVELOPER_GUIDE.md` for workflow stages, decision trees, and CI parity.

## MCP Tools Available

### Playwright MCP
Browser automation for testing Hotwire/Turbo interactions:
- `playwright_navigate` - Navigate to URLs
- `playwright_click` - Click elements
- `playwright_fill` - Fill form fields
- `playwright_screenshot` - Capture screenshots

### Rails MCP
Rails project analysis tools:
- `get_schema` - View database schema
- `get_routes` - List all routes
- `analyze_models` - Inspect model associations
- `get_file` - Read project files
- `analyze_controller_views` - Controller/view relationships
