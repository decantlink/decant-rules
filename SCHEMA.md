# decant-rules — Rule Format Contract

This document is the **durable, cross-repo, cross-language contract** for Decant rules.
`decant-core` (Swift), and any future port (Kotlin, JS), must honor it exactly. It changes
**only additively** (see Versioning). Treat it as an API, not a doc.

> Status: v1 (MVP — query-parameter removal). Rewrite and routing actions are reserved,
> not yet defined. The shape below is designed so they can be added **without a repaint.**

---

## 1. Three formats, one contract

The same logical rule exists in three forms. Keep them distinct:

| Layer | Form | Lives in | Optimized for |
|---|---|---|---|
| **Authoring** | many small JSON files, per category | `rules/*.json` | human review — clean git diffs, blame, PRs |
| **Delivery** | one signed bundle | `dist/rules.bundle.json` (+ `.sig`) | integrity + one fetch; compiled from authoring files |
| **Runtime** | in-memory compiled indices | `decant-core` only | O(params) matching; never serialized |

The build concatenates the authoring files, stamps the envelope (§5), and signs the **exact bytes**.
The runtime never re-serializes; it verifies bytes, then parses.

---

## 2. Versioning & forward-compatibility

- `schemaVersion` is an **integer**, bumped only on a breaking change. v1 = this document.
- The contract evolves **additive-only**: new optional fields, new action `type`s, new matcher
  `type`s. **A field's meaning is never repurposed.** A removed field is tombstoned in this doc,
  never reused.
- An engine declares the max `schemaVersion` it understands. **Unknown-element skip granularity
  (normative):**

  | Engine encounters | Action |
  |---|---|
  | Unknown **action** `type` | **skip the whole rule** (a half-applied rule is a broken URL) |
  | Unknown **matcher** `type` | **skip the whole rule** |
  | Unknown **optional field** on a known type | ignore the field, keep the rule |
  | Unknown key inside `hostPath`'s `path`, or `path` without `prefix` | **skip the whole rule** (§3; an ignored scoping field would widen the rule) |
  | `schemaVersion` > engine max | load rules it understands, **skip-and-log** the rest; never fail the whole bundle |

  Rationale: an old client meeting a v2 routing rule must keep cleaning with the rules it does
  understand — never crash, never partial-apply.

---

## 3. Host matching semantics (normative)

A cleaner processes **one URL in isolation** — there is no page context, so there is **no
first-party/third-party determination, and the Public Suffix List is out of scope.** Host
scoping is author-declared, matched by literal label boundaries.

`matcher` is a tagged object:

```jsonc
{ "type": "any" }                                   // global — matches every URL
{ "type": "host", "suffix": ["amazon.com", ...] }   // label-boundary suffix match
{ "type": "host", "exact":  ["x.com", ...] }        // exact host match
{ "type": "hostRegex", "pattern": "^(.*\\.)?amazon\\.[a-z.]+$" }  // escape hatch
{ "type": "hostPath", "exact": ["instagram.com"],
  "path": { "prefix": ["/reel", "/p"] } }           // host match + path-segment prefix
```

- **`suffix`** matches host `H` against declared domain `D` iff `H == D` **or** `H` ends with
  `"." + D`. This is the label-boundary anchor: `notamazon.com` does **not** match `amazon.com`.
- **`exact`** matches iff `H == D`.
- A `host` matcher may carry `exact` **and/or** `suffix` (each a list; union of both).
- **Multi-ccTLD brands are a list, not a wildcard.** Amazon =
  `suffix: ["amazon.com","amazon.es","amazon.co.uk","amazon.de", …]`. Pure data, diff-reviewable.
  A missing TLD is a one-line PR triggered by a broken-link report.
- **`hostRegex` is the audited escape hatch**, for cases a list cannot express. Validation
  **requires the pattern be anchored** (`^…$`); an unanchored host regex is rejected
  (`amazon.*` would match `amazon.com.phishing.ru`). Use sparingly — every regex is an
  unreviewable matcher.
