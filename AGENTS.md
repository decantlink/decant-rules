# decant-rules — Decant rule database (public)

The rule data + its normative contract. Authoring sources are human-reviewed; CI compiles
them into one signed bundle that `decant-core` loads. Data repo — no Swift.

## Structure

```
SCHEMA.md                   the normative contract — read first
schema/rule.schema.json     JSON Schema for one rule
schema/bundle.schema.json   JSON Schema for the delivery bundle
rules/*.json                authoring source, per category (human-reviewed)
dist/rules.bundle.json      compiled, signed delivery bundle (CI-generated; example committed)
fixtures/url-fidelity.json  acceptance corpus engines must pass (surgical-splice fidelity)
```

## Commands

- Add/edit a rule: edit `rules/<category>.json` per `SCHEMA.md`; validate against `schema/rule.schema.json`.
- The signed `dist/rules.bundle.json` is **CI-built** (concatenate authoring files → stamp `generation` → Ed25519-sign exact bytes). Don't hand-edit `dist/`.

## Conventions

- **Three formats, one contract:** authoring (`rules/*.json`) → delivery (signed bundle) → runtime (compiled, in `decant-core` only). Keep them distinct.
- Rule `id` is a stable namespaced merge key (e.g. `social.twitter`), not a UUID.
- `hostRegex` matchers must be anchored `^…$` (enforced by `decant-core`'s `RuleValidator`, not the schema).

## Contracts

- Rule data format → **canonical here**: `SCHEMA.md` + `schema/*.json` (versioned by `schemaVersion` + monotonic `generation`). Consumed by `decant-core`.

## Pointers
- Current state: `~/.agents/memories/Decant/SUMMARY.md` · Decisions: vault Bible §12 · Cross-repo map: `decant-meta/AGENTS.md`.

<!-- Update on: schema change, new rule category, changed bundle/signature scheme, new fixture format. -->
