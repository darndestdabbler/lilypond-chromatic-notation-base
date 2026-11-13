# Changelog

## 1.8.0

- A dozenal clef sized by `cnb:clef-size-semitones` is now scaled about
  the staff's middle line. Its vertical offsets (the left digit's −0.5
  translate and the engraver's −1 staff-space Y-offset) are multiplied by
  its height H in staff spaces over 3, so the treble numeral 50 runs from
  1.4418 × H/3 above the middle line to 1.5582 × H/3 below it; before,
  the offsets stayed fixed and a numeral of another height left its
  place. With the size `#f`, or at exactly 3 staff spaces, it engraves as
  before, and the `'text` and `'custom` clefs are unchanged, so a file
  that does not set the size with the dozenal clef engraves as before.
- New spec `tests/clef-size-dozenal-middle`: the dozenal clef at 8.172
  semitones on the Configurator's staff of 4 semitones per staff space.
- The golden and harvests of `clef-size-dozenal`, which sets the size
  with the dozenal clef, changed on 2.24 and 2.26: its numeral now sits
  4/3 as far from the middle line.
  `docs/session-sets/041-dozenal-clef-size/configurator-handoff.md` gives
  the numeral's measured top, bottom and width.

## 1.7.0

- New setting `cnb:multinote-overlap`, default `#f`. When it is a number,
  each repeated notehead starts (1 − overlap) times the head's own X width
  after the last, in place of `cnb:multinote-padding`, which is then not
  read. At 1/3 a minim is 1 + 2/3 heads wide and a semibreve 3, whatever
  the shape. With `#f` the copies join at the padding, as before, so a
  file that does not set it engraves its notes as before.
- The tie of a breve, longa or maxima in repeat mode now runs from the
  centre of the first semibreve group to the centre of the last, as a tie
  joins two notes; before, it ran from the first head's centre to the last
  head's. It keeps its height limit, ratio, thickness and black colour,
  and every width is unchanged.
- New spec `tests/multinote-overlap`: the Configurator's default notehead
  at an overlap of 1/3, from a quarter to a longa.
- The goldens and harvests with a breve or longer changed, on 2.24 and
  2.26: `breve-tied-semibreves` (its tie depths re-measured) and
  `duration-rules`.
  `docs/session-sets/039-repeat-overlap/configurator-handoff.md` gives the
  default notehead's widths and tie at 1/3.

## 1.6.0

- A mark-table mark can be placed by its origin. A `head`, `symbol`,
  `sharp` or `flat` mark takes an optional last element,
  `(at dx . dy)`, in staff spaces. With it, the stencil's origin goes to
  the column's x plus `dx` and the semitone's height plus `dy`, and its
  box is not centred on the column. A mark without it is centred as
  before. A head's ledger lines stay at the staff positions its semitone
  takes and span the placed head, so they follow it along the staff.
- A sharp or flat can carry a colour after its scale, a registered
  colour name or a hex string:
  `(13 1 sharp 0.6473 red-cc0000 (at 0.1 . 0.25))`. A sign without one
  draws black, as before. A sign with a colour or an `at` writes its
  scale even when it is 1, so the elements keep their positions.
- A new mark kind, `(semi column symbol shape cutout color [at])`, is
  drawn as a `head` is, solid for a cutout of `#f` or hollow by a
  registered hollow name, but takes no ledger lines. It serves a head's
  added symbols, such as a dot's tail.
- The marks draw in one order: the bars, then every head's ledger
  lines, then each mark once, in the table's order. Marks layered at one
  semitone and column, a dot and its tail, draw as written, and no
  ledger covers a mark. A mark's ledgers come from its `head` only.
- New spec `tests/keysig-marks-placed`: D and B♭ major on the default
  4-8 staff, with placed, coloured and layered marks.
- No tracked harvest changed. The SVGs of the specs whose tables have
  heads (`keysig-marks`, `keysig-marks-columns`, `keysig-ledgers-marks`)
  changed only in element order, since each head is now drawn once
  instead of twice.
  `docs/session-sets/037-placed-keysig-marks/configurator-handoff.md`
  gives a worked case for each change.

## 1.5.0

- A mark-table sharp or flat can be drawn at a scale. A sign mark takes
  an optional fourth element, a positive number:
  `(semi column sharp 0.6473)` or `(semi column flat 0.6473)`. The
  Emmentaler glyph is scaled by it about its origin, on both axes, so
  the sharp's centre or the flat's bowl stays at the semitone's height,
  and is then centred on its column as before. Without the element, or
  with `1`, a sign draws exactly as in 1.4.1. Any other value warns,
  naming the key, and the sign draws unscaled. The format note in
  `cnb/config.ly` and the README give the element. New spec
  `tests/keysig-marks-scaled`: D and B♭ major on the default 4-8 staff
  at scale 0.6473.
