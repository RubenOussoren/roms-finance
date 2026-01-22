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

## Command

```bash
bin/rails test [arguments]
```

## Instructions

1. If no arguments provided, run `bin/rails test` to execute all tests
2. If arguments provided, pass them directly to the test command
3. Report the test results with:
   - Number of tests run
   - Number of assertions
   - Number of failures/errors
   - Failed test details if any
4. Use `bin/rails test:db` if the user mentions needing a database reset

## Important Notes

- This project uses Minitest + fixtures (NEVER RSpec or factories)
- System tests are separate - use `/test-system` for those
- Keep fixtures minimal (2-3 per model for base cases)
- Only test critical code paths that significantly increase confidence
