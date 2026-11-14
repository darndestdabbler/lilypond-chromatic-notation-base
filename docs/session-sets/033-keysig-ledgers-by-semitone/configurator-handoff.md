# Configurator handoff — key-signature ledgers from the notation's ledger rules (session 33)

**From:** `lilypond-chromatic-notation-base`, session 33 ("Key-signature
ledgers from the notation's ledger rules").
**To:** `chromatic-notation-configurator`. Its session 49 engine round
trip (`cnb/tests/cnb-lilypond-tests.js`, "mark table (engine)") found the
disagreement this session fixes, and the operator chose to fix it in the
engine instead of copying the engine's rule into the canvas.
**Date:** 2026-11-11. **Release:** ships in engine 1.4.1, released by
session 34.

> **Cross-repo rule of engagement (unchanged since set 005):** export-spec
> changes are authored **Configurator-side** from this record. This
> session does not touch the Configurator's LY export spec (its 1.3.9
> §5.7 and 1.3.15 §5.6a). This file is the engine-contract source of
> truth for that work.

The export does not change. Its `cnb:ledgers-by-semitone` table, already
in every export since LY spec 1.3.9, now governs the key signature's
heads as it governs the notes.

---

## 1. What changed

A key-signature head takes its ledger lines from
`cnb:ledgers-by-semitone` (engine semitone, middle C = 0, → ledger staff
positions in half staff spaces from the middle line):

| The head's semitone | Ledgers drawn |
|---|---|
| has an entry with positions | exactly those positions |
| has an empty entry, `(s . ())` | none |
| has no entry | the engine's rule, as before |
| any, in a score with no table | the engine's rule, as before |

The engine's rule is unchanged: `cnb:proximity-rule` on the head's staff
position rounded to a whole number (or, with `cnb:staff-and-ledger-lines`,
its ledger lookup). This is the same split the export's `\layout` block
makes for the notes through `NoteHead.ledger-positions` / `no-ledgers`.

- **`'chord`:** each head's semitone is its pitch from
  `cnb:keysig-pitches`, `ly:pitch-semitones`.
- **`'marks`:** each head mark's semitone is the mark's own `semi`, the
  first element of `(semi column head shape hollow color)`. Sharps and
  flats still draw no ledgers.
- **Magnification:** positions are scaled by the font magnification as
  before, so `cnb:default-magnify` and `\magnifyStaff` scale the table's
  ledgers with the heads.

**What did not change:** a ledger's length (4/3 of the head's width,
starting 1/6 of it before the head), its thickness (0.2 staff spaces),
its round caps and its layer (ledgers under the heads, the heads drawn
again on top); the heads, bars, sharps, flats and the signature's
spacing rules; `'none`; the table's format; and how the notes' ledgers
are drawn. The table also joins both key-signature stencil caches' keys,
so a changed table can never reuse a stale stencil.

## 2. `define`, not `set!`

`cnb/config.ly` now defines `cnb:ledgers-by-semitone` as `'()`, so the
engine can read it in a score that has no table. The export **keeps
`#(define cnb:ledgers-by-semitone …)`**, after `\include
"ChromaticNotationBase.ly"`, exactly as it writes it today; no `set!` is
needed. A top-level `define` of a name that is already bound rebinds it,
and the signature is drawn when the score is engraved, after every
top-level form has run, so the engine reads the export's table. This is
the same as `cnb:keysig-marks` since session 30. An export that defined
the table *before* the include would be overwritten by the default, but
the export writes Section B after the include.

## 3. Worked case: the default 4-8 staff's C major

The default Configurator config: 4 semitones per staff space, lines at
`-4 -2 2 4` (no middle line), and the table the default export writes:

```lilypond
#(define cnb:ledgers-by-semitone
   '((0 . (-6)) (1 . (-6)) (2 . (-6 -5)) (3 . ()) (4 . ()) (5 . ())
     (6 . ()) (7 . ()) (8 . ()) (9 . ()) (10 . (-1)) (11 . ())
     (12 . (0)) (13 . (0)) (14 . (0 1)) (15 . ()) (16 . ()) (17 . ())
     (18 . ()) (19 . ()) (20 . ()) (21 . ()) (22 . (5)) (23 . ())
     (24 . (6))
     ))
```

Treble clef, so semitone 12 is the middle position. C major anchored
`'centred` sits on semitones 12–24.

| Head | Staff position | Before (engine's rule) | After (the table) |
|---|---|---|---|
| C, 12 | 0 | none | 0 (in the gap where the middle line would be) |
| D, 14 | 1 | none | 0 and 1 |
| B, 23 | 5.5, rounded to 6 | 6, above the staff | none |
| C, 24 | 6 | 6 | 6 |

The signature now agrees with the notes and with the canvas.

**Measured** (`tests/keysig-ledgers-chord`, `tests/keysig-ledgers-marks`;
LilyPond 2.24 and 2.26 alike, to 0.001 staff spaces; widths from the
harvest's control-point hulls; "first note" is its left edge from the
signature's left edge):

| Signature | Before: width × height, first note | After: width × height, first note |
|---|---|---|
| `'chord` C major (12–24) | 2.334 × 6.5, 6.783 | 2.334 × 6.5, 6.783 |
| `'chord` G major (7–19) | 2.0 × 6.0, 4.0 | 2.334 × 6.0, 4.433 |
| `'marks` C major: C 12 and B 23 in column 0, D 14 in column 1, no bar | 2.167 × 3.75, 6.516 | 2.334 × 3.75, 6.783 |

- `'chord` C major's extent does not change: its in-gap ledgers lie
  inside its heads' extent, and C 24's ledger already spans both columns.
- `'chord` G major: C (12) and D (14) are its only heads with ledgers,
  one in each column, and their ledgers widen the signature past its
  heads by 1/6 of a head on each side, moving the first note.
- `'marks` C major: before, only B's ledger (column 0) reached past the
  heads; now C's and D's reach past both columns. B's old ledger lay
  inside its head's height, so the height is the same.

A ledger past the marks moves the signature's ink and so the first note,
as the Configurator's round trip found; with the table, the engine's
ledgers are the preview's, so the ink and the first note follow the
preview's wherever its ledgers are the table's.

## 4. Compatibility

- **No existing golden defines the table**, so every existing
  `tests/*.svg` and both harvests of every existing spec are
  byte-identical. Every score without a table engraves as in 1.4.0.
- **Every export since LY spec 1.3.9** carries the table, so its
  signature's ledgers change wherever the engine's rule disagreed with
  the table. The export text does not change.
- **A table needs engine 1.4.1** for the signature to follow it. Engine
  1.4.0 and earlier read the table only through the notes' `\layout`
  overrides, and draw the signature by the engine's rule.

## 5. Verification

- Unit (`test-unit.ly`, "keysig.ly — cnb:notehead-ledgers by semitone"):
  the default `'()`; on the 4-8 staff, D (14) gets exactly `(0 1)`, C
  (12) `(0)`, both scaled by the magnification; B (23)'s empty entry
  gives none where the rule gives one; semitone 30, with no entry, keeps
  the rule; with no table C, D and B get the rule. 2.24 and 2.26.
- Integration: `tests/keysig-ledgers-chord` and
  `tests/keysig-ledgers-marks`, the extents and first-note positions
  above, on 2.24 and 2.26. The whole integration suite passes on both
  with no harvest drift.

## 6. Next

**Session 34 releases engine 1.4.1**: it packs and publishes what is on
the trunk. The Configurator's round trip can then hold the signature's
ink to the preview's where the engine's rule and the table disagreed.
