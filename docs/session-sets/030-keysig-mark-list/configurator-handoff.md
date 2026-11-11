# Configurator handoff — key signatures from a mark list (session 30)

**From:** `lilypond-chromatic-notation-base`, session 30 ("Key signatures
from a mark list").
**To:** `chromatic-notation-configurator`. Its session 49 exports the
table, and its engine round trip waits on this session. The design is the
Configurator's `docs/planning/key-signature-designer-design.md` §9.
**Date:** 2026-11-11. **Release:** ships in engine 1.4.0 (session 31).

> **Cross-repo rule of engagement (unchanged since set 005):** export-spec
> changes are authored **Configurator-side** from this record. This
> session does not touch the Configurator's LY export spec (its 1.3.15
> §5.6a). This file is the engine-contract source of truth for that work.

One setting value and one setting are added. Nothing that exports today
changes: `'chord` and `'none` are untouched, and every existing golden is
byte-identical.

---

## 1. The format as landed

```lilypond
#(set! cnb:keysig-style 'marks)
#(define cnb:keysig-marks '(ENTRY …))
```

`cnb:keysig-marks` defaults to `'()`. It is read when the score is
engraved, so it may be defined anywhere before the music.

**An entry** is `(KEY . VALUE)`.

| Part | Form | Meaning |
|---|---|---|
| KEY | `((notename . alteration) . pitch-classes)` | The tonic's note name, `0` = C … `6` = B, and its alteration, `1/2` sharp, `-1/2` flat, `0` natural, both as `\key` gives them (`ly:pitch-notename`, `ly:pitch-alteration` of the context's `tonic`). Then the key's seven pitch classes from `keyAlterations`, ascending, C = 0. |
| VALUE | `((columns …) (bars …) (marks …))` | An alist; the order of its three members does not matter. |

**Which keys are read correctly.** The pitch classes come from the
engine's `cnb:get-key-pitch-classes`. It is correct for every key with at
most seven sharps or flats: read from real `\key` events, C♯, C♭, F♯ and G♭
major and A♯, A♭ and G♯ minor (whose E♯, B♯, F♭ and C♭ share a pitch class
with another letter) all give their seven pitch classes. A key with
double sharps or flats (D♯ major, say) is read wrongly: its list repeats
pitch classes, as the warning below shows. No entry the Configurator's
105 keys need can match it, so such a key draws no signature and warns.

The key is matched with `equal?`, so `1/2` must be written as the exact
rational (`1/2`, not `0.5`), and the pitch classes must be ascending. C
major is `((0 . 0) 0 2 4 5 7 9 11)`, A minor `((5 . 0) 0 2 4 5 7 9 11)`, F♯
major `((3 . 1/2) 1 3 5 6 8 10 11)`, G♭ major `((4 . -1/2) 1 3 5 6 8 10
11)` and B♭ major `((6 . -1/2) 0 2 3 5 7 9 10)`.

**VALUE's members:**

| Member | Form | Units |
|---|---|---|
| `columns` | `(columns x0 x1 …)` | Each column's **centre**, in staff spaces from the signature's start (its stencil's x = 0). |
| `bars` | `(bars (x bottom top color thickness) …)` | `x` in staff spaces, the same origin; `bottom` and `top` in engine semitones (middle C = 0); `color` a colour name registered with `cnb:register-color!` or a hex string `"#rrggbb"`; `thickness` in staff spaces. `(bars)` when there are none. |
| `marks` | `(marks MARK …)` | See below. |

**A mark** is one of:

| Mark | Meaning |
|---|---|
| `(semi column head shape hollow color)` | A notehead. `shape` is a path name registered with `cnb:register-path!` (a sized variant is its own registered name, as Section A writes it); `hollow` is a hollow name registered with `cnb:register-hollow!` (`crotchet-minim-cutout`) or `#f` for solid; `color` is a registered colour name (a hex string also works). |
| `(semi column sharp)` | Emmentaler's `accidentals.sharp`. |
| `(semi column flat)` | Emmentaler's `accidentals.flat`. |

`semi` is the engine semitone, middle C = 0; `column` indexes `columns`
from 0. Two marks at one semitone in neighbouring columns are a double
notehead and need nothing of their own.

### What the engine draws

- **Heads:** built from the registered path, hollow and colour exactly as
  a note's head is (`cnb:build-stencil-from-config`, so `cnb:false-hollow`
  applies), scaled by the staff's font magnification. The head's **X
  extent is centred** on its column's x.
- **Height:** each mark's origin is placed as a key-signature notehead's
  has always been (`cnb:keysig-note-y-offset`): through the pitch-axis hook
  when `cnb:get-pitch-staff-position` is set, else `(semi + 2 ×
  middleCPosition) / cnb:semitones-per-staff-space` staff spaces from the
  middle line. A head's origin is its path's (0, 0). A sharp's origin is
  at its centre line; a flat's origin is at its bowl's line, so it stands
  above the semitone's height (Emmentaler Y extent −0.63 .. 1.83 staff
  spaces).
