# Change log — 004-end-to-end-pipeline-verification

## Session 1 (2026-07-05) — Render the exporter's config and diff against the golden baseline

**Orchestrator:** claude-code / anthropic (lightweight tier, no metered calls)

- Pre-flight gate passed: Configurator modular-rewrite exporter landed
  (its sets 003/006 complete; shared release-gate set 007 closed VERIFIED
  2026-07-05).
- Generated `kite-4-369-from-configurator.ly` (7665 bytes, zero hand
  edits) via the Configurator's `export-kite-4-369.mjs` fixture from
  `kite-4-369-config.json`.
- Rendered `tests/joy-to-the-world-configurator.ly` (lilypond 2.24.2,
  SVG backend); harvested 195 elements / 19 measures via
  `tools/harvest_svg.py`.
- Diffed against the golden baseline: 74/74 golden assertions passed on
  the exported-config render; element-level diff clean on every dimension
  except `visual.path_hash` on the 21 kite-down noteheads
  (runtime-rotated vs pre-baked path text; geometry verified identical) —
  accepted cosmetic for Session 1.
- Recorded findings (`findings.md` §§1–6) with the Session 2 work list.
- Deliverable commit: `cf378ae`.

## Session 2 (2026-07-05) — Fix discrepancies and document the full pipeline workflow

**Orchestrator:** claude-code / anthropic (lightweight tier, no metered calls)

### Discrepancies resolved — `session-002/discrepancies-resolved`

- **E1:** `tests/joy-to-the-world.ly` and `tests/example-notes.ly`
  migrated off the pre-rename color names (`cnb:rose` → `cnb:1-rose`
  etc.) and onto `Kite-4-369-Notation-Procedure.ly`, matching the
  top-level golden score. The checked-in golden suite compiles and passes
  as checked in again; stale SVG/harvest snapshots regenerated.
- **D3:** `tools/harvest_svg.py` canonicalizes numeric tokens in path
  text before hashing (4-decimal rounding, trailing-zero strip, `-0` →
  `0`). The golden-vs-exported harvest diff is now completely clean:
  191/191 elements, zero differing fields **including `path_hash`** —
  Session 1's accepted-cosmetic caveat is eliminated, not just
  documented.
- **Harness fix:** `tools/run_tests.py` directory discovery excludes
  `*.harvested.json` snapshots (the default all-tests run crashed
  treating them as specs).

### Workflow documented — `session-002/workflow-documented`

- `README.md`: new "End-to-End Walkthrough: Rendering an Exported
  Config" section (the render half: install → exported config → include
  from score → render, with the `cnb:use-accessible-colors`
  define-before-include hand-off → verify against the golden baseline),
  cross-linked to the Configurator README's design half per the 007
  cross-repo handoff. Accessible-colors hand-off smoke-tested live.
- `README.md` housekeeping: status updated to release-criterion-met,
  assertion counts refreshed (179 unit + 231 integration), resolved
  callback-collision issue removed (set 002), accessible colors moved
  from planned to shipped, vector-model removal marked unblocked.
- `docs/CNB-LY-EXPORT-SPEC-v1_2.md` merged to **1.2.1** (always-emitted
  `cnb:use-procedure-model #t`, half-staff-space conversion, changelog
  row) while preserving this repo's `repeat`-field documentation that the
  Configurator's copy lacks (FYI filed back in findings §7.4).

### Release criterion — `session-002/release-criterion-met`

**The release criterion from `docs/planning/project-plan.md` §1 is
satisfied:** the Configurator generates a working `.ly` config that
renders correctly through this engine end-to-end, verified against the
golden baseline — 74/74 golden assertions and hash-identical harvests
with zero accepted differences. Full suites green post-change:
integration 231/231 (317 assertions, 5 specs, no skips), unit 179/179.
