# Configurator handoff — sized sharps and flats, and the magnification a config sets (session 35)

**From:** `lilypond-chromatic-notation-base`, session 35 ("Sized sharps
and flats, and the magnification a config sets").
**To:** `chromatic-notation-configurator`. Its session 52 sizes a
traditional signature's sharps and flats in semitones and needs the
engine to draw a sign at a given scale. Its session 51 round trips found
the magnification problem this session also fixes.
**Date:** 2026-11-11. **Release:** ships in engine 1.5.0, released by
session 36.

> **Cross-repo rule of engagement (unchanged since set 005):** export-spec
> changes are authored **Configurator-side** from this record. This
> session does not touch the Configurator's LY export spec. This file is
> the engine-contract source of truth for that work.

---

## 1. What changed

### 1a. A sign mark takes a scale

In `cnb:keysig-marks`, a sharp or flat mark takes an optional fourth
element, a positive number:

```lilypond
(semi column sharp [scale])
(semi column flat  [scale])
```

| The fourth element | The sign drawn |
|---|---|
| absent | Emmentaler's glyph at the staff's size, as in 1.4.1 |
| `1` | the same, byte for byte |
| a positive number `s` | the glyph scaled by `s` on both axes, about its origin |
| anything else (`0`, `-1`, a symbol, …) | unscaled, with a warning naming the key, the mark and the value |

- **About the origin:** the sharp's origin is its centre line and the
  flat's is its bowl line, so that line stays at the semitone's height.
  Only the parts above and below it shrink or grow.
- **Then centred:** the scaled glyph's X extent is centred on its column,
  as before. The columns are the Configurator's to lay out for the
  scaled widths.
- **The scale is relative to the glyph at the staff's size**, that is,
  after the staff's magnification (see 1b). A sharp is 3 staff spaces
  tall unscaled. On the default 4-8 staff, at 4 semitones a staff space,
  that is 12 semitones, so a sharp sized to `k` semitones between its
  bars takes the scale the Configurator computes from that.

**What did not change:** heads and bars (no scale), the signs' glyphs,
their column centring, their layer (on top), and that signs draw no
ledger lines; `'chord` and `'none`. A sign's semitone is placed as
before, through the pitch-axis hook when it is set.

### 1b. A plain score engraves at `cnb:default-magnify` as the config sets it

`cnb/score-defaults.ly` gave every Staff `\magnifyStaff
#cnb:default-magnify` in a `\layout` block. That argument was evaluated
when the engine was included, before an exported config `set!`s the
variable after its `\include`. So a plain score engraved every staff at
7/4, whatever the config said, and only a staff that magnified itself
with `\magnifyStaff #cnb:default-magnify` got the config's value.

Now the Staff context's `\applyContext` builds `\magnifyStaff` from
`cnb:default-magnify` as it stands **when each staff is created**, and
applies it to that staff. A config included after the engine that
`set!`s the variable takes effect, for every glyph, the signs' optical
size among them.

**What did not change:**

- A staff's own `\magnifyStaff`, in its `\with` block or its music,
  still wins.
- `\magnifyStaff` is still idempotent (it records its factor in
  `magnifyStaffValue`). A staff that also magnifies itself with
  `#cnb:default-magnify` is not magnified twice.
- `#(define cnb:score-defaults #f)` before the include still opts out of
  the magnification and the indents.
- `cnb:default-magnify` still defaults to 7/4, and the indents are
  unchanged.

## 2. Worked case: sized signs on the default 4-8 staff

`tests/keysig-marks-scaled`: 4 semitones a staff space, lines at
`-4 -2 2 4`, `'marks`, no bars, every sign at scale 0.6473. The columns
are laid out for the scaled widths, each column the scaled sign's width
wide: Emmentaler's sharp 1.1 and flat 0.92 staff spaces, times 0.6473,
are 0.712 and 0.5955.

```lilypond
#(define cnb:keysig-marks
   '((((1 . 0) . (1 2 4 6 7 9 11))                 ; D major
      . ((columns 0.356 1.068)
         (bars)
         (marks (18 0 sharp 0.6473) (13 1 sharp 0.6473))))
     (((6 . -1/2) . (0 2 3 5 7 9 10))              ; B flat major
      . ((columns 0.29775 0.89325)
         (bars)
         (marks (10 0 flat 0.6473) (15 1 flat 0.6473))))))
```

**Measured** on LilyPond 2.24 and 2.26 alike, to 0.001 staff spaces, by
the harvest's control-point hulls. "Unscaled" is the same file with the
fourth elements removed and the columns laid out for 1.1 and 0.92:

| Signature | Unscaled: width × height | Scale 0.6473: width × height |
|---|---|---|
| D major, F♯ 18 and C♯ 13 | 2.052 × 4.25 | 1.328 × 3.192 |
| B♭ major, B♭ 10 and E♭ 15 | 1.78 × 3.73 | 1.152 × 2.855 |

- Each width is 0.6473 of the unscaled one.
- Each height, less the 1.25 staff spaces between its two signs'
  semitones, is 0.6473 of the unscaled: 1.942 of 3.0 for the sharps,
  1.605 of 2.48 for the flats.
- The signs stay at their semitones. The top sharp (18) reaches 1.020
  above its centre (unscaled 1.576), and the bottom sharp (13) 0.922
  below its centre (unscaled 1.424). The top flat (15) reaches 1.204
  above its bowl (unscaled 1.86), and the bottom flat (10) 0.401 below
  its bowl (unscaled 0.62). Each is 0.6473 of the unscaled.

## 3. Worked case: a plain score whose config `set!`s the magnification

`tests/score-defaults-magnify-1` and `tests/score-defaults-magnify-5-2`:
a plain score with no `\magnifyStaff` of its own and the score defaults
on, which includes the engine and then, as an export does:

```lilypond
\include "ChromaticNotationBase.ly"
#(set! cnb:default-magnify 5/2)   % or 1
```

Measured on 2.24 and 2.26 alike, on the engine's default four-space
staff:

| Config's `cnb:default-magnify` | Before (1.4.1): staff height, notehead | After (1.5.0): staff height, notehead |
|---|---|---|
| 1 | 7.0, 1.75 | 4.0, 1.0 |
| 7/4 (the default) | 7.0, 1.75 | 7.0, 1.75 (the SVG is byte-identical) |
| 5/2 | 7.0, 1.75 | 10.0, 2.5 |

A staff with its own `\with { \magnifyStaff #3/2 }` in the 5/2 score
engraves at 3/2 (6.0), and one that adds `\magnifyStaff
#cnb:default-magnify` in its `\with` block and its music engraves at
5/2 (10.0), not 25/4.

## 4. The round trips' `\magnifyStaff #cnb:default-magnify` prefix

**From engine 1.5.0 the Configurator's round trips can drop it.** With
the score defaults on, every staff now engraves at the config's
`cnb:default-magnify`, which the prefix only restated. Keeping it is
harmless, because `\magnifyStaff` is idempotent, but it is no longer
needed. Two cases still need it, or the equivalent:

- a round trip against **engine 1.4.1 or earlier**, where the score
  defaults read the variable when the engine was included;
- a round trip that opts out with `#(define cnb:score-defaults #f)`,
  which applies no magnification at all.

## 5. Compatibility

- **No existing golden changed.** None uses a sign scale, and none
  `set!`s a magnification other than 7/4. Every existing `tests/*.svg`
  and both harvests of every existing spec are byte-identical.
- **A scaled sign needs engine 1.5.0.** Engine 1.4.1 and earlier ignore
  a fourth element and draw the sign at full size.
- **A plain score whose config `set!`s another magnification** now
  engraves at that magnification, where 1.4.1 engraved it at 7/4. That
  is the intended change. A score that magnifies its own staves is
  unaffected.

## 6. Verification

- Unit (`test-unit.ly`, "keysig.ly — cnb:keysig-marks-stencil"): for a
  sharp and for a flat, scale 1 draws as no scale; scale 0.5 is half as
  wide and half as tall, its ends half the glyph's about the semitone,
  and it is still centred on its column; scales `0`, `-1` and a symbol
  warn and draw unscaled. 2.24 and 2.26, 439 assertions passing.
- Integration: `tests/keysig-marks-scaled`,
  `tests/score-defaults-magnify-1` and `tests/score-defaults-magnify-5-2`,
  with the values above, on 2.24 and 2.26. The whole integration suite
  passes on both, 410 assertions, with no harvest drift.

## 7. Next

**Session 36 releases engine 1.5.0**: it packs and publishes what is on
the trunk. The Configurator's session 52 can then export sized signs,
and its round trips can drop their `\magnifyStaff #cnb:default-magnify`
prefix.
