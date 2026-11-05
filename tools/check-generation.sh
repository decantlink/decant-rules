#!/bin/sh
# Exactly +1, not merely higher: clients keep the highest generation they've seen, so one
# mistyped jump would make them reject every later normally-numbered publish.
set -eu

base_ref=${1:?usage: tools/check-generation.sh <base-ref>}
bundle=dist/rules.bundle.json

if git diff --quiet "$base_ref" -- "$bundle"; then
  echo "$bundle unchanged from $base_ref; nothing to check"
  exit 0
fi

base_generation=$(git show "$base_ref:$bundle" | jq -e '.generation')
generation=$(jq -e '.generation' "$bundle")
expected=$((base_generation + 1))

if [ "$generation" != "$expected" ]; then
  echo "error: $bundle changed but generation is $generation; it must be $expected ($base_ref has $base_generation)" >&2
  exit 1
fi
echo "$bundle generation $generation = $base_ref + 1"
