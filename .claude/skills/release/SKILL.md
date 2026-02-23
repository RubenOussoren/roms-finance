---
name: release
description: Manage GitHub release notes -- add notes to draft, review status, publish
---

# Manage GitHub Release Notes

Manage release notes using GitHub draft releases as the working document. Uses `gh` CLI exclusively.

## Usage

```
/release                   # Show release status (default)
/release status            # Show release status
/release note              # Add a note to the draft release
/release publish           # Finalize and publish the draft release
```

## Mode: Status (default)

Show current release state.

1. **List releases**
   ```bash
   gh release list --limit 5
   ```

2. **Identify latest published tag**
   ```bash
   gh release view --json tagName,name,publishedAt
   ```

3. **Show commits since last release**
   ```bash
   git log $(gh release view --json tagName -q .tagName)..HEAD --oneline
   ```

4. **Show draft release if one exists**
   ```bash
   gh release list --json tagName,name,isDraft -q '.[] | select(.isDraft)'
   ```
   If a draft exists, show its body:
   ```bash
   gh release view <draft-tag> --json body -q .body
   ```

5. Report to the user:
   - Latest published release tag and date
   - Number of commits since that release
   - Whether a draft exists (and its current contents)

## Mode: Note

Add a bullet point to the draft release notes.

1. **Check for existing draft release**
   ```bash
   gh release list --json tagName,isDraft -q '.[] | select(.isDraft) | .tagName'
   ```

2. **If no draft exists, create one**
   - Parse the latest published tag to determine version:
     ```bash
     gh release view --json tagName -q .tagName
     ```
   - Suggest next version using semver:
     - Fix-only changes = patch bump (e.g. v1.0.0 -> v1.0.1)
     - New features = minor bump (e.g. v1.0.0 -> v1.1.0) -- this is the default
     - Breaking changes = major bump (e.g. v1.0.0 -> v2.0.0)
   - **Ask the user to confirm the version tag before creating**
   - Create the draft with section template:
     ```bash
     gh release create <tag> --draft --title "<tag>" --notes "$(cat <<'EOF'
     ## Summary

     One-line summary of this release.

     ## Features

     ## Fixes

     ## Infrastructure

     EOF
     )"
     ```

3. **Analyze recent commits** to draft a bullet point
   ```bash
   git log $(gh release list --json tagName,isDraft -q '.[] | select(.isDraft | not) | .tagName' | head -1)..HEAD --oneline
   ```
   - Show the user the commits and suggest a bullet point
   - Classify into the correct section:
     - **Features**: New user-facing functionality
     - **Fixes**: Bug fixes, corrections
     - **Infrastructure**: Refactors, tests, CI, dependencies, docs

4. **Show the user what will be added and ask for confirmation**

5. **Fetch current draft body, insert bullet, update**
   ```bash
   gh release view <draft-tag> --json body -q .body
   ```
   Insert the new bullet under the correct section heading, then:
   ```bash
   gh release edit <draft-tag> --notes "$(cat <<'EOF'
   <updated body>
   EOF
   )"
   ```

6. Confirm the note was added and show the updated draft body.

## Mode: Publish

Finalize and publish the draft release.

1. **Find the draft release**
   ```bash
   gh release list --json tagName,isDraft -q '.[] | select(.isDraft) | .tagName'
   ```
   If no draft exists, inform the user and suggest `/release note` first.

2. **Show the full draft for review**
   ```bash
   gh release view <draft-tag> --json body -q .body
   ```

3. **Pre-publish checks** -- warn the user if:
   - The Summary section still has the placeholder text
   - Any section (Features/Fixes/Infrastructure) is completely empty (suggest removing the heading)
   - No bullet points exist at all

4. **Add test count to Infrastructure section**
   ```bash
   bin/rails test 2>&1 | tail -5
   ```
   Add a bullet like: `- Test suite: 1500 tests, 0 failures, 0 errors`

5. **Ask the user for final confirmation before publishing**

6. **Publish the release**
   ```bash
   gh release edit <draft-tag> --draft=false
   ```

7. **Return the release URL**
   ```bash
   gh release view <draft-tag> --json url -q .url
   ```

## Important Notes

- **Always confirm before writing** -- show the user what will be added or published before doing it
- Draft releases on GitHub are the single source of truth -- no local CHANGELOG.md
- This skill uses `gh` CLI only -- no changes to Rails app or Provider::Github
- Version bump suggestion is advisory -- always let the user decide
- Empty sections should be removed from the body before publishing
- The Summary line should be meaningful prose, not a placeholder
