# Change log — 008-pitch-axis-hook

## Session 2 (2026-07-12/13) — x-offset field + collision semantics (backlog 6.2, 6.5 / E13-2, E13-5)

**Orchestrator:** claude-code / anthropic (lightweight tier, no metered
calls). Session suspended mid-way on 2026-07-12 (WIP commit `c2321d5`)
and completed 2026-07-13; the interim resume notes were folded into
this entry and deleted.

**Goal met:** the procedure-model alist's optional `(x-offset . N)`
field moves noteheads horizontally by N staff spaces — for single notes
(head AND stem move together, spacing accounts for the moved extent)
and for chord members including the diatonic-second shared-position
pair the 013 spike measured being absorbed — and multi-voice collision
semantics on the compact axis are measured and documented. Zero drift
with the field unset: unit 291/291, integration 246/246, goldens
byte-identical, s1 spike-parity re-verified PASS on the final build.

---

### The engine surface landed

- **`cnb/procedure.ly`** — the config alist's optional `x-offset` field
  (staff spaces, positive = right) is documented in the procedure and
  resolver doc blocks; `cnb:resolve-config` passes it through
  normalized: absent → `0`, present non-number → warning + `0` (a
  misconfigured field cannot move a notehead silently).
- **`cnb/noteheads.ly`** — the acknowledger captures
  `x-offset × staff-space` into the new custom grob property
  `cnb-x-offset` at acknowledge time (the key-dependent config cache is
  current there, not at layout time). New X-OFFSET SUPPORT block
  defines `cnb:apply-note-x-offsets` (below) and records the measured
  mechanism story.
- **`cnb/layout.ly`** — `Stem.before-line-breaking` now chains
  `cnb:compensate-stem-length` then `cnb:apply-note-x-offsets`.
- **`test-unit.ly`** — 3 new resolver assertions (present / absent /
  non-number), 288 → 291. **`README.md`** — optional-field paragraph
  (`repeat`, `x-offset`) + refreshed count.

### The 6.2 chord-mechanism decision — what measurement forced

**Both candidate mechanisms named by the 013 record §3.4 fail, plus two
more discovered on the way; the landed mechanism is the fifth.** Every
step below is measured in `s2-evidence/` (renders + transcripts);
LilyPond 2.24.2 sources (`lily/stem.cc`, `lily/note-collision.cc`)
were read to model the failures exactly.

1. **Candidate A — write the mapped value into `staff-position` (013's
   "chord layout in axis space"): insufficient.** With stencil
   translation + the property write, `<gis' a'>` still absorbed the
   offset (separation pinned at 0.357 in offset AND control renders)
   while `<c' cis'>`/`<f' fis'>` honored it. A property dump proved the
   write lands (both members read the same axis value) — the
   arrangement distinguishes the pairs by something else entirely.
2. **Why stencil translation is unreliable for chords (the corrected
   causal model — the 013 record §3.4's "diatonic-derived arrangement"
   reading was mistaken; flag for the Configurator):**
   `Stem::calc_positioning_done` already reads placed GEOMETRY (axis
   space). Its edge-alignment loop translates every head so its
   stem-side edge aligns with the support head's edge — computed from
   stencil EXTENTS, cancelling relative stencil translations — then its
   parity loop shifts reversed heads by their OWN extent (which
   includes a stencil translation). Net: an offset survives or is
   absorbed depending on stem direction and which member gets reversed.
   Exact arithmetic reproduced both measured chords (thickness 0.13:
   0.5 − 1.1×0.13 = 0.357).
