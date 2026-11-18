# End-to-end pipeline verification (release gate)

> ## ✅ UNBLOCKED as of 2026-07-05 — banner removed per this spec's own instruction
>
> The cross-repo prerequisite is satisfied. The
> `chromatic-notation-configurator` repo's modular rewrite has a working
> `.ly` exporter (`cnb/src/cnb-lilypond.js`, its set `003-lilypond-exporter`,
> complete) plus the full UI export path (set `006`), and its shared
> release-gate set `007-end-to-end-pipeline-verification` closed
> **VERIFIED** on 2026-07-05: a Configurator-exported Kite 4-369 config
> rendered `joy-to-the-world` through THIS engine with zero hand patches —
> 74/74 on this repo's golden assertion suite, 0 differing pixels vs. the
> golden baseline at 4×/16× raster, exhaustive element diff clean apart
> from a documented cosmetic `-0.0000`-vs-`0` path-text artifact.
> Consumables for this set live in that repo:
> `cnb/fixtures/kite-4-369-config.json`, `cnb/fixtures/export-kite-4-369.mjs`,
> `cnb/fixtures/joy-to-the-world-configurator.ly`, the full transcript record
> `docs/session-sets/007-end-to-end-pipeline-verification/s2-uat.md`, and the
> engine-facing handoff items in
> `docs/session-sets/007-end-to-end-pipeline-verification/s2-cross-repo-coordination.md`
> (README render-side walkthrough half, stale `tests/joy-to-the-world.ly`,
> `-0` hash normalization, LY spec 1.2.1 sync).

> **Purpose:** The actual release criterion for this engine: prove the full
> three-repo pipeline (Inkscape toolkit → Configurator → this engine)
> produces a correctly rendered score, verified against a golden baseline.
> **Session Set:** `docs/session-sets/004-end-to-end-pipeline-verification/`
> **Created:** 2026-07-04
> **Workflow:** lightweight
> **Prerequisite:** SATISFIED 2026-07-05 — `chromatic-notation-configurator`
> exporter landed (its set 003; Phase 4 / "Session 14" milestone) and its
> set 007 verified the round-trip through this engine end-to-end. Session
> 1's Step 1 pre-flight gate should confirm and record this, then proceed.

---

## Session Set Configuration

```yaml
tier: lightweight
requiresUAT: false
requiresE2E: false
uatScope: none
uatStyle: ad-hoc
verificationMode: out-of-band-or-none
totalSessions: 2
# prerequisites:                # cross-repo blocker — see the banner above;
#   - slug: <prerequisite-slug> # the schema's prerequisites block only
#     condition: complete       # expresses same-repo set dependencies
```

> **Tier:** see the tier model SSoT:
> <https://github.com/darndestdabbler/dabbler-ai-orchestration/blob/master/docs/concepts/tier-model.md>.
>
> Rationale: rendering + diffing against a golden baseline uses the repo's
> existing LilyPond/Python harness — no metered calls needed. Two sessions:
> one to get the exported config rendering and diffed, one to fix
> discrepancies and document the workflow. If Session 1 comes out clean,
> Session 2 collapses to documentation only.

---

## Project Overview

Project plan §1 (release criterion) and §3 Phase D: this engine does not
ship as "done" until the Configurator can generate a working `.ly` config
that renders correctly through this engine end-to-end, verified against a
golden baseline.

The verification vehicle is `joy-to-the-world.ly` (or a similarly-scoped
score), re-rendered through a config newly exported by the Configurator's
rewritten exporter, and compared against the known-good baseline this repo
already has from the existing `Kite-4-369-Notation-Procedure.ly` config.

**Before scheduling Session 1**, check the Configurator repo's
`docs/planning/project-plan.md` for exporter status. When the blocker
clears, **remove the ⛔ banner at the top of this file** and update the
"Prerequisite" line — that edit is the signal that the set is startable.

