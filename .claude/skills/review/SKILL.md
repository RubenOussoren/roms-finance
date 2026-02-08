---
name: review
description: Code review for issues, best practices, and project conventions
---

# Code Review

Perform a comprehensive code review checking for project-specific issues and convention compliance.

## Usage

```
/review                    # Review staged changes
/review path/to/file.rb    # Review specific file
```

## Code Quality Checklist

1. **N+1 Queries** - Missing `includes`/`joins`? Queries inside loops?
2. **Design Tokens** - Using `text-primary`, `bg-container`, `border-primary`?
3. **Auth Context** - Using `Current.user`/`Current.family` (not `current_user`)?
4. **Icon Helper** - Using `icon` helper (not `lucide_icon`)?
5. **Security** - SQL injection, XSS, command injection, mass assignment?
6. **Controller Balance** - Business logic in models, not controllers?

## Convention Compliance Checklist

1. **Minimize Dependencies** - New gems/packages without strong justification?
2. **Skinny Controllers, Fat Models** - Business logic in controllers? Files in `app/services/`? (Exception: debt simulators use `AbstractDebtSimulator` pattern in `app/services/`)
3. **Hotwire-First** - Custom JS instead of native HTML? Direct `lucide_icon` usage?
4. **Simplicity** - Over-engineered? Premature abstractions?
5. **Validations** - Complex validations in DB? Missing DB constraints?

### Financial Code (stricter)
- Hardcoded tax rules/brackets? Use `Jurisdiction` model instead.
- Calculators in `app/calculators/`, Simulators in `app/services/`

## Instructions

1. Identify files to review (staged changes or specified path)
2. Check against both checklists above
3. Report: file:line, issue category, description, suggested fix
4. Prioritize security and correctness over style
5. Note: guidelines not absolute rules - some violations may be justified

## Important Notes

- This is a quick, focused code review. For a full post-phase quality gate with 5-dimension scoring, use `/phase-review` instead.
