# Project Plan — lilypond-chromatic-notation-base (CNB Engine)

> **Created:** 2026-07-04
> **Repo role:** LilyPond/Scheme rendering engine — the third stage of the
> three-repo chromatic-notation pipeline.
> **Tier recommendation:** `lightweight` (small, solo-maintained, no UI;
> `verificationMode: out-of-band-or-none` is enough — escalate to
> `dedicated-sessions` only if a set touches the shared engine-contract
> surface with the Configurator).
> **`requiresUAT` / `requiresE2E`:** `false` / `false` — no UI, and the
> existing `test-unit.ly` + `tools/run_tests.py` harness already is the
> automated verification surface. Re-use it inside each session rather than
> adding a parallel gate.

---

## 1. Vision (condensed from the ecosystem plan)

CNB is a **configurable engine**, not a single notation system: given a
declarative config (produced by the sibling `chromatic-notation-configurator`
repo), it renders chromatic music notation to PDF/SVG/PNG via LilyPond. The
engine is deliberately generic — pitch-class-indexed notehead shape/color/
hollow/attachment/off-key-mark registration, a procedure model
`(semitone, duration, key) → config alist`, accessible-color switching — so
that designing a new notation is "write a config," not "extend the renderer."

**Release criterion (unchanged from the original plan):** this engine does
not ship as "done" until `chromatic-notation-configurator` can generate a
working `.ly` config that renders correctly through this engine end-to-end,
verified against a golden baseline.