- **Most many-TLD tracking is global, not host-scoped.** Google's ~190 ccTLDs never need
  enumerating: `gclid`/`utm_*` strip on `{ "type": "any" }`. Only brand-specific params
  (Amazon `tag`/`ref`) are host-scoped, and those brands have manageable TLD counts.

### `hostPath` — host plus path prefix

```jsonc
{ "type": "hostPath",
  "exact":  ["instagram.com", "www.instagram.com"],   // same semantics as `host`; exact and/or suffix
  "path":   { "prefix": ["/reel", "/reels", "/p", "/tv"] } }
```

- **Composition:** the rule matches iff the host matches (identical to `host`) **and** the path
  matches any listed prefix.
- **Path definition:** the RFC 3986 path component of the input URL, exactly as written
  (percent-encoded, no decoding). No query, no fragment. An empty path is `/`. No dot-segment
  normalization. Matching is case-sensitive.
- **Segment-boundary prefix:** `P` matches path `X` iff `X == P`, or `X` starts with `P + "/"`.
  If `P` itself ends with `/`, `X` starting with `P` is enough. So `/reel` matches `/reel`,
  `/reel/` and `/reel/ABC/`, but not `/reels/ABC/`. This mirrors the host `suffix` label anchor
  (`notamazon.com` ≠ `amazon.com`).
- **Validation:** at least one prefix, each starting with `/`, no `?` or `#`. Host rules are the
  same as for `host`.
- **`path` is an object, not a bare list.** Its only v1 key is `prefix`. A missing `prefix` or an
  unknown key inside `path` makes the rule undecodable, so engines skip the whole rule (§2) rather
  than widen it to every path.

> Reserved (not in v1): `pathPattern` matching, `compound` (allOf/anyOf/noneOf).
> These arrive with rewrite/routing.

---

## 4. Actions (v1 = Phase 0 "clean" only)

`actions` is an **ordered** array of tagged objects. v1 defines only the **clean** phase
(parameter removal). Clean actions are **commutative and batched** across all matching rules
(union of removals) — except `keepOnly` (see below).

```jsonc
{ "type": "removeParameters", "select": { "names":   ["tag", "ref"] } }
{ "type": "removeParameters", "select": { "prefix":  "utm_" } }
{ "type": "removeParameters", "select": { "regex":   "^(fb|gc|mc)lid$" } }
{ "type": "removeParameters", "select": { "keepOnly": ["v", "t", "list", "index"] } }
{ "type": "removeAllParameters" }
```

`select` is **exactly one of** `names` / `prefix` / `regex` / `keepOnly`.

- **Name comparison is percent-decoded and case-sensitive.** `utm_source` matches the decoded
  parameter name. (Tracker param names are ASCII in practice; case-sensitive avoids
  over-removal.)
- **`keepOnly` does not stack** (it is a complement op, not commutative with other `keepOnly`s).
  If multiple matching rules carry `keepOnly`, the **highest-priority** rule's allowlist wins;
  `names`/`prefix`/`regex` removals from all matching rules still apply on top.
- `removeAllParameters` subsumes every `removeParameters` in scope (validator warns).

> Reserved (not in v1): `rewriteURL`, `expandURL` (Phase 1 — rewrite); `redirect`, `openInApp`
> (Phase 2 — route). When defined, the phase model is: **clean → rewrite → route**, rewrite and
> route each at most one per rule, route terminal. Loop detection and redirect-safety validation
> are concerns of the route phase **only** and do not exist in v1.

---

## 5. Bundle envelope & integrity

Delivery bundle (`dist/rules.bundle.json`):

```jsonc
{
  "schemaVersion": 1,
  "generation": 17,                       // monotonic; anti-rollback (§5.2)
  "generatedAt": "2026-06-18T00:00:00Z",  // informational
  "rules": [ /* Rule objects */ ]
}
```

