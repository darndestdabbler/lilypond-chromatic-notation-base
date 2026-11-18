# Configurator handoff — the breve in shape mode, a double notehead or two tied semibreves (session 45)

**From:** `lilypond-chromatic-notation-base`, session 45 ("The breve in
shape mode, a double notehead or two tied semibreves").
**To:** `chromatic-notation-configurator`: its session 76, which draws and
exports `cnb:breve-style` and runs the engine round trip.
**Brief:** the Configurator's `docs/planning/shape-mode-breve-brief.md`
(Configurator session 74, 2026-11-17).
**Date:** 2026-11-18. **Release:** ships in engine 1.10.0 (session 46).

> **Cross-repo rule of engagement (unchanged since set 005):** export-spec
> changes are authored **Configurator-side** from this record. This
> session does not touch the Configurator's LY export spec. This file is
> the engine-contract source of truth for that work.

---

## 1. The setting

| | |
|---|---|
| Setting | `#(set! cnb:breve-style 'tied)` after the include: `'single`, `'double` or `'tied` |
| Default | `'single`: one head, exactly as engine 1.9.0 draws a shape-mode breve |
| Read for | a breve (duration log −1) whose resolved notehead has `(repeat . #f)`, and nothing else |
| `'double` | two copies of the notehead's stencil (outline, cutout and colour), the second starting (1 − overlap) × w after the first, w one head's X width and the overlap `cnb:multinote-overlap`; when that is `#f`, the copies are w + `cnb:multinote-padding` apart, as repeat mode spaces them. No tie |
| `'tied` | two copies, the second's left edge 1 staff space after the first's right edge, and one `(make-tie-stencil (cons xa y0) (cons xb y0) 0.12 DOWN)`, xa and xb the two heads' centres and y0 the bottom of the head's Y extent. The tie is added after the head is coloured, so it is black on a coloured head too. `'tied` does not read the overlap |
| Another value | a warning naming `cnb:breve-style` and the value, and the breve draws as `'single` |

**An unknown value warns; it does not stop LilyPond.** The brief asks for
an error, "as the engine's other style settings do". The engine's other
style settings (`cnb:clef-style`, `cnb:keysig-style` and the rest) warn and
fall back, and none stops LilyPond. By the operator's decision of
2026-11-18 this setting follows the engine. The Configurator only ever
writes `'double` or `'tied`, so this changes nothing in its exports.

**The breve stays one note.** It is one NoteHead grob, and only its stencil
changes, as with a repeat-mode breve. Dots, spacing, ledgers and the
per-pitch fields (shape, cutout, colour, attachment, x-offset) behave as
for any notehead. A shape's reference point (LY spec §4.1e, the `-ref`
registrations) is in the head's path, so it moves both copies, and the tie
runs below the moved heads. The stencil cache keeps the three styles apart
from each other and from repeat mode.

**A shape-mode longa or maxima** still draws as one head, the breve's,
under every style (the Configurator has neither). The first one in a run
gives one warning that it reads shorter than it is (backlog §7). The
warning changes no output.

**Unchanged:** every duration but the breve; repeat mode, where a breve is
still two tied groups of four whatever the setting; stems (a breve has
none); the open tie the backlog counts. A file that does not set
`cnb:breve-style` engraves byte-identically: every golden and harvest is
unchanged on both versions.

**Needs engine 1.10.0.** A file that sets `cnb:breve-style` fails on engine
1.9.0 or older, where the variable is unbound and LilyPond stops.

---

## 2. Measured breves at an overlap of 1/3

Measured 2026-11-18 from the engraved SVGs of the four new specs
(`tests/breve-shape-double.ly`, `-tied.ly`, `-double-diamond.ly`,
`-tied-diamond.ly`). The head outlines were sampled along their curves, so
these are ink extents, not the harvest's control-point boxes. **Identical
on LilyPond 2.24.2 and 2.26.0** to the SVG's 4 decimals: the two differ
only by ±0.0001 in a few positions, from that rounding. Units are staff
spaces before magnification. As in the brief, x is measured from the
breve's centre (the middle of its heads' X extent) and y up from the
pitch. The tie is LilyPond's: a filled outline stroked 0.1 wide. Its "ends"
are the outline's ends, its "bow" the outer curve's depth below them, and
its "lowest ink" includes the half stroke.

### The default notehead (`crotchet-minim`), 4 semitones a staff space

The Default 4-8 System export's `crotchet-minim` head with its
`crotchet-minim-cutout` (as `cnb/fixtures/default-export-baseline.ly`
writes it), black, on the 4-8 staff (lines −4 −2 2 4) with the export's
`cnb:ledgers-by-semitone`.

| Figure | Engraved (2.24.2 and 2.26.0) | Preview (brief) |
|---|---|---|
| Head w × h | 0.8621 × 0.6810 (top 0.3405, bottom −0.3405) | 0.8621 × 0.681 |
| `'double` width | 1.4369 | 1.4369 |
| `'double` heads' centres | ±0.2874 | ±0.2874 |
| `'tied` width | 2.7243 | 2.7243 |
| `'tied` tie's ends, x | ±0.9311 | ±0.9311 |
| `'tied` tie's ends, y | −0.3406 | −0.3405 |
| Tie's bow | 0.4887 | 0.4887 |
| Tie's lowest ink | −0.8793 | −0.8792 |
| `'tied` height, top of the heads to the tie's ink | 1.2198 | 1.2197 |

