# Domain Model: LENS for Android

<!-- matt-skills:domain-model 1 -->
<!-- Ported from lens-desktop's CONTEXT.md; mobile-specific terms are added at the bottom. -->

## Glossary

### ResearchSession
A bounded, stateful investigation triggered by a user query. It tracks research depth, selected analytical perspectives, discovered web sources, decomposed subqueries, live telemetry logs, and the resulting synthesized document.

### Perspective
An analytical lens or expert persona (derived from the Stanford STORM methodology) applied to decompose a complex topic into multidimensional inquiries:
- **Technical & Architectural**: mechanisms, protocols, benchmarks, code implementations, specifications.
- **Market & Commercial**: industry dynamics, leading companies, economic valuation, adoption trends, business models.
- **Critical & Skeptical**: vulnerabilities, limitations, trade-offs, controversies, counter-arguments.
- **Balanced & Comprehensive**: general-purpose cross-sectional investigation combining all facets.

### Subquery
A targeted, search-engine-optimized boolean or semantic query dynamically synthesized by the agent to investigate a specific facet of a perspective.

### Source & Evidence
An external digital document scraped and analyzed by the agent. Each source carries a canonical URL, extracted title, domain authority score (0–100%), relevance snippet, and publication timestamp when available.

### Reflection & Gap Analysis
An intermediate reasoning phase (derived from Open Deep Research) where the agent pauses after initial web exploration to audit its findings, identify unanswered sub-questions or conflicting data points, and formulate targeted second-hop inquiries.

### LivingReport
The final synthesized deliverable formatted in clean, human-readable Markdown. It includes an Executive Summary, structured chapters with in-line academic citations (`[1]`, `[2]`), a comparative analysis matrix, and a verified bibliography.

### ResearchGraph
A directed acyclic graph (DAG) representing the agent's exploration path: Root Query → Perspectives → Subqueries → Visited Sources → Synthesized Sections.

### FollowupCopilot
A grounded conversational agent operating adjacent to the LivingReport that answers user inquiries, drafts comparison tables, and interrogates the research findings strictly against the acquired source evidence.

### AIProvider
An inference provider or model gateway (e.g., Google Gemini, OpenAI, Anthropic, Groq, DeepSeek, Ollama, OpenRouter, Mistral). Each provider declares required authentication keys, base endpoints, and available model families.

### ModelDescriptor
A metadata record characterizing an AI model: its canonical identifier (`id`), user-facing label (`name`), maximum context window length (e.g., `128k`, `1M`, `200k`), capability badges (`Reasoning`, `Speed`, `Vision`, `Local`), and whether it is a local offline model.

### ProviderRegistry
A backend module responsible for maintaining the catalog of known models across all providers, dynamically discovering models from local or remote gateways, and executing live connection tests with latency metrics.

### ConnectionTest
A real-time diagnostic ping validating whether the user's API key or local endpoint is functional before committing to an expensive research run, returning latency in milliseconds and detailed error diagnostics if rejected.

### BM25Index
A zero-native-compilation lexical search engine based on the Okapi BM25 formulation. It features bilingual tokenization, Arabic diacritic stripping, letter normalization, and prefix clitic morphological stemming (`ال`, `وال`, `فال`, `بال`, `لل`), with tuned saturation k1 = 1.2 and document length penalization b = 0.75.

### ReciprocalRankFusion (RRF)
A non-parametric rank fusion algorithm combining dense neural vector rankings and sparse BM25 lexical rankings into a unified score using standard rank smoothing (k = 60).

### ContextualChunk
A structure-aware document segment enriched with hierarchical heading paths (`[Document Title > Section Path] + Clean Content`). The contextual header ensures dense embeddings and BM25 indices capture topical provenance, while the clean content is supplied to LLM synthesis.

### MaximalMarginalRelevance (MMR)
A greedy selection algorithm balancing relevance against novelty (λ = 0.7) to eliminate passage redundancy from the same website or section, incorporating quadratic domain clustering decay penalties (0.75^c).

### EvidenceCoverageAudit
A mathematical audit quantifying subquery coverage, quantitative metric density, analytical perspective breadth, and domain diversity across admitted evidence, driving smart early exit and honest budget exhaustion.

### CitationGroundingContract
A deterministic provenance mechanism assigning immutable 1-based citation indices before synthesis, then verifying and stripping or remapping unmapped citation brackets post-synthesis to guarantee zero hallucinated citations.

### PlanApprovalModal (desktop term; mobile: PlanApprovalSheet)
The human-in-the-loop authorization surface for a versioned ResearchPlan. On desktop it is a React modal; on mobile it is expected to become a bottom-sheet flow with the same capabilities: inline subquery editing, milestone creation/removal, contextual skill toggles, and trajectory freezing.

### SkillRegistry
A 3-tier deterministic discovery registry scanning Workspace skills, User Global skills, and Built-in bundles with strict precedence shadowing. It validates agent-skill packages (frontmatter, allowed tools, name grammar) before activation.

## Mobile-Added Terms

These terms are specific to the Android version and have no desktop equivalent.

### OfflineVault
The on-device encrypted store for sessions, drafts, reports, evidence, and API keys on Android. Replaces the desktop's filesystem/workstation storage with app-private storage so the device works fully offline between research runs.

### ForegroundResearchRun
An Android-foreground execution of a ResearchSession, bound to a persistent user-visible notification. It keeps long research alive under Doze/App Standby, offers pause/resume, and survives transient process death via persisted session checkpoints.

### ConnectionBridge (provisional)
The eventual mechanism by which the Android app reuses the desktop's embedded TypeScript engine — either a ported engine implementation, an on-device runtime (e.g., embedded Node/JS runtime), or a local network bridge to a paired desktop. **Not yet decided; requires an ADR before implementation.**

### MobileDepthMode
The mobile adaptation of research depth (Quick / Balanced / Deep), tuned to battery, data, and attention constraints on a phone: tighter retrieval budgets, notification-friendly progress, and resumable sessions.
