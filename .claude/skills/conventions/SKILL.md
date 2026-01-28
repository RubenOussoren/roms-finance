---
name: conventions
description: Check code against project conventions from CLAUDE.md
---

# Project Conventions Check

Verify code follows the 5 project conventions defined in CLAUDE.md.

## Usage

```
/conventions                    # Check staged changes
/conventions path/to/file.rb   # Check specific file
```

## Checklist

1. **Minimize Dependencies** - New gems/packages without strong justification?
2. **Skinny Controllers, Fat Models** - Business logic in controllers? Files in `app/services/`?
3. **Hotwire-First** - Custom JS instead of native HTML? Direct `lucide_icon` usage?
4. **Simplicity** - Over-engineered? N+1 queries?
5. **Validations** - Complex validations in DB? Missing DB constraints?

### Financial Code (stricter)
- Hardcoded tax rules/brackets? Use `Jurisdiction` model instead.
- Calculators in `app/calculators/`, Simulators in `app/services/`

## Instructions

1. Identify files to check
2. Verify against conventions above
3. Report: convention violated, file:line, description, fix suggestion
4. Note: guidelines not absolute rules - some violations may be justified