### 5.1 Signing — sign the exact bytes
- A **detached Ed25519 signature** over the **exact served bytes** of the bundle file,
  published alongside as `rules.bundle.json.sig`.
- The public key is **pinned in the app binary**. The private key is never committed.
  Pre-release bundles are signed locally with a development key (public half:
  `keys/dev_public.key`); release bundles are signed in CI with a managed key (ideally
  offline/hardware-backed).
- Verification order: **fetch bytes → verify signature over those bytes → only then parse.**
  Never canonicalize or re-serialize before verifying (JSON is not byte-stable; re-serialization
  is an attack surface).
- **One verification path for all sources.** The seed bundle shipped inside the app is itself a
  signed bundle and goes through the same verify-then-parse path. No "trusted because local."

### 5.2 Anti-rollback
- `generation` is a monotonic integer, incremented every publish.
- The client **refuses a bundle whose `generation` ≤ the cached one**, even if validly signed —
  prevents a CDN/MITM replaying an older signed bundle to re-expose a removed bad rule.

### 5.3 Threat model note
Rules are public (MIT). Signing is **integrity, not secrecy.** In v1 (removal-only) a forged
bundle's worst case is over-removal (broken links) or under-removal (missed tracker) — annoying,
not catastrophic. The catastrophic blast radius (redirect → phishing) only appears with route
actions. Signing ships now anyway because it is cheap and establishes the single verify path
before routing exists.

---

## 6. Rule object

```jsonc
{
  "id": "shopping.amazon",            // stable, namespaced, unique within a bundle
  "name": "Amazon tracking",
  "description": "Strips affiliate tags and session params across Amazon marketplaces.",
  "matcher": { "type": "host", "suffix": ["amazon.com", "amazon.es"] },
  "actions": [ { "type": "removeParameters", "select": { "names": ["tag", "ref"] } } ],
  "priority": 100,                    // lower = higher priority; default 100
  "enabled": true,
  "source": "builtIn",               // builtIn | user | community | ai
  "category": "shopping",            // tracking|affiliate|session|analytics|social|shopping|advertising|urlRewriting|appRouting|custom
  "version": 1                       // per-rule, for sync conflict resolution (future)
}
```

Required: `id`, `name`, `matcher`, `actions`, `source`. Others optional with defaults
(`priority` 100, `enabled` true, `version` 1).

`id` is a **stable namespaced string** (`category.brand`), not a UUID — it is the merge key for
broken-link reports and overrides, and must survive re-authoring. (The draft's per-rule UUID is
dropped: a content-addressable stable id is better for a data file under version control.)

---

## 7. URL fidelity — "copy-perfect" defined

Decant promises copy-perfect output. **Definition:** the output is **byte-identical to the input
on the portion that is kept** — only the removed parameters (and their separators) are excised.

- The engine operates by **surgical splice on the raw query substring**, not by round-tripping
  through `URLComponents` (which re-percent-encodes, turns `+`↔space, and can reorder/drop).
- Kept parameters retain their **original bytes verbatim** (original encoding, original order).
- "Copy-perfect" is byte-identity **on the remainder**, not a promise to fix a malformed input.
  A malformed input's surviving parts are preserved as-is.
- This is the **highest bug-density component**; it has a dedicated fixture corpus
  (`fixtures/url-fidelity.json`) covering: leading param (no `&`), `;` separators, `+`/space,
  fragments containing `?`, empty values, repeated names, percent-encoded names.

---

## 8. Seed provenance

Seed rules in `rules/` are **curated from public knowledge** of tracking parameters and
**cross-referenced** against existing open lists (ClearURLs, AdGuard URL-tracking filter) for
coverage gaps. They are **not cloned**: the curated *compilation* of a peer project may carry
copyright (US) or a sui-generis database right (EU), and wholesale copying contradicts Decant's
honest-business principle. Anything genuinely derived from a specific source is attributed in the
rule's `description` or a sibling `NOTICE`. Individual facts ("`utm_source` is a tracker") are
not owned; the curated list is ours.