3. **Candidate B — the `X-offset` property (013's "post-note-column-
   layout X-offset"): fails everywhere.** Chord members' X-offset
   callbacks are silently DISCARDED (`Grob::translate_axis`, run by the
   arrangement on every head, materializes the offset cache before the
   property is evaluated), and single-note stems do not follow the
   head. Measured: all chord effects 0.000, stem dx 0 vs head dx +0.85.
4. **Wrapping `Stem.positioning-done` (grob-transformer or plain
   lambda) and translating from inside: SEGFAULTS 2.24.2 on multi-voice
   scores.** Mutating grobs while that property is being evaluated is
   not survivable; single-voice scores masked it (the suspend-day
   acceptance run passed single-voice only).
5. **Translating every head of a stem — from any phase: SEGFAULTS
   2.24.2 on multi-voice scores.** Root cause found in the sources:
   `Stem::note_head_positions (…, filter=true)` (stem.cc:263-281) drops
   heads at nonzero relative X (its way of skipping reversed heads) and
   `check_meshing_chords` (note-collision.cc:42-91) indexes the
   surviving vector UNGUARDED — a stem whose only head is moved yields
   an empty vector → out-of-bounds → segfault. Minimal repro: two
   voices, shared axis position, one offset single note. (Upstream
   LilyPond fragility; stock scores never move every head of a stem.)

**Landed mechanism — post-arrangement column + residual translation.**
`cnb:apply-note-x-offsets`, chained on `Stem.before-line-breaking`
(a plain grob hook — mutation happens OUTSIDE property evaluation):
after checking the stem's heads for captured offsets (plain reads; no
early forcing on offset-free scores, so the default pipeline is
untouched), it forces `positioning-done` to completion, then translates
the **NoteColumn** by the COMMON component (the least-displaced head's
offset) and each head by its RESIDUAL:

- single note → pure column translate: head, stem, and flag move as one;
- mixed chord {0, N} → column stays (stem anchored to the unshifted
  member), the offset member moves by N;
- uniform chord {N, N} → pure column translate.

**Crash invariant (do not weaken):** the least-displaced head's
residual is exactly 0, so every stem keeps one head at relative X = 0
and the meshing filter can never empty the position vector.

**`staff-position` write: KEPT, justification corrected.** The hook
path still writes the mapped position into `staff-position` — NOT
because arrangement/collision read it (they read geometry; measured and
source-verified), but so the property never disagrees with the placed
geometry for any direct property reader. s1 spike parity passes with
the write on the final build.

### Acceptance evidence (`session-002/x-offset`)

`s2-evidence/`: `xoffset-cases.ly` (the 013 spike's exact axis + the
+0.85 disambiguation on the sharper members, pcs {1,4,6,9,11}) vs
byte-identical control `xoffset-cases-ctrl.ly` (`xoff:amount 0.0`,
field omitted per the v1.3 §6.3 zero-omission rule); harvested with
`tools/harvest_svg.py`, measured by `measure_xoffset.py` (transcript
with exit 0: `measure_xoffset_transcript.txt`):

