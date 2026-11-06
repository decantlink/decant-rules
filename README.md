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
fixtures/semantic-safety.json  functional parameters the rules must never strip
tools/                     bundle build, generation check, signing
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
the exact bytes are signed (Ed25519, detached `.sig`) locally by the maintainer; CI only
verifies. Clients verify the signature over the served bytes before parsing, and refuse a
bundle whose `generation` isn't higher than the one they hold. See SCHEMA.md §5.

## Publishing

Merging to `main` publishes. Apps download `dist/rules.bundle.json` and its `.sig` from
`https://raw.githubusercontent.com/decantlink/decant-rules/main/dist/`, which GitHub caches
for about 5 minutes, so devices see a merge within minutes of their next check.

1. Open a PR with the `rules/*.json` change and any fixture updates.
2. Rebuild the bundle: `tools/build-bundle.sh --bump` (generation + 1, `generatedAt` = now).
3. The maintainer signs in their own terminal with `swift tools/sign-bundle.swift`, entering the
   managed key at the hidden prompt (or piping it in), and commits the `.sig`.
4. CI checks the schema, rules-vs-bundle consistency, the signature, the +1 generation rule,
   and runs the fixtures against the real engine.
5. Merge = publish. If `main` gained a publish meanwhile, take its `dist/`, bump and sign again.
   A bad publish is fixed by another +1 publish, never by lowering `generation`.
