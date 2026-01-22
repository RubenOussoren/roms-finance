---
name: security
description: Run security analysis with Brakeman
---

# Security Analysis

Run Brakeman security analysis to identify vulnerabilities.

## Command

```bash
bin/brakeman --no-pager
```

## Instructions

1. Run Brakeman security analysis
2. Report findings grouped by severity:
   - **High** - Critical vulnerabilities requiring immediate attention
   - **Medium** - Significant issues to address
   - **Low** - Minor concerns
   - **Weak** - Informational warnings
3. For each finding, include:
   - File and line number
   - Vulnerability type
   - Description
   - Suggested fix
4. Report total counts by category

## Common Vulnerability Types

- **SQL Injection** - User input in SQL queries
- **Cross-Site Scripting (XSS)** - Unescaped output in views
- **Mass Assignment** - Unprotected attributes
- **Command Injection** - User input in shell commands
- **File Access** - Path traversal vulnerabilities
- **Redirect** - Open redirects
- **Session** - Session handling issues

## OWASP Top 10 Context

Be especially vigilant for:
1. Injection (SQL, Command, etc.)
2. Broken Authentication
3. Sensitive Data Exposure
4. XML External Entities (XXE)
5. Broken Access Control
6. Security Misconfiguration
7. Cross-Site Scripting (XSS)
8. Insecure Deserialization
9. Using Components with Known Vulnerabilities
10. Insufficient Logging & Monitoring

## Important Notes

- Review all warnings, even low severity
- False positives may occur - use judgment
- Never commit code with high severity warnings
- Run as part of `/pre-pr` workflow before pull requests
