---
name: dev-check
description: Verify development environment is properly configured
---

# Development Environment Check

Verify that all required services and dependencies are properly configured.

## Checks to Perform

### 1. Ruby Version
```bash
ruby --version
```
Expected: Ruby 3.4.4

### 2. Node.js Version
```bash
node --version
```
Expected: Node.js 20.x

### 3. PostgreSQL Status
```bash
brew services list | grep postgresql
pg_isready
```
Expected: PostgreSQL running and accepting connections

### 4. Redis Status
```bash
brew services list | grep redis
redis-cli ping
```
Expected: Redis running, returns "PONG"

### 5. Database Exists
```bash
bin/rails db:version
```
Expected: Shows current schema version

### 6. Tailwind CSS Built
```bash
ls -la app/assets/builds/tailwind.css
```
Expected: File exists with recent timestamp

### 7. Dependencies Installed
```bash
bundle check
npm ls --depth=0 2>/dev/null | head -5
```
Expected: Bundle complete, npm packages installed

## Instructions

1. Run each check above
2. Report status for each:
   - ✅ Passing checks
   - ❌ Failing checks with remediation steps
3. Provide overall status: Ready / Not Ready
4. For failing checks, provide the fix command

## Remediation Commands

- **Ruby version wrong:** `rbenv install 3.4.4 && rbenv rehash`
- **PostgreSQL not running:** `brew services start postgresql@14`
- **Redis not running:** `brew services start redis`
- **Database missing:** `bin/rails db:prepare`
- **Tailwind not built:** `bin/rails tailwindcss:build`
- **Bundle incomplete:** `bundle install`
- **npm packages missing:** `npm install`

## Important Notes

- Do NOT start any services automatically without user confirmation
- Do NOT run `rails server` as part of this check
- Report all issues found, not just the first one
