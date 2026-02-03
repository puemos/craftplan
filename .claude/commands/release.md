---
description: Create a new release with version bump, commit, tag, push, and GitHub release
allowed-tools: Bash, Read, Grep, Edit, AskUserQuestion, Skill
---

# Release Workflow

Follow these steps to create a new release:

## Step 1: Get current state

1. Get the current version from `mix.exs`:
   ```bash
   grep 'version:' mix.exs | head -1
   ```

2. Get the latest git tag:
   ```bash
   git tag --sort=-v:refname | head -1
   ```

3. Get commits since last tag for release notes:
   ```bash
   git log $(git tag --sort=-v:refname | head -1)..HEAD --oneline --no-merges
   ```

## Step 2: Run tests

Run the test suite and ensure all tests pass:

```bash
mix test
```

**CRITICAL: Do NOT proceed if any tests fail.** Report the failures to the user and stop the release process.

## Step 3: Run formatter

Run the formatter to ensure all code is properly formatted:

```bash
mix format
```

Check if the formatter made any changes:

```bash
git diff --stat
```

If there are changes, inform the user that formatting was applied and these will be included in the release commit.

## Step 4: Determine new version

Ask the user what type of release this is:
- **patch** (x.y.Z): Bug fixes, minor improvements
- **minor** (x.Y.0): New features, backwards compatible
- **major** (X.0.0): Breaking changes, major milestone

Calculate the new version number based on the latest tag (not mix.exs, as they may differ).

## Step 5: Update mix.exs

Use the Edit tool to update the version in `mix.exs`:
- Find the line `version: "x.y.z",`
- Replace with the new version

## Step 6: Commit

Use the `/commit` skill to create a commit with the message:
```
chore(release): bump version to x.y.z
```

## Step 7: Create and push tag

Create an annotated tag and push both the commit and tag:

```bash
git tag vX.Y.Z
git push origin main
git push origin vX.Y.Z
```

## Step 8: Generate release notes

Get all commits since the previous tag and format them:

```bash
git log PREV_TAG..vX.Y.Z --oneline --no-merges
```

Group changes by type (feat, fix, refactor, ui, etc.) for the release notes.

## Step 9: Create GitHub release

Use `gh release create` to create the GitHub release:

```bash
gh release create vX.Y.Z --title "vX.Y.Z" --notes "RELEASE_NOTES"
```

The release notes should include:
- "## What's Changed" section with bullet points for each change
- A "Full Changelog" link comparing to the previous tag

## Step 10: Confirm success

Show the user:
1. The commit hash
2. The tag that was created
3. The GitHub release URL
