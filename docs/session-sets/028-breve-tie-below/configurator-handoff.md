# Configurator handoff — the breve's tie below the noteheads (session 28)

**From:** `lilypond-chromatic-notation-base`, session 28 ("The breve's tie
below the noteheads").
**To:** `chromatic-notation-configurator` — its session 46, whose preview
draws the same tie and whose engine round trip waits on this session.
**Date:** 2026-11-11. **Release:** ships in engine 1.3.1 (session 29).

> **Cross-repo rule of engagement (unchanged since set 005):** export-spec
> changes are authored **Configurator-side** from this record. This
> session does not touch the Configurator's LY export spec. This file is
> the engine-contract source of truth for that work.

No setting is added and nothing new is exported. Only the tie of a breve
(and of a longa or maxima) in repeat mode moves; it replaces the tie
geometry in section 2 of
[the session-25 handoff](../025-breve-tied-semibreves/configurator-handoff.md),
whose groups, gaps and X extents still hold.

---

## 1. The rule

| | |
|---|---|
| Applies when | the resolved config's `repeat` is not `#f`, and the note's duration log L ≤ −1 (breve −1, longa −2, maxima −3) |
| Groups and gaps | unchanged: 2^(−L) whole-note groups, 1 staff space apart (session 25) |
| Tie | one for the whole note: `(make-tie-stencil (cons xa y0) (cons xb y0) 0.12 DOWN)`, LilyPond's default height limit 1.0 and ratio 0.33 ([`cnb:build-duration-stencil`](../../../cnb/stencils.ly#L170)) |
| xa | the centre of the first head of the first group: the centre of the head stencil's X extent |
| xb | the centre of the last head of the last group: xa + (the composite's right edge − the head's right edge) |
| y0 | the bottom of the group stencil's Y extent (the head's bottom), so the tie bows down below the heads |

The ties that sat in each gap on the head's centre line (y = 0) are gone.

**Unchanged:** the groups, the 1 staff space gaps and so the X extent and
spacing; the cache key; dots; the per-pitch `repeat` field and the
procedure's duration category 0; with `(repeat . #f)` a breve is one head;
whole notes and shorter engrave byte-identically (no golden without a
breve changed).

**The tie is still not coloured.** It is added after the head's colour is
applied, so it draws in LilyPond's default black (or in `NoteHead.color`
where a score overrides it). The preview should draw it black.

---

## 2. Geometry for the Configurator's default notehead

The head is the Default 4-8 System export's `crotchet-minim` path, solid,
on its staff of 4 semitones per staff space, as in session 25
(`tests/breve-tied-semibreves.ly` turns repeat on).

Measured 2026-11-11 with a probe of `cnb:build-duration-stencil` and
`make-tie-stencil` outside the tree (stencil extents, in staff spaces
before magnification; x = 0 is the first head's centre, y = 0 its centre
line). **Identical on LilyPond 2.24.2 and 2.26.0.** Semitones are staff
spaces × 4.

| Quantity | Staff spaces | Semitones |
|---|---|---|
| One head: X extent | −0.4311 .. 0.4311 (width 0.8622) | width 3.449 |
| One head: Y extent | −0.3406 .. 0.3405 | height 2.724 |
| Tie start (xa, y0) | (0.0000, −0.3406) | (0, −1.362) |
| Tie end (xb, y0), n groups | (1.9488n + (n − 1) − 0.8622, −0.3406) | |
| Thickness (argument) | 0.12 | 0.48 |

| Note | Tie end (xb, y0) | Span | Bow height h | Lowest point of the outer curve (middle) | Inner curve at the middle | Lowest ink |
|---|---|---|---|---|---|---|
| Breve | (4.0354, −0.3406) | 4.0354 | 0.7161 | −1.0567 | −0.9667 | −1.1067 |
| Longa | (9.9329, −0.3406) | 9.9329 | 0.8779 | −1.2184 | −1.1284 | −1.2684 |
| Maxima | (21.7281, −0.3406) | 21.7281 | 0.9436 | −1.2842 | −1.1942 | −1.3342 |

The bow height is LilyPond's tie formula, h = (2/π) · atan(π · 0.33 · span
/ 2), approaching the height limit 1.0 as the span grows. The bow is a
closed bézier sandwich: the outer curve's control points are at xa +
span/4 and xa + 3·span/4 (angularity 0.5), y = y0 − (4/3)h (breve −1.2954,
longa −1.5111, maxima −1.5987); the inner curve's 0.12 above them, so at
the middle the curves are 0.09 apart. It is filled and outlined with a 0.1
line, so its ink reaches 0.05 beyond both curves and both end points:
x from −0.05 to xb + 0.05, y from the lowest ink to y0 + 0.05 = −0.2906,
0.19 thick at the middle.

**The whole stencil:**

| Note | Groups | X extent | Width | Y extent |
|---|---|---|---|---|
| Whole (unchanged) | 1 | −0.4311 .. 1.5177 | 1.9488 | −0.3406 .. 0.3405 |
| Breve | 2 | −0.4311 .. 4.4665 | 4.8976 | −1.1067 .. 0.3405 |
| Longa | 4 | −0.4311 .. 10.3640 | 10.7951 | −1.2684 .. 0.3405 |
| Maxima | 8 | −0.4311 .. 22.1592 | 22.5903 | −1.3342 .. 0.3405 |

The X extents are session 25's. The top edge is the head's; the bottom is
the tie's ink.

**In the engraving** (`tests/breve-tied-semibreves.json`, passing on 2.24
and 2.26): the harvest measures each path by its control-point hull, so it
reads the breve's lower edge 0.910 staff spaces below the whole note's and
the longa's 1.126 below (the tie's control points, −1.2954 and −1.5111,
less the head hull's bottom, −0.3853), identical on both versions; the
widths (whole 2.016, breve 4.965, longa 10.862) and the shared top edge
are as in session 25.

---

## 3. Verification status

- `tests/breve-tied-semibreves` and `tests/duration-rules` pass on 2.24
  and 2.26; their SVGs and harvests are the only goldens regenerated, the
  only two with a breve or longer.
- `engine-unit` and `engine-unit-2.26`: 374 assertions, all passing,
  including the composite's width, left edge, top edge and the tie's
  bottom below the head for 2 and 4 groups.
- Engine 1.3.1 is released by session 29.
