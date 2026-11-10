# Configurator handoff — the breve as tied semibreves (session 25)

**From:** `lilypond-chromatic-notation-base`, session 25 ("The breve as
tied semibreves").
**To:** `chromatic-notation-configurator` — its session 44 ("The breve as
tied semibreves"), whose preview draws the same composite and whose engine
round trip waits on this session.
**Date:** 2026-11-10. **Release:** ships in engine 1.3.0 (session 26).

> **Cross-repo rule of engagement (unchanged since set 005):** export-spec
> changes are authored **Configurator-side** from this record. This
> session does not touch the Configurator's LY export spec. This file is
> the engine-contract source of truth for that work.

No setting is added and nothing new is exported. What a breve (and a longa
or maxima) engraves in repeat mode changes; everything else is as before.

---

## 1. The rule

| | |
|---|---|
| Applies when | the resolved config's `repeat` is not `#f`, and the note's duration log L ≤ −1 (breve −1, longa −2, maxima −3) |
| Groups | 2^(−L): breve 2, longa 4, maxima 8 ([`cnb:semibreve-groups`](../../../cnb/utils.ly#L329)) |
| Each group | the whole note's stencil, unchanged: 4 copies of the head, each overlapping the last by `cnb:multinote-padding` (−0.5 staff-space) |
| Layout | left to right, each group 1 staff space after the previous group's right edge (stencil extents, not ink) |
| Ties | one per gap: `(make-tie-stencil (cons x1 0) (cons x2 0) 0.12 DOWN)`, x1 the left group's right edge, x2 = x1 + 1 the right group's left edge, y = 0 the head's centre line, LilyPond's default height limit 1.0 and ratio 0.33 ([`cnb:build-duration-stencil`](../../../cnb/stencils.ly#L168)) |
| Cache | keyed on (pitch class, duration category, group count), so the longa and maxima are not drawn as the breve ([`cnb:make-cache-key`](../../../cnb/utils.ly#L308)) |

**Unchanged:** the note stays one note (one `NoteHead` grob, no real ties
in the music); the configuration procedure still gets duration category 0
for breve, longa and maxima; dots, note spacing and the per-pitch `repeat`
field behave as before; with `(repeat . #f)` a breve is one head, as
before; whole notes and shorter engrave byte-identically (no golden without
a breve changed).

**Flag — the tie is not coloured.** The tie is added after the head's
colour is applied, so it draws in LilyPond's default black (or in
`NoteHead.color` where a score overrides it), whatever the pitch's colour.
The preview should draw it black to match.

---

## 2. Geometry for the Configurator's default notehead

The head is the Default 4-8 System export's `crotchet-minim` path
(`cnb/fixtures/default-export-baseline.ly` there), solid, on its staff of
4 semitones per staff space. That export writes `(repeat . #f)`, so the
composite appears only when a config turns repeat on;
`tests/breve-tied-semibreves.ly` does so.

Measured 2026-11-10 with a probe of `cnb:build-duration-stencil` (stencil
extents, in staff spaces before magnification; x = 0 is the first head's
centre, y = 0 its centre line). **Identical on LilyPond 2.24.2 and
2.26.0.** Semitones are staff spaces × 4.

| Quantity | Staff spaces | Semitones |
|---|---|---|
| One head: X extent | −0.4311 .. 0.4311 (width 0.8622) | width 3.449 |
| One head: Y extent | −0.3406 .. 0.3405 | height 2.724 |
| Head-to-head step inside a group (0.8622 − 0.5) | 0.3622 | 1.449 |
| One group (the whole note): X extent | −0.4311 .. 1.5177 (width 1.9488) | width 7.795 |
| Gap between groups | 1 | 4 |
| Group-to-group step (1.9488 + 1) | 2.9488 | 11.795 |
| Group k (k = 0, 1, …) X extent | −0.4311 + 2.9488k .. 1.5177 + 2.9488k | |
| Tie k (between groups k and k+1): end points | (1.5177 + 2.9488k, 0) → (2.5177 + 2.9488k, 0) | |
| Tie bow height (to the outer curve, below y = 0) | 0.3046 | 1.218 |
| Tie thickness (argument; the inner curve's control points sit this far inside the outer's) | 0.12 | 0.48 |

The bow height is LilyPond's tie formula for a 1-staff-space span,
h = (2/π) · atan(π · 0.33 · 1 / 2) = 0.3046. The bow is a closed bézier
sandwich: the outer curve's control points are at x1 + 0.25 and x1 + 0.75
(angularity 0.5), y = −(4/3)h; the inner curve's at y = −((4/3)h − 0.12),
so at the middle the outer curve passes y = −0.3046 and the inner
y = −0.2146. It is filled and outlined with a 0.1 line, so its ink reaches
0.05 beyond both curves and both end points: tie k's ink spans
x 1.4677 + 2.9488k .. 2.5677 + 2.9488k, y −0.3545 .. 0.05, and at the
middle y −0.3546 .. −0.1646.

**The whole stencil:**

| Note | Groups | X extent | Width | Y extent |
|---|---|---|---|---|
| Whole (unchanged) | 1 | −0.4311 .. 1.5177 | 1.9488 | −0.3406 .. 0.3405 |
| Breve | 2 | −0.4311 .. 4.4665 | 4.8976 | −0.3545 .. 0.3405 |
| Longa | 4 | −0.4311 .. 10.3640 | 10.7951 | −0.3545 .. 0.3405 |
| Maxima | 8 | −0.4311 .. 22.1592 | 22.5903 | −0.3545 .. 0.3405 |

Width = 1.9488n + (n − 1). The tie's ink dips 0.014 below the head, so the
breve and longer are 0.014 taller at the bottom; the top edge is the
head's.

**In the engraving** (`tests/breve-tied-semibreves.json`, 8 assertions,
passing on 2.24 and 2.26): the harvest measures each head by its path's
control-point hull (0.929 wide, not the 0.8622 LilyPond spaces by), so it
reads the whole note 2.016 wide, the breve 4.965 and the longa 10.862,
heights 0.735 and 0.756, identical on both versions. The spec takes the
hull's excess out once per join and confirms the 1-staff-space gap and the
shared top edge.

---

## 3. Verification status

- `engine-integration` and `engine-integration-2.26`: 359 assertions, all
  passing. The only harvests that changed are `tests/duration-rules`
  (its breve, the one breve among the existing goldens) and the new
  `tests/breve-tied-semibreves`.
- `engine-unit` and `engine-unit-2.26`: 370 assertions, all passing,
  including `cnb:semibreve-groups` for logs −3..2, the group-count cache
  keys, and the composite's width for 2 and 4 groups.
