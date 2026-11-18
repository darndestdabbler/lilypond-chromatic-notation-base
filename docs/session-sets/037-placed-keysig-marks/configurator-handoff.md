# Configurator handoff — placed, coloured and layered key-signature marks (session 37)

**From:** `lilypond-chromatic-notation-base`, session 37 ("Placed,
coloured and layered key-signature marks").
**To:** `chromatic-notation-configurator`. Its session 53 designed one
model for every key signature (`docs/planning/key-signature-designer-design.md`
§13), its session 54 draws it on the canvas, and its session 55 writes
the mark table's new fields (§13.10). This record is the engine side of
that contract.
**Date:** 2026-11-12. **Release:** ships in engine 1.6.0, released by
session 38.

> **Cross-repo rule of engagement (unchanged since set 005):** export-spec
> changes are authored **Configurator-side** from this record. This
> session does not touch the Configurator's LY export spec. This file is
> the engine-contract source of truth for that work.

---

## 1. What changed

The mark table (`cnb:keysig-marks`, engine 1.4.0; the sign scale of
1.5.0) keeps its shape. A mark gains fields, and there is one new kind:

```lilypond
(semi column head   shape hollow color [at])
(semi column symbol shape cutout color [at])          ; new kind
(semi column sharp  [scale [color]] [at])
(semi column flat   [scale [color]] [at])
```

### 1a. `(at dx . dy)`: a mark placed by its origin

The optional **last** element of a `head`, `symbol`, `sharp` or `flat`
mark, in staff spaces.

| The mark | Its stencil |
|---|---|
| without `at` | X extent centred on its column, origin at the semitone's height: as in 1.5.0 |
| with `(at dx . dy)` | origin at the column's x + `dx`, the semitone's height + `dy`; the box is **not** centred |

- `dx` and `dy` scale with the staff's font magnification, as the
  columns do. The semitone's height is placed as before, through the
  pitch-axis hook when it is set.
- **The engine places origins only.** It reads no reference point, size
  or offset: `dx` and `dy` are the designer's offset less the symbol's
  reference point, converted as its path is (§13.10).
- **A head's ledgers** stay at the staff positions its semitone takes
  (`cnb:ledgers-by-semitone`, or the engine's rule) and span the placed
  head's X extent, so they follow it along the staff. `dy` does not
  move them: it is a move of the symbol, not a change of pitch, and for
  a symbol whose origin is not its reference point it is nonzero even
  with no offset at all.

### 1b. A sign's colour

A `sharp` or `flat` may carry a colour after its scale: a registered
colour name (registered as a head's colour is, in Section A) or a hex
string. An unregistered name warns and draws black.

- **A black sign writes no colour**, so an unchanged sign is written as
  in 1.5.0 and draws Emmentaler's glyph uncoloured.
- **A sign with a colour or an `at` writes its scale, even when it is
  1**, so the elements keep their positions: `(13 1 sharp 1 red-cc0000)`,
  `(13 1 sharp 1 (at 0.1 . 0.25))`.

### 1c. The `symbol` kind

`(semi column symbol shape cutout color [at])` is drawn by the same code
as a `head`: a registered shape, `#f` for solid or a registered hollow
name for the cutout, its colour, scaled with the staff. It takes **no
ledger lines**. It serves a head's added symbols (a dot's tail) and any
base whose shape has `ledgers: false`, which may be hollow. An
unregistered shape warns and the mark is skipped, as for a head.

### 1d. Drawing order

Bottom up: **the bars, then every head's ledger lines, then each mark
once, in the table's order.**

- Marks layered at one semitone and column (a dot, then its tail) draw
  as written, so the table's order is the layer order.
- No ledger covers a mark, a neighbouring column's included.
- A mark's ledgers come from its `head` only, so a tail beside it adds
  none.
- Before, each head was drawn with its ledgers and then again on top,
  and the signs last. A table with heads now draws the same ink with
  each head once.

### What did not change

The table's key, `columns` and `bars` (bars take no `at` and no new
field); the sign scale and its warning; the column layout, which stays
the Configurator's; the cache (every field is part of the entry it keys
on); `'chord` and `'none`; the notes' noteheads and ledgers; and the
key-change, transposition and system-start behaviour (their specs pass
unchanged).

## 2. Worked cases: `tests/keysig-marks-placed`

The default 4-8 staff (4 semitones a staff space, lines on semitones
4 8 16 20), `'marks`, no bars, one system per key. The file registers
two one-sided shapes whose origin is not their centre, as an imported
symbol's is:

- `test-dot`: a square half a staff space wide, its origin at its lower
  left corner, with a cutout `test-dot-cutout`;
- `test-tail`: a thin bar rising from its origin to the right.

So `(at -0.25 . -0.25)` puts the dot's centre on its column and
semitone, as the Configurator's offset-less-reference conversion would.