**Where they differ:** only the tie's height, by 0.0001. The tie starts
at the bottom of the head's stencil extent as LilyPond computes it, and
the SVG writes that as −0.3406. The head's sampled ink bottom is −0.3405,
so the extent lies less than 0.0001 below the ink. The lowest ink and the
top-to-ink height carry the same 0.0001. Everything else matches to the
4 places written, well inside session 76's 0.001.

### The tutorial's diamond, 2 semitones a staff space

The diamond and its `diamond-cutout` from the Configurator's
`docs/playbook/tutorial/downloads/tutorial.ly`, red (`#cc0000`) on the
C-major off-key pitch classes (C♯ here) and black elsewhere, on the
3-5-7-9 staff (lines −9 −7 −5 −3 3 5 7 9) with the tutorial's
`cnb:ledgers-by-semitone`.

| Figure | Engraved (2.24.2 and 2.26.0) | Preview (brief) |
|---|---|---|
| Head w × h | 1.5000 × 1.0000 (top 0.5, bottom −0.5) | 1.5 × 1 |
| `'double` width | 2.5000 | 2.5 |
| `'double` heads' centres | ±0.5000 | ±0.5 |
| `'tied` width | 4.0000 | 4 |
| `'tied` tie's ends, x | ±1.2500 | ±1.25 |
| `'tied` tie's ends, y | −0.5000 | −0.5 |
| Tie's bow | 0.5816 | 0.5816 |
| Tie's lowest ink | −1.1316 | −1.1316 |
| `'tied` height, top of the heads to the tie's ink | 1.6316 | 1.6316 |

**No difference** at 4 places. (The diamond's export coordinates are exact,
so the ~0.0002 the brief expects from 4-place path coordinates does not
arise here, and on the default notehead it is below the 4 places written.)

### Heads, fill and colour (both notations, both styles)

Each breve is one notehead with two head paths. Each path is the single
head's outline and cutout (one path, opposite windings), so both heads are
hollow, and each is in its own colour group with the head's colour: black
on the default notehead and on the diamond's B and E, red
`rgb(80%, 0%, 0%)` on the diamond's C♯. The tie is drawn after them,
outside the colour groups, in `currentColor`, so it is **black on both
notations, the red C♯ included**. The tie's ink runs 0.05 beyond each end
in x (±0.9811 on the default head, ±1.3000 on the diamond), inside the
heads' extent.

### Ledgers

Each ledger is centred on its breve (offset 0.0000 ± 0.0001) and is **1.5
times the whole stencil's width**, as LilyPond sizes ledgers from the
stencil:

| Notation | Style | Breve and its ledgers (staff position) | Ledger length | ÷ breve width |
|---|---|---|---|---|
| Default, 4-8 | `'double` | C5: 0; D5: 0 and 1 | 2.1555 | 1.5001 |
| Default, 4-8 | `'tied` | C5: 0; D5: 0 and 1 | 4.0866 | 1.5001 |
| Diamond, 3-5-7-9 | `'double` | B4: −1; C♯5: 1 | 3.7503 | 1.5001 |
| Diamond, 3-5-7-9 | `'tied` | B4: −1; C♯5: 1 | 6.0003 | 1.5001 |

The positions are the ones `cnb:ledgers-by-semitone` gives (default: 12 →
`(0)`, 14 → `(0 1)`; tutorial: 11 → `(-1)`, 13 → `(1)`), each ledger on
its breve's pitch line. The breves on the staff (E5) have none.

### The dot

A dotted breve's dot stands **0.4500 after the whole stencil's right
edge** (0.4501 on 2.26.0 for three of the four), for both styles and both
notations: LilyPond places it from the stencil's extent, as for any note.
Its y is LilyPond's: on the default 4-8 staff, E5 is on a line, so the dot
moves up half a staff space (+0.5000). On the diamond's staff, E5 is in a
space, so the dot stays level (0.0000).

---

## 3. Verification status

- `engine-unit` and `engine-unit-2.26`: 577 assertions, all passing. They
  include `cnb:make-cache-key` with the style index, `cnb:breve-style-index`,
  and `cnb:shape-mode-stencil`: `'single` and an unknown value are the base
  head; `'double` is (2 − overlap) w wide at 1/3 and 0.25, and 2w + padding
  at `#f`; `'tied` is 2w + 1 wide with the tie's ink below the heads,
  including for a head off its reference point. Also covered: a shape-mode
  semibreve and longa are the base head under every style; repeat mode is
  unchanged under every style; and the longa warning is given once.
- `engine-integration` and `engine-integration-2.26`: 473 assertions, all
  passing, 32 of them in the four new specs. No other golden or harvest
  changed.
- Engine 1.10.0 is released by session 46.
