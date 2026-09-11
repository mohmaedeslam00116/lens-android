# LENS — Research, in focus.

**نظرة أعمق. فهم أوضح.**

LENS for Android is the mobile version of [LENS](https://github.com/mohmaedeslam00116/lens-desktop) — an autonomous research workspace that turns complex questions into clear, source-backed understanding. It aims for **full feature parity with the desktop version**, adapted to a mobile, standalone experience on par with ChatGPT, DeepSeek, Gemini, Claude — and especially Perplexity.

## Goal

A standalone Android research app that runs entirely on the user's device, carrying over the desktop's core capabilities:

- **Focused research workspace** — framed question composer with quick, balanced, and deep research modes, and domain focus (All Web / Academic / Community).
- **Streamed reasoning & evidence progress** — live research timeline: subqueries, visited sources, academic citations, and transparent gap reflection.
- **Live discovery feed** — real-time news and trending research topics; one tap turns any headline into a deep investigation.
- **Structured report dossiers** — publication-grade markdown reports with inline citations, comparison tables, diagrams, reading-time metrics, and a table of contents.
- **Multi-provider & local model autonomy** — Gemini, OpenAI, Anthropic Claude, Groq, DeepSeek, OpenRouter, Mistral, and offline Ollama, with dynamic model discovery and connection testing.
- **Bilingual RTL / LTR** — seamless Arabic and English interfaces with direction-aware layouts (Inter & Cairo typography).
- **Export & speech** — PDF / Word / Markdown / CSV export and built-in text-to-speech reading.
- **Human-in-the-loop research plans** — versioned plan blueprints with approval, inline subquery editing, and sub-second cancellation.
- **Citation grounding** — deterministic citation indices with post-synthesis verification: zero hallucinated citations.
- **Agent skills** — discovery, validation, sandboxing, and management of agent skill packages, including the desktop's official launch skills.

Mobile-specific adaptations (offline-first storage, foreground research runs with persistent notifications, battery/data-aware depth modes) are tracked in `CONTEXT.md`.

## Status

🚧 **Planning.** The stack is decided — **Flutter (Dart)** per [ADR-0001](docs/adr/0001-flutter-stack.md) — and the remaining architecture decisions (engine reuse, module structure) are being charted on the [wayfinder map](https://github.com/mohmaedeslam00116/lens-android/issues/1). No application code yet. See `CONTEXT.md` for the domain model and `docs/adr/` for decisions as they land.

## Repository layout

```
lens-android/
├── AGENTS.md            # Operational guidelines for AI agents
├── CONTEXT.md           # Domain model and glossary (ported from desktop + mobile terms)
├── docs/
│   ├── agents/          # Issue tracker, triage labels, and domain doc conventions
│   └── adr/             # Architecture Decision Records
└── lib/                 # the Flutter app module (structure per the wayfinder map)
```

## Related

- **Desktop version**: [mohmaedeslam00116/lens-desktop](https://github.com/mohmaedeslam00116/lens-desktop)

---

Open source and crafted for research and investigative inquiry.

**مفتوح المصدر ومصنوع للبحث والتحقيق.**
