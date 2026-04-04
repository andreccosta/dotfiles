---
name: commit-message
description: Generate semantic commit messages
---

## When to use
Use this when preparing a new commit.

## Format (Conventional Commits)
```
<type>: <short summary>

<optional body explaining why, not what>
```

## Types
- `feat`: New feature
- `fix`: Bug fix
- `ref`: Code change that neither fixes a bug nor adds a feature
- `test`: Adding or updating tests
- `chore`: Build process, dependencies, or tooling changes
- `perf`: Performance improvements

## Rules
- Summary line under 50 characters
- Use imperative mood ("add" not "added")
- No period at the end of summary
- Body wrapped at 72 characters

## Body (Use Sparingly)
- Prefer title only when sufficient
- Use short body only for complex or non-obvious changes