- A plain score engraves at the magnification its config sets.
  `cnb/score-defaults.ly` now reads `cnb:default-magnify` when each staff
  starts, not when the engine is included, so a config included after
  the engine that `set!`s it takes effect. Before, every staff in a plain
  score engraved at 7/4 whatever the config said, unless it magnified
  itself with `\magnifyStaff #cnb:default-magnify`. A staff's own
  `\magnifyStaff` still wins, `\magnifyStaff` is still not applied twice,
  and `cnb:score-defaults #f` still opts out. New specs
  `tests/score-defaults-magnify-1` and `tests/score-defaults-magnify-5-2`.
- No existing golden changed: none uses a sign scale, and none `set!`s a
  magnification other than 7/4.
  `docs/session-sets/035-sized-signs-and-magnify/configurator-handoff.md`
  gives a worked case for each change.

## 1.4.1

- A key signature's noteheads take their ledger lines from the
  notation's ledger rules, as the score's notes do. A head whose pitch
  has an entry in `cnb:ledgers-by-semitone`, the table every
  Configurator export defines, draws exactly that entry's ledgers, and
  none for an empty entry. This covers `'chord` and `'marks` alike. A
  head with no entry, or a score with no table, keeps the engine's own
  rule. On the Configurator's default 4-8 staff, C major's C and D now
  draw their in-gap ledgers and its B none, where the signature drew a
  ledger on B above the staff and none on C and D. Ledger length,
  thickness, caps and layering are unchanged. `cnb:ledgers-by-semitone`
  now defaults to `'()` in `cnb/config.ly`. New specs
  `tests/keysig-ledgers-chord` and `tests/keysig-ledgers-marks`; no
  existing golden defines the table, and none changed.
  `docs/session-sets/033-keysig-ledgers-by-semitone/configurator-handoff.md`
  gives a worked case.

## 1.4.0

- A key signature can be drawn from a mark list. With
  `cnb:keysig-style 'marks`, the engine draws the score's key from
  `cnb:keysig-marks`, which has one entry per key: the columns' offsets,
  the gold bars, and the marks (noteheads through their registered path,
  hollow and colour, or Emmentaler sharps and flats). The engine computes
  no layout of its own. An entry's key is the tonic's spelling and the
  key's pitch classes, so F♯ and G♭ major can differ. A key change draws
  the new key's marks with no cancelling naturals. A key the table lacks
  draws no signature and warns. `'chord`, `'none` and every existing
  output are unchanged.
  `docs/session-sets/030-keysig-mark-list/configurator-handoff.md` gives
  the format and the measured spacing around the signature.
- A key with double sharps or flats (D♯ major, F♭ major) now gives its
  seven pitch classes. Before, its list could repeat pitch classes:
  `\key dis \major` gave `(2 2 3 7 7 8 10)` in place of
  `(0 2 3 5 7 8 10)`. This reaches the configuration procedure's `key`
  argument, off-key marks, and the `'marks` table's lookup and its
  warning. Every other key read correctly before and is unchanged.

## 1.3.1

- A breve's tie now runs below the noteheads, as a tie under a note does:
  one tie from the centre of the first head to the centre of the last,
  bowing down from the bottom of the heads, in place of a tie in each gap
  on the heads' centre line. A longa and a maxima get one longer tie the
  same way. The groups, the gaps and the width are unchanged, and so is
  everything shorter than a breve or engraved with `(repeat . #f)`.
  `docs/session-sets/028-breve-tie-below/configurator-handoff.md` gives
  the measured tie for the Configurator's default notehead.

## 1.3.0

- Three settings let a Configurator export engrave its clef and key
  signature where the preview draws them; each defaults to the old
  behaviour. `cnb:clef-anchor-semitones` puts a `'text` clef's top edge
  at a semitone, placed as a `'custom` clef's anchor is.
  `cnb:clef-gutter-left-semitones` adds blank space before the clef, as
  `cnb:clef-gutter-semitones` does after it. `cnb:keysig-tonic-octave
  'centred` picks each key's octave by the Configurator's rule, centring
  the tonic's octave span on the staff's centre semitone.
  `docs/session-sets/024-configurator-gaps/configurator-handoff.md` gives
  their units and measured behaviour.
- In repeat mode a breve now engraves as tied semibreves, so it no longer
  looks like a whole note: 2 of the whole note's 4-head groups, 1 staff
  space apart, with a tie bowing down between them; a longa as 4 groups
  and a maxima as 8. It stays one note, and dots, spacing, the procedure's
  duration category and `(repeat . #f)` are unchanged.
  `docs/session-sets/025-breve-tied-semibreves/configurator-handoff.md`
  gives the measured geometry for the Configurator's default notehead.
