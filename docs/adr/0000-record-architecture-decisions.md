# 0000 — Record architecture decisions

- **Status**: accepted
- **Date**: 2026-09-11

## Context

Decisions hard to reverse — implementation stack, state management, background execution strategy, storage format, engine reuse approach — need a consistent, discoverable home so agents and humans don't relitigate them.

## Decision

We record architecture decisions as short ADRs in `docs/adr/`, numbered `NNNN-slug.md`, each stating context, decision, and consequences. Every significant, hard-to-reverse choice gets an ADR before implementation code lands.

The substantive ADRs for LENS Android:

- ADR-0001: mobile implementation stack — **landed**: Flutter (Dart)
- ADR-0002: engine-reuse ratification (hybrid Dart port with desktop-TS parity oracle; pending the on-device spike numbers)
- ADR-0003: mobile architecture (state, structure, execution model, navigation) — **landed**; includes the background-execution model for `ForegroundResearchRun`

_(Originally ADR-0003 was reserved for background execution alone; the architecture ADR subsumed it, per the reconciliation recorded during [PR #11](https://github.com/mohmaedeslam00116/lens-android/pull/11)'s review.)_

## Consequences

ADR conflicts must be surfaced explicitly, not silently overridden (see `docs/agents/domain.md`).
