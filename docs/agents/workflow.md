# Workflow: Task Lifecycle, PR Gate, and Flow Routing

Routing per `/ask-matt` (the skills' router): the main flow `idea → /grill-with-docs → /to-spec → /to-tickets → /implement (TDD) → /code-review → PR`. This document **overrides** the default ask-matt close-out: instead of a single `/code-review` before commit, every task ends in a **PR with a mandatory two-subagent gate** before merge.

## The One Rule

**Every completed task ships as a PR.** No direct commits to `main` — ever. `main` receives changes only through merged PRs.

## PR Lifecycle (mandatory, in order)

Every PR goes through this exact sequence. Skipping any step is a workflow violation.

1. **Task completion** → open a PR.
   - Branch: `task/<slug>` (e.g. `task/offline-vault-schema`), cut from `main`.
   - Title convention: `Task: <one-line summary> (#<issue-number>)` — the PR body links the GitHub Issue with `Closes #<n>` (the issue auto-closes on merge, ending the ticket in the tracker).
   - A task may touch multiple files/modules but **one logical change**; if it needs several PRs, split the ticket first via `/to-tickets`.

2. **Review subagent** (as soon as the PR is open).
   - A dedicated subagent whose only job is review + failure report. It **never writes code** — not on this PR, not anywhere.
   - It runs the `/code-review` two-axis review (Standards + Spec) against `main` and additionally audits: error handling, edge cases, security/secret exposure, test coverage of the diff, and bilingual (AR/EN) parity of user-facing strings.
   - It posts a **Failure Report** as a comment on the PR. The report must categorize each finding: `blocker` (must fix before merge), `advisory` (fix-or-waive). The report is the merge gate.

3. **Fix subagent** (once the main agent is informed of the report).
   - The main agent reads the Failure Report and spawns a dedicated fix subagent with one job: resolve the `blocker` findings (and any advisory it accepts) **on the same PR branch** — it pushes fixes as new commits, never force-pushes.
   - The fix subagent must not expand scope beyond the report; anything it discovers that needs more than the current PR goes to a **new ticket** in the tracker.
   - Re-review: fixes are pushed, the **review subagent** re-reviews the fix commits only (a narrow pass, not a full re-review), until no `blocker`s remain.

4. **Merge**.
   - Gate: zero open `blocker`s; every advisory either fixed or explicitly waived by the user.
   - The user (or the user-authorized agent) merges with a regular merge commit on GitHub.
   - `Closes #<n>` ends the linked issue.

5. **Issue closes when the PR merges.** The ticket ends in the GitHub Issue linked to the PR. Reopening the issue afterwards goes through a new task/PR, never by editing the merged branch.

## Where this fits the main flow

- `/implement` runs `/tdd` (red-green slices) per ticket, then **opens the PR** — `/code-review` is executed by the review subagent **on the PR**, not pre-commit in-session.
- `/triage` produces agent-ready issues; each becomes a task → PR per this lifecycle.
- `/wayfinder` decisions produce tickets; each decision ticket also closes via PR (typically docs-only: ADRs, specs).

Even docs-only and bootstrap tasks (like this file) go through the PR lifecycle.

## Roles recap

| Role | Job | Writes code? |
|---|---|---|
| Main agent | Drives the flow; opens PRs; reads reports; spawns subagents | Yes (on task branches) |
| Review subagent | Reviews the PR diff; posts the categorized Failure Report as a PR comment | Never |
| Fix subagent | Fixes the report's blockers on the same branch; no scope expansion | Only what the report demands |
| User | Authorizes merges; waives advisories | — |

## Context hygiene (from ask-matt)

- Keep grilling → spec → tickets in **one unbroken context window**; `/implement` starts fresh per ticket.
- Both subagents are **Phase-boundary "Subagent"** moves: tightly-scoped task, own window, report back to the main agent.
