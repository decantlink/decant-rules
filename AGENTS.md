# decant-rules — Decant rule database (public)

The rule data + its normative contract. Authoring sources are human-reviewed and compiled
into one signed bundle that `decant-core` loads. Data repo — no Swift package; the only Swift
is the dev signing script in `tools/`.

## Structure

```
SCHEMA.md                   the normative contract — read first
schema/rule.schema.json     JSON Schema for one rule
schema/bundle.schema.json   JSON Schema for the delivery bundle
rules/*.json                authoring source, per category (human-reviewed)
dist/rules.bundle.json      compiled delivery bundle + .sig (built and signed locally, committed)
fixtures/url-fidelity.json  acceptance corpus engines must pass (surgical-splice fidelity)
```

## Commands

- Add/edit a rule: edit `rules/<category>.json` per `SCHEMA.md`; validate against `schema/rule.schema.json`.
- The signed bundle is built and signed locally (`swift tools/sign-bundle.swift`; dist + .sig committed); CI verifies the schema, authored-vs-dist consistency, and the signature against keys/dev_public.key. CI signing with a managed key replaces this at the release gate.

## Conventions

- **Three formats, one contract:** authoring (`rules/*.json`) → delivery (signed bundle) → runtime (compiled, in `decant-core` only). Keep them distinct.
- Rule `id` is a stable namespaced merge key (e.g. `social.twitter`), not a UUID.
- `hostRegex` matchers must be anchored `^…$` (enforced by `decant-core`'s `RuleValidator`, not the schema).

## Contracts

- Rule data format → **canonical here**: `SCHEMA.md` + `schema/*.json` (versioned by `schemaVersion` + monotonic `generation`). Consumed by `decant-core`.

## Pointers
- Consumed by `decant-core` (loads the signed bundle).

<!-- Update on: schema change, new rule category, changed bundle/signature scheme, new fixture format. -->