**⚠️ Naming/claims caution — read before touching README or docs.** See
[§5](#5-naming-attribution--ip-caution-important) below. The current
`README.md` opening line overclaims what's actually implemented today and
needs a documentation fix as part of this plan, not just a caveat here.

---

## 2. Current state (what works today)

- **17 engine modules** in `cnb/` (utils, colors, config, procedure,
  path-geometry, stencils, noteheads, stems, clefs, ledgers, staff, keysig,
  beams, articulations, dots, off-key, layout) — all functional.
- **Procedure-oriented configuration model**: named definition tables,
  hash-table registration, resolver, config cache. This is the *only*
  configuration model — the legacy vector-cycling model was removed in
  set 007 (see Known Issue #2, now resolved).
- **163 unit-test assertions** in `test-unit.ly`, all passing.
- **Python test pipeline** (`tools/harvest_svg.py`, `tools/run_tests.py`):
  render → harvest SVG to structured JSON → assert. Integration tests
  passing (72/72, C-major scale).
- **One working reference notation**: `Kite-4-369-Notation-Procedure.ly`
  (the legacy vector-model `Kite-4-369-Notation-Clean.ly` was retired in
  set 007) — an original notation system devised
  for this project (not affiliated with any external "Kite" system — see
  §5's naming-collision note), at a specific tuning/config (4-369), plus
  `joy-to-the-world.ly` as the validation test score. This is the *only*
  named system with a real, working config in this repo today — see §5
  before implying otherwise anywhere else.
- Dozenal (base-12) clef symbols, notehead-based key signatures, proximity-
  based ledger visibility, beam/articulation/dot positioning corrections, and
  per-note off-key marks (chosen by the config procedure's `off-key-mark`
  field: `'dot`, `'ring`, `'tick`, or a custom generator) — all implemented.

### Known issues (carried over, still open)

1. **Callback collision**: `test-ids.ly` and `cnb/off-key.ly` both hook
   `after-line-breaking` on `NoteHead` grobs — last-one-wins. Needs callback
   chaining. Unfixed.
2. **Dual model coexistence** — ✅ **RESOLVED (set 007, 2026-07-09).** The
   legacy vector-cycling model has been removed from every engine module; the
   procedure model is now the only configuration model. `cnb:use-procedure-model`
   remains defined as a permanent no-op (default `#t`) so existing Configurator
   exports, which `set!` it, keep working. See
   `docs/session-sets/007-vector-model-removal/`.
3. **Legacy anchor Y-convention change**: the Inkscape toolkit's
   `buildAttachmentPoints` Y-inversion fix means legacy shapes' `.ly` anchor
   values now have inverted Y vs. older exports. More correct, but a
   compatibility note worth keeping visible.

---

## 3. Remaining work → session sets

The phases below are sized to map roughly 1:1 onto session sets. Phase order
matters: A and B are independent and can run in either order or be combined
into one set; D is blocked on the Configurator repo (see §4).

### Phase A — Accessible color flag (engine side)
**Goal:** add `cnb:use-accessible-colors` support so the Configurator's
conditional color-registration export (already spec'd in
`CNB-LY-EXPORT-SPEC-v1_2.md` §New in v5.0) has something to bind to.
- Define `cnb:use-accessible-colors` (default `#f`).
- Verify the conditional registration pattern the Configurator emits
  actually resolves correctly against this variable.
- Add unit tests to `test-unit.ly`.
- Document the flag in `README.md`.
- **Size:** 1 session. **Depends on:** nothing (Configurator emits the
  conditional block regardless; this just makes the variable meaningful).

### Phase B — Fix the `after-line-breaking` callback collision
**Goal:** resolve Known Issue #1 with callback chaining so `test-ids.ly` and
`off-key.ly` can both hook `NoteHead` grobs without one clobbering the other.
- Implement callback chaining (wrap, don't replace, the existing hook).
- Add a regression test that exercises both hooks together.
- **Size:** 1 session, can bundle with Phase A if small enough in practice.
- **Depends on:** nothing.

### Phase C — Documentation accuracy & attribution pass
**Goal:** fix the overclaim in `README.md` line 8 and tighten the
Acknowledgments section per §5's guidance below. This is a real, scoped
deliverable, not a footnote.
- Rewrite the "CNB is not a single notation system..." claim to distinguish
  *architectural capability* (config-driven, in principle broad) from
  *what's actually implemented* (Kite 4-369 is the only working reference
  config in this repo).
- Revise the Acknowledgments section so it's unambiguous that Paul Morris's
  and Jan Braunstein's credited work is **prior art / inspiration**, not
  something this repo redistributes or claims to reproduce byte-for-byte.
- Add explicit license/attribution lines per §5 (Clairnote SN → CC BY-SA
  4.0 / Paul Morris; Chromatic Lyre Notation → Jan Braunstein, license
  unconfirmed — link out, don't assert terms) and add a one-line
  disambiguation for "Kite" (this project's own original system, no
  relation to the unaffiliated xenharmonic theorist "Kite Giedraitis").
- **Size:** 1 short session (docs-only, no code risk).
- **Depends on:** nothing — do this early, it's cheap and de-risks every
  other repo's docs by setting the pattern to copy.

### Phase D — End-to-end pipeline verification (release gate)
**Goal:** the actual release criterion. Design a notation via the full
pipeline (Inkscape toolkit → Configurator → this engine), export `.ly`,
render a test score, diff against a golden baseline, fix discrepancies,
document the full workflow.
- **Blocked on:** `chromatic-notation-configurator`'s modular rewrite
  reaching a working `.ly` exporter (its own Phase 4/"Session 14" — see that
  repo's project plan). The rewrite currently produces no `.ly` output at
  all outside the frozen `legacy/` monolith.
- Once unblocked: re-render `joy-to-the-world.ly` (or a similarly-scoped
  score) through the newly-exported config and compare against the existing
  known-good baseline this repo already has.
- **Size:** likely 1–2 sessions once the blocker clears; do not schedule
  this set's first session until the Configurator side is ready — starting
  it early just produces a stalled, confusing session set in the Explorer.

### Deferred / explicitly out of scope for "finish line"
Duration-aware and key-aware rules, off-key mark assignment per rule,
`cnb:get-staff-config`. Do not fold these into a session set unless separately
requested — they aren't required for the release criterion. (Full removal of
the legacy vector-cycling model was previously listed here as deferred; it was
completed in set 007, 2026-07-09.)

---

## 4. Cross-repo context

This repo is the **last stage** of a three-repo pipeline:

```
inkscape-music-glyph-toolkit  →  chromatic-notation-configurator  →  lilypond-chromatic-notation-base (this repo)
(SVG shape authoring)             (rule assignment, .ly export)       (rendering)
```

- **`inkscape-music-glyph-toolkit`** — stable, feature-complete for its
  current scope. Its `data-lilypond-notehead`/`data-lilypond-hollow`
  attributes are what this engine's config ultimately traces back to. No
  blocking dependency in either direction right now.
- **`chromatic-notation-configurator`** — the active bottleneck. Mid
  ground-up rewrite (legacy monolith frozen in `legacy/`, new modular code
  in `cnb/`, only through its own "Phase 1 Foundation"). This engine's
  Phase D cannot start until that repo's exporter (its Phase 4 / Session 14)
  lands. Check that repo's `docs/planning/project-plan.md` for current
  status before scheduling Phase D's first session.

---

## 5. Naming, attribution & IP caution (important)

The repo currently name-drops three notation systems in `README.md` and the
shared `docs/CNB-PROJECT-PLAN-20260224.md`: **Kite notation**, **Clairnote
SN** (Paul Morris), and **Chromatic Lyre Notation** (Jan Braunstein). Of
these, only the latter two are external, individually-authored systems —
"Kite" in this project is an **original system the project author devised**,
not a reference to any outside work. Treat these differently:

- **Kite notation (this project's own)** — no external attribution is owed;
  it's original work. **Naming-collision caution, not a copyright issue:**
  there is an unrelated, real "Kite Giedraitis," a xenharmonic/microtonal
  music theorist who publishes notation and tuning work under the name
  "Kite" (Xenharmonic wiki, Kite guitar, Kite's color notation, etc.). The
  two are unaffiliated. Because the name overlaps, docs/searches/AI
  assistants (this one included, in an earlier draft of this file) can
  wrongly conflate the two — worth a short disambiguation note in the
  README ("no relation to Kite Giedraitis's xenharmonic work") so future
  readers, search engines, and AI tools don't make the same mistake.
- **Clairnote SN** — two separate things carry two separate licenses, and
  it's important not to conflate them: the *notation system design and
  clairnote.org site content* are CC BY-SA 4.0 (Attribution-ShareAlike);
  Paul Morris's *separate LilyPond implementation*
  ([`clairnote.ly`](https://github.com/PaulMorris/LilyPond-Clairnote)) is
  licensed **GPL v3** — a different, stronger-copyleft license. Any future
  code (not just presets) that translates or ports pieces of `clairnote.ly`
  would need to satisfy GPL v3, not CC BY-SA.
- **Chromatic Lyre Notation** — Jan Braunstein's system, documented via The
  Music Notation Project (musicnotation.org). His separate LilyPond
  implementation ([`lyrebird.ly`](https://github.com/scaleshift-scores/scaleshift_conversion_scripts/blob/main/chromaticlyre.ly))
  carries **no license header at all** — treat it as "all rights reserved"
  by default. Do not port or translate code from it without asking Jan
  Braunstein directly first.
- **What was actually checked (2026-07-04):** four engine files reference
  Clairnote and/or Chromatic Lyre in their header comments —
  `cnb/articulations.ly`, `cnb/beams.ly`, `cnb/stems.ly`, `cnb/ledgers.ly`.
  Each was compared directly against the real upstream source
  (`clairnote.ly`, `chromaticlyre.ly`). All four are **independent
  implementations** — different variable names, different algorithms
  (e.g. `ledgers.ly`'s "proximity rule" is explicitly a simpler, different
  approach than Clairnote's "recipe system," not a port of it). The only
  shared elements are a general technique largely dictated by the
  underlying math or by LilyPond's own grob-property API (not creative,
  copyrightable expression), plus one bare numeric tuning constant (a
  `1.1` beam-spacing fudge factor). This is a normal, low-risk "learned the
  technique from published prior art, then wrote original code" pattern —
  not evidence of copied/translated code. `articulations.ly`'s header
  originally said "ADAPTED FROM," which overstated the actual relationship;
  it's been reworded to "related prior art (no shared code)" to match what
  the code actually does.
- **Resolved 2026-07-04:** the author confirmed public-domain intent for
  all three repos. Added a `LICENSE` file (CC0 1.0 Universal, verified
  against the canonical text) to each of the three repos, plus a short
  README note in each. This repo's README also now notes that LilyPond's
  own GPL v2+ license doesn't reach this repo's `.ly` files (authoring
  input processed by a GPL tool is the standard non-derivative-work case).
- **Remaining hardening step, still worth doing:**
  1. Consider a short, friendly note to Paul Morris and Jan Braunstein —
     both are active, publicly-reachable people in a small, collegial
     notation-design community — crediting them (already done in
     Acknowledgments) and mentioning their published work informed this
     project. Costs little, forecloses any future ambiguity completely,
     and this kind of outreach is generally well-received in this
     community. This matters more for Braunstein's code specifically,
     since no license terms are on record for it at all.
- **General rule for this repo and its siblings:** it's accurate and fine to
  say "the engine's architecture is flexible enough to *support* notation
  systems with characteristics similar to Kite, Clairnote SN, or Chromatic
  Lyre Notation" — it is **not** accurate to say "CNB produces Clairnote SN
  and Chromatic Lyre notation" when no such config exists in this codebase.
  That's the exact overclaim in the original README opening line (Phase C
  above fixes it — already done as of 2026-07-04).
- None of the above is legal advice — it's a careful reading of the code
  and the licenses, not a formal clearance. If this project moves toward
  public distribution or anything resembling a commercial offering, get an
  actual IP/copyright review, especially before shipping any named-system
  presets or before writing any new code that more closely tracks
  `clairnote.ly` or `lyrebird.ly` than the four files reviewed here do.

---

## 6. Recommended session-set decomposition

| Set slug (suggested) | Phase | Sessions | Tier | Depends on |
|---|---|---|---|---|
| `001-accessible-color-flag` | A | 1 | lightweight | — |
| `002-callback-chaining-fix` | B | 1 | lightweight | — (can merge into 001) |
| `003-docs-attribution-pass` | C | 1 | lightweight | — (do early) |
| `004-end-to-end-pipeline-verification` | D | 1–2 | lightweight | Configurator's exporter (Phase 4/Session 14) |

Sets 001–003 have no dependencies and can be authored and run immediately.
Do not create set 004 until the Configurator repo confirms its exporter is
producing real `.ly` output — check that repo's project plan first.

**Added 2026-07-07 — post-release-criterion backlog sets** (from
`docs/planning/configurator-coordination-backlog.md`; sets 001–004 are all
complete). Note that the vector-model removal, listed as deferred in §3,
is now "separately requested" via the Configurator set-007 handoff and is
scheduled as set 007:

| Set slug | Backlog items | Sessions | Tier | Depends on |
|---|---|---|---|---|
| `005-clef-configurability` | §1.1–1.4 | 3 | lightweight | — |
| `006-keysig-configurability` | §2.1–2.4 | 3 | lightweight | — (after 005 by `NNN` order) |
| `007-vector-model-removal` | §3.1 | 2 | lightweight | — (after 005/006 by `NNN` order) |
