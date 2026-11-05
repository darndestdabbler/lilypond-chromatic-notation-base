# Changelog

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
