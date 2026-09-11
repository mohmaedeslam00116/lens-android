# 0003 — Mobile architecture: Riverpod, feature-first packages, engine isolate, GoRouter

- **Status**: accepted
- **Date**: 2026-09-11
- **Resolves**: [Grilling: engine architecture & app module structure](https://github.com/mohmaedeslam00116/lens-android/issues/5) (user decided 2026-09-11)
- **Builds on**: [ADR-0001](0001-flutter-stack.md) (stack); the hybrid engine strategy ([Research: reusing the desktop TypeScript engine on Android](https://github.com/mohmaedeslam00116/lens-android/issues/3)); the OfflineVault schema ([Grilling: OfflineVault storage schema](https://github.com/mohmaedeslam00116/lens-android/issues/13)). ADR-0002 (engine-reuse ratification) remains pending the on-device spike numbers.

## Context

With the stack fixed (Flutter/Dart) and the engine strategy fixed (Dart port with a desktop-TS parity oracle), the app's shape had to be settled before the spec freeze: state management for streaming-heavy live research, module structure that keeps parity kernels widget-free, the execution model that binds `ForegroundResearchRun` to the session state machine, and navigation for a phones-only bilingual app.

## Decision

1. **State management: Riverpod.** Compile-safe providers; stream composition for the live timeline (subqueries, sources, telemetry); providers are widget-free and testable without pumpWidget. The desktop's React data flow maps cleanly: component state → widget-local providers, cross-view state → session providers.
2. **Module structure: feature-first, engine and vault as packages.**
   ```
   lib/
   ├── features/{research,discover,library,settings}/
   ├── core/               # routing, theming (DESIGN.md tokens), l10n, di
   packages/
   ├── lens_engine/        # pure Dart kernels; spike kernels graduate here
   └── lens_vault/         # drift DB, secure key storage
   ```
   Import rule: features depend on engine/vault **public APIs only**; widgets never import drift directly. This preserves the desktop's engine/UI seam and keeps the parity kernels testable in isolation.
3. **Execution: engine isolate + typed broadcast streams.** The research pipeline runs in a long-lived isolate; the UI consumes broadcast streams of typed session events; the foreground-service notification is driven by the session state machine (planning → awaiting_approval → running → completed / cancelled / budget_exhausted / failed). **Cancellation** is a token checked at every I/O and loop boundary (the AbortController equivalent; <100 ms preserve-partial-evidence budget). **Process death** is recovered from `lens_vault` transactional checkpoints — the checkpoint is the contract; neither the isolate nor the service is assumed to survive (OEM variance per ADR-0001's caution 3).
4. **Navigation: GoRouter + bottom `NavigationBar`.** Destinations: Home (composer + active session), Discover, Library (+ Settings). Deep links open reports by id (needed for notification taps); `TextDirection` follows the app locale (AR → RTL, EN → LTR) with the LENS wordmark always LTR. A Knowledge-graph slot is reserved but hidden behind the still-pending scope ruling.

Persistence (from #13, restated for completeness): one drift DB owned by `lens_vault`, API keys in `flutter_secure_storage`, keep-until-deleted retention with a settings usage readout.

## Alternatives considered

- **Bloc** for state: stricter traceability, but heavier per-feature boilerplate for a solo project; revisit if Riverpod streams prove untestable at scale.
- **Layer-first folders**: simpler start; rejected because the engine/UI boundary blurs and parity kernels would tangle with widgets.
- **Main-isolate async pipeline**: simpler, rejected — JSON parsing and SimHash over 200 sources would jank the UI precisely when the live timeline is busiest.
- **Drawer navigation**: more room for future destinations; rejected — hides the three primary destinations and departs from the desktop rail's directness.

## Consequences

- Spike kernels move into `packages/lens_engine` at spec time, bringing their tests and the gold-vector contract with them.
- Every feature exposes its state through providers; no `setState`-owned session state.
- Notification + deep-link plumbing is a spec requirement, not an afterthought (notification → report deep link is the recovery path).
- This ADR **reconciles ADR-0000's numbering plan**: the originally listed "ADR-0002: engine reuse" and "ADR-0003: background execution" collapse into ADR-0002 (ratification after the spike) and this ADR (execution model included). ADR-0000's list is updated in the same PR to prevent the numbering conflict flagged during PR #11's review.
