# Configurator handoff — the repeated noteheads' overlap and the breve's tie (session 39)

**From:** `lilypond-chromatic-notation-base`, session 39 ("The repeated
noteheads' overlap and the breve's tie").
**To:** `chromatic-notation-configurator` — its session 58, whose preview
draws both and writes `cnb:multinote-overlap` in repeat mode, and whose
engine round trip waits on this session.
**Date:** 2026-11-12. **Release:** ships in engine 1.7.0 (session 40).

> **Cross-repo rule of engagement (unchanged since set 005):** export-spec
> changes are authored **Configurator-side** from this record. This
> session does not touch the Configurator's LY export spec. This file is
> the engine-contract source of truth for that work.

One setting is added, `cnb:multinote-overlap`, and the tie of a breve (and
of a longa or maxima) in repeat mode moves. The tie replaces the geometry
in [the session-28 handoff](../028-breve-tie-below/configurator-handoff.md);
the groups and gaps of
[the session-25 handoff](../025-breve-tied-semibreves/configurator-handoff.md)
still hold.

---

## 1. The rules

### The overlap

| | |
|---|---|
| Setting | `#(set! cnb:multinote-overlap 1/3)` after the include, a number, or `#f` |
| Default | `#f`: the copies join at `cnb:multinote-padding` (−0.5 staff spaces), exactly as in 1.6.0 |
| As a number | the share of each head's own X width that the next copy overlaps: each copy starts (1 − overlap) × the head stencil's X width after the last, and `cnb:multinote-padding` is not read |
| At 1/3 | each copy starts 2/3 of a head's width after the last: a minim is 1 + 2/3 head widths, a semibreve 1 + 3 × 2/3 = 3 |
| Shapes | one fraction for every shape; the width is each head's own stencil X extent ([`cnb:build-duration-stencil`](../../../cnb/stencils.ly#L173)) |
| Applies when | the resolved config's `repeat` is not `#f`; a quarter or shorter is one head |

### The tie

| | |
|---|---|
| Applies when | `repeat` is not `#f` and the duration log L ≤ −1 (breve −1, longa −2, maxima −3): 2^(−L) semibreve groups, 1 staff space apart (unchanged) |
| Tie | one for the whole note: `(make-tie-stencil (cons xa y0) (cons xb y0) 0.12 DOWN)`, LilyPond's default height limit 1.0 and ratio 0.33 (unchanged) |
| xa | the centre of the first group's X extent |
| xb | the centre of the last group's X extent: xa + (groups − 1) × (group width + 1) |
| y0 | the bottom of the group stencil's Y extent (the head's bottom), unchanged |

The tie was from the centre of the first head to the centre of the last
head; it now joins the groups' centres, as a tie joins two notes.

**Unchanged:** the repeat counts (minim 2, semibreve 4, breve 2 groups,
longa 4, maxima 8); the 1 staff space between groups, so with the overlap
`#f` every X extent and all spacing; `cnb:multinote-padding` itself; the
tie's thickness, height limit, ratio and colour (still black: it is added
after the head is coloured); the cache key; dots; with `(repeat . #f)` a
breve is one head. A file without the setting engraves its whole notes and
shorter byte-identically; only a breve or longer moves its tie.

**Needs engine 1.7.0.** A file that sets `cnb:multinote-overlap` fails on an
older engine (the variable is unbound there). A file that does not set it
engraves under 1.7.0 as under 1.6.0 except for the breve's tie.

---

## 2. Geometry for the Configurator's default notehead at an overlap of 1/3

The head is the Default 4-8 System export's `crotchet-minim` path, solid,
on its staff of 4 semitones per staff space (as in
`tests/multinote-overlap.ly`).

Measured 2026-11-12 with a probe of `cnb:build-duration-stencil` and
`make-tie-stencil` outside the tree (stencil extents, in staff spaces
before magnification; x = 0 is the first head's centre, y = 0 its centre
line). **Identical on LilyPond 2.24.2 and 2.26.0.** Semitones are staff
spaces × 4.

| Quantity | Staff spaces | Semitones |
|---|---|---|
| One head: X extent | −0.4311 .. 0.4311 (width 0.8622) | width 3.449 |
| One head: Y extent | −0.3406 .. 0.3405 | height 2.724 |
| Step from one copy to the next (2/3 × 0.8622) | 0.5748 | 2.299 |

| Note | X extent | Width | Width in heads | Width in semitones |
|---|---|---|---|---|
| Minim | −0.4311 .. 1.0059 | 1.4370 | 1 + 2/3 | 5.748 |
| Semibreve | −0.4311 .. 2.1555 | 2.5866 | 3 | 10.346 |
| Breve | −0.4311 .. 5.7421 | 6.1732 | 2 × 3 + 1 staff space | 24.693 |

(With the overlap `#f` they are 1.2244, 1.9488 and 4.8976, as in 1.6.0.)

**The breve's tie at 1/3:**

| Quantity | Staff spaces | Semitones |
|---|---|---|
| Start (xa, y0): the first group's centre | (0.8622, −0.3406) | (3.449, −1.362) |
| End (xb, y0): the second group's centre | (4.4488, −0.3406) | (17.795, −1.362) |
| Span | 3.5866 | 14.346 |
| Thickness (argument) | 0.12 | 0.48 |
| Bow height h = (2/π) · atan(π · 0.33 · span / 2) | 0.6860 | 2.744 |
| Lowest point of the outer curve (the middle, y0 − h) | −1.0266 | −4.106 |
| Lowest ink (the tie stencil's Y extent bottom) | −1.0764 | −4.306 |
| Tie stencil: X extent | 0.8122 .. 4.4988 | |
| Tie stencil: Y extent | −1.0764 .. −0.2906 | |

The bow is a closed bézier sandwich filled and outlined with a 0.1 line,
so its ink reaches 0.05 beyond both curves and both end points, as in
session 28.

**The whole breve stencil at 1/3:** X −0.4311 .. 5.7421 (width 6.1732),
Y −1.0764 .. 0.3405 (height 1.4169). The top edge is the head's; the
bottom is the tie's ink.

For the other lengths at 1/3: longa X −0.4311 .. 12.9152, tie
xa 0.8622 → xb 11.6219, Y −1.2776 .. 0.3405; maxima X −0.4311 .. 27.2616,
tie 0.8622 → 25.9683, Y −1.3417 .. 0.3405. With the overlap `#f` the
breve's tie runs 0.5433 → 3.4921 and its stencil's Y extent is
−1.0217 .. 0.3405.

**In the engraving** (`tests/multinote-overlap.json`, passing on 2.24 and
2.26): the harvest measures each path by its control-point hull (a head
0.929 wide), so it reads the half 1.504, the whole 2.653, the breve 6.240
and the longa 13.413 wide, and the breve's lower edge 0.870 staff spaces
below the whole note's (the longa's 1.138). In
`tests/breve-tied-semibreves.json` (overlap `#f`) the breve's lower edge
is now 0.797 below the whole note's and the longa's 1.106 (0.910 and
1.126 before).

---

## 3. Verification status

- `engine-unit` and `engine-unit-2.26`: 499 assertions, all passing,
  including the minim and semibreve widths at the overlap `#f` and 1/3,
  that the padding is not read at 1/3, and the tie's lowest point and
  ends for 2 and 4 groups.
- `engine-integration` and `engine-integration-2.26`: 426 assertions, all
  passing. The new spec `tests/multinote-overlap` engraves 1/3;
  `tests/breve-tied-semibreves` and `tests/duration-rules`, the only specs
  with a breve or longer, are the only goldens regenerated.
- Engine 1.7.0 is released by session 40.
