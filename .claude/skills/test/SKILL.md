---
name: test
description: Run Rails tests with optional file/line arguments
---

# Run Tests

Run the Rails test suite using Minitest.

## Usage

```
/test                           # Run all tests
/test test/models/account_test.rb    # Run specific test file
/test test/models/account_test.rb:42 # Run specific test at line
```

## Instructions

1. If no arguments provided, run `bin/rails test` to execute all tests
2. If arguments provided, pass them directly: `bin/rails test [arguments]`
3. Use `bin/rails test:db` if database reset is needed
4. Report: tests run, assertions, failures/errors, and failed test details
