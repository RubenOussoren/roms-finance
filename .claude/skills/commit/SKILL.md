---
name: commit
description: Create a git commit with proper message formatting
---

# Create Git Commit

Create a well-formatted git commit following repository conventions.

## Usage

```
/commit                    # Commit staged changes
/commit -m "message"       # Commit with specific message
```

## Workflow

1. **Check Status**
   ```bash
   git status
   ```

2. **Review Changes**
   ```bash
   git diff --staged
   git diff
   ```

3. **Check Recent Commits** (for style reference)
   ```bash
   git log --oneline -10
   ```

4. **Stage Changes** (if needed)
   ```bash
   git add <files>
   ```

5. **Create Commit**
   ```bash
   git commit -m "$(cat <<'EOF'
   Commit message here.

   Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
   EOF
   )"
   ```

## Commit Message Guidelines

### Format
```
<type>: <short description>

<optional body explaining why>

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

### Types
- `Add` - New feature or functionality
- `Update` - Enhancement to existing feature
- `Fix` - Bug fix
- `Refactor` - Code restructuring without behavior change
- `Test` - Adding or updating tests
- `Docs` - Documentation changes
- `Chore` - Maintenance tasks

### Examples
```
Add user authentication flow

Fix N+1 query in accounts index

Update dashboard to show investment projections

Refactor calculator to use concern pattern
```

## Instructions

1. Run `git status` to see changes
2. Run `git diff` to review unstaged changes
3. Run `git diff --staged` to review staged changes
4. Run `git log --oneline -10` to see commit style
5. Analyze changes and draft appropriate message
6. Stage relevant files if not already staged
7. Create commit with Co-Authored-By attribution
8. Run `git status` to verify success

## Git Safety Protocol

- NEVER update git config
- NEVER run destructive commands (push --force, hard reset)
- NEVER skip hooks (--no-verify)
- NEVER use `git commit --amend` unless explicitly requested
- NEVER commit files with secrets (.env, credentials.json)

## Important Notes

- Only commit when explicitly requested
- Focus on "why" not "what" in commit messages
- Keep messages concise (1-2 sentences)
- Always include Co-Authored-By attribution
- Do NOT push to remote unless explicitly asked
