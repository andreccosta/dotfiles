#!/usr/bin/env bash

set -eo pipefail

any_failed=false

# find all executables and run `shellcheck`
for f in $(find . -type f -not -iwholename '*.git*' | sort -u); do
    if file "$f" | grep --quiet shell; then
        shellcheck "$f" && echo "[OK]: sucessfully linted $f" || any_failed=true
    fi
done

if $any_failed; then 
  exit 1
fi
