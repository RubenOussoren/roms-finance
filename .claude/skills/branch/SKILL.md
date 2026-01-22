---
name: branch
description: Git branch management (create, list, cleanup)
---

# Branch Management

Manage git branches for feature development.

## Usage

```
/branch                      # Show current branch status
/branch feature-name         # Create new feature branch
/branch --list               # List all branches
/branch --cleanup            # Clean up merged branches
```

## Commands

### Show Branch Status
```bash
git branch -vv
git log main..HEAD --oneline
```

### Create Feature Branch
```bash
git checkout -b feature/feature-name main
```

### List All Branches
```bash
git branch -a
```

### Delete Merged Branches
```bash
git branch --merged main | grep -v "main" | xargs git branch -d
```

### Show Branch Divergence
```bash
git log --oneline --left-right main...HEAD
```

## Branch Naming Conventions

```
feature/description    # New features
fix/description        # Bug fixes
refactor/description   # Code refactoring
test/description       # Test additions
docs/description       # Documentation
chore/description      # Maintenance tasks
```

## Instructions

### No Arguments - Show Status
1. Show current branch name
2. Show tracking status (ahead/behind remote)
3. Show commits since diverging from main
4. Show any uncommitted changes

### With Branch Name - Create Branch
1. Verify main branch is up to date
2. Create new branch from main
3. Report new branch name

### --list - List Branches
1. Show all local branches
2. Show remote tracking branches
3. Indicate current branch

### --cleanup - Clean Merged Branches
1. Show branches that would be deleted
2. Confirm with user before deleting
3. Delete merged branches (except main)

## Important Notes

- Always create branches from `main` (the default base)
- Never force delete branches (`-D`) without confirmation
- Keep branch names descriptive but concise
- Clean up branches after PRs are merged
