# Change log — 007-vector-model-removal

## Session 1 (2026-07-08) — Inventory and migration off the vector path

**Orchestrator:** claude-code / anthropic (lightweight tier, no metered calls)

**Goal met:** zero in-repo consumers of the vector-cycling path remain; the
procedure model is now the default (`cnb:use-procedure-model` default `#t`);
full unit + integration suites green. The vector *code* is still present but
unreferenced — Session 2 removes it.

---

### Pre-flight — true inventory re-verified (`session-001/inventory-recorded`)

Grepped the whole tree (`cnb:use-procedure-model`, every `*-sequence`,
`cnb:build-base-stencils`/`cnb:base-stencil-vector`, `cnb:off-key-indicator`,
`cnb:stem-attachment-*`). The spec's line references from 2026-07-07 still
hold except where noted. **This is the list Session 2 executes against.**

**Engine code that implements the vector path (remove in Session 2 — still
present after this session):**

- `cnb/config.ly`
  - the **flag** `cnb:use-procedure-model` — **KEEP FOREVER** (default flipped
    to `#t` this session, ~line 339). Every Configurator export emits
    `#(set! cnb:use-procedure-model #t)` (LY export spec 1.2.1 §5.1); deleting
    the variable would break every existing export.
  - the seven cycling sequence vectors (remove): `cnb:notehead-color-sequence`
    (line 400), `-shape-sequence` (405), `-hollow-sequence` (414),
    `-rotation-sequence` (426), `-scaling-sequence` (432), `-offset-sequence`
    (438), and `cnb:stem-attachment-sequence` (456).
  - `cnb:off-key-indicator` (the vector-model off-key flag; see `cnb/off-key.ly`
    below). Session 2 must decide whether this is removed with the vector
    off-key branch — if removed, the unit assertion at `test-unit.ly:506` goes
    with it (see below).
- `cnb/stencils.ly` — `cnb:build-base-stencils` (127), the six
  `cnb:notehead-*-modulus` helpers (73–83) and their sequence reads (131–141),
  `cnb:base-stencil-vector` + `cnb:get-base-stencils` (252–257), and the
  `(if cnb:use-procedure-model …)` branches at 354 and 396 (procedure branch
  becomes unconditional). `cnb:build-stencil-from-config` (210) is the
  procedure path that stays.
- `cnb/stems.ly` — `cnb:stem-attachment-modulus` (53) and the vector branch of
  `cnb:stem-attachment` (the `else` at 80–82; the cache-miss fallback at 77–78
  also references the sequence).
- `cnb/off-key.ly` — the vector arms of `cnb-off-key-engraver`: the
  `(memq cnb:off-key-indicator '(dot ring tick custom))` acknowledger arm (242)
  and the non-procedure `else` of the `(if cnb:use-procedure-model …)` at 249,
  plus the header-comment "VECTOR MODEL" block (57–61).
- `cnb/noteheads.ly` — `(if cnb:use-procedure-model …)` at 93 (procedure branch
  becomes unconditional).
- `cnb/layout.ly` — references `cnb:use-procedure-model`; re-verify at removal.
- `cnb/procedure.ly` — header "COEXISTENCE" note (38–42) still describes the
  dual model; doc-only, update in Session 2.

**Consumers of the vector path (migrated/retired THIS session):** see below.
After this session, `grep` finds `cnb:use-procedure-model` /
`cnb:off-key-indicator` / `*-sequence` **only** in engine `cnb/*.ly`, in the
two procedure configs that `set!` the flag to `#t`
(`Kite-4-369-Notation-Procedure.ly`, `kite-4-369-from-configurator.ly`), in the
migrated `tests/off-key-coexistence.ly`, and in the single
`cnb:off-key-indicator` default assertion in `test-unit.ly`.

---

### Default flipped (`session-001/default-flipped`)

`cnb/config.ly` ~line 339: `cnb:use-procedure-model` default `#f` → **`#t`**,
with a keep-forever comment (Configurator exports `set!` it). Per the spec's
"Touches: cnb/config.ly (default flip only)", **no other config.ly change** was
made — the sequence vectors and their values are untouched and are removed in
Session 2.

