# Accessible color flag — verification & documentation

> **Purpose:** Close out Phase A of the project plan: confirm
> `cnb:use-accessible-colors` is correctly wired end-to-end and document it,
> since the underlying implementation and tests already exist in the
> codebase.
> **Session Set:** `docs/session-sets/001-accessible-color-flag/`
> **Created:** 2026-07-04
> **Workflow:** lightweight
> **Prerequisite:** None

---

## Session Set Configuration

```yaml
tier: lightweight
requiresUAT: false
requiresE2E: false
uatScope: none
uatStyle: ad-hoc
verificationMode: out-of-band-or-none
totalSessions: 1
# prerequisites:
#   - slug: <prerequisite-slug>
#     condition: complete
```

> **Tier:** see the tier model SSoT:
> <https://github.com/darndestdabbler/dabbler-ai-orchestration/blob/master/docs/concepts/tier-model.md>.
>
> Rationale: docs-plus-verification work with no metered-call need; a single
> session is enough since the code-level deliverable is already implemented
> (see Project Overview).

---

## Project Overview

`docs/planning/project-plan.md` Phase A calls for adding
`cnb:use-accessible-colors` support so the Configurator's conditional
color-registration export (spec'd in `docs/CNB-LY-EXPORT-SPEC-v1_2.md`,
"New in v1.2" / §1.1) has something real to bind to.

**Pre-flight check performed when this set was authored (2026-07-04):** the
flag is already defined at `cnb/config.ly:245`
(`#(define cnb:use-accessible-colors #f)`), the guard pattern
`(if (and (defined? 'cnb:use-accessible-colors) cnb:use-accessible-colors) ...)`
matches the export spec's conditional block exactly
(`docs/CNB-LY-EXPORT-SPEC-v1_2.md` lines ~159 and ~401), and both the
default-value and both-branches-render assertions already exist in
`test-unit.ly` (lines ~862-938). All of that is already committed on `main`
(`7de7fed`) — nothing there needs redoing.

The one gap: **`README.md` does not document the flag at all.** This session
set exists to (a) verify the above is still true (in case of drift since
2026-07-04) and (b) close that one documentation gap. Do not re-implement
the flag, re-add tests, or otherwise duplicate work that's already done —
if verification in Step 1 finds it's still all in place, move straight to
the README addition.

**Non-goal:** this set does not touch the legacy vector-cycling model or any
duration/key-aware rule work — those are explicitly deferred per the
project plan §3.

---

## Sessions

### Session 1 of 1: Verify the accessible-colors flag and document it in README

**Goal:** Confirm `cnb:use-accessible-colors` still resolves correctly
against the Configurator's export-spec conditional pattern, then add the
missing README documentation for it.

**Steps:**
1. Re-check that `cnb:use-accessible-colors` is still defined in
   `cnb/config.ly` (default `#f`) and that the guard pattern there still
   matches `docs/CNB-LY-EXPORT-SPEC-v1_2.md`'s conditional color-registration
   block. If it has drifted (e.g. the variable was renamed or the spec
   changed), note the discrepancy and reconcile it — otherwise this step is
   a confirmation, not new work.
2. Re-check `test-unit.ly`'s existing `cnb:use-accessible-colors` assertions
   (default value, `#t`/`#f` branch behavior) still pass via
   `tools/run_tests.py` (or the LilyPond unit-test entry point this repo
   uses). Do not add new tests unless verification in Step 1 surfaced a gap
   the existing tests don't cover.
3. Add a short section to `README.md` documenting: what the flag does, its
   default (`#f`), how to set it (`#(define cnb:use-accessible-colors #t)`
   before the notation `\include`), and a pointer to
   `docs/CNB-LY-EXPORT-SPEC-v1_2.md` for the Configurator-side conditional
   block it pairs with.
4. Run the full test suite once more after the README edit to confirm no
   regressions (docs-only change, but keep the gate consistent with other
   sets).
5. Commit the README change.

**Creates:** none (no new files expected — see Project Overview)
**Touches:** `README.md`
**Ends with:** `README.md` documents `cnb:use-accessible-colors`; existing
`test-unit.ly` assertions for the flag still pass; change committed.
**Progress keys:** `session-001/flag-verified`, `session-001/readme-documented`

---

## End-of-set deliverables

- `README.md` documents `cnb:use-accessible-colors` (purpose, default,
  usage, link to the export spec).
- Confirmation (or reconciliation) that the flag and its tests still match
  the Configurator's export spec.
