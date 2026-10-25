# decant-rules

The open tracker-parameter rule database for [Decant](https://decant.link). Plain data, MIT.

`decant-core` (and any future port) consumes these rules to strip tracking parameters from
URLs on-device. Rules are **data, not code** — updated here, delivered out-of-band, never
requiring an app release.

## Layout

```
SCHEMA.md                  the normative contract — read this first
schema/rule.schema.json    JSON Schema for one rule
schema/bundle.schema.json  JSON Schema for the delivery bundle
rules/*.json               authoring source — per-category, human-reviewed
dist/rules.bundle.json     compiled delivery bundle + .sig (built and signed locally, committed)
fixtures/url-fidelity.json acceptance corpus for engines (surgical-splice fidelity)
```

## Contributing a rule

1. Add or edit the relevant `rules/<category>.json` entry. One rule = one reviewable diff.
2. Host-scope by enumerating domains as a `suffix` list (e.g. all Amazon ccTLDs) — see
   SCHEMA.md §3. Reach for `hostRegex` only when a list cannot express the match.
3. Strip only **tracking** params. When unsure a param is safe to remove, don't — a false
   positive silently breaks a link, which is worse than a missed tracker.
4. Don't copy another project's rule file wholesale (SCHEMA.md §8). Curate; attribute derivations.

## Delivery & integrity

`rules/*.json` are compiled into `dist/rules.bundle.json` with a monotonic `generation`, and
the exact bytes are signed (Ed25519, detached `.sig`). For now this happens locally with a
development key, and CI verifies the signature; CI signing with a managed key replaces it
before release. Clients verify the signature over the served bytes before parsing, and refuse
a bundle older than the one cached. See SCHEMA.md §5.