**Consequence — bare-default notehead size changed (recorded honestly, NOT a
regression to chase this session):** the vector model scaled the default oval
by `(0.75 . 0.75)` (`cnb/stencils.ly:180`); the procedure model applies no
scaling (rotation/scaling are baked into a config's own paths —
`cnb/stencils.ly:194`). So a **bare** `\include "ChromaticNotationBase.ly"`
with no notation config now renders the default oval at full size: notehead
height went from **2.0 → 2.666 semitones** (bbox `1.333` staff-spaces × the
default `cnb:semitones-per-staff-space 2`; the old value was `1.333 × 0.75 =
1.0` staff-space = 2 semitones, which is what README §"Notehead height = 2
semitones" documents).

- **Real configs are unaffected.** Kite / Configurator-exported configs
  register their own correctly-sized paths and never use `default-oval`; the
  set-004 round-trip golden (`tests/joy-to-the-world-configurator.json`) is
  byte-stable and passes.
- **Only the repo's bare-default test fixtures shift** (see regenerated
  artifacts below). Because config.ly is scoped to "default flip only" this
  session, the fix is deferred: **Session 2 open question — after the 0.75
  scaling is deleted with the vector code, either pre-scale the default
  `cnb:notehead-shape-path`/`-hollow-path` to restore the documented 2-semitone
  default, or update the README's "2 semitones" claim.** Flagged here so
  Session 2 decides deliberately.

---

### Consumers migrated / retired (`session-001/consumers-migrated`)

1. **`Kite-4-369-Notation-Clean.ly` — RETIRED (deleted).** It was the pure
   vector-model reference config (defines all cycling sequences, relied on the
   `#f` default). No active consumer: the only references were commented-out
   `%%\include` lines and doc pointers. Its procedure-model equivalent
   `Kite-4-369-Notation-Procedure.ly` already exists (spec's expected outcome).
   Dangling references fixed: `ChromaticNotationBase.ly:33` and
   `docs/planning/project-plan.md:52` now point to the Procedure variant;
   README got a retirement note by the model note.

2. **Dead vector `cnb:notehead-color-sequence` blocks removed** from
   `joy-to-the-world.ly`, `tests/joy-to-the-world.ly`, `tests/example-notes.ly`
   (each was tagged `TODO: REMOVE WHEN VECTOR-MODEL IS OBSOLETE`). These files
   already `\include` the Procedure config (`#t`), so the vector define was dead
   under the procedure model — removal is a rendering no-op (verified: the two
   with JSON specs still pass). The commented-out `Kite-…-Clean.ly` includes
   went with them.

3. **`tests/off-key-coexistence.ly` — MIGRATED to the procedure model.** It set
   `cnb:off-key-indicator 'dot` (the vector-model off-key call site, removed in
   Session 2). Migrated to override `cnb:get-notehead-config` with a key-aware
   `off-key-mark 'dot` rule (the procedure-model call site), keeping its
   richer **measure 2 (beam/slur/tie)** content — the unique callback-chaining
   coverage of test-ids.ly's Beam/Tie/Slur hooks that the procedure twin lacked.
   Its JSON assertions are relative (bbox ratios, structural counts, spanner
   ids) and survive the migration unchanged; only the spec `description` was
   updated (vector → procedure).

4. **`tests/off-key-coexistence-procedure.ly` (+ `.json`) — RETIRED.** With the
   vector test migrated to the procedure model it became a strict **subset**
   (measure 1 only, no beam/slur/tie). Its coverage is now wholly inside the
   migrated `off-key-coexistence` test. Retired to avoid a redundant render.

---

### `test-unit.ly` cycling-vector assertions — none to migrate

Step 3 re-verified: **`test-unit.ly` has zero assertions on the cycling
sequence vectors** (no `*-sequence` / `build-base-stencils` references at all).
The only vector-adjacent unit assertion is `test-unit.ly:506` — "off-key-
indicator defaults to 'none" — which tests the scalar `cnb:off-key-indicator`
flag's default, not a cycling vector. It stays valid this session (the flag
still exists) and is flagged above to retire in Session 2 **if** that flag is
removed with the vector off-key branch. **Assertion count unchanged: 287.**

---

### Re-baselined test (caused by the default-model flip, not a code change)

- **`tests/clef-custom.json`** — the gutter check pins the first notehead's
  absolute x. The 4-semitone gutter's *contribution* is the thing under test
  and is **still exactly +1.5 staff-spaces** (re-measured under the procedure
  default: no-gutter `13.651`, gutter `15.151`; the old vector-default pair was
  `13.262` / `14.762`). Both absolutes shifted up ~0.39 because the procedure
  default notehead is full-size. Updated the pinned value `14.762 → 15.151` and
  the description's no-gutter reference `13.262 → 13.651` with a note.

---

### Verification (lightweight, `out-of-band-or-none`, no metered calls)