- A score with a key change now engraves each key's own signature. Before,
  every key signature after the first in a file drew the first one's
  marks, because the stencil cache was keyed on a context property
  LilyPond never sets.

## 1.2.0

- One `\include` line now makes a plain LilyPond score chromatic, for
  example musicxml2ly output. The engine applies `cnb/score-defaults.ly`
  itself: every staff gets `\magnifyStaff #cnb:default-magnify`, and the
  paper gets a 25 mm indent and a 12 mm short-indent, so instrument names
  are no longer clipped at the page edge. A score's own `\paper` and
  `\layout` still win. To opt out, write
  `#(define cnb:score-defaults #f)` before the `\include`.
  **A score that set its own size may now be magnified twice.** A staff
  that already uses `\magnifyStaff` is not, because it replaces the
  default. A score sized any other way is now magnified on top of its
  own size and should opt out. Other ways include
  `#(set-global-staff-size …)` and `fontSize` or `StaffSymbol.staff-space`
  overrides.
- Cautionary and forced accidentals (`gis?`, `c!`) and suggested
  accidentals no longer print as parenthesised traditional glyphs.
  `AccidentalCautionary` and `AccidentalSuggestion` are blanked beside
  `Accidental`.
- A stem may be anchored at its notehead's centre, `'(0 . 0)`. Its far end
  stays LilyPond's standard length from the head's centre. Stems are now
  drawn over noteheads, so a stem anchored inside a hollow head stays
  visible across the hole, true or false. `tests/stem-centre.ly` and
  `tests/stem-centre-false-hollow.ly` prove it on both versions.
- The MusicXML smoke tier: `tools/run_musicxml.py` converts 71 files of
  the MIT-licensed Unofficial MusicXML test suite (`tests/musicxml/`) with
  LilyPond's own musicxml2ly, adds the Kite include and engraves them.
  It runs as the suites `engine-musicxml` and `engine-musicxml-2.26`, and
  `tests/musicxml/expect.json` lists the allowed exceptions.
- The corpus gate: `tools/run_corpus.py DIR` runs the same pipeline over
  a directory of real scores before every release. It writes
  `docs/runs/corpus-<date>.md` and fails when a file that passed in the
  previous table no longer does.
- The `No viable beam quanting found` lines that grace-note beams log on a
  magnified staff (smoke files 24c–24e) are LilyPond's own issue 2383,
  not the engine's. They are documented under Known Issues, without a
  workaround.
- A key signature engraved before the score's first note now draws its
  noteheads. The trigger was a key signature at a moment with no note:
  a top staff opening on a rest or a spacer, or a staff with no notes
  (Ave Maria's second voice is all spacer rests). The display read the
  notehead config cache before the notehead engraver had filled it, so
  each of its noteheads was empty and its `-inf` width produced
  `programming error: Improbable offset for stencil: -inf staff space`
  (8 lines for a two-accidental key with the Kite config, hence counts
  in multiples of 8). The key signature was drawn as its bar alone, and
  a staff of nothing but rests made LilyPond abort. The key-signature
  engraver now refreshes the cache for the current key before it draws.
  The corpus scores and the smoke files 02a–02c and 41b now engrave
  without the error.

## 1.1.1

- Duration categories now follow the documented scale: breve 0, whole 1,
  half 2, quarter or shorter 3, taken from the duration log alone, so
  dots and tuplets no longer change a note's category. A hand-written
  config that relied on the old off-by-one numbering must change.
- A dot moved off a ledger line now moves one staff position, rather
  than counting its notehead's offset twice.
- A mid-score key change no longer changes the stem attachment of the
  notes before it.
- The test runner cannot pass a broken render: it deletes earlier renders
  before LilyPond runs, fails a multi-page render, reports drift for
  repeated ids, requires `"absent": true` for an absence check, and checks
  that `CNB_LILYPOND_X_Y` names that version.
- The harvester records what is drawn: circles, ellipses, polygons and
  polylines count toward an element's bbox, and a new `visual.shape_hash`
  covers their geometry and text. The baselines of both versions are
  updated.
- The articulation offset correction and the beam and stem compensation
  for compressed staves are removed. They did nothing on the engine's own
  staff, and every render is unchanged.
- The source zip leaves out process records and editor settings, and no
  longer contains local paths.

## 1.1.0

- LilyPond 2.26 support. The engine and the SVG harvester work on both
  2.24 and 2.26, and the unit and integration suites pass on each.
- Harvest baselines per version: `tests/*.harvested.json` for 2.24 and
  `tests/lilypond-2.26/*.harvested.json` for 2.26. The test runners take
  `--lilypond-version X.Y` and find that version through the
  `CNB_LILYPOND_X_Y` environment variable or `PATH`.

## 1.0.0

- First release.