- **Ledger lines:** each head gets its own, by the same rule as `'chord`
  (the staff's ledger candidates, or the custom ledger table), drawn
  beneath the heads. A ledger line is 4/3 of its head's width, so it
  reaches 1/6 of the head's width beyond it on each side. Sharps and flats
  get none.
- **Sharps and flats:** the glyphs from the staff's own music font, at its
  size, black, X extent centred on their column. Emmentaler's widths are
  1.1 staff spaces for the sharp (extent 0 .. 1.1) and 0.92 for the flat
  (−0.12 .. 0.80).
- **Bars:** a round-capped line of the given thickness from (x, bottom) to
  (x, top), heights as for marks, drawn beneath everything. The caps add
  half the thickness at each end.
- **Layers, bottom up:** bars, heads with their ledger lines, the heads
  again (so a neighbouring column's ledger never covers a head), sharps
  and flats.

### What the engine does not do

- **No layout:** no column offsets, bar positions or mark heights are
  computed; a column with no marks is simply empty.
- **A key change** draws the new key's entry; LilyPond's cancelling
  naturals (the KeyCancellation grob) draw nothing under `'marks`.
- **A key the table lacks** draws no signature, and the engine warns once
  per key, naming its tonic and its key, for `\key dis \major`:
  `cnb:keysig-marks has no entry for the key of #<Pitch dis >, ((1 . 1/2)
  2 2 3 7 7 8 10) (tonic, pitch classes); no key signature drawn`. There
  is no fallback to the scale stack.
- **An unregistered shape** warns naming it, and that mark is skipped.
- **The signature repeated** at each system's start is the same grob type
  and draws the same entry.

---

## 2. A worked entry

C major, two columns of the Configurator's default notehead, a double
notehead on the tonic and one gold stem: the head is 1.0 staff space wide
here (the engine's default oval), so the columns' centres are 0.5 and 1.5
and the stem sits on their boundary at 1.0.

```lilypond
#(cnb:register-color! 'black-000000 "#000000")
#(set! cnb:keysig-style 'marks)
#(define cnb:keysig-marks
   '((((0 . 0) . (0 2 4 5 7 9 11))
      . ((columns 0.5 1.5)
         (bars (1.0 8 16 "#ffd42a" 0.2))
         (marks (8 0 head default-oval #f black-000000)
                (12 0 head default-oval #f black-000000)
                (12 1 head default-oval #f black-000000)
                (16 1 head default-oval default-oval-cutout black-000000))))))
```

On the engine's default staff (2 semitones per staff space, treble
clef: middle line = semitone 12), the marks sit at −2, 0, 0 and +2 staff
spaces, the stem runs from −2 to +2 (−2.1 .. 2.1 with its caps), and the
signature is 2.0 staff spaces wide. This is `tests/keysig-marks.ly`'s C
major entry.

---

## 3. The space around the signature

Measured from `tests/keysig-marks-columns` on LilyPond 2.24.2 and 2.26.0
(staff spaces, the engine's default staff, no time signature, so each
system is clef, signature, first note). Each column is its widest mark's
width wide, as `CNBKeySignature.marks` lays it out, so the signature runs
from its start to its **end**, columns × width.

| Signature | Width each | End | Staff's start → start (no clef) | Clef's left edge → start | Clef's right edge → start | End → first note's centre |
|---|---|---|---|---|---|---|
| Two columns of heads | 1.0 | 2.0 | 0.75 | 2.5 (2.24) / 3.025 (2.26) | 1.398 / 1.923 | 2.5 |
| Three columns of sharps | 1.1 | 3.3 | 0.75 | 2.5 / 3.025 | 1.398 / 1.923 | 2.5 |
| Four columns of flats | 0.92 | 3.68 | 0.75 | 2.5 / 3.025 | 1.398 / 1.923 | 2.5 |

The clef is the engine's default dozenal clef, whose ink is 1.102 staff
spaces wide and starts 0.75 after the staff's start.

**What the numbers say:**

- **Neither space depends on the number of columns or on the marks.**
  LilyPond spaces the signature by its stencil's extent: its left edge
  0.75 after the staff's start, and the first note's head origin (its
  centre, for the engine's centred heads) 2.5 after its right edge.
- **The space before**, with no clef, is the 0.75 the Configurator uses
  for `'chord`, and is the same on both versions.
- **The space after** is 2.5 after the signature's end on both versions.
  For the Configurator's `'chord` figure of 4.8636 from the marks' start,
  read **start + columns × width + 2.5** for `'marks`.
- **The space from the clef** differs between versions: 2.26 puts the
  signature 0.525 further from the clef than 2.24. It is measured here
  against the engine's default clef; the Configurator's 3.5 after the
  clef's left edge is measured against its own clef glyph, so the
  preview keeps its own clef figure and this table shows how far the two
  versions differ.
- **The extent is the ink's, including ledger lines.** A first-column head
  with a ledger line moves the signature right by 1/6 of the head's width
  (the ledger's overhang), and a last-column head with one moves the first
  note right by the same. A mark wider than its column does the same. The
  measurements above have no ledger lines.

`tests/keysig-marks-columns.json` asserts every figure in the table on
both versions, against the harvest's control-point hulls (which put the
flats' ink 0.048 before the signature's start).

---

## 4. Verification status

- `engine-unit` and `engine-unit-2.26`: 399 assertions, all passing,
  including the table's keys (C major and A minor, F♯ and G♭ major, B♭
  major), an entry found and one missing, and the stencil: heads centred on
  their columns, a double notehead, a bar's ends, a low head's ledger
  lines, a sharp with none, a sharp and a flat, and an unregistered shape
  skipped.
- `engine-integration` and `engine-integration-2.26`: 391 assertions, all
  passing, no harvest drifted. `tests/keysig-marks` covers a key change
  with no naturals, a `\transpose`d passage, the F♯ / G♭ pair, the
  signature repeated at a system start, a double notehead, a hollow head
  and a key the table lacks; `tests/keysig-marks-columns` covers two,
  three and four columns with their bars, sharps and flats, and the
  spacing above.
- Engine 1.4.0 is released by session 31.
