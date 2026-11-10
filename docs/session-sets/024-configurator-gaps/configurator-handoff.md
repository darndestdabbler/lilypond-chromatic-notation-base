# Configurator handoff — clef anchor, clef padding, key-signature octave (session 24)

**From:** `lilypond-chromatic-notation-base`, session 24 ("Clefs and key
signatures engrave where the Configurator draws them").
**To:** `chromatic-notation-configurator` — for its plan item "Export what
engine session 24 adds", against its LY export spec 1.3.8.
**Date:** 2026-11-10. **Release:** the settings ship in engine 1.3.0
(session 26).

> **Cross-repo rule of engagement (unchanged since set 005):** export-spec
> changes are authored **Configurator-side** from this record. This
> session does not touch `docs/CNB-LY-EXPORT-SPEC-v1_2.md`. This file is
> the engine-contract source of truth for that work.

The export spec 1.3.8 records three divergences only the engine could
close (§5.4d, §5.5). Each now has a setting. Every one defaults to the
behaviour before this session, so an export that does not write them
engraves exactly as before.

---

## 1. The new engine contract

| Setting | Type | Default | Units | Closes | Defined |
|---|---|---|---|---|---|
| `cnb:clef-anchor-semitones` | `#f` or number | `#f` | semitone (absolute pitch, a float) | §5.5 "a text clef's height on the staff" | [config.ly:228](../../../cnb/config.ly#L228) |
| `cnb:clef-gutter-left-semitones` | `#f` or number | `#f` | semitones (a length) | §5.5 Gutter, "the left padding has no engine counterpart" | [config.ly:215](../../../cnb/config.ly#L215) |
| `cnb:keysig-tonic-octave 'centred` | new value of an existing setting (`#f`, integer, or `'centred`) | `#f` (unchanged) | — | §5.4d "known divergence, auto placement only" | [config.ly:294](../../../cnb/config.ly#L294) |

All three are score-level Scheme variables, set like every other `cnb:`
setting: `#(set! cnb:… …)` after the `\include`.

### 1.1 `cnb:clef-anchor-semitones` — the text clef's height

- **Semantics.** A number puts a `'text` clef's **top edge** at that
  semitone, by the same path a `'custom` clef's `anchor-semitones` takes
  ([`cnb:clef-anchor-y-offset`](../../../cnb/clefs.ly#L300)): the linear
  notehead formula with `middleCPosition`, or through
  `cnb:get-pitch-staff-position` when the hook is set, a fractional value
  interpolating between its two integer neighbours. The label is first
  sized by `cnb:clef-size-semitones` as before, then built with its top
  edge at y = 0 ([`cnb:clef-text-place`](../../../cnb/clefs.ly#L396)).
- **`#f`** keeps the fixed placement around the staff centre.
- **Ignored** unless `cnb:clef-style` is `'text`. A `'custom` clef keeps
  its definition's own `anchor-semitones`; the `'dozenal` clef is not
  anchored.
- **What to write.** The text clef's `anchorSemi`, converted exactly as
  §5.5 converts a glyph clef's `anchor-semitones`: on a linear staff
  `anchorSemi − staff.midpoint + 12`, under a pitch axis `anchorSemi` as
  it is.
- **Measured** (2026-11-10, identical on 2.24 and 2.26), with a 2-staff-space
  label (a filled path markup, because a string label harvests only as a
  text anchor point):
  - linear default staff, treble, anchor 15.5 → top edge 1.75 staff-spaces
    above the staff centre (expected (15.5 − 12) / 2 = 1.75; measured
    1.754) — `tests/clef-text-anchor.json`;
  - the Twinline hook, anchor 16.5 (between E at position 5 and F at 6)
    → top edge 2.75 staff-spaces above the centre (expected 5.5 / 2;
    measured 2.754; the linear formula would give 2.25) —
    `tests/clef-text-anchor-axis.json`.

### 1.2 `cnb:clef-gutter-left-semitones` — padding before the clef

- **Semantics.** A number N leaves N / `cnb:semitones-per-staff-space`
  staff-spaces of blank space before the clef's ink: the ink moves right,
  and the clef's horizontal extent keeps its left edge
  ([`cnb:clef-apply-gutter`](../../../cnb/clefs.ly#L438)). It is the
  left-hand counterpart of `cnb:clef-gutter-semitones`, in the same units,
  and applies to every rendered style. The engine always divides by
  `cnb:semitones-per-staff-space`, with or without the hook, exactly as it
  does the right gutter; the hook is never consulted for it. Under a pitch
  axis that variable holds the value the exporter writes for it,
  `axisUnitsPerStaffSpace` (§5.4a), so the same `paddingH ÷ pxPerSemi`
  value reads as grid units there too — no separate conversion (§5.5
  "Units under a pitch axis").
- **`#f`** adds nothing.
- **What to write.** The same value as `cnb:clef-gutter-semitones`:
  `clef.gutter.paddingH ÷ display.pxPerSemi`, since the preview pads both
  sides by `paddingH`.
- **Measured** (2026-11-10) — `tests/clef-gutter-left.json`: the 2-wide
  custom rectangle clef with left 3 and right 4 semitones at sps 2, against
  an identical render without either setting:

  | | 2.24 | 2.26 |
  |---|---|---|
  | clef ink starts (control 3.645) | +1.5 | +1.5 |
  | clef ink → key signature (control 0.834 / 0.920) | +1.5 | +2.0 |
  | clef ink → first notehead (control 7.617 / 7.704) | +1.5 | +2.0 |

  **Flag — LilyPond 2.24 absorbs the first 0.5 staff-space after the
  clef.** On 2.24 the key signature sits at least 2.834 after the clef's
  left extent edge, else 0.334 after its right one. In the default layout
  the first rule wins, with 0.5 to spare, so the first 0.5 of extent the
  gutters add (on either side) fills that slack before it moves anything
  after the clef. With the left setting alone, 2.24 leaves 0.5 *less*
  after the ink (the key signature 0.334 after it, the first notehead
  7.117); 2.26 leaves the control's spacing. The right gutter alone
  showed the same 1.5-for-2.0 on 2.24 in set 005 (`tests/clef-custom.json`).
  So with equal padding P staff-spaces on both sides, 2.26 adds exactly P
  after the clef, and 2.24 adds P − 0.5 (for P ≥ 0.25).

### 1.3 `cnb:keysig-tonic-octave 'centred` — the octave per tonic

- **Semantics.** Each key's tonic sits at t = pc + 12k, the octave whose
  span [t, t+12] is centred on the staff's centre semitone M, ties going
  up — the rule of `CNBKeySignature.tonicSemi`,
  k = round((M − 6 − pc) / 12) with half-up rounding
  ([`cnb:keysig-centred-octave`](../../../cnb/keysig.ly#L120)). The
  octave is taken for the tonic's own spelling, so B♯ and C♭ land on the
  Configurator's semitone (B♯ as pc 0, C♭ as pc 11).
- **The centre M** ([`cnb:keysig-centre-semitone`](../../../cnb/keysig.ly#L104)):
  under a pitch axis, the lowest semitone the hook sends nearest staff
  position 0 (searched over −120..120; on a pitch-class map whose midpoint
  shares a position, the lowest of the pair). On a linear staff, the
  middle line's semitone, −2 × `middleCPosition`: 12 under the treble
  clef.
- **An integer and `#f`** behave as before.
- **What to write.** Under a pitch axis, `#(set! cnb:keysig-tonic-octave
  'centred)` in place of §5.4d's computed C-tonic value whenever
  `keys.keySignature.placement.tonicOctave` is not an integer; keep
  writing the integer when it is. The hook §5.4b compiles sends
  `staff.midpoint` to position 0, so the engine's M is `staff.midpoint`
  — unless the midpoint shares its position with the semitone below it
  (the upper member of a shared pair, such as C♯ beside C on the Twinline
  map). Then M is that lower semitone, and the one tonic whose pitch
  class is the midpoint's lands an octave lower than the preview's (the
  rounding steps at pc ≡ M). The hook alone cannot tell the two members
  of a pair apart, so that one tonic stays a known divergence for such a
  midpoint; every other tonic matches.
- **Measured** (2026-11-10, identical on 2.24 and 2.26) —
  `tests/keysig-centred-axis.json`, the Twinline fixture's geometry and
  hook (midpoint 7), twelve keys: every signature's vertical centre within
  0.006 staff-space of the centre of [hook(t), hook(t+12)] for the
  Configurator's t. C..G sit at t = 0..7; G♯, A, A♯ and B at t = −4..−1,
  3.5 staff-spaces below where today's single exported octave (0) puts
  them — the four tonics §5.4d names.

  **Flag — on a linear staff, M is the engine's middle line, not
  `staff.midpoint`.** The engine puts semitone 12 on the middle line under
  the treble clef wherever the preview puts its midpoint (§5.5), so on a
  linear staff `'centred` matches the preview's choice when
  `staff.midpoint` is 12 (the default). This session does not change what
  a linear export writes; for another midpoint an explicit `tonicOctave`
  stays the exact route.

---

## 2. A fix that changes exported scores with key changes

The key-signature stencil cache was keyed on the context property
`keySignature`, which LilyPond 2.24 and 2.26 never set (the key is in
`keyAlterations`). Every key signature after the first in a file therefore
drew the first one's marks: the tracked golden
`tests/stem-attachment-key-change.svg` showed its G-major signature as C
major. The cache now keys on the grob's `alteration-alist` and the
context's `tonic` ([`cnb:get-key-signature-stencil`](../../../cnb/keysig.ly#L369)).
Any export with a key change now engraves each key's own signature, as the
preview draws it; that golden's SVG and both harvests changed accordingly.
No export change is needed.

---

## 3. Verification status

- `engine-integration` and `engine-integration-2.26`: 351 assertions, all
  passing, no harvest drifted other than the corrected
  `stem-attachment-key-change` (§2).
- `engine-unit` and `engine-unit-2.26`: 354 assertions, all passing,
  including the new defaults, `cnb:clef-text-place`,
  `cnb:clef-gutter-left-pad`, the two-sided `cnb:clef-apply-gutter`,
  `cnb:keysig-centre-semitone` and `cnb:keysig-centred-octave` (all twelve
  Twinline tonics, the linear treble default, B♯ and C♭).
