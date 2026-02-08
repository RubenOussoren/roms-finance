---
name: db
description: Database management (setup, reset, migrate)
---

# Database Management

Unified database skill with subcommands for setup, reset, and migration.

## Usage

```
/db             # Show available subcommands
/db setup       # Set up database from scratch
/db reset       # Reset database to clean slate
/db migrate     # Run pending migrations
/db migrate status    # Show migration status
/db migrate rollback  # Rollback last migration
/db migrate rollback 3  # Rollback last 3 migrations
```

---

## Subcommand: setup

Set up the database from scratch with migrations, seed data, and a test user.

### Commands

#### 1. Prepare Database
```bash
bin/rails db:prepare
```

#### 2. Load Seed Data
```bash
bin/rails db:seed
```

#### 3. Build Tailwind CSS
```bash
bin/rails tailwindcss:build
```

### Instructions

1. Run `bin/rails db:prepare` to create database and run migrations
2. Run `bin/rails db:seed` to load seed data (creates users, accounts, transactions)
3. Build Tailwind CSS for styling
4. Report success and test user credentials

### Prerequisites

Ensure these services are running:
- PostgreSQL (`brew services start postgresql@16`)
- Redis (`brew services start redis`)

### Important Notes

- Do NOT run `rails server` after setup
- Seeds create both users and financial data — no separate user creation needed
- Use `/db reset` if you need a clean slate

---

## Subcommand: reset

Reset the database to a clean state and reload all data.

### Warning

This command will:
- Drop all existing databases
- Delete ALL data (accounts, transactions, users, etc.)
- Create fresh databases
- Run all migrations
- Load seed data

### Commands

#### 1. Reset Database
```bash
bin/rails db:reset
```

#### 2. Load Seed Data
```bash
bin/rails db:seed
```

#### 3. Rebuild Tailwind CSS
```bash
bin/rails tailwindcss:build
```

### Instructions

1. Warn the user that this will DELETE ALL DATA
2. Run `bin/rails db:reset` (drops, creates, migrates, seeds)
3. Rebuild Tailwind CSS
4. Report success and test user credentials

### When to Use

- Development environment is in a broken state
- Need to test fresh installation flow
- Database schema has diverged significantly
- After major migration changes

### Important Notes

- Do NOT use in production
- Do NOT run `rails server` after reset
- Backup any data you need before running

---

## Subcommand: migrate

Run pending database migrations and show status.

### Commands

#### Run Migrations
```bash
bin/rails db:migrate
```

#### Check Migration Status
```bash
bin/rails db:migrate:status
```

#### Rollback Last Migration
```bash
bin/rails db:rollback
```

#### Rollback Multiple Migrations
```bash
bin/rails db:rollback STEP=n
```

### Instructions

1. If no arguments, run `bin/rails db:migrate`
2. If "status" argument, run `bin/rails db:migrate:status`
3. If "rollback" argument, run `bin/rails db:rollback` with optional STEP
4. Report:
   - Migrations that were run
   - Current schema version
   - Any errors encountered

### Important Notes

- Do NOT automatically run migrations - this skill is for when the user explicitly requests it
- Review migration files before running if they modify existing data
- For rollback, verify which migrations will be affected
- After migration, may need to rebuild Tailwind CSS if views changed

### Convention

From CLAUDE.md:
- Simple validations (null checks, unique indexes) belong in DB migrations
- Complex business logic validations belong in ActiveRecord models

---

## Test Credentials

**Admin:** `admin@roms.local` / `password`
**Member:** `member@roms.local` / `password`

> For first-time project setup, prefer `/setup` which includes environment verification.
