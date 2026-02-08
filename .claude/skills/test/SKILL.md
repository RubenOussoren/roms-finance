---
name: test
description: Run Rails tests (unit, integration, or system)
---

# Run Tests

Run the Rails test suite using Minitest.

## Usage

```
/test                                   # Run all unit/integration tests
/test system                            # Run system tests (slower, use sparingly)
/test test/models/account_test.rb       # Run specific test file
/test test/models/account_test.rb:42    # Run specific test at line
```

## Instructions

### Unit/Integration Tests (default)

1. If no arguments provided, run `bin/rails test` to execute all tests
2. If arguments provided (not "system"), pass them directly: `bin/rails test [arguments]`
3. Use `bin/rails test:db` if database reset is needed
4. Report: tests run, assertions, failures/errors, and failed test details

### System Tests (`/test system`)

1. Warn the user that system tests take longer than unit tests
2. Run `bin/rails test:system`
3. Report results including:
   - Number of system tests run
   - Pass/fail status
   - Any failures with details
4. If specific system test files are provided, run only those

## When to Use System Tests

- Testing complete user workflows (login, checkout, etc.)
- Testing JavaScript-dependent functionality
- Verifying Turbo/Stimulus interactions
- End-to-end feature validation

## When NOT to Use System Tests

- Testing model validations (use unit tests)
- Testing controller logic (use integration tests)
- Testing isolated components (use unit tests)

## Important Notes

- **Prefer unit tests** (`/test`) for most testing needs
- System tests require a browser driver (Capybara)
- If system tests fail due to missing driver, suggest installing Chrome/ChromeDriver
