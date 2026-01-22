---
name: test-system
description: Run system tests (use sparingly - they take longer)
---

# Run System Tests

Run Rails system tests for critical user flows.

## Command

```bash
bin/rails test:system
```

## Instructions

1. Warn the user that system tests take longer than unit tests
2. Run `bin/rails test:system`
3. Report results including:
   - Number of system tests run
   - Pass/fail status
   - Any failures with details
4. If specific test files are provided as arguments, run only those

## Important Notes

- **Use sparingly** - System tests are slower than unit/integration tests
- System tests are for critical user flows only
- Prefer unit tests (`/test`) for most testing needs
- System tests require a browser driver (Capybara)
- If tests fail due to missing driver, suggest installing Chrome/ChromeDriver

## When to Use System Tests

- Testing complete user workflows (login, checkout, etc.)
- Testing JavaScript-dependent functionality
- Verifying Turbo/Stimulus interactions
- End-to-end feature validation

## When NOT to Use System Tests

- Testing model validations (use unit tests)
- Testing controller logic (use integration tests)
- Testing isolated components (use unit tests)
