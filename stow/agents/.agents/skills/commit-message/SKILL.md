---
name: commit-message
description: Generate Conventional Commit style messages for repository changes. Use when the user asks to commit, create a commit message, write a conventional commit, or simply says "commit".
---

Use the format below as the base. When the repository's history follows its own convention (scopes, other types, casing), match it instead.

## Format (Conventional Commits)
```
<type>: <short summary>

<optional body explaining why, not what>
```

## Types
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `perf`: Performance improvement
- `test`: Adding or updating tests
- `docs`: Documentation only
- `chore`: Build process, dependencies, or tooling changes

## Rules
- Summary: imperative mood ("add" not "added"), no trailing period, around 50 characters, but clarity matters more
- Prefer a summary only; add a short body for complex or non-obvious changes, wrapped at 72 characters

## Example
```text
fix: load plugins sequentially

Parallel loading raced on the shared registry, so hooks registered
by later plugins were sometimes dropped.
```
