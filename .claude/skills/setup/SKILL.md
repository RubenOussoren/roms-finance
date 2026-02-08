---
name: setup
description: Full project setup with environment verification
---

# Full Project Setup

Set up the complete development environment for roms-finance, then verify everything works.

## Usage

```
/setup          # Full setup + verification
/setup check    # Run only environment verification checks
```

---

## Full Setup

### Automated Setup (Recommended)

```bash
bin/setup-complete
```

Options:
- `--reset` - Reset database first (clean slate)
- `--skip-user` - Skip test user creation
- `--help` - Show help

### Manual Setup Steps

If automated setup fails, follow these steps:

#### 1. Environment Configuration
```bash
cp .env.local.example .env.local
```

#### 2. Install Dependencies
```bash
bundle install
npm install
```

#### 3. Database Setup
```bash
bin/rails db:prepare
bin/rails db:seed
```

#### 4. Create Test User
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

#### 5. Compile Assets
```bash
bin/rails tailwindcss:build
```

### Test Credentials

After setup, access the application at http://localhost:3000:
- **Email:** user@maybe.local
- **Password:** password

### Common Issues

#### PostgreSQL connection refused
```bash
brew services start postgresql@16
```

#### Redis connection refused
```bash
brew services start redis
```

#### Ruby version mismatch
```bash
rbenv install 3.4.4
rbenv rehash
```

#### Tailwind CSS not found
```bash
bin/rails tailwindcss:build
```

### Instructions

1. First try the automated setup with `bin/setup-complete`
2. If it fails, diagnose the error and run manual steps as needed
3. After setup completes, run the verification checks below
4. Report the test user credentials at the end

---

## Environment Verification (`/setup check`)

Verify that all required services and dependencies are properly configured.

### Checks to Perform

#### 1. Ruby Version
```bash
ruby --version
```
Expected: Ruby 3.4.4

#### 2. Node.js Version
```bash
node --version
```
Expected: Node.js 20.x

#### 3. PostgreSQL Status
```bash
brew services list | grep postgresql
pg_isready
```
Expected: PostgreSQL running and accepting connections

#### 4. Redis Status
```bash
brew services list | grep redis
redis-cli ping
```
Expected: Redis running, returns "PONG"

#### 5. Database Exists
```bash
bin/rails db:version
```
Expected: Shows current schema version

#### 6. Tailwind CSS Built
```bash
ls -la app/assets/builds/tailwind.css
```
Expected: File exists with recent timestamp

#### 7. Dependencies Installed
```bash
bundle check
npm ls --depth=0 2>/dev/null | head -5
```
Expected: Bundle complete, npm packages installed

### Verification Instructions

1. Run each check above
2. Report status for each check
3. Provide overall status: Ready / Not Ready
4. For failing checks, provide the fix command

### Remediation Commands

- **Ruby version wrong:** `rbenv install 3.4.4 && rbenv rehash`
- **PostgreSQL not running:** `brew services start postgresql@16`
- **Redis not running:** `brew services start redis`
- **Database missing:** `bin/rails db:prepare`
- **Tailwind not built:** `bin/rails tailwindcss:build`
- **Bundle incomplete:** `bundle install`
- **npm packages missing:** `npm install`

### Important Notes

- Do NOT start any services automatically without user confirmation
- Do NOT run `rails server` as part of this check
- Report all issues found, not just the first one