- **Unit:** `lilypond test-unit.ly` → **287 passed, 0 failed** (unchanged).
- **Integration:** `python tools/run_tests.py` → **246 passed, 0 failed
  (349 assertions, 10 specs).** Was 250/250 (353 assertions, 11 specs) at set
  006 close; the −4 assertions / −1 spec is exactly the retired
  `off-key-coexistence-procedure.json`, whose coverage moved into the migrated
  test.
- **Golden note (differs from prior sets):** the stored `tests/*.svg` and
  `tests/*.harvested.json` for the **bare-default** fixtures (c-major, clef-*,
  keysig-*, off-key-coexistence) are **regenerated, not byte-identical** — the
  default render legitimately changed with the model flip (see above). The
  **set-004 round-trip golden** (`joy-to-the-world-configurator`) is
  byte-stable and passes, satisfying spec constraint 2.

**Ends with:** zero in-repo vector-path consumers; procedure model is the
default; full suite green; committed. Vector code still present, unreferenced —
Session 2 removes it and resolves the two flagged open questions
(default-oval sizing; `cnb:off-key-indicator` fate).

---

## Session 2 (2026-07-09) — Remove the vector code paths and re-verify

**Orchestrator:** claude-code / anthropic (lightweight tier, no metered calls)

**Goal met:** the vector-cycling implementation is gone from every engine
module; the procedure model is the only model; `cnb:use-procedure-model` is
kept as a permanent no-op; docs and backlog updated; full suites green and the
set-004 round-trip re-verified byte-stable. **This is the final session — set
007 is ready to close.**

---

### Open questions resolved (both flagged by Session 1)

