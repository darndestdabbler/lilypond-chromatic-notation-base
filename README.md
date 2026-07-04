# ChromaticNotationBase (CNB)

> **Status: Work in Progress (February 2026)**
> The engine is stable and tested (163 assertions passing). The three-tool pipeline — Inkscape extension, web-based Configurator, and this engine — is under active development. CNB will not be formally released until the Configurator can generate a working `.ly` config file that produces correct output end-to-end.

A configurable engine for chromatic music notation in LilyPond.

CNB is not a single notation system — it is infrastructure that can produce multiple chromatic notation systems (Kite, Clairnote SN, Chromatic Lyre, and others) from declarative configuration. The goal is shared infrastructure so that designing a new notation means writing a config file, not building a rendering engine from scratch.


## Three-Tool Pipeline

CNB is one part of a three-tool workflow. Each tool has a focused responsibility, and the tools communicate through well-defined file contracts:

```
┌─────────────────────────────────────────────────────┐
│  INKSCAPE + MUSIC GLYPH TOOLKIT                     │
│                                                     │
│  Knows: Geometry, paths, semitone scaling, stems    │
│  Produces: Clean SVG with data-* attributes         │
│  Doesn't know: Pitch classes, colors, staff layout  │
└─────────────────┬───────────────────────────────────┘
                  │ .svg files (one per shape variant)
                  ▼
┌─────────────────────────────────────────────────────┐
│  CHROMATIC NOTATION CONFIGURATOR                    │
│                                                     │
│  Knows: Pitch assignment, colors, staff geometry,   │
│         duration rules, LilyPond code generation    │
│  Consumes: SVG data-* attributes (trusts geometry)  │
│  Produces: .ly config file + .json save file        │
│  Doesn't know: How to normalize SVGs                │
└─────────────────┬───────────────────────────────────┘
                  │ .ly config file
                  ▼
┌─────────────────────────────────────────────────────┐
│  CNB ENGINE (LilyPond/Scheme)          ← YOU ARE HERE│
│                                                     │
│  Knows: Rendering, positioning, engraving           │
│  Consumes: Procedure-model config                   │
│  Produces: PDF / SVG / PNG                          │
└─────────────────────────────────────────────────────┘
```

**What was hard before CNB:** Converting SVG paths to Scheme format by hand. Calculating stem attachment points manually. Writing modulus-cycling logic in Scheme. Debugging visual output without structured IDs. All of this required deep Scheme knowledge and tedious trial-and-error.

**What CNB makes easy:** The Inkscape extension normalizes paths, computes stem anchors, and pre-bakes LilyPond code. The Configurator assigns shapes to pitches, defines staff geometry, and generates the config file. The engine renders music. The notation designer focuses on creative decisions.


## What CNB Provides

- **Chromatic staff positioning** — configurable semitones-per-staff-space (any integer)
- **Procedure-oriented configuration** — a single `(semitone, duration, key) → config` procedure with named symbolic references, replacing the legacy vector-cycling model
- **Custom notehead stencils** — shape, color, and hollow cycling by pitch class, duration, and key
- **Double/quadruple noteheads** — half notes render as 2 noteheads, whole notes as 4 (configurable)
- **Proximity-based ledger lines** — ledger visibility determined by notehead proximity to staff
- **Per-line staff/ledger styling** — individual thickness, color, and dash patterns per line
- **Dozenal clef symbols** — base-12 clef notation
- **Notehead-based key signatures** — seventh chord stacks
- **Off-key note indicators** — 6 display modes for marking out-of-key notes (`none`, `standard`, `dot`, `ring`, `tick`, `custom`)
- **Engraving corrections** — beam thickness/spacing compensation, articulation Y-offset correction, augmentation dot avoidance


## Requirements

