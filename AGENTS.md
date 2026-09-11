# AGENTS.md

Operational guidelines, conventions, and context for AI agents working in this repository.

## Repository Overview

**LENS for Android** is the mobile version of **LENS** ("Research, in focus." / "نظرة أعمق. فهم أوضح."), an autonomous research workspace that turns complex questions into clear, source-backed understanding.

- **Sibling project (feature reference)**: [mohmaedeslam00116/lens-desktop](https://github.com/mohmaedeslam00116/lens-desktop) — the Electron desktop application. Read its `PRODUCT.md`, `BRAND.md`, `DESIGN.md`, and `CONTEXT.md` when porting behavior or design.
- **Goal**: full feature parity with the desktop version, adapted to mobile UX — a standalone research app on par with ChatGPT / Perplexity-class assistants.
- **Runtime & stack**: not yet decided. Once the implementation stack is chosen (e.g., native Kotlin + Jetpack Compose, or Flutter), record it here and in `docs/adr/` before writing application code.
- **Domain model**: see `CONTEXT.md` for the glossary shared with the desktop project, plus mobile-specific terms.

## Agent skills

### Skill Router

- **Flow Routing**: Consult `/ask-matt` (`.agents/skills/ask-matt/SKILL.md`) to route work along the standard flow: `idea` → `/grill-with-docs` → `/to-spec` → `/to-tickets` → `/implement` (TDD) → `/code-review` → PR.

### Issue tracker

Issues and specs live as GitHub issues (using the `gh` CLI) in `mohmaedeslam00116/lens-android`. See `docs/agents/issue-tracker.md`.

### Triage labels

Canonical 5-role triage label vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context repository layout (`CONTEXT.md` at root, `docs/adr/` for decisions). See `docs/agents/domain.md`.

## Guidelines

- Keep bilingual parity in mind from day one: every user-facing string exists in Arabic (RTL) and English (LTR). Use the glossary in `CONTEXT.md`; don't invent synonyms.
- Any hard-to-reverse architectural choice (stack, state management, background execution strategy, storage format) gets an ADR in `docs/adr/`.
- The issue tracker is GitHub Issues via `gh`; publish specs and tickets there, not as loose files.
