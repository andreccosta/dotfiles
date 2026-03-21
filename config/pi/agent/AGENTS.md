- In all interaction and commit messages, be extremely concise and sacrifice grammar for the sake of concision.

## Code exploration

You run in an environment where ast-grep (`sg`) is available; whenever a search requires syntax aware or structural matching, default to `sg --lang $language -p '<pattern>'` and avoid falling back to text-only tools like `rg` or `grep` unless I explicitly request a plain-text search.
