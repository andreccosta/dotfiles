#!/usr/bin/env bash

set -euo pipefail

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "error: shellcheck is required" >&2
  exit 1
fi

if ! command -v file >/dev/null 2>&1; then
  echo "error: file is required" >&2
  exit 1
fi

any_failed=false

while IFS= read -r f; do
  if file -b "$f" | grep -qi 'shell script'; then
    if shellcheck "$f"; then
      echo "[OK]: successfully linted $f"
    else
      any_failed=true
    fi
  fi
done < <(git ls-files | sort -u)

if [ "$any_failed" = true ]; then
  exit 1
fi
