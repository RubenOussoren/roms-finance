---
name: review
description: Code review checking for common issues and best practices
---

# Code Review

Perform a code review checking for project-specific issues.

## Usage

```
/review                    # Review staged changes
/review path/to/file.rb    # Review specific file
```

## Checklist

1. **N+1 Queries** - Missing `includes`/`joins`? Queries inside loops?
2. **Design Tokens** - Using `text-primary`, `bg-container`, `border-primary`?
3. **Auth Context** - Using `Current.user`/`Current.family` (not `current_user`)?
4. **Icon Helper** - Using `icon` helper (not `lucide_icon`)?
5. **Security** - SQL injection, XSS, command injection, mass assignment?
6. **Controller Balance** - Business logic in models, not controllers?

## Instructions

1. Identify files to review
2. Check against checklist above
3. Report: file:line, issue category, description, suggested fix
4. Prioritize security and correctness over style
