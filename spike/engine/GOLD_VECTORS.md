# Gold-Vector Generation Plan — the engine parity contract

The hybrid strategy (resolution of [wayfinder research ticket #3](https://github.com/mohmaedeslam00116/lens-android/issues/3)) keeps the desktop TypeScript engine as the **parity oracle**. This document specifies, concretely, how gold vectors are produced and consumed. Bit-for-bit parity on these vectors is a merge gate for every kernel ported from the desktop engine.

## Principle

One generator script lives in **lens-desktop** (the oracle), runs the real engine modules over **fixed, seeded inputs**, and emits deterministic JSON. The Dart port consumes those vectors in CI and must reproduce them exactly — no tolerances on decisions, exact values on scores (serialized with full double precision).

## Generator (in lens-desktop, next PR)

- Location: `lens-desktop/frontend/electron/engine/__parity__/generate-vectors.ts`
- Run: `npm run parity:generate` (node >= 18, offline, seeded PRNG — same inputs on every machine).
- Inputs are committed alongside the vectors (`__parity__/inputs/`), so regeneration is reproducible and diffable.

## Vector files (emitted to `spike/engine/gold/`)

| File | Input | Records | Pinned by |
|---|---|---|---|
| `tokenization.json` | 200 bilingual strings (AR w/ diacritics + clitics, EN, mixed) | `input → token[]` | `tokenization.dart::analyze` |
| `bm25.json` | 50-doc seeded corpus, 6 fixed queries | per query: ranked `docId[]` + `score` (double) | `bm25.dart` |
| `dedup.json` | 40 records w/ planted dupes (L1 URL variants, L2 near-same text, L3 near-paraphrase) | per record: `verdict`, `matchedUrl?`, `simhashHex` | `dedup.dart` |
| `citations.json` | 20 admitted sources + 10 synthetic drafts | per draft: `kept[]`, `stripped[]` bracket indices | `citation_sse.dart` |
| `sse.json` | 3 recorded provider streams (malformed frames included) | `event[]` + `ringLast` + `replaySince(id)` | `citation_sse.dart` |

## CI contract

1. `parity:generate` re-runs on the desktop; if its committed vectors change, the PR flags it explicitly (oracle moved).
2. The Dart test suite loads `gold/*.json` and asserts exact equality on every record.
3. **Parity target: 100% on decisions (`verdict`, `docId` order, `kept/stripped`), exact doubles on scores.** The spike gate's "≥ 90%" applies only to the interim hand-check before the generator lands.

## Status

- [x] Dart kernels + tests (this PR)
- [ ] Generator PR in lens-desktop → vectors committed here
- [ ] Vectors wired into `kernels_test.dart` (follow-up PR)
- [ ] Spike numbers recorded on [the spike ticket](https://github.com/mohmaedeslam00116/lens-android/issues/12)
