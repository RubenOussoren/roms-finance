---
name: conventions
description: Check code against project conventions from CLAUDE.md
---

# Project Conventions Check

Verify code follows the project conventions defined in CLAUDE.md.

## Convention 1: Minimize Dependencies

Check for:
- New gems added to Gemfile without strong justification
- New npm packages without clear need
- Favor old/reliable over new/flashy

## Convention 2: Skinny Controllers, Fat Models

Check for:
- Business logic in controllers (should be in models)
- Files in `app/services/` (should be in `app/models/`)
- Models that don't answer questions about themselves

**Good:** `account.balance_series`
**Bad:** `AccountSeries.new(account).call`

## Convention 3: Hotwire-First Frontend

Check for:
- Custom JS components instead of native HTML
  - Use `<dialog>` for modals
  - Use `<details><summary>` for disclosures
- Client-side state instead of query params
- Client-side formatting instead of server-side
- Direct `lucide_icon` usage instead of `icon` helper

## Convention 4: Optimize for Simplicity

Check for:
- Over-engineered solutions
- Premature optimization
- N+1 queries (these DO need attention)

## Convention 5: Database vs ActiveRecord Validations

Check for:
- Complex validations in migrations (should be in models)
- Missing DB constraints for simple checks (null, unique)
- Duplicate validations in both places

## Financial Architecture Conventions

### Calculator vs Simulator Pattern
- Calculators in `app/calculators/` - Pure functions, no side effects
- Simulators in `app/services/` - Multi-step processes with state

### Jurisdiction-Aware Design (Canadian-First)
- ❌ Hardcoded tax rules
- ❌ Hardcoded tax brackets
- ✅ Use `Jurisdiction` model (has `tax_config` JSONB and `marginal_tax_rate(income:)` method)
- ✅ Use `ProjectionStandard` for PAG 2025 assumptions

## Usage

```
/conventions                    # Check staged changes
/conventions path/to/file.rb   # Check specific file
/conventions --all              # Check all modified files
```

## Instructions

1. Identify files to check
2. Read each file and verify against conventions
3. Report violations with:
   - Convention number violated
   - File and line number
   - Description of violation
   - How to fix it
4. Provide summary of compliance status

## Important Notes

- These are guidelines, not absolute rules
- Some violations may be justified - note the reason
- Focus on new/modified code, not existing patterns
- Financial code has stricter requirements