- **Singles:** every offset head+stem pair moves +0.850 TOGETHER
  (dx_stem = dx_head to 3 decimals, all 19 single columns incl.
  repeat-mode minims and the semibreve); within-measure spacing
  increments exact (+0.85 offset column / 0.000 non-offset). LilyPond's
  elastic barline spacing redistributes ~0.10 at measure boundaries —
  reported, not asserted (spacing elasticity, not offset loss; the 013
  spike's "exact accumulation" held only within measures here).
- **Chords (offset effect on separation):** `<c' cis'>` +0.851,
  `<gis' a'>` **+0.850** (the 013 absorbed case — THE acceptance),
  `<f' fis'>` +0.850, spanning `<c' g'>` 0.000.
- **Ledgers follow** the moved below-staff heads (each rect dx matches
  its head's dx); **verticals untouched** in every element.

### Collision semantics on the compact axis (`session-002/collision-semantics`)

`s2-evidence/collision-cases.ly` — two voices, cross-voice
simultaneities at axis distances 0/1/2/4/7 plus a shared-pair chord
over a second voice; `measure_collisions.py` transcript with exit 0:
`measure_collisions_transcript.txt`. Findings (6.5 is verify+document;
nothing here needs redesign):

- **The collision machinery operates in AXIS space:** meshing and the
  `cnb:collision-threshold` overrides read placed geometry back as
  ROUNDED staff positions (`Stem::note_head_positions` →
  `get_rounded_position`). Consequence for fractional-position maps:
  collision analysis quantizes to integer positions (flag in handoff).
- **Axis distance 0, equal durations (the shared-position case):**
  LilyPond's merge treatment aligns the two columns (shift 0) and — for
  equal duration + equal dots — wipes NO head (note-collision.cc:
  `wipe_ball` stays null): both pitches render, and the x-offset
  provides the visual separation (measured +0.850 on `cis'/c'` and
  `a'/gis'`). Caveat for the handoff: stock merge logic DOES wipe the
  down-stem head's DOTS in this case (`dot_wipe_head`), so a dotted
  cross-voice shared-position pair loses the down voice's dot.
- **Distances 1–2 (≤ threshold):** stock shift/touch heuristics apply
  in axis space (measured column shifts −1.001 at distance 1, −0.150
  "touch" alignment at distance 2); **x-offsets compose additively**
  with collision shifts (measured −1.850 = 1.0 shift + 0.85 offset).
- **Distances 4, 7 (> threshold):** columns aligned (dx 0.000), no
  collision handling — correct.
- **Chord over a second voice:** works; within-chord separation 1.207 =
  0.357 base + 0.85, identical to the single-voice acceptance.
- 17/17 heads at exact mapped verticals; 16 stems sane.

### Zero-drift verification with the field unset (spec step 5)

- Unit suite **291/291**; integration **246/246** (349 assertions,
  10 specs), re-run after all edits.
- **Golden baseline byte-identical:** `git status -- tests/` clean
  after the suite re-rendered the goldens (both Kite 4-369
  `joy-to-the-world` specs incl. the set-004 round-trip).
  `test-unit.pdf` is timestamp-only churn, committed as prior sets did.
- **s1 spike parity re-verified on the final build:** 35/35 noteheads,
  7/7 ledger rects, all stem directions (transcript regenerated in the
  session scratchpad; measured by the s1 instrument unchanged).

### Honest-record notes

- The suspend-day WIP commit (`c2321d5`) message claims the acceptance
  PASS — true, but only single-voice scores had been exercised; the
  mechanism it shipped (head+stem translation inside a
  `Stem.positioning-done` grob-transformer) segfaults multi-voice
  scores and was replaced this session (mechanism steps 4–5 above).
- A same-day "collision render success" observation was an artifact of
  piping lilypond through `tail` (masking exit 139) plus a stale SVG
  from the interim build; every render in this session's evidence was
  re-produced with exit codes checked directly.

---

## Session 1 (2026-07-10) — The hook (backlog 6.1 / E13-1)

**Orchestrator:** claude-code / anthropic (lightweight tier, no metered calls)

**Goal met:** `cnb:get-pitch-staff-position` exists (default `#f`), the
notehead engraver consults it, and the 013 spike's compact axis renders
through the REAL hook with measured parity to the spike's tables — 35/35
noteheads, 7/7 ledger rects, all stem directions. Zero drift with the hook
unset: unit 288/288, integration 246/246, golden SVGs/harvests
byte-identical in git.

---

### Pre-flight — backlog §6 engine facts re-verified (spec step 1)

**No drift.** Every fact recorded in backlog §6 (from the Configurator's
013 record, 2026-07-10) still holds against the current tree:

- `cnb/noteheads.ly:83-109` — the notehead engraver is the single primary
  site; sets `Y-offset` as a plain number from the linear
  `cnb:semitones-per-staff-space` formula (lines 102–105 pre-change);
  `staff-position` never written.
- Two secondary semitone→vertical sites confirmed:
  `cnb/keysig.ly` (mark placement divides by sps at 224 and 248) and
  `cnb/clefs.ly` (glyph anchoring, 207–261). Untouched this session
  (Session 3 scope).
- `cnb/ledgers.ly` — pure staff-position-space logic
  (`cnb:ledger-positions-function` at 253–258, candidates auto-generated
  from `cnb:staff-line-positions` spacing); no semitone input anywhere.
- `cnb/layout.ly:97-98` — `Stem`/`NoteCollision`
  `note-collision-threshold` from `cnb:collision-threshold` (default 2,
  `cnb/config.ly`). Session 2 scope (6.5).

### The hook landed (`session-001/hook-landed`)

- **`cnb/config.ly`** — new setting `cnb:get-pitch-staff-position`,
  default `#f`, in the staff-geometry section (it shares the
  `cnb:staff-line-positions` unit). Documented with the full unit
  contract from the Configurator's approved design (do not deviate):
  the procedure receives the note's **absolute semitone** (integer,
  middle C = 0, `ly:pitch-semitones`) and returns the LilyPond staff
  position in **half-staff-spaces from the staff center**; the octave
  anchor is **baked into the procedure** (the config's `staff.midpoint`
  lands at position 0), so the result is used as-is and is **not**
  adjusted by `middleCPosition` (precedent:
  `cnb:keysig-tonic-octave`). May be many-to-one and non-uniform.
- **`cnb/noteheads.ly`** — the engraver's `Y-offset` assignment branches:
  when the hook is a procedure, `Y-offset = (hook note-semis) × 0.5 ×
  staff-space` (one staff position = half a staff space); when `#f`, the
  **literal pre-hook formula runs unchanged** (kept verbatim, not
  re-derived). File-header VERTICAL POSITIONING doc extended.
- **`test-unit.ly`** — two new default assertions (defined + `#f`),
  286 → 288. **`README.md`** — new Engine Settings row; unit count
  refreshed.

**Decision — the hook path does NOT write `staff-position` this session
(deferred to Session 2's 6.2 mechanism decision).** Reasoning, recorded
per spec step 3:

1. Writing the mapped value into `NoteHead.staff-position` is precisely
   one of the two candidate mechanisms 6.2 must decide between for
   chord-internal horizontal arrangement (vs post-note-column-layout
   `X-offset`). Committing to it now would preempt that decision without
   the measurements Session 2 is designed to produce (the
   diatonic-second chord acceptance case and the 6.5 collision-semantics
   observation — `staff-position` feeds both chord arrangement AND
   collision logic, so the choice must be made looking at both).
2. Parity comparability: the 013 spike's measured tables — this
   session's acceptance benchmark — were produced with `staff-position`
   untouched. Landing the hook in the same shape makes the parity
   comparison exact; any `staff-position` effects arrive in Session 2
   with their own before/after evidence.
3. The site comment in `cnb/noteheads.ly` states the deferral explicitly
   so Session 2 finds the decision point documented in code.

### Spike parity through the real hook (`session-001/spike-parity`)

Evidence in `s1-evidence/` (this set): `hook-parity.ly` — the 013
spike's exact axis (pc→position `[0,0,1,2,2,3,3,4,5,5,6,6]`, stride 7,
anchor middle C → −4), staff `'(-3 -1 1 4 6 8)`, and note-for-note the
spike's music — but through the REAL hook (`set!` to a procedure; **no
score-level engraver, no post-placement coercion**). The spike's +0.85
x-offset disambiguation is deliberately absent (Session 2 work; vertical
positions are identical between the spike's offset and control renders,
013 record §3.1, so the same tables apply). Rendered
`lilypond -dbackend=svg` with `cnb/test-ids.ly`; harvested with
`tools/harvest_svg.py` (`hook-parity.harvested.json`); measured by
`measure_hook_parity.py` (adapted from 013's `measure_spike.py` +
`extract_ledgers.py`; positions derived from the harvested staff-line
extremes, top = +8, bottom = −3). Full transcript with exit code:
`measure_transcript.txt`. Results vs the 013 record:

