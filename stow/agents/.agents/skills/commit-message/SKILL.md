---
name: commit-message
description: Generate Conventional Commit style messages for repository changes. Use when the user asks to commit, create a commit message, write a conventional commit, or simply says "commit".
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
- Prefer a concise summary line; around 50 characters is ideal, but clarity matters more
- Use imperative mood ("add" not "added")
- No period at the end of summary
- Body wrapped at 72 characters

## Body (Use Sparingly)
- Prefer title only when sufficient
- Use short body only for complex or non-obvious changes

## Examples
```text
feat: add search filters
```

```text
fix: handle missing config file
```

```text
ref: simplify cache invalidation
```

```text
test: add coverage for login flow
```

```text
chore: update eslint dependencies
```

```text
perf: reduce query allocations
```

