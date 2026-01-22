---
name: review
description: Code review checking for common issues and best practices
---

# Code Review

Perform a comprehensive code review checking for project-specific issues and best practices.

## Review Checklist

### 1. N+1 Query Detection
Look for patterns like:
- Iterating over collections and calling associations
- Missing `includes`, `joins`, or `preload`
- Queries inside loops

### 2. Design System Token Usage
Verify usage of functional tokens from `app/assets/tailwind/maybe-design-system.css`:
- ✅ `text-primary` not `text-white`
- ✅ `bg-container` not `bg-white`
- ✅ `border-primary` not `border-gray-200`

### 3. Current User/Family Usage
Check for correct authentication context:
- ✅ `Current.user` (correct)
- ❌ `current_user` (incorrect)
- ✅ `Current.family` (correct)
- ❌ `current_family` (incorrect)

### 4. Icon Helper Usage
Verify icon implementation:
- ✅ `icon` helper from `application_helper.rb`
- ❌ `lucide_icon` direct usage

### 5. Security Vulnerabilities (OWASP Top 10)
Check for:
- SQL injection risks
- XSS vulnerabilities
- Command injection
- Mass assignment issues
- Sensitive data exposure

### 6. Controller/Model Balance
Verify skinny controllers, fat models:
- Business logic should be in models
- Controllers should be thin
- Avoid `app/services/` unless necessary

### 7. Testing Patterns
Check test files for:
- ✅ Minitest + fixtures
- ❌ RSpec or FactoryBot
- Minimal fixtures (2-3 per model)

## Usage

```
/review                    # Review staged changes
/review path/to/file.rb    # Review specific file
/review --all              # Review all modified files
```

## Instructions

1. Identify files to review (staged, specified, or all modified)
2. Read each file and check against the review checklist
3. Report issues found with:
   - File and line number
   - Issue category
   - Description
   - Suggested fix
4. Provide summary of total issues by category

## Important Notes

- Focus on project-specific conventions from CLAUDE.md
- Don't report style issues already caught by linters
- Prioritize security and correctness over style
- Be constructive in feedback
