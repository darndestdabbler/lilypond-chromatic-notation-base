# Change log — 008-pitch-axis-hook

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