**Q1 — default-oval sizing (`session-002/vector-code-removed`).** Chose to
**pre-scale the default paths**, not to update the README. `cnb:notehead-shape-path`
and `cnb:notehead-hollow-path` are now stored at their final rendered size
(the oval spans ±0.5 in Y = 1.0 staff-space = **2 semitones** at the default
`cnb:semitones-per-staff-space 2`) — i.e. the former vector-model `0.75` build-
time scaling is baked into the coordinates. Rationale: the notation's entire
identity encodes 2 semitones (`cnb:notation-label` "Oval 2-024 Notation",
`cnb:file-suffix` "-Oval-2-024-Notation", the footnote, the README). Changing
docs to 2.666 would contradict the name. This is a pure default-data change:
real configs register their own paths and never use `default-oval`, so the
golden baseline is unaffected. Consequence: the bare-default fixtures render
back at 2 semitones (undoing Session 1's temporary 2.666 state), and
`tests/clef-custom.json`'s absolute first-notehead pin reverts `15.151 → 14.762`
(no-gutter reference `13.651 → 13.262`); the 4-semitone gutter delta under test
stays exactly **+1.5** — re-measured, unchanged.

**Q2 — fate of `cnb:off-key-indicator` (`session-002/vector-code-removed`).**
**Removed** it and `cnb:off-key-flag-stencil` entirely — both are vector-model-
only scalars (the Configurator emits neither; the export spec drives off-key
marking through the per-note `off-key-mark` field, and no procedure config uses
the scalar flag). Accidental suppression in `cnb/layout.ly`, which was the only
non-vector reader of the flag, is now **unconditional** (`\override
Accidental.stencil = ##f`) — correct for a chromatic engine where every pitch
has its own position, and a no-op for the golden (every real config already ran
at the default `'none` = suppressed). The `test-unit.ly:506` assertion on the
flag's default was removed with it (**unit count 287 → 286**).

---

### Vector code removed (`session-002/vector-code-removed`)

Executed against Session 1's recorded inventory:

- **`cnb/config.ly`** — deleted the seven cycling sequence vectors
  (`cnb:notehead-color/-shape/-hollow/-rotation/-scaling/-offset-sequence`,
  `cnb:stem-attachment-sequence`), `cnb:off-key-indicator`, and
  `cnb:off-key-flag-stencil`. Pre-scaled `cnb:notehead-shape-path` /
  `cnb:notehead-hollow-path` (Q1). Rewrote the model-flag comment into a
  KEEP-FOREVER note; `#(define cnb:use-procedure-model #t)` retained.
- **`cnb/stencils.ly`** — deleted the six `cnb:notehead-*-modulus` helpers,
  `cnb:rotate-stencil`, `cnb:build-base-stencils`, `cnb:base-stencil-vector` +
  `cnb:get-base-stencils`. The two `(if cnb:use-procedure-model …)` branches
  (`cnb:get-note-stencil`, `cnb:get-keysig-note-stencil`) are now unconditional
  config-cache reads. `cnb:build-stencil-from-config` (the procedure path) is
  unchanged.
- **`cnb/stems.ly`** — deleted `cnb:stem-attachment-modulus` and the vector
  branch/cache-miss fallback of `cnb:stem-attachment`; the config-cache read is
  unconditional, with a small centered-side literal as the cache-miss fallback.
- **`cnb/off-key.ly`** — deleted `cnb:apply-off-key-flag` and the engraver's
  vector arm (both the `memq cnb:off-key-indicator` acknowledger branch and the
  `keyAlterations`-based detection `else`). The engraver now always collects
  noteheads and reads `off-key-mark` from the cache.
- **`cnb/noteheads.ly`** — `cnb:handle-key-change` is now called
  unconditionally (was guarded by `cnb:use-procedure-model`).
- **`cnb/layout.ly`** — accidental suppression unconditional (Q2).
- **Doc-only header updates:** `cnb/procedure.ly` (dropped the COEXISTENCE
  note), `cnb/colors.ly` (dropped "legacy vector model" aside), and the
  DUAL-MODEL header blocks in `stencils.ly`/`stems.ly`/`off-key.ly`/`noteheads.ly`.

Post-removal grep: `cnb:use-procedure-model` / `-sequence` / `off-key-indicator`
/ `build-base-stencils` appear in engine `cnb/*.ly` only as the kept flag's
definition and as historical "removed in set 007" comments; the two procedure
configs still `set!` the flag; no code reads a vector symbol.

### Docs + backlog updated (`session-002/backlog-updated`)

- **`README.md`** — feature bullet no longer says "replacing the legacy vector-
  cycling model"; removed the `cnb:off-key-indicator` config-table row; rewrote
  the model **Note** to "procedure model is the only model" + the kept-no-op
  explanation; deleted Known Issue #3 (vector coexistence) and the "Vector model
  removal" roadmap bullet; corrected the stale unit-assertion count to 286.
- **`docs/planning/project-plan.md`** — **Known Issue #2 marked ✅ RESOLVED**
  (set 007, 2026-07-09); current-state and deferred-scope paragraphs updated to
  single-model; the "6 off-key indicator modes" line rephrased to the per-note
  `off-key-mark` field. *(This planning file is untracked in this repo — as it
  was through Session 1, which likewise edited it without committing — so the
  edit is applied but not part of the deliverable commit. The authoritative,
  committed resolution record is the backlog §5 entry above.)*
- **`docs/planning/configurator-coordination-backlog.md`** — **§3.1 marked
  resolved**, header table row flagged ✅, and a new **§5 "Vector-model removal"**
  entry records the removal, both honored constraints, the default-oval
  restoration, and — per spec step 5 — that **no Configurator-side action is
  required** (the emitted `#(set! cnb:use-procedure-model #t)` line stays valid).
- **`docs/CNB-LY-EXPORT-SPEC-v1_2.md`** — the §5.1 D1 rationale and the
  Engine-Settings default (`#f → #t`) annotated with the engine-side set-007
  note (always-emit contract unchanged; line now a harmless no-op).
- **`docs/INTEGRATION-TESTING.md`** — the stale off-key/callback limitation note
  (named the removed flag) rewritten around `cnb:chain-after-line-breaking!` and
  the per-note `off-key-mark` field.

---

### Verification (lightweight, `out-of-band-or-none`, no metered calls)

- **Unit:** `lilypond test-unit.ly` → **286 passed, 0 failed** (287 → 286: the
  retired `off-key-indicator` default assertion).
- **Integration:** `python tools/run_tests.py` → **246 passed, 0 failed
  (349 assertions, 10 specs)** — same counts Session 1 left.
- **Spec constraint 2 (golden must not move):** the set-004 round-trip golden
  `tests/joy-to-the-world-configurator` is **byte-stable** — its committed
  `.svg` and `.harvested.json` are unchanged (git-clean) — and passes **74/74
  (101 assertions)** on its own. `tests/joy-to-the-world` (procedure Kite) is
  likewise byte-stable.
- **Regenerated fixtures (expected, from Q1):** the **bare-default** fixtures
  that use `default-oval` — `c-major-scale`, `clef-custom/-none/-size-dozenal/
  -text-size`, `keysig-bar-style/-none`, `off-key-coexistence` — have updated
  `.svg` / `.harvested.json` because the default notehead returned from 2.666 to
  2 semitones. Their JSON assertions are relative and still pass; only
  `clef-custom.json`'s one absolute pin was updated (14.762, see Q1).

**Ends with:** single-model engine; `cnb:use-procedure-model` kept as a
documented no-op; full suites green; set-004 round-trip byte-stable; docs +
backlog + project-plan updated; **set 007 complete.**
