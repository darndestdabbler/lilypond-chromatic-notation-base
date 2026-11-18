# Change log — 002-callback-chaining-fix

## Session 1 (2026-07-04) — Chain `after-line-breaking` callbacks instead of overwriting them

**Orchestrator:** claude-code / anthropic (lightweight tier, no metered calls)

### Confirmation pass (Step 1)

- Confirmed the five direct `ly:grob-set-property! ... 'after-line-breaking`
  overwrites the spec lists: `cnb/off-key.ly:280` (procedure model, NoteHead)
  and `:304` (vector model, NoteHead); `cnb/test-ids.ly:494` (Beam), `:519`
  (Tie), `:523` (Slur).
- **Spec nuance found:** `test-ids.ly` does NOT hook NoteHead
  `after-line-breaking` — its NoteHead tagging happens at acknowledger time
  via `output-attributes` (`cnb:test-id-notehead`). So the NoteHead
  "collision" was latent, not active: no current test-ids hook was being
  clobbered by off-key on NoteHead, but every one of the five sites would
  silently clobber (or be clobbered by) any other module's hook. The fix
  (chaining at all five sites) closes the issue as specified either way.
- Ordering constraint check (per spec step 2): off-key's callbacks mutate
  `'stencil`; test-ids' spanner callbacks set `'output-attributes`. The
  properties are independent, so no ordering invariant exists between the
  modules; existing-first (registration order) was chosen as the least
  surprising rule.

### Changes (Steps 2–4)

- `cnb/utils.ly`: new "GROB CALLBACK CHAINING" section with two helpers:
  - `cnb:compose-after-line-breaking` — pure composer: returns the new
    callback unchanged when there is no existing procedure, otherwise a
    procedure that calls existing-then-new. Unit-testable without a grob.
  - `cnb:chain-after-line-breaking!` — grob-level installer. Reads the
    current value with `ly:grob-property-data` (NOT `ly:grob-property`,
    which would evaluate — i.e. prematurely fire — an existing callback on
    access), composes, and sets.
- `cnb/off-key.ly`: both NoteHead call sites now register through
  `cnb:chain-after-line-breaking!`; header comment updated.
- `cnb/test-ids.ly`: Beam/Tie/Slur call sites now register through
  `cnb:chain-after-line-breaking!`; KNOWN LIMITATIONS #1 marked resolved
  and #4 updated.
- `test-unit.ly`: 5 new assertions for the pure composer (unset/'()/#f
  pass-through identity, two-callback ordering, three-deep chain ordering,
  grob argument propagation).
- `tests/off-key-coexistence.{ly,json}` (+ committed `.svg` /
  `.harvested.json` per repo convention): vector-model regression test.
  Both modules active; asserts the off-key F#4 NoteHead carries BOTH
  effects (test-id tag present AND bbox ~1.35× taller from the dot
  stencil), in-key noteheads unmarked, and that the Beam/Tie/Slur chained
  hooks all fired (measure 2 has a beam, slur, and tie).
- `tests/off-key-coexistence-procedure.{ly,json}` (+ artifacts):
  procedure-model companion — `cnb:use-procedure-model = #t` with a
  key-aware config assigning `off-key-mark 'dot` outside the key, so the
  procedure-model chaining site executes at runtime too. Same
  both-effects-on-one-NoteHead assertions.

### Verification (Step 5)

- Unit suite (`lilypond test-unit.ly`): **179 passed, 0 failed**
  (174 baseline + 5 new). The spec's "163 assertions" count was already
  stale when set 001 ran; 174 was the pre-session baseline.
- Integration suite: **83 passed, 0 failed** (72 baseline + 11 new across
  the two new specs). Baseline before edits was 72 passed, 0 failed —
  no regressions.
- Smoke: root `joy-to-the-world.ly` (Kite procedure-model config +
  test-ids) renders successfully with the chained hooks.

### Pre-existing issues observed (not fixed — out of scope)

- `tests/joy-to-the-world.ly` fails to render: `Unbound variable: cnb:rose`
  at line 7 (a color name no longer defined). The suite SKIPs it (0
  assertions counted) — this predates this set and explains why "72/72"
  was the recorded baseline.
- `tools/run_tests.py` with no arguments globs `tests/*.json` and chokes on
  the `*.harvested.json` outputs it writes itself
  (`TypeError ... input_file ... NoneType`). Run with explicit spec paths.
  Also, its box-drawing banner crashes on Windows cp1252 consoles — run
  with `PYTHONUTF8=1`.
- Tie IDs harvest as `ti-?-0.000-0-0`: `cnb:spanner-left-note-attrs` looks
  up `'note-heads` on the spanner's left bound, but a Tie's bound IS a
  NoteHead (not a NoteColumn), so the lookup always falls through to the
  "?" fallback. The chained tie hook itself fires (a tagged tie element is
  emitted; the regression test asserts it by `count('tie')`).
- `tests/c-major-scale.harvested.json` (tracked) predates the harvester's
  `num_systems`/`systems` fields — regenerating it produces schema-drift
  noise. Restored to HEAD rather than committed here.
- `README.md`, `cnb/articulations.ly`, and `test-unit.pdf` carry
  uncommitted working-tree changes belonging to set
  `003-docs-attribution-pass` (and a stale pdf regen); deliberately left
  out of this session's commits, same as set 001 did.

### Progress keys

- `session-001/chaining-helper-added` — done
- `session-001/collision-fixed` — done
- `session-001/regression-test-passing` — done

### Notes for later sets

- Known Issue #1 can be closed: all five `after-line-breaking` overwrites
  now chain, and both engraver models are regression-tested against
  test-ids coexistence.
- Candidate follow-ups: fix `tests/joy-to-the-world.ly`'s `cnb:rose`
  reference (would un-skip that spec), make `run_tests.py` ignore
  `*.harvested.json` when globbing, and resolve Tie left-bound attrs in
  `cnb:spanner-left-note-attrs` so ties get real IDs.
