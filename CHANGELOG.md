# Changelog

## 1.1.0

- LilyPond 2.26 support. The engine and the SVG harvester work on both
  2.24 and 2.26, and the unit and integration suites pass on each.
- Harvest baselines per version: `tests/*.harvested.json` for 2.24 and
  `tests/lilypond-2.26/*.harvested.json` for 2.26. The test runners take
  `--lilypond-version X.Y` and find that version through the
  `CNB_LILYPOND_X_Y` environment variable or `PATH`.

## 1.0.0

- First release.
