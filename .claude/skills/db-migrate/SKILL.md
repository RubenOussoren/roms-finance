---
name: db-migrate
description: Run pending database migrations
---

# Run Database Migrations

Run pending database migrations and show status.

## Commands

### Run Migrations
```bash
bin/rails db:migrate
```

### Check Migration Status
```bash
bin/rails db:migrate:status
```

### Rollback Last Migration
```bash
bin/rails db:rollback
```

### Rollback Multiple Migrations
```bash
bin/rails db:rollback STEP=n
```

## Usage

```
/db-migrate              # Run pending migrations
/db-migrate status       # Show migration status
/db-migrate rollback     # Rollback last migration
/db-migrate rollback 3   # Rollback last 3 migrations
```

## Instructions

1. If no arguments, run `bin/rails db:migrate`
2. If "status" argument, run `bin/rails db:migrate:status`
3. If "rollback" argument, run `bin/rails db:rollback` with optional STEP
4. Report:
   - Migrations that were run
   - Current schema version
   - Any errors encountered

## Important Notes

- Do NOT automatically run migrations - this skill is for when the user explicitly requests it
- Review migration files before running if they modify existing data
- For rollback, verify which migrations will be affected
- After migration, may need to rebuild Tailwind CSS if views changed

## Convention

From CLAUDE.md:
- Simple validations (null checks, unique indexes) belong in DB migrations
- Complex business logic validations belong in ActiveRecord models
