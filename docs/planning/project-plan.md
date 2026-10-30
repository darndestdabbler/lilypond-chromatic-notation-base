# Project Plan — lilypond-chromatic-notation-base (CNB Engine)

> **Created:** 2026-07-04
> **Amended:** 2026-10-30 — the wrap-up program to 1.0.0 is imported from
> `docs/planning/brief.md` as [§7](#7-wrap-up-program-to-100-2026-10-30);
> §2, §3 and §6 are brought up to date with sets 001–008, all complete.
> **Amended:** 2026-10-30 (session 2) — the cuts are challenged in
> [§7.7](#77-challenge-of-the-cuts-session-2-2026-10-30) before §7 is
> broken into numbered sessions.
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
- **303 unit-test assertions** in `test-unit.ly`, all passing (2026-10-30).
- **Python test pipeline** (`tools/harvest_svg.py`, `tools/run_tests.py`):
  render → harvest SVG to structured JSON → assert. 246 tests / 349
  assertions passing across the `tests/*.json` specs (2026-10-30).
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

### Known issues

1. **Callback collision** — ✅ **RESOLVED (set 002, 2026-07-04).**
   `test-ids.ly` and `cnb/off-key.ly` both hooked `after-line-breaking` on
   `NoteHead` grobs, last-one-wins; the hooks now chain. See
   `docs/session-sets/002-callback-chaining-fix/`.
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

> **Status 2026-10-30:** Phases A–D are complete (sets 001–004), and so are
> the backlog sets 005–008 in §6. The release criterion in §1 is met. The
> phase text below is kept as the record of what was planned; the work
> still to do is the wrap-up program in §7.

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
  *(2026-10-30: no longer the bottleneck — its exporter landed, Phase D
  passed in set 004, and every item in
  `docs/planning/configurator-coordination-backlog.md` is resolved.)*

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

**Status 2026-10-30:** all eight sets, 001–008 (the last being
`008-pitch-axis-hook`), are complete. `docs/session-sets/` stays in place
as read-only history; later work runs as numbered sessions in
`docs/sessions/session-plan.md`, decomposed from §7.

---

## 7. Wrap-up program to 1.0.0 (2026-10-30)

Imported from `docs/planning/brief.md`, the operator-approved wrap-up plan.

### 7.1 Objective

Finish, clean up and document the CNB engine to the level of "reliable for
simple exploration", as the last stage of the three-tool pipeline in §4,
then release it as **1.0.0** and make the repository public under CC0.

**Out of scope:** new engine features, new configuration models, the
deferred items in §3 ("Deferred / explicitly out of scope"), and support
for LilyPond versions other than 2.24.x (E2 only records what a newer
version does).

**Success:** from a fresh clone on a stock Windows console, the unit and
integration suites run green with no environment variables set and leave
the working tree unchanged; the README's figures and status match reality;
a `v1.0.0` tag exists.

### 7.2 Production split

Nothing runs separately in production, and nothing talks to a database:
there is no database. The engine is a library of LilyPond/Scheme source
that a user's score `\include`s; LilyPond runs it on the user's machine.

### 7.3 Handoff artifacts

| Part | Handed over as | Produced by |
|---|---|---|
| The engine (whole repository) | A source archive, `lilypond-chromatic-notation-base-1.0.0.zip` | `git archive --format=zip --output={output}/lilypond-chromatic-notation-base-1.0.0.zip HEAD`, the declared `pack` |
| The release marker | An annotated `v1.0.0` tag pushed to origin | The release session, reading the version from the root `version.json` |

Users may equally clone the repository; the archive and the tag are the
same tree.

### 7.4 Module

**One module: the repository itself.** No cut is made, because nothing in
it is deployed, versioned or reused apart from the rest.

- **Responsibility:** render chromatic music notation from a declarative
  config. `ChromaticNotationBase.ly` loads the engine modules in `cnb/`;
  `tools/` holds the Python 3.8+ test tooling (render → harvest SVG →
  assert); `tests/` holds the scores, assertion specs and golden harvests.
- **Contract in:** LilyPond 2.24.x on `PATH`; a config (normally exported
  by `chromatic-notation-configurator`, per `docs/CNB-LY-EXPORT-SPEC-v1_2.md`)
  that registers its definitions and procedure before the score; a score
  that `\include`s `ChromaticNotationBase.ly` and the config.
- **Contract out:** LilyPond's PDF/SVG/PNG output with noteheads, stems,
  clefs, key signatures, ledgers, beams, articulations, dots and off-key
  marks drawn as the config's procedure resolves them; the golden harvests
  in `tests/` do not drift between releases unless a session says so and
  re-baselines them.
- **How it fails:** a malformed config or an unsupported LilyPond version
  fails at render time with LilyPond's own error output; the engine adds no
  error channel of its own. The test tooling exits non-zero on any failed
  assertion (E1 extends this to the unit suite).
- **Dependency direction:** this engine depends on nothing in the sibling
  repositories at run time; the Configurator depends on this engine's
  export contract, and the Inkscape toolkit feeds the Configurator.
- **Cuts deferred:** none. Splitting `tools/` into its own package was
  considered and not made: it exists only to test this tree.

### 7.5 Phases

**E1 — Test tooling is portable and gates honestly.**
1. In `tools/run_tests.py` and `tools/harvest_svg.py`, reconfigure stdout to
   UTF-8 (or fall back to ASCII) and open files with explicit encodings;
   render with `-dno-point-and-click` (or write rendered SVGs and harvests to
   an ignored output folder) so a run never modifies tracked files; warn
   when LilyPond is not 2.24.x.
2. Add `tools/run_unit.py`: runs `lilypond test-unit.ly` into an ignored
   output folder, parses `TEST RESULTS: N passed, M failed`, and exits
   non-zero on any failure or a missing line. Declare it in `dabbler.yaml`
   as a second suite (`command:` form), and drop `-X utf8` from the
   integration suite's command once step 1 makes it unnecessary.
3. Write `tests/example-notes.json` from the existing harvest, pruned to
   meaningful assertions; delete `tests/TODO.md`; update the README counts
   and status banner.

**E2 — Remove cruft; record LilyPond compatibility.** `Policy: fast`.
1. Delete `tools/old/` and `tools/to-transition-to-python/` (or move them to
   `docs/archive/` with a short note on what the JSX inspector was); stop
   tracking `test-unit.pdf` and ignore it.
2. Mark `configurator-coordination-backlog.md` as closed at the top.
3. Render one score on the newest LilyPond stable and record the result
   (works / fails / untested) in README Requirements. No code change.

**E3 — Guidance and README cleanup.** `Policy: fast`.
1. Replace the placeholder `lessons-learned.md` with real lessons harvested
   from the session-set `change-log.md` files, or delete it together with
   `lessons-archive.md` and `project-guidance.md`; remove v1 `ai_router`
   instructions from whatever is kept.
2. README: status 1.0.0, a "Known limitations" section (LilyPond 2.24.x
   only, tested on Windows, configs are generated by the Configurator,
   clefs/key signatures follow the score), and a "Running the tests"
   section matching the declared suites.
3. Add a root `version.json` reading `{ "version": "1.0.0" }`; the release
   reads its version and tag from it.

**Packaging** — writes the `packaging:` block into `dabbler.yaml` and does
nothing else: a `pack` with no `push`, whose artifact is the source archive
in §7.3. Its check is `dabbler packaging --rehearse`. (`release: tag` is not
usable here: in Dabbler 3.27.0 it validates the orchestration repository's
own manifests and names a `vsix-v*` tag.)

**Release 1.0.0** — `### Session N: Release 1.0.0 (release: 1.0.0)`, no
steps. A major version: this is the first release.

### 7.6 Constraints

- `docs/session-sets/` stays in place as read-only history: the README and
  the Configurator's records link into it (notably
  `008-pitch-axis-hook/configurator-handoff.md`, which the Configurator's
  next session reads).
- Golden baselines (`tests/*.harvested.json`, the `joy-to-the-world` pair)
  must not drift. Any session that changes rendering proves zero drift.
- IP posture per §5: Kite is this project's own system; Clairnote SN and
  Chromatic Lyre Notation are prior art only.

### 7.7 Challenge of the cuts (session 2, 2026-10-30)

**Should the module exist, and as one?** Yes. The repository is the unit
users clone and `\include`, and nothing in it is deployed, versioned or
reused apart from the rest. The one deferred cut — `tools/` as its own
package — stays deferred: `tools/` tests only this tree, ships with it and
has no other consumer.

**Is each contract clause a promise something can prove?**

- *Contract in* (LilyPond 2.24.x, a registered config, an `\include`ing
  score): proved by the engine-integration suite, whose
  `joy-to-the-world-configurator` score renders a Configurator-exported
  config. The 2.24.x precondition is not checked today; E1 adds a warning.
- *Contract out — golden harvests do not drift:* provable only by
  `git diff --exit-code -- tests` after an engine-integration run.
  `tools/run_tests.py` evaluates the assertion specs, then rewrites
  `tests/*.harvested.json` (and `tests/*.svg`) in place; it compares no
  stored baseline. The tracked tree is therefore the drift detector. E1
  takes the brief's first option, rendering with `-dno-point-and-click` in
  place, and not an ignored output folder, which would stop regenerating
  the tracked harvests and so hide drift. The tracked SVGs are re-baselined
  once (their `textedit://` links go); the harvests stay byte-identical,
  since they carry no links (checked 2026-10-30:
  `tests/c-major-scale.svg` has 10, its harvest 0).
- *How it fails:* the integration suite exits non-zero on a failed
  assertion. The unit suite cannot fail — LilyPond exits 0 whatever
  `test-unit.ly` reports — so this clause is unprovable for it until E1's
  `tools/run_unit.py`.

**Does the dependency direction hide the decisions most likely to change?**
Two decisions are likely to change, and both are already explicit. The
LilyPond version is a precondition this engine does not control; E1 warns
when it is not 2.24.x and E2 records what the newest stable does. The
Configurator's export contract is owned by
`docs/CNB-LY-EXPORT-SPEC-v1_2.md` and pinned by the
`joy-to-the-world-configurator` test, so a change there fails a named
test, not a silent render.

**Corrections to §7.5 made while numbering the sessions:**

- `Policy: fast` is not carried into E2 or E3. The release preflight (in
  Dabbler 3.27.0) refuses a release while any session closed since the
  last release lacks a VERIFIED verdict, so a session that skipped
  verification would block Release 1.0.0. Both sessions are small, and
  verifying them costs little.
- E2's cruft list adds the tracked `tools/__pycache__/*.pyc` files: they
  are already ignored by `.gitignore`, and one is for a `normalize_svg.py`
  that no longer exists.
- The skeleton session is E1 (session 3). There is no solution or build
  file to scaffold. What a skeleton contributes here is the suite
  declarations: E1 declares the unit suite, with a hang limit in its own
  command, beside the engine-integration suite.
- The packaging session may name the archive with the router's
  `{version}` placeholder, not the literal `1.0.0`, if
  `dabbler packaging --rehearse` accepts it; otherwise it keeps the
  brief's argv.
