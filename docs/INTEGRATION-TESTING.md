# Integration Testing Pipeline

CNB's integration tests render music with LilyPond, extract structured data from the SVG output, and evaluate assertions against expected values. The pipeline has three components that work together.


## Quick Reference

```bash
# Run all integration tests:
python3 tools/run_tests.py

# Run a specific test spec:
python3 tools/run_tests.py tests/c-major-scale.json

# Verbose output (show all assertion details, not just failures):
python3 tools/run_tests.py --verbose

# Generate a golden harvest file from a known-good render:
python3 tools/run_tests.py --generate tests/c-major-scale.ly
```


## Component 1: ID Engraver (`cnb/test-ids.ly`)

A LilyPond engraver that tags every musically-relevant grob (graphical object) with a unique `id` and `data-*` attributes in the SVG output. It is included only during test runs — not in production renders.

### Usage in a Test Score

```lilypond
\include "ChromaticNotationBase.ly"
\include "cnb/test-ids.ly"        %% ← enables SVG tagging

\relative c' { c4 d e f | g a b c | }
```

### ID Format by Grob Type

| Grob Type | ID Pattern | Example |
|-----------|-----------|---------|
| NoteHead | `nh-{measure}-{beat}-{midi}-{voice}` | `nh-1-0.000-60-0` |
| Stem | `st-{measure}-{beat}-{voice}` | `st-1-0.000-0` |
| Dots | `dt-{measure}-{beat}-{midi}-{voice}` | `dt-1-0.000-60-0` |
| Accidental | `ac-{measure}-{beat}-{midi}-{voice}` | `ac-1-0.000-61-0` |
| Flag | `fl-{measure}-{beat}-{voice}` | `fl-1-0.000-0` |
| Beam | `bm-{measure}-{beat}-{voice}` | `bm-1-0.000-0` |
| Rest | `rs-{measure}-{beat}-{voice}` | `rs-1-0.000-0` |
| LedgerLine | `ll-{measure}-{beat}-{voice}` | `ll-1-0.000-0` |
| Tie | `ti-{measure}-{beat}-{midi}-{voice}` | `ti-1-0.000-60-0` |
| Slur | `sl-{measure}-{beat}-{midi}-{voice}` | `sl-1-0.000-60-0` |
| BarLine | `bl-{measure}` | `bl-2` |
| StaffSymbol | `staff-symbol` | `staff-symbol` |
| Clef | `cl-{measure}` | `cl-1` |
| KeySignature | `ks-{measure}` | `ks-1` |
| TimeSignature | `ts-{measure}` | `ts-1` |

### Field Definitions

- **measure** — bar number (integer, starting at 1)
- **beat** — position within the measure as a decimal string with 3 places (e.g., `0.000`, `0.250`, `0.500`, `0.750`), derived from LilyPond's `measurePosition` moment
- **midi** — MIDI pitch number (middle C = 60)
- **voice** — voice context id (defaults to `0` for single-voice scores)

### Data Attributes

These are injected alongside the `id` on each tagged grob:

| Attribute | Description | Example |
|-----------|-------------|---------|
| `data-type` | Grob type | `notehead`, `stem`, `barline` |
| `data-measure` | Bar number | `1` |
| `data-beat` | Beat position | `0.250` |
| `data-midi` | MIDI pitch | `60` |
| `data-pitch-class` | Pitch class 0–11 | `0` (for C) |
| `data-voice` | Voice id | `0` |
| `data-duration` | Duration log (0=whole, 1=half, 2=quarter, 3=eighth…) | `2` |

### Known Limitations

1. Multiple modules may set `after-line-breaking` on the same grob (e.g., `off-key.ly` and `test-ids.ly`). They cooperate via `cnb:chain-after-line-breaking!` (set 002), which preserves any previously-installed callback rather than overwriting it. Off-key marks are driven per note by the config procedure's `off-key-mark` field; a config that returns `#f` for every note installs no off-key callback at all.
2. `StaffSymbol` is a single grob spanning the system. Individual staff lines don't have separate grobs.
3. `LedgerLineSpanner` creates one grob for all ledger lines in a column, tagged with the first notehead's info.


## Component 2: SVG Harvester (`tools/harvest_svg.py`)

Parses a LilyPond SVG (rendered with `test-ids.ly` included), walks all nested transforms to compute absolute positions, establishes a staff-relative coordinate system, and outputs structured JSON.

```bash
# Basic usage (output to stdout):
python3 tools/harvest_svg.py output.svg

# Save to file with pretty-printing:
python3 tools/harvest_svg.py output.svg -o harvested.json --pretty

# Output only the elements array:
python3 tools/harvest_svg.py output.svg --elements-only
```

