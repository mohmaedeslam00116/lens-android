# 0001 — Flutter as the implementation stack for LENS Android v1

- **Status**: accepted
- **Date**: 2026-09-11
- **Resolves**: [Research: Flutter vs Kotlin/Compose for LENS Android](https://github.com/mohmaedeslam00116/lens-android/issues/2) (user approved the recommendation on 2026-09-11)

## Context

LENS Android needs a stack that carries the desktop app's feature surface to phones: bilingual RTL/LTR UI (Cairo + Inter), markdown/GFM report rendering with interactive citation pills, Mermaid diagram support, PDF/DOCX export, multi-provider LLM streaming (SSE), foreground research runs that survive Doze, on-device SQLite storage, and possible reuse of the desktop's TypeScript engine via an embedded JS runtime.

The two candidate stacks were **Flutter (Dart)** and **native Kotlin + Jetpack Compose**. The full comparison lives in the resolution comment on issue #2; the load-bearing findings:

- Bilingual RTL/LTR, SQLite, SSE, and foreground-service capability are ties — both stacks deliver, with design discipline doing the real work.
- Flutter leads on widget-based markdown rendering (`flutter_markdown_plus`, the maintained community continuation of Google's discontinued `flutter_markdown`), report-quality PDF generation (`pdf` + `printing` with Arabic shaping via an embedded Cairo font), and single-codebase velocity for a solo, Android-first project with a working Flutter 3.41.7 toolchain already installed.
- Kotlin/Compose leads on first-party AndroidX `JavaScriptSandbox` access and zero plugin indirection for foreground services. Honest, but not decisive for v1.
- Mermaid is a WebView/JS component on either stack.

## Decision

**Flutter is the implementation stack for LENS Android v1**, targeting Android (minSdk ≈ API 21, target API 35 per Play policy).

Consequences of this choice that are now settled:

- App language: **Dart**. Engine-port work (see ADR-0002, pending) happens in Dart or behind a JS-runtime boundary — not Kotlin-first.
- UI: Material 3 with direction-aware layouts; RTL is a first-class requirement, not a retrofit.
- State management, module structure, and the engine-reuse mechanism remain open (wayfinder map tickets); this ADR fixes only the stack.

## Cautions carried forward (not blockers)

1. Use `flutter_markdown_plus` (or `markdown_widget`), never the discontinued `flutter_markdown`; pin the dependency and be prepared to vendor-patch.
2. The engine decision ([Research: reusing the desktop TypeScript engine on Android](https://github.com/mohmaedeslam00116/lens-android/issues/3)) must include an on-device QuickJS performance spike (BM25 + dedup + ingestion bound), not paper analysis.
3. `ForegroundResearchRun` must degrade gracefully under OEM battery-killer variance (persisted session checkpoints; never assume the service survives).

## Alternatives considered

- **Kotlin + Jetpack Compose (rejected for v1)**: deeper OS integration and a first-party JS sandbox, at the cost of slower solo iteration; recorded fairly in issue #2. Revisit only if v1 exposes a hard Flutter limitation.
- **React Native / KMP**: not evaluated in depth; no advantage over either finalist for this feature surface, and both add bridge risk to the same axes.
- **Hybrid WebView app**: rejected — the research pipeline and offline vault need real native storage, background execution, and streaming guarantees.

## Consequences

- The dev machine's Flutter 3.41.7 toolchain is the supported build environment; CI must pin a Flutter version.
- Every user-facing string ships Arabic + English from the first commit (bilingual parity policy).
- This ADR supersedes the "stack: not yet decided" note in `AGENTS.md`, updated in the same PR.
