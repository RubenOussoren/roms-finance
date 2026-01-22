---
name: pr
description: Create a pull request with proper formatting
---

# Create Pull Request

Create a well-formatted pull request using GitHub CLI.

## Usage

```
/pr                        # Create PR for current branch
/pr --draft                # Create draft PR
/pr --base develop         # PR against specific base branch
```

## Workflow

1. **Check Branch Status**
   ```bash
   git status
   git branch -vv
   ```

2. **Review All Commits** (from base branch)
   ```bash
   git log main..HEAD --oneline
   git diff main...HEAD
   ```

3. **Push to Remote** (if needed)
   ```bash
   git push -u origin <branch-name>
   ```

4. **Create Pull Request**
   ```bash
   gh pr create --title "the pr title" --body "$(cat <<'EOF'
   ## Summary
   <1-3 bullet points>

   ## Test plan
   - [ ] Test item 1
   - [ ] Test item 2

   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   EOF
   )"
   ```

## PR Description Format

```markdown
## Summary
- Brief description of change 1
- Brief description of change 2
- Brief description of change 3

## Test plan
- [ ] Verify feature X works as expected
- [ ] Check edge case Y
- [ ] Run tests: `bin/rails test`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## Instructions

1. Run `git status` to check for uncommitted changes
2. Run `git branch -vv` to check remote tracking
3. Run `git log main..HEAD` to see ALL commits to include
4. Run `git diff main...HEAD` to see full diff from base
5. Analyze ALL commits (not just latest) for PR description
6. Push to remote if needed
7. Create PR with `gh pr create`
8. Return the PR URL to user

## Important Notes

- Review ALL commits in the branch, not just the latest
- The Summary should reflect the complete change set
- Test plan should be actionable checklist
- Do NOT use TodoWrite or Task tools
- Always return PR URL when complete

## Draft PRs

Use `--draft` flag for work-in-progress:
```bash
gh pr create --draft --title "WIP: Feature name" --body "..."
```

## Base Branch

Default base is `main`. Specify different base with `--base`:
```bash
gh pr create --base develop --title "..." --body "..."
```
