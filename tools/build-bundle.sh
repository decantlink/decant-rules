#!/bin/sh
# Builds dist/rules.bundle.json from rules/*.json. Run from the repo root.
set -eu

bundle=dist/rules.bundle.json

build() {
  jq -s 'add' rules/global.json rules/social.json rules/shopping.json | jq \
    --argjson schemaVersion "$(jq '.schemaVersion' "$bundle")" \
    --argjson generation "$1" \
    --arg generatedAt "$2" \
    '{schemaVersion: $schemaVersion, generation: $generation, generatedAt: $generatedAt, rules: .}'
}

case "${1:-}" in
  --bump)
    generation=$(( $(jq -e '.generation' "$bundle") + 1 ))
    tmp=$(mktemp "$bundle.XXXXXX")
    build "$generation" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$tmp"
    mv "$tmp" "$bundle"
    echo "built $bundle at generation $generation; sign it before committing"
    ;;
  --check)
    built=$(build "$(jq -e '.generation' "$bundle")" "$(jq -r '.generatedAt' "$bundle")")
    if [ "$(printf '%s' "$built" | jq -S .)" != "$(jq -S . "$bundle")" ]; then
      echo "error: $bundle is out of date with rules/*.json; run tools/build-bundle.sh --bump" >&2
      exit 1
    fi
    echo "$bundle matches rules/*.json"
    ;;
  *)
    echo "usage: tools/build-bundle.sh --bump | --check" >&2
    exit 2
    ;;
esac
