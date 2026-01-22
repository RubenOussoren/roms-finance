---
name: db-setup
description: Set up database with migrations, seeds, and test user
---

# Database Setup

Set up the database from scratch with migrations, seed data, and a test user.

## Commands

### 1. Prepare Database
```bash
bin/rails db:prepare
```

### 2. Load Seed Data
```bash
bin/rails db:seed
```

### 3. Create Test User
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

### 4. Build Tailwind CSS
```bash
bin/rails tailwindcss:build
```

## Instructions

1. Run `bin/rails db:prepare` to create database and run migrations
2. Run `bin/rails db:seed` to load seed data
3. Create test user with the runner command
4. Build Tailwind CSS for styling
5. Report success and test user credentials

## Test Credentials

- **Email:** user@maybe.local
- **Password:** password

## Prerequisites

Ensure these services are running:
- PostgreSQL (`brew services start postgresql@14`)
- Redis (`brew services start redis`)

## Important Notes

- Do NOT run `rails server` after setup
- The seed data creates OAuth applications, not users
- Test user must be created separately
- Use `/db-reset` if you need a clean slate
