# decant-rules — Decant rule database (public)

The rule data + its normative contract. Authoring sources are human-reviewed and compiled
into one signed bundle that `decant-core` loads. Data repo — no Swift package; the only code
is the build, check and signing tools in `tools/`.

## Structure

```
SCHEMA.md                   the normative contract — read first
schema/rule.schema.json     JSON Schema for one rule
schema/bundle.schema.json   JSON Schema for the delivery bundle
rules/*.json                authoring source, per category (human-reviewed)
dist/rules.bundle.json      compiled delivery bundle + .sig (built and signed locally, committed)
fixtures/url-fidelity.json  acceptance corpus engines must pass (surgical-splice fidelity)
fixtures/semantic-safety.json  functional parameters the rules must never strip
tools/build-bundle.sh       rules/*.json -> dist (--bump to rebuild, --check to verify)
tools/check-generation.sh   CI gate: a changed dist must be exactly base generation + 1
tools/sign-bundle.swift     local signer; the maintainer runs it, never an agent or CI
```

## Commands

- Add/edit a rule: edit `rules/<category>.json` per `SCHEMA.md`; validate against `schema/rule.schema.json`.
- Rebuild dist: `tools/build-bundle.sh --bump`; check it: `tools/build-bundle.sh --check`.
- CI (`validate`): generation +1, schema, rules-vs-dist consistency, signature. CI (`fixtures`): the
  fixture suites of `decant-core` at `CORE_REF` (the engine version the app resolves) against this bundle.

## Publishing

Merging to `main` publishes: apps fetch `dist/` from GitHub raw (~5-minute cache). A rules PR:
edit `rules/` + fixtures → `tools/build-bundle.sh --bump` → the maintainer signs locally → CI →
merge. Every change to `dist/` is exactly +1 generation; fixes roll forward, never back. Agents
prepare everything except signing, and never read, generate or print a private key.

## Conventions

- **Three formats, one contract:** authoring (`rules/*.json`) → delivery (signed bundle) → runtime (compiled, in `decant-core` only). Keep them distinct.
- Rule `id` is a stable namespaced merge key (e.g. `social.twitter`), not a UUID.
- `hostRegex` matchers must be anchored `^…$` (enforced by `decant-core`'s `RuleValidator`, not the schema).

## Contracts

- Rule data format → **canonical here**: `SCHEMA.md` + `schema/*.json` (versioned by `schemaVersion` + monotonic `generation`). Consumed by `decant-core`.

## Pointers
- Consumed by `decant-core` (loads the signed bundle).

<!-- Update on: schema change, new rule category, changed bundle/signature scheme, new fixture format. -->
