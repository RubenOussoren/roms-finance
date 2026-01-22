---
name: setup
description: Full project setup for development environment
---

# Full Project Setup

Set up the complete development environment for roms-finance.

## Automated Setup (Recommended)

```bash
bin/setup-complete
```

Options:
- `--reset` - Reset database first (clean slate)
- `--skip-user` - Skip test user creation
- `--help` - Show help

## Manual Setup Steps

If automated setup fails, follow these steps:

### 1. Environment Configuration
```bash
cp .env.local.example .env.local
```

### 2. Install Dependencies
```bash
bundle install
npm install
```

### 3. Database Setup
```bash
bin/rails db:prepare
bin/rails db:seed
```

### 4. Create Test User
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

### 5. Compile Assets
```bash
bin/rails tailwindcss:build
```

## Test Credentials

After setup, access the application at http://localhost:3000:
- **Email:** user@maybe.local
- **Password:** password

## Common Issues

### PostgreSQL connection refused
```bash
brew services start postgresql@14
```

### Redis connection refused
```bash
brew services start redis
```

### Ruby version mismatch
```bash
rbenv install 3.4.4
rbenv rehash
```

### Tailwind CSS not found
```bash
bin/rails tailwindcss:build
```

## Instructions

1. First try the automated setup with `bin/setup-complete`
2. If it fails, diagnose the error and run manual steps as needed
3. Verify setup by checking that the Rails server can start (but do NOT start it)
4. Report the test user credentials at the end