### Harvested Element Format

```json
{
  "id": "nh-1-0.000-60-0",
  "type": "notehead",
  "data": {
    "type": "notehead",
    "measure": "1",
    "beat": "0.000",
    "midi": "60",
    "pitch-class": "0",
    "voice": "0",
    "duration": "2"
  },
  "absolute": { "x": 13.762, "y": 16.045 },
  "staff_relative": {
    "measure": "1",
    "vertical": -0.9988,
    "staff_spaces_from_center": -5.995,
    "horizontal": 0.1726
  },
  "visual": {
    "color": "rgb(0.0000%, 0.0000%, 0.0000%)",
    "path_hash": "0543760854b7",
    "bbox": { "x": 13.262, "y": 15.545, "w": 1.0, "h": 1.0 }
  }
}
```

### Coordinate Systems

| System | Origin | Orientation | Description |
|--------|--------|-------------|-------------|
| Absolute | SVG top-left | Y increases downward | Raw SVG points |
| Staff-relative vertical | Bottom staff line = 0.0, top = 1.0 | Higher pitch = higher value | Normalized to staff extent |
| Staff-relative horizontal | Left barline = 0.0, right barline = 1.0 | Left-to-right | Normalized to measure width |
| `staff_spaces_from_center` | Staff center = 0.0 | Positive = above | In staff-space units |

The harvester supports multi-system scores, detecting all systems and assigning elements to the correct staff geometry.

**Important:** The harvester requires raw LilyPond SVG output. It cannot process normalized SVGs (where staff lines have been moved into `<defs>` sections).


## Component 3: Test Runner (`tools/run_tests.py`)

Orchestrates the full pipeline: renders LilyPond → harvests SVG → evaluates assertions → reports results.

### Test Spec Format

JSON files with a test name, input file, and an array of assertions:

```json
{
  "test_name": "C major scale — structural and visual validation",
  "input_file": "c-major-scale.ly",
  "assertions": [
    {
      "id": "nh-1-0.000-60-0",
      "description": "Middle C, first beat, quarter note",
      "expect": {
        "type":                    ["== 'notehead'"],
        "data.midi":               ["== '60'"],
        "staff_relative.vertical": [">= -1.05", "<= -0.95"]
      }
    }
  ]
}
```

### Assertion Expressions

Each property maps to an array of Python expression strings. Every expression must evaluate to `True` for the assertion to pass. Available variables:

| Variable | Type | Description |
|----------|------|-------------|
| `v` | any | The value of the current property |
| `el` | dict | All harvested elements, keyed by `id` |
| `prop(id, key)` | function | Cross-element property lookup, e.g., `prop('nh-1-0.000-60-0', 'data.midi')` |
| `count(type)` | function | Count elements of a given type, e.g., `count('notehead')` |
| `staff` | dict | Staff geometry (`top_line_y`, `bottom_line_y`, `center_y`, etc.) |
| `measures` | dict | Measure boundaries (`left_x`, `right_x`, `width`) |

### Expression Examples

```
Exact match:       ["== 'notehead'"]
Range:             [">= 0.0", "<= 1.0"]
Tolerance:         ["abs(v - 0.5) < 0.05"]
Cross-element:     ["v > prop('nh-1-0.000-60-0', 'staff_relative.vertical')"]
Same shape:        ["== prop('nh-1-0.000-60-0', 'visual.path_hash')"]
Element count:     ["count('notehead') == 8"]
Existence:         ["v is not None"]
Absence:           ["v is None"]
Membership:        ["v in ['#FF0000', '#0000FF']"]
```

Expressions starting with a comparison operator (`==`, `!=`, `<`, `>`, `<=`, `>=`) are automatically prefixed with `v `, so `"== 'notehead'"` becomes `"v == 'notehead'"`.


## Creating a New Integration Test

1. Write a test score (`.ly` file) that includes `ChromaticNotationBase.ly` and `cnb/test-ids.ly`.
2. Generate a golden harvest: `python3 tools/run_tests.py --generate tests/my-test.ly`
3. Review the harvested JSON to understand element IDs and positions.
4. Write a test spec (`.json` file) with assertions referencing those element IDs.
5. Run the test: `python3 tools/run_tests.py tests/my-test.json`

### Generating a Golden Baseline

```bash
python3 tools/run_tests.py --generate tests/c-major-scale.ly
```

This renders the `.ly` file, harvests the SVG, and writes a `.harvested.json` file showing all element positions and properties. Use this output to write or update assertion specs.
