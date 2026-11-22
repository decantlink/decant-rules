#!/bin/sh
# Warn-only: CORE_REF should track the decant-core version the app resolves, which may lag the
# newest tag on purpose. Exits 0 either way so a new core release never blocks a rules PR.
set -eu

pinned=$(sed -n 's/^ *CORE_REF: *//p' .github/workflows/ci.yml | head -n 1)
latest=$(git ls-remote --tags --refs https://github.com/decantlink/decant-core |
  sed 's|.*refs/tags/||' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1)

if [ -z "$pinned" ] || [ -z "$latest" ]; then
  echo "warning: could not read CORE_REF ('$pinned') or the latest decant-core tag ('$latest')" >&2
  exit 0
fi

if [ "$pinned" = "$latest" ]; then
  echo "CORE_REF $pinned is the latest decant-core tag"
  exit 0
fi

msg="CORE_REF $pinned is behind decant-core $latest. Do not bump it yourself: tell the maintainer, who decides once the app resolves $latest and the fixtures pass against it."
if [ "${GITHUB_ACTIONS:-}" = "true" ]; then echo "::warning::$msg"; else echo "warning: $msg"; fi