- **LilyPond 2.24.x** (tested with 2.24.2) — [download](https://lilypond.org/download.html)
- **Python 3.8+** — for the integration testing tools

```bash
lilypond --version
python3 --version
```


## Quick Start

Config files (like `Kite-4-369-Notation-Procedure.ly`) include `ChromaticNotationBase.ly`, which loads all engine modules. Your music file only needs to include the config:

```lilypond
\version "2.24.2"
\include "Kite-4-369-Notation-Procedure.ly"

\relative c' {
  c4 d e f g a b c
}
```

Render from the command line:

```bash
# PDF (default):
lilypond my-score.ly

# SVG (needed for testing and inspection):
lilypond -dbackend=svg my-score.ly

# PNG:
lilypond -dbackend=eps -dno-gs-load-fonts -dinclude-eps-fonts --png my-score.ly
```

Output files appear in the current directory.


## Configuration Model

CNB uses a **procedure-oriented configuration model**. A single Scheme procedure maps `(semitone, duration, key)` to a configuration alist containing named symbolic references:

```scheme
#(set! cnb:get-notehead-config
   (lambda (semitone duration key)
     (let ((pc (modulo semitone 12)))
       (cond
         ((memv pc '(0 4 8))
          '((shape      . kite-up)
            (color      . shamrock-1b9e77)
            (hollow     . #f)
            (attachment . kite-up-attach)
            (off-key-mark . #f)))
         ;; ... more pitch class groups
         ))))
```

Config files are meant to be **generated by the Chromatic Notation Configurator** — you should not need to write them by hand. See [CNB-LY-EXPORT-SPEC-v1_2.md](docs/CNB-LY-EXPORT-SPEC-v1_2.md) for the full file format specification, and `Kite-4-369-Notation-Procedure.ly` for a complete working example.

### Registration API

Before the procedure, the config file registers named definitions that the procedure references symbolically:

| Function | Purpose | Definition Table |
|----------|---------|------------------|
| `cnb:register-path!` | Register a notehead path | `cnb:path-defs` |
| `cnb:register-hollow!` | Register a hollow cutout path | `cnb:hollow-defs` |
| `cnb:register-attachment!` | Register stem attachment points (4-point model) | `cnb:attachment-defs` |
| `cnb:register-color!` | Register a named color | `cnb:color-defs` |
| `cnb:register-off-key-mark!` | Register a custom off-key mark | `cnb:off-key-mark-defs` |

### Engine Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `cnb:semitones-per-staff-space` | `2` | Semitones per staff space |
| `cnb:staff-line-positions` | `'(-4 -2 0 2 4)` | Staff line positions (half-staff-spaces from center) |
| `cnb:ledger-positions` | `'()` | Ledger candidates (empty = auto-generate from staff pattern) |
| `cnb:default-magnify` | `7/4` | Global magnification factor |
| `cnb:false-hollow` | `#f` | Use white-overlay hollows for angular shapes |
| `cnb:multinote-padding` | `-0.5` | Spacing between multi-noteheads |
| `cnb:collision-threshold` | `2` | Note collision detection threshold |
| `cnb:off-key-indicator` | `'none` | Off-key flag mode |
| `cnb:use-accessible-colors` | `#f` | Use a config's colorblind-safe alternative palette (see below) |
| `cnb:indent` | `0` | First system left indent (staff-spaces) |
| `cnb:file-suffix` | `"-Oval-2-024-Notation"` | Appended to output filenames |
| `cnb:notation-label` | `"Oval 2-024 Notation"` | Human-readable notation name |
| `cnb:notation-footnote` | *(descriptive string)* | Footnote text for notation parameters |

> **Note:** The engine currently supports both the procedure model (`cnb:use-procedure-model #t`) and a legacy vector-cycling model. The reference config uses the procedure model. Vector model support will be removed in a future release.

### Accessible Colors

Configs exported by the Configurator can carry two color palettes: the primary palette and a colorblind-safe alternative. The exported config registers one or the other at `\include` time based on `cnb:use-accessible-colors` (default `#f`, defined in `cnb/config.ly`).

Because the conditional executes when the config file is included, the flag must be set **before** the `\include`:

```lilypond
#(define cnb:use-accessible-colors #t)
\include "MyNotation.ly"
{ c'4 d' e' f' }
```

The exported conditional guards with `(defined? 'cnb:use-accessible-colors)`, so configs work whether or not the engine defines the flag, and the flag has no effect on configs that don't include the conditional color-registration block. See [CNB-LY-EXPORT-SPEC-v1_2.md](docs/CNB-LY-EXPORT-SPEC-v1_2.md) (Section A, "Accessible color switching") for the Configurator-side format.


## Project Structure

```
├── ChromaticNotationBase.ly          Main engine entry point
├── Kite-4-369-Notation-Procedure.ly  Reference config (Kite notation, procedure model)
├── test-unit.ly                      Unit test suite (163 assertions)
├── README.md                         This file
│
├── cnb/                              Engine modules (17 files, loaded in dependency order)
│   ├── utils.ly                      Math, list, color, and caching utilities
│   ├── colors.ly                     Named color palette (hex strings)
│   ├── config.ly                     All configurable variables with defaults
│   ├── procedure.ly                  Procedure-oriented config infrastructure
│   ├── path-geometry.ly              Path winding detection, reversal, normalization
│   ├── stencils.ly                   Notehead stencil construction and caching
│   ├── noteheads.ly                  Notehead engraver (positions + renders notes)
│   ├── stems.ly                      Stem attachment points and length compensation
│   ├── clefs.ly                      Dozenal clef number system and engraver
│   ├── ledgers.ly                    Proximity-based ledger line visibility
│   ├── staff.ly                      Staff lines, ledger lines, and their engravers
│   ├── keysig.ly                     Notehead-based key signatures and engraver
│   ├── beams.ly                      Beam thickness/spacing compensation
│   ├── articulations.ly              Articulation Y-offset correction
│   ├── dots.ly                       Augmentation dot avoidance for ledger lines
│   ├── off-key.ly                    Off-key note flags (configurable indicators)
│   └── layout.ly                     Engraver registration and paper settings
│
├── scores/                           Example music files
│   └── joy-to-the-world.ly           Test score used for validation
│
├── tests/                            Integration test specs, reference SVGs, and harvested data
│
├── tools/                            Developer utilities (SVG harvester, integration test runner)
│
└── docs/
    ├── CNB-LY-EXPORT-SPEC-v1_2.md    Config file format specification
    ├── CNB-PROJECT-PLAN-20260224.md   Architecture plan and roadmap
    └── INTEGRATION-TESTING.md         Integration test pipeline documentation
```


## Module Dependency Order

Modules are loaded in this exact order by `ChromaticNotationBase.ly`. Each module depends only on modules loaded before it:

```
utils.ly → colors.ly → config.ly → procedure.ly → path-geometry.ly →
stencils.ly → noteheads.ly → stems.ly → clefs.ly → ledgers.ly →
staff.ly → keysig.ly → beams.ly → articulations.ly → dots.ly →
off-key.ly → layout.ly
```


## Testing

### Unit Tests

```bash
lilypond test-unit.ly
```

163 assertions covering: utility functions, path geometry, ledger line generation, key pitch class computation, config defaults, registration and resolution, and config caching.

### Integration Tests

The integration pipeline renders music with LilyPond, extracts structured data from the SVG output, and evaluates assertions against expected values:

```bash
# Run all integration tests:
python3 tools/run_tests.py

# Run a specific test:
python3 tools/run_tests.py tests/c-major-scale.json

# Verbose output:
python3 tools/run_tests.py --verbose
```

The pipeline consists of three components: an ID engraver (`cnb/test-ids.ly`) that tags SVG output with structured metadata, an SVG harvester (`tools/harvest_svg.py`) that extracts element positions and properties, and a test runner (`tools/run_tests.py`) that orchestrates the full render → harvest → assert cycle.

See [docs/INTEGRATION-TESTING.md](docs/INTEGRATION-TESTING.md) for full documentation of the testing pipeline, assertion format, coordinate systems, and how to create new tests.


## Known Issues

1. **`test-ids.ly` / `off-key.ly` callback collision** — Both modules set `after-line-breaking` on NoteHead grobs. When both are active, the last one wins. Fix planned: callback chaining.

2. **Comment syntax in Scheme blocks** — Inside `#(define ...)` blocks, use `;;` for comments, not `%%`. The `%%` style is only valid in LilyPond context. If you see "source expression failed to match any pattern", check for stray `%%` inside Scheme code.

3. **Multi-system SVG harvesting** — Edge cases exist with elements spanning system breaks. The harvester handles multiple systems but some boundary conditions may produce incorrect staff-relative coordinates.

4. **Legacy vector model coexistence** — The engine still contains the vector-cycling configuration model alongside the procedure model. Both code paths are maintained until the vector model is removed in a future release.


## Planned Features

- **Colorblind-safe accessible colors** — A `cnb:use-accessible-colors` flag that switches registered colors to colorblind-safe alternatives at runtime. The Configurator will generate a conditional block in the exported `.ly` file; the engine just needs the flag. See [BATON-ENGINE-ACCESSIBLE-COLORS.md](BATON-ENGINE-ACCESSIBLE-COLORS.md) for the design.

- **Vector model removal** — Once the Configurator generates procedure-model configs end-to-end, the legacy vector-cycling branches will be stripped from all engine modules.


## Related Projects

| Repository | Description |
|------------|-------------|
| [inkscape-music-glyph-toolkit](https://github.com/darndestdabbler/inkscape-music-glyph-toolkit) | Inkscape extension for converting SVG notehead shapes to LilyPond paths and standardized SVGs for import into the Configurator |
| [chromatic-notation-configurator](https://github.com/darndestdabbler/chromatic-notation-configurator) | JavaScript tool for designing chromatic notation systems and generating `.ly` config files for this engine |
| [lilypond-chromatic-notation-base](https://github.com/darndestdabbler/lilypond-chromatic-notation-base) | This project — the LilyPond rendering engine |


## Acknowledgments

- **Paul Morris** — Clairnote music notation and LilyPond implementation
- **Jan Braunstein** — Chromatic Lyre (LyreBird) notation and LilyPond implementation
- **The Music Notation Project** — Criteria and community for alternative notation systems


## License

This work is dedicated to the public domain under the [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/) license. To the extent possible under law, the author has waived all copyright and related or neighboring rights to this work.
