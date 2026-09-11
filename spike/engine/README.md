# LENS engine spike

On-device performance + parity harness for the LENS Android engine kernels (wayfinder ticket #12; mandated by the engine-strategy resolution on #3 and ADR-0001's caution #2).

## Kernels under test (`lib/src/`)

- `tokenization.dart` — bilingual AR/EN analysis: diacritic strip, letter normalization, prefix-clitic stemming (parity surface #1)
- `bm25.dart` — Okapi BM25 (k1=1.2, b=0.75)
- `dedup.dart` — L1 URL canonicalization, L2 invariant SHA-256, L3 64-bit SimHash (Hamming ≤ 3)
- `citation_sse.dart` — citation pre-allocation + unmapped-bracket stripping; SSE frame parser; 300-event ring buffer with `since=` replay
- `corpus.dart` — deterministic seeded corpus (500 docs, AR/EN mixed, skewed lengths)

## Run

```bash
flutter test                 # kernel unit tests (CI)
flutter run --profile        # on-device harness (real measurements!)
```

The app shows four benchmark buttons: **BM25 (500 docs)**, **Dedup (200 docs)**, **Citation (50 src)**, **SSE 10k events**. Always run in `--profile` on a real mid-range device — debug numbers are meaningless.

## Go / no-go thresholds (resolution of #3)

| Probe | Go |
|---|---|
| BM25 build + 6 queries, 500 docs | < 3 s |
| 3-level dedup, 200 docs | < 10 s |
| Citation pass, 50-source report | < 1 s |
| Peak RSS increment | < 150 MB |
| Bit-for-bit parity on gold vectors | ≥ 90% interim; 100% once the generator lands |
| 10k SSE events + abort | parse budget met; partial evidence preserved |

## Parity oracle

See [GOLD_VECTORS.md](GOLD_VECTORS.md) — the desktop TS engine generates gold vectors; the Dart kernels must reproduce them bit-for-bit.
