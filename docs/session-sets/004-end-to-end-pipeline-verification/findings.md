# Session 1 findings — exported-config render vs. golden baseline

**Session set:** 004-end-to-end-pipeline-verification — Session 1 of 2
**Date:** 2026-07-05
**Verdict:** **Clean pass against baseline** — 74/74 golden assertions, one
accepted cosmetic difference (path-hash text, geometry identical). No
engine or exporter rendering defects found. Session 2 collapses to the
documentation + housekeeping items enumerated below (spec rationale: "If
Session 1 comes out clean, Session 2 collapses to documentation only").

---

## 1. Pre-flight gate (Step 1) — PASSED

The cross-repo blocker is cleared. Confirmed in
`chromatic-notation-configurator` (now at `d:\Projects\chromatic-notation-configurator`;
it moved from `c:\Users\denmi\source\repos\`):

- `cnb/src/cnb-lilypond.js` exists in the modular rewrite (13 modules total).
- Its exporter set `003-lilypond-exporter` and UI export set `006` are
  complete; its shared release-gate set
  `007-end-to-end-pipeline-verification` is `complete` and closed
  **VERIFIED** (2026-07-05).
- The exporter produces real `.ly` output from the rewrite (not the frozen
  `legacy/` monolith) — regenerated live in this session (§2).

## 2. Exported config (Step 2)

Generated fresh from the Configurator fixture — zero hand edits:

```
node d:\Projects\chromatic-notation-configurator\cnb\fixtures\export-kite-4-369.mjs \
     kite-4-369-from-configurator.ly        # 7665 bytes, no validation warnings
```

- Source config: `cnb/fixtures/kite-4-369-config.json` (Kite 4-369,
  CB-safe skyblue/rose/black palette baked in).
- Committed here as `kite-4-369-from-configurator.ly` (repo root, alongside
  the other notation configs). Procedure-model export per LY spec 1.2.x:
  emits `#(set! cnb:use-procedure-model #t)`, Sections A/B/C.
- Music file: `tests/joy-to-the-world-configurator.ly`, copied verbatim from
  the Configurator's `cnb/fixtures/joy-to-the-world-configurator.ly` — same
  music as the golden score, `\include`s the generated config instead of the
  hand-written Kite include.

## 3. Render + harvest (Step 3)

`lilypond -dbackend=svg` (2.24.2) rendered
`tests/joy-to-the-world-configurator.ly` with no errors;
`tools/harvest_svg.py` harvested **195 elements / 19 measures**
(191 unique identified elements) →
`tests/joy-to-the-world-configurator.harvested.json`.

## 4. Diff against golden baseline (Step 4)

### 4a. Assertion pipeline — 74/74 PASS

`tests/joy-to-the-world-configurator.json` is the golden spec
(`tests/joy-to-the-world.json`, 74 assertions / 101 expressions) with only
`test_name` and `input_file` changed:

```
.venv/Scripts/python.exe tools/run_tests.py tests/joy-to-the-world-configurator.json
→ RESULTS: 74 passed, 0 failed (101 assertions)
```

Covers element counts, staff line count, per-note pitch/position for all
four systems, interval geometry (1-semitone ≈ 0.0556, octave ≈ 0.667),
color grouping by pitch class, horizontal ordering, beams, flags, dots, and
cross-system shape identity.

### 4b. Element-level diff vs. checked-in golden harvest

Compared `tests/joy-to-the-world.harvested.json` (golden, checked in)
against the new harvest, per element id:

| Dimension | Result |
|---|---|
| Element ids | 191/191 present in both, none extra |
| `type`, `data.midi`, `visual.color` | identical |
| `staff_relative.vertical/horizontal` | identical (tol 1e-4) |
| `visual.bbox.w/h` | identical (tol 1e-4) |
| Staff geometry | identical |
| Measure boundaries (19) | identical |
| `visual.path_hash` | **21 noteheads differ** — see below |

### 4c. The single difference: path-hash text on kite-down noteheads

The 21 differing elements are exactly the kite-down noteheads (pitch
classes 4/7/11 in this score: E, G, B). Cause, verified in the SVGs:

- **Golden config** implements kite-down as a runtime 180° rotation:
  the SVG carries the kite-up path text
  (`M0 -0.6667L0.6667 -0.3333…`) inside a
  `rotate(-180.0000, cx, cy)` group.
- **Configurator config** pre-bakes the rotated points: no rotate group,
  path text `M0 0.6667L-0.6667 0.3333…`.

Negating the golden local coordinates (the effect of the 180° rotation)
reproduces the Configurator path exactly — **the rendered geometry is
identical**; bbox, position, and color already match (§4b). Only the raw
path text hashed by `harvest_svg.py` differs. This is the same artifact
class the Configurator's set 007 cataloged as **D3** (there observed as
`-0.0000` vs `0` number formatting; here as rotated-vs-pre-baked path
text — both are "hash reflects path text, not geometry").

**Accepted as cosmetic for this set.** Within-render shape-identity
assertions (all D5 share a hash, etc.) pass on both sides; the hash only
diverges when comparing *across* configs that author the same shape
differently.

## 5. Discrepancy list for Session 2

No rendering discrepancies. Items for Session 2, with ownership:

1. **E1 — stale `tests/joy-to-the-world.ly` (engine repo, fix here).**
   The checked-in golden spec `tests/joy-to-the-world.json` resolves
   `input_file` to `tests/joy-to-the-world.ly`, which still uses the old
   vector-model score and fails to compile:
   `tests/joy-to-the-world.ly:7: Unbound variable: cnb:rose` (renamed to
   `cnb:1-rose` etc. in the `cnb/colors.ly` rename). Reproduced this
   session — the golden suite as checked in SKIPs its flagship test.
   Also note: the working tree already carried a stale modified
   `tests/joy-to-the-world.svg` (old green/non-CB-safe palette render)
   predating this set; resolve alongside E1.
2. **D3 — path-hash normalization (engine repo, optional).** Consider
   normalizing hashed path text in `tools/harvest_svg.py` (apply/flatten
   trivial transforms or at least normalize `-0`) so cross-config
   comparisons don't flag geometry-identical shapes. Alternative: document
   the limitation.
3. **README render-side walkthrough (engine repo).** Add the render half
   (install, include an exported config, `lilypond -dbackend=svg`,
   `cnb:use-accessible-colors`, harvest/assert tooling) and cross-link the
   Configurator README's design-side walkthrough.
4. **LY spec sync (engine repo).** Pick up the Configurator's 1.2.1
   amendment to `docs/CNB-LY-EXPORT-SPEC-v1_2.md`
   (`cnb:use-procedure-model #t` always emitted; half-staff-space
   conversion documented).
5. **FYI — vector-model removal unblocked** (this round-trip proves the
   procedure model end-to-end); out of scope for this set per spec
   non-goals, coordinate before removing `cnb:use-procedure-model`.

## 6. Artifacts committed with this session

- `kite-4-369-from-configurator.ly` — the Configurator-exported config
- `tests/joy-to-the-world-configurator.ly` — round-trip music file
- `tests/joy-to-the-world-configurator.json` — spec running the 74 golden
  assertions against the exported config's render
- `tests/joy-to-the-world-configurator.svg` — rendered output
- `tests/joy-to-the-world-configurator.harvested.json` — harvested output
- this `findings.md`

Progress keys logged to `activity-log.json`:
`session-001/preflight-gate-passed`, `session-001/exported-config-rendered`,
`session-001/baseline-diff-recorded`.