**Non-goals:** duration-aware/key-aware rules, off-key mark assignment per
rule, `cnb:get-staff-config`, legacy vector-model removal — all explicitly
deferred per project plan §3.

---

## Sessions

### Session 1 of 2: Render the exporter's config and diff against the golden baseline

**Goal:** A config exported by the Configurator's new exporter renders
`joy-to-the-world.ly` through this engine, with a structured diff against
the existing known-good baseline.

**Steps:**
1. **Pre-flight gate (mandatory, before registering the session):** confirm
   in the `chromatic-notation-configurator` repo that its exporter (Phase
   4 / Session 14) has landed and produces real `.ly` output from the
   modular rewrite (not the frozen `legacy/` monolith). If it hasn't, STOP
   — do not run `start_session`; report the blocker to the operator and
   leave this set `not-started`.
2. Export (or obtain from the Configurator repo) a `.ly` config for the
   Kite 4-369 notation via the new exporter, conforming to
   `docs/CNB-LY-EXPORT-SPEC-v1_2.md`.
3. Render `joy-to-the-world.ly` through the newly exported config with this
   engine (`lilypond -dbackend=svg`), then harvest structured JSON via
   `tools/harvest_svg.py`.
4. Diff the harvested output against the existing known-good baseline
   (the repo's current `Kite-4-369-Notation-Procedure.ly` rendering /
   existing integration-test golden JSON) using the `tools/run_tests.py`
   assertion pipeline.
5. Record every discrepancy (or the clean pass) in a findings list in this
   set's folder; commit the exported config, harvested output, and
   findings.

**Creates:** `docs/session-sets/004-end-to-end-pipeline-verification/findings.md`,
the exported test config (path per repo convention at execution time)
**Touches:** `tests/` (possibly new golden/spec JSON), `tools/` only if the
harness needs a small extension to express the diff
**Ends with:** a committed findings list: either "clean pass against
baseline" or an enumerated discrepancy list for Session 2.
**Progress keys:** `session-001/preflight-gate-passed`,
`session-001/exported-config-rendered`, `session-001/baseline-diff-recorded`

---

### Session 2 of 2: Fix discrepancies and document the full pipeline workflow

**Goal:** Discrepancies from Session 1 are resolved (in whichever repo owns
each root cause) and the end-to-end workflow is documented; the release
criterion is met.

**Steps:**
1. Triage Session 1's findings: for each discrepancy, determine whether the
   root cause is in this engine, the Configurator's exporter, or the
   baseline/test spec itself. Fix engine-side issues here; file
   exporter-side issues against the Configurator repo (do not patch around
   them in the engine).
2. Re-run the Session 1 render → harvest → diff loop until the exported
   config's rendering matches the golden baseline (or until every remaining
   difference is understood and accepted as an intentional baseline
   update — document any such acceptance explicitly).
3. Run the full unit suite and the full integration suite to confirm no
   regressions.
4. Document the end-to-end workflow (Inkscape toolkit → Configurator →
   engine, including the accessible-colors flag hand-off) — a new
   `docs/END-TO-END-WORKFLOW.md` or a README section, whichever fits the
   repo's docs conventions at execution time.
5. Commit; note in the change log that the release criterion from
   `docs/planning/project-plan.md` §1 is satisfied.

**Creates:** end-to-end workflow documentation (see Step 4)
**Touches:** `cnb/` modules (only where a discrepancy's root cause lives),
`tests/`, `README.md`
**Ends with:** exported-config rendering verified against the golden
baseline with the full suite green; workflow documented; release criterion
recorded as met.
**Progress keys:** `session-002/discrepancies-resolved`,
`session-002/workflow-documented`, `session-002/release-criterion-met`

---

## End-of-set deliverables

- Verified end-to-end render: Configurator-exported config →
  this engine → output matching the golden baseline.
- Findings record of every discrepancy and its resolution (or clean pass).
- End-to-end pipeline workflow documentation.
- The project's release criterion (plan §1) attested as met.