- **Noteheads 35/35** at the mapped position, uniform delta +0.010
  (the known line-edge harvest artifact, same value as 013 §3.1) — 0
  mismatches, octave stride and euclidean negative octaves exact.
- **Shared pairs coincide:** all three m7 shared-position chord pairs at
  dpos = 0.000.
- **Ledgers 7/7** with the exact 013 §3.2 multiset {−5: 4, −7: 1, +10: 2};
  in-gap and just-above-staff negative cases correct (no spurious rects).
- **Stems 30/30 present; single-note directions flip at LilyPond
  position 0** (mapped pos ≤ −1 up, ≥ 0 down — f′/f♯′ at −1 up, g′ at 0
  down, exactly 013 §3.3), and the spanning chord `<c' g'>` draws one
  stem spanning −4 → +7 as the record describes.

One measurement-script iteration recorded honestly: the first run
flagged 2 stem-direction "mismatches" (f′/f♯′) — a script bug comparing
the artifact-shifted measured position (−0.99) against the ≤ −1
threshold; fixed to derive the threshold input from the mapped (integer)
position. The render itself was correct on both runs.

### Zero-drift verification with the hook unset (spec step 4a)

- Unit suite **288/288** (`lilypond test-unit.ly`).
- Integration suite **246/246** (349 assertions, 10 specs) via
  `tools/run_tests.py`, re-run after all edits.
- **Golden baseline byte-identical:** the suite re-renders the committed
  golden SVGs/harvests (both Kite 4-369 `joy-to-the-world` specs,
  including the set-004 round-trip `joy-to-the-world-configurator`);
  `git status` shows zero modified files under `tests/` after the run.
  (`test-unit.pdf` is timestamp-only churn, committed as prior sets did.)