```lilypond
#(define cnb:keysig-marks
   '((((1 . 0) . (1 2 4 6 7 9 11))                 ; D major
      . ((columns 0.5 1.5 2.5)
         (bars)
         (marks (-1 0 head default-oval #f black-000000 (at 0.1 . 0))
                (14 1 head test-dot #f black-000000 (at -0.25 . -0.25))
                (14 1 symbol test-tail #f black-000000 (at 0.25 . -0.05))
                (18 2 symbol test-dot test-dot-cutout black-000000 (at -0.25 . -0.25))
                (13 2 sharp 1 red-cc0000 (at -0.35 . 0.25)))))
     (((6 . -1/2) . (0 2 3 5 7 9 10))              ; B flat major
      . ((columns 0.5 1.5)
         (bars)
         (marks (10 0 flat 0.6473 red-cc0000 (at -0.3 . 0))
                (15 1 flat 1 blue-0000cc (at -0.46 . 0.25)))))))
```

**Measured** on LilyPond 2.24 and 2.26 alike, to 0.001 staff spaces, by
the harvest's control-point hulls. "Without `at`" is the same file with
every `at` removed:

| Signature | Without `at`: width × height | With `at`: width × height |
|---|---|---|
| D major | 3.069 × 5.75 | 3.169 × 5.826 |
| B♭ major | 1.681 × 3.511 | 1.641 × 3.761 |

### 2a. Placed marks

- **The head on B (−1), `(at 0.1 . 0)`.** Its origin, the default
  head's centre, is 0.1 right of column 0 (x 0.5). Its ledger, at the
  staff position of semitone 0, follows it: D major's left edge, the
  ledger's, is 0.1 further right than without `at` (the head's left
  0.1, less a sixth of its width). The bottom is the head's, half a
  staff space below B's height, 3.75 below d''.
- **The sharp on C♯ (13), `(at -0.35 . 0.25)`.** Its origin, the glyph's
  left edge on its centre line, is at 2.5 − 0.35 = 2.15 and a quarter
  staff space above C♯. D major's right edge is its ink, 0.952 right of
  that origin, and its top is the sharp's, 1.576 above its centre.
  Without `at` the sharp is centred, its origin at 2.5 − 0.55, and the
  top is the hollow square's instead. Width
  (2.15 + 0.952) − (0.1 − 1/6) = 3.169.
- **The flats.** The blue flat on E♭ (15), `(at -0.46 . 0.25)`, is raised
  a quarter staff space: B♭ major's top is 1.86 above its bowl. The red
  flat on B♭ (10), scale 0.6473 and `(at -0.3 . 0)`, is B♭ major's
  bottom, 0.6473 of the flat's 0.62 below its bowl. Each sign's scale
  is about its origin, then the `at` places that origin.

### 2b. Coloured signs

The sharp (`red-cc0000`, scale 1, with `at`) and both flats
(`red-cc0000` at 0.6473, `blue-0000cc` at 1) draw in their colours. The
harvest records a signature's first colour: B♭ major's, with no bar or
ledger drawn before its first mark, is the red flat's,
`rgb(80%, 0%, 0%)`. Each colour's rgb and its unchanged extents are
checked in the unit specs.

### 2c. The `symbol` kind

- The tail, `(14 1 symbol test-tail #f …)`, is solid, and the square on
  F♯ (18), `(18 2 symbol test-dot test-dot-cutout …)`, hollow. Neither
  draws a ledger.
- In the unit specs, a solid and a hollow symbol below the staff are
  each exactly their shape's width, where a head there is widened by its
  ledgers.

### 2d. Drawing order: a dot and its tail

The dot head and the tail symbol share semitone 14 and column 1. The
signature draws, in order, the B head's ledger, then the B head, the
dot, the tail, the hollow square and the red sharp. The tail is drawn
over the dot, and the dot's semitone, inside the staff, takes no
ledger. In the unit specs a dot and tail below the staff give the
dot's ledgers alone. Two marks at one semitone and column come back in
the order written.

## 3. Compatibility

- **A table without any new field is engraved as by 1.5.0.** Every
  table exported today keeps its ink. No tracked harvest changed, on
  2.24 or 2.26. The SVGs of the three specs whose tables have heads
  (`keysig-marks`, `keysig-marks-columns`, `keysig-ledgers-marks`)
  changed only in element order, since each head is now drawn once.
- **A table that uses any new field needs engine 1.6.0.** On 1.5.0:
  - an `at` element is ignored, so the mark is centred on its column
    (a sign's scale, which is always written before it, is still read);
  - a sign's colour is ignored, and the sign draws black;
  - a `symbol` mark is not drawn.

## 4. Verification

- Unit (`test-unit.ly`), on 2.24 and 2.26, 486 assertions passing:
  - "keysig.ly — cnb:keysig-marks-stencil": a head and a sharp with
    `(at dx . 0)` and `(at 0 . dy)` placed by their origins; a placed
    head's ledgers at its semitone's staff positions, following it in
    x; a red sharp and flat (name and hex) with the uncoloured sign's
    extents; no colour on a sign without one; a coloured sign at scale
    1 with an `at`; a solid and a hollow symbol with no ledgers; a dot
    and its tail giving the dot's ledgers alone.
  - "keysig.ly — cnb:keysig-marks-layers": bars, then the ledgers, then
    the marks in table order, and the signature's extents those of its
    layers.
- Integration: `tests/keysig-marks-placed`, with the values above, on
  2.24 and 2.26. The whole suite passes on both, 418 assertions, with
  no harvest drift.

## 5. Next

**Session 38 releases engine 1.6.0**: it packs and publishes what is on
the trunk. The Configurator's session 55 can then write `at`, sign
colours and `symbol` marks.
