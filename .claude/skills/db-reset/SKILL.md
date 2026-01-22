---
name: db-reset
description: Reset database to clean slate with fresh data
---

# Reset Database

Reset the database to a clean state and reload all data.

## Commands

### 1. Reset Database
```bash
bin/rails db:reset
```

### 2. Load Seed Data
```bash
bin/rails db:seed
```

### 3. Re-create Test User
```bash
bin/rails runner "
family = Family.create!(name: 'Test Family')
user = User.create!(
  email: 'user@maybe.local',
  password: 'password',
  password_confirmation: 'password',
  family: family,
  role: 'admin',
  first_name: 'Test',
  last_name: 'User'
)
puts \"Created user: #{user.email}\"
"
```

### 4. Rebuild Tailwind CSS
```bash
bin/rails tailwindcss:build
```

## Instructions

1. Warn the user that this will DELETE ALL DATA
2. Run `bin/rails db:reset` (drops, creates, migrates, seeds)
3. Re-create the test user
4. Rebuild Tailwind CSS
5. Report success and test user credentials

## Test Credentials

- **Email:** user@maybe.local
- **Password:** password

## Warning

⚠️ This command will:
- Drop all existing databases
- Delete ALL data (accounts, transactions, users, etc.)
- Create fresh databases
- Run all migrations
- Load seed data

## When to Use

- Development environment is in a broken state
- Need to test fresh installation flow
- Database schema has diverged significantly
- After major migration changes

## Important Notes

- Do NOT use in production
- Do NOT run `rails server` after reset
- Backup any data you need before running
