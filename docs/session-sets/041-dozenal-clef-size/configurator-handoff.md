# Configurator handoff — the dozenal clef sized about the middle line (session 41)

**From:** `lilypond-chromatic-notation-base`, session 41 ("The dozenal clef
sized about the middle line").
**To:** `chromatic-notation-configurator` — its session 59, which writes
`cnb:clef-size-semitones` for the dozenal clef at its automatic size, and
whose engine round trip waits on this session.
**Date:** 2026-11-13. **Release:** ships in engine 1.8.0 (session 42).

> **Cross-repo rule of engagement (unchanged since set 005):** export-spec
> changes are authored **Configurator-side** from this record. This
> session does not touch the Configurator's LY export spec. This file is
> the engine-contract source of truth for that work.

No setting is added. `cnb:clef-size-semitones` already set the dozenal
numeral's height; it now also scales the numeral's vertical offsets, so a
sized numeral keeps its place on the staff's middle line. The size itself
is the Configurator's to compute: the engine reads the number it writes.

---

## 1. The rule

| | |
|---|---|
| Setting | `#(set! cnb:clef-size-semitones 8.172)` after the include, a number of semitones, or `#f` |
| Height H | `cnb:clef-size-semitones` / `cnb:semitones-per-staff-space` staff spaces (unchanged, [`cnb:clef-target-height`](../../../cnb/clefs.ly#L184)); `#f` is 3 |
| Offset scale | H / 3, or 1 with `#f` ([`cnb:dozenal-clef-offset-scale`](../../../cnb/clefs.ly#L193)) |
| Left digit | scaled to height H (half width), translated by −0.5 × the offset scale ([`cnb:dozenal-clef-numeral`](../../../cnb/clefs.ly#L374)) |
| Y-offset | −1 × the offset scale staff spaces from the middle line, `'dozenal` style only ([the clef engraver](../../../cnb/clefs.ly#L539)) |
| So | every height of the numeral is scaled by H/3 about the middle line: the treble 50 spans 1.4418 × H/3 above it to −1.5582 × H/3 below it |

The offsets were fixed at −0.5 and −1 staff spaces whatever the height, so a
numeral of another height than 3 staff spaces left its place: a smaller one
hung low, a larger one rode high.

**Unchanged:** with the size `#f`, or at exactly 3 staff spaces (for
example 6 semitones on 2 per staff space, 12 on 4), the numeral engraves
byte-identically; its digits, their relative scales (the left digit at half
width, the right at 2/3 of the height beside it) and so its width rule; the
X-offset; the gutters; the cache key; the `'text` clef (with or without
`cnb:clef-anchor-semitones`) and the `'custom` glyph clef, whose anchor
contract (top edge at the anchor semitone, from its registered top and
height) already sizes it about its anchor.

**Needs engine 1.8.0.** A file that sizes the dozenal clef engraves under
an older engine without error, but its numeral is not on the middle line
there: the offsets stay at −0.5 and −1. A file that does not set the size
engraves under 1.8.0 as under 1.7.0.

---

## 2. The numeral's geometry

Measured 2026-11-13 with a probe of `cnb:dozenal-clef-numeral` outside the
tree, its digits from `interpret-markup` on the default paper (stencil
extents plus the engraver's Y-offset, in staff spaces before magnification;
y = 0 is the staff's middle line, x = 0 the numeral's left edge, which the
engraver's X-offset of 1 staff space places as before). **Identical on
LilyPond 2.24.2 and 2.26.0.** Semitones are on the Configurator's default
staff of 4 semitones per staff space: staff spaces × 4.

The extents follow the left digit: the right digit, 2/3 as tall on the same
baseline, lies within them. A 5 or a 3 (50, 36, 30) reaches a little below
its baseline; a 4 (46, 40) does not.

### At 3 staff spaces (`#f`, or 12 semitones on 4 per staff space)

| Numeral | Top | Bottom | Width |
|---|---|---|---|
| 50, 36, 30 | 1.4418 ss (5.767 st) | −1.5582 ss (−6.233 st) | 2.3859 ss (9.544 st) |
| 46, 40 | 1.5000 ss (6.000 st) | −1.5000 ss (−6.000 st) | 2.4331 ss (9.732 st) |

### At the Configurator's automatic size on its default staff (8.172 semitones, 2.043 staff spaces)

The offset scale is 2.043 / 3 = 0.681.

| Numeral | Top | Bottom | Width |
|---|---|---|---|
| 50, 36, 30 | 0.9819 ss (3.928 st) | −1.0611 ss (−4.245 st) | 1.6248 ss (6.499 st) |
| 46, 40 | 1.0215 ss (4.086 st) | −1.0215 ss (−4.086 st) | 1.6569 ss (6.628 st) |

Each value is the 3-staff-space one × 0.681, and each numeral is 2.043 staff
spaces tall. The unit specs in `test-unit.ly` ("clefs.ly —
cnb:dozenal-clef-numeral") pin the 50's top and bottom at both sizes.

---

## 3. The specs

- `tests/clef-size-dozenal-middle` (new): the dozenal clef at 8.172
  semitones on the staff of 4 semitones per staff space, lines −4 −2 2 4.
  Its harvested clef (two text anchors) is 2.043/3 of the 3-staff-space
  numeral of `tests/c-major-scale` in width (0.7505), in the anchors'
  separation (0.3405) and in the lower anchor's depth below the middle
  line (0.676 staff spaces on 2.24, 0.682 on 2.26, against 0.995 and
  1.001 at 3 staff spaces).
- `tests/clef-size-dozenal` (8 semitones on 2 per staff space, 4 staff
  spaces): its golden and 2.24 and 2.26 harvests changed, its numeral now
  4/3 as far from the middle line (anchor separation 0.5 → 0.667).

---

## 4. Release

Session 42 releases engine 1.8.0. Configurator session 59's engine round
trip of a sized dozenal clef can run against 1.8.0 once it is published.
