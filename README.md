# ChromaticNotationBase (CNB)

> **Status: Release criterion met (July 2026)**
> The engine is stable and tested (179 unit + 231 integration assertions passing). The release criterion — the Configurator generates a working `.ly` config file that produces correct output end-to-end — was verified on 2026-07-05: a Configurator-exported config renders the golden test score identically to the hand-written baseline (see the [walkthrough](#end-to-end-walkthrough-rendering-an-exported-config) below).

A configurable engine for chromatic music notation in LilyPond.

CNB is not a single notation system — it is infrastructure for building chromatic notation systems from declarative configuration, rather than bespoke rendering code. **Kite notation** — an original system devised for this project (see the disambiguation note in [Acknowledgments](#acknowledgments); it is not affiliated with the unrelated xenharmonic/microtonal theorist who separately publishes work under the same name) — is the only notation system with a complete, working configuration in this repo today (`Kite-4-369-Notation-Procedure.ly`). The architecture is also designed with an eye toward supporting systems with characteristics similar to Paul Morris's Clairnote SN and Jan Braunstein's Chromatic Lyre Notation, cited below as examples of what a config-driven chromatic notation can look like — no working configuration for either exists in this repo yet, and neither author has reviewed or endorsed this project. The goal is shared infrastructure so that designing a new notation means writing a config file, not building a rendering engine from scratch.


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
- **Procedure-oriented configuration** — a single `(semitone, duration, key) → config` procedure with named symbolic references drives all notehead rendering
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


## End-to-End Walkthrough: Rendering an Exported Config

This is the render half of the three-tool pipeline — the same path used to
verify the ecosystem's shared release gate (a Configurator-designed system
rendered through this engine, matching the golden baseline exactly). The
design half (authoring a shape in Inkscape, importing it, designing the
notation, exporting the `.ly` config) lives in the
[Configurator repository's README](https://github.com/darndestdabbler/chromatic-notation-configurator#end-to-end-walkthrough-from-shape-to-rendered-score)
— link, don't duplicate.

### 1. Install the engine

Install [LilyPond 2.24.x](https://lilypond.org/download.html) and clone
this repository. There is no build step — the engine is the `cnb/` module
tree loaded by `ChromaticNotationBase.ly`. Python 3.8+ is only needed for
the verification tooling (step 5).

### 2. Obtain an exported config

In the Configurator, **Export .ly** produces a config file conforming to
[CNB-LY-EXPORT-SPEC-v1_2.md](docs/CNB-LY-EXPORT-SPEC-v1_2.md). A checked-in
example is [`kite-4-369-from-configurator.ly`](kite-4-369-from-configurator.ly)
— generated by the Configurator's exporter with zero hand edits.

### 3. Include it from a score

Place the exported config in this repository's root (next to
`ChromaticNotationBase.ly`, which it `\include`s itself) and reference it
from your music file:

```lilypond
\version "2.24.2"
\include "kite-4-369-from-configurator.ly"  % loads the engine itself

\relative {
  \clef treble
  \key d \major
  d''4 cis8. b16 | a4. g8 | fis4 e | d2
}
```

A complete example is [`tests/joy-to-the-world-configurator.ly`](tests/joy-to-the-world-configurator.ly).

### 4. Render (with or without accessible colors)

```bash
lilypond my-score.ly                 # PDF
lilypond -dbackend=svg my-score.ly   # SVG (used by the test tooling)
```

Exported configs carry a colorblind-safe alternative palette. To render
with it, set the flag **before** the `\include` (see
[Accessible Colors](#accessible-colors)):

```lilypond
#(define cnb:use-accessible-colors #t)
\include "kite-4-369-from-configurator.ly"
```

### 5. Verify against the golden baseline (optional)

The integration tooling turns a rendered SVG into structured JSON and
evaluates assertions against it — this is how the pipeline's release gate
was verified:

```bash
python3 tools/run_tests.py tests/joy-to-the-world-configurator.json
```

That spec runs the golden score's 74 assertions against the
Configurator-exported config's rendering. The harvested output
(`tests/joy-to-the-world-configurator.harvested.json`) matches the
hand-written golden config's harvest
(`tests/joy-to-the-world.harvested.json`) element-for-element: 191/191
element ids with identical types, pitches, colors, positions, bounding
boxes, path-shape hashes, staff geometry, and measure boundaries.
See [docs/INTEGRATION-TESTING.md](docs/INTEGRATION-TESTING.md) for the
harvest/assertion pipeline itself.


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

The alist may also carry optional fields: `(repeat . #f)` suppresses multi-notehead repetition for half/whole notes, and `(x-offset . N)` moves the notehead (with its stem and spacing) horizontally by `N` staff spaces — used by pitch-axis configs to disambiguate shared-position pitches (missing field = 0 = no offset; see `cnb/procedure.ly` and the X-OFFSET SUPPORT notes in `cnb/noteheads.ly`).

### Registration API

Before the procedure, the config file registers named definitions that the procedure references symbolically:

| Function | Purpose | Definition Table |
|----------|---------|------------------|
| `cnb:register-path!` | Register a notehead path | `cnb:path-defs` |
| `cnb:register-hollow!` | Register a hollow cutout path | `cnb:hollow-defs` |
| `cnb:register-attachment!` | Register stem attachment points (4-point model) | `cnb:attachment-defs` |
| `cnb:register-color!` | Register a named color | `cnb:color-defs` |
| `cnb:register-off-key-mark!` | Register a custom off-key mark | `cnb:off-key-mark-defs` |
| `cnb:register-clef!` | Register a custom clef glyph (path + top-edge anchor) | `cnb:clef-defs` |

A custom clef definition is an alist: required `(path . <command list>)` (same format as notehead paths) and `(anchor-semitones . <number>)` — the semitone position of the glyph's **top edge**, a float per the Configurator's anchor contract — plus optional `(height-semitones . <positive number>)` (design height; the explicit `cnb:clef-size-semitones` override wins) and `(color . "#RRGGBB")`. Select it with `cnb:clef-style 'custom` + `cnb:clef-name`.

### Engine Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `cnb:semitones-per-staff-space` | `2` | Semitones per staff space |
| `cnb:staff-line-positions` | `'(-4 -2 0 2 4)` | Staff line positions (half-staff-spaces from center) |
| `cnb:ledger-positions` | `'()` | Ledger candidates (empty = auto-generate from staff pattern) |
| `cnb:get-pitch-staff-position` | `#f` | Pitch-axis hook: a procedure `(semitone) → staff position` (half-staff-spaces from center, octave anchor baked in, used as-is — not adjusted by `middleCPosition`) replaces the linear formula at every placement site — noteheads, key-signature marks, and custom-clef anchors (fractional anchors interpolate between integer semitones); `#f` = the linear `cnb:semitones-per-staff-space` formula |
| `cnb:default-magnify` | `7/4` | Global magnification factor |
| `cnb:false-hollow` | `#f` | Use white-overlay hollows for angular shapes |
| `cnb:multinote-padding` | `-0.5` | Spacing between multi-noteheads |
| `cnb:collision-threshold` | `2` | Note collision detection threshold |
| `cnb:clef-style` | `'dozenal` | Clef display: `'dozenal` (computed register numeral), `'text` (render `cnb:clef-text`), `'none` (no clef stencil), or `'custom` (registered glyph named by `cnb:clef-name`) |
| `cnb:clef-text` | `""` | Label for `'text` clef mode (a string renders bold; a markup is used as-is) |
| `cnb:clef-size-semitones` | `#f` | Clef display height in semitones (`#f` = legacy 3 staff-spaces for `'dozenal`/`'text`, or the registered definition's own height for `'custom`) |
| `cnb:clef-name` | `#f` | Which registered custom clef to display in `'custom` style (see `cnb:register-clef!`) |
| `cnb:clef-gutter-semitones` | `#f` | Extra blank space after the clef, in semitones (`#f` = legacy spacing); applies to every rendered clef style |
| `cnb:keysig-style` | `'chord` | Key-signature display: `'chord` (notehead-chord display) or `'none` (suppress entirely, so a Configurator `keys.keySignature.enabled: false` is honored) |
| `cnb:keysig-bar-color` | `cnb:gold` | Color of the separator bar drawn through the two notehead columns |
| `cnb:keysig-bar-thickness` | `4` | Separator-bar thickness, in LilyPond `#:draw-line` units (≈ 0.4 staff-space before magnification) |
| `cnb:keysig-bar-extent-semis` | `12` | Separator-bar half-extent in semitones; `12` = today's ±1 octave on any staff |
| `cnb:keysig-tonic-octave` | `#f` | Tonic-octave anchor: `#f` derives from `middleCPosition` (middle-C anchoring); an integer anchors the tonic notehead at that LilyPond octave (`0` = the middle-C octave) |
| `cnb:use-accessible-colors` | `#f` | Use a config's colorblind-safe alternative palette (see below) |
| `cnb:indent` | `0` | First system left indent (staff-spaces) |
| `cnb:file-suffix` | `"-Oval-2-024-Notation"` | Appended to output filenames |
| `cnb:notation-label` | `"Oval 2-024 Notation"` | Human-readable notation name |
| `cnb:notation-footnote` | *(descriptive string)* | Footnote text for notation parameters |

> **Note:** The procedure model is the engine's only configuration model. Off-key marking is expressed per note by the configuration procedure's `off-key-mark` field (not a global flag) — see [CNB-LY-EXPORT-SPEC-v1_2.md](docs/CNB-LY-EXPORT-SPEC-v1_2.md) and `cnb/procedure.ly`. Every Configurator export begins with `#(set! cnb:use-procedure-model #t)`; that variable is retained as a permanent, documented no-op so existing exports keep working, but the engine no longer branches on it. The legacy vector-cycling model was removed in set 007 (its reference config `Kite-4-369-Notation-Clean.ly` was retired in favor of `Kite-4-369-Notation-Procedure.ly`).

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
├── test-unit.ly                      Unit test suite (303 assertions)
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

254 assertions covering: utility functions, path geometry, ledger line generation, key pitch class computation, config defaults, registration and resolution, config caching, clef style/size settings, and custom-clef registration (anchor placement, size precedence, gutter padding, stencil geometry).

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

1. **Comment syntax in Scheme blocks** — Inside `#(define ...)` blocks, use `;;` for comments, not `%%`. The `%%` style is only valid in LilyPond context. If you see "source expression failed to match any pattern", check for stray `%%` inside Scheme code.

2. **Multi-system SVG harvesting** — Edge cases exist with elements spanning system breaks. The harvester handles multiple systems but some boundary conditions may produce incorrect staff-relative coordinates.


## Related Projects

| Repository | Description |
|------------|-------------|
| [inkscape-music-glyph-toolkit](https://github.com/darndestdabbler/inkscape-music-glyph-toolkit) | Inkscape extension for converting SVG notehead shapes to LilyPond paths and standardized SVGs for import into the Configurator |
| [chromatic-notation-configurator](https://github.com/darndestdabbler/chromatic-notation-configurator) | JavaScript tool for designing chromatic notation systems and generating `.ly` config files for this engine |
| [lilypond-chromatic-notation-base](https://github.com/darndestdabbler/lilypond-chromatic-notation-base) | This project — the LilyPond rendering engine |


## Acknowledgments

A few of this engine's LilyPond modules (`cnb/articulations.ly`,
`cnb/beams.ly`, `cnb/stems.ly`, `cnb/ledgers.ly`) were written after
studying how other chromatic-notation LilyPond implementations solve the
same rendering problems (ledger-line collision avoidance, beam/stem
compensation on compressed staves). Each of those files documents which
prior art informed it and, where relevant, how this engine's implementation
differs. None of them share code with, or are translations of, the
projects below — see each file's header comment for specifics.

- **Paul Morris** — creator of Clairnote SN notation
  ([clairnote.org](https://clairnote.org); the notation system design and
  site content are CC BY-SA 4.0). His separate LilyPond implementation,
  [`clairnote.ly`](https://github.com/PaulMorris/LilyPond-Clairnote), is
  licensed **GPL v3** — a different, stronger-copyleft license than the
  notation design itself. This project is not affiliated with or endorsed
  by Paul Morris.
- **Jan Braunstein** — creator of Chromatic Lyre Notation, documented via
  [The Music Notation Project](https://musicnotation.org/system/chromatic-lyre-notation-by-jan-braunstein/),
  with a separate LilyPond implementation
  ([`lyrebird.ly`](https://github.com/scaleshift-scores/scaleshift_conversion_scripts/blob/main/chromaticlyre.ly))
  that carries no license header. This project is not affiliated with or
  endorsed by Jan Braunstein.
- **The Music Notation Project** — criteria and community for alternative
  notation systems.

No configuration in this repo reproduces Clairnote SN or Chromatic Lyre
Notation, and no code from either project's LilyPond implementation is
copied or translated here.

> **Naming note:** "Kite notation" in this repo (`Kite-4-369-Notation-*.ly`) is an original system devised for this project. It is unrelated to Kite Giedraitis, a xenharmonic/microtonal music theorist who separately publishes notation and tuning work under the name "Kite."


## License

This work is dedicated to the public domain under the [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/) license — see the [`LICENSE`](LICENSE) file for the full legal text. To the extent possible under law, the author has waived all copyright and related or neighboring rights to this work.

Note: this dedication covers this project's own original code only. LilyPond itself (which renders the `.ly` files here) is separately licensed GPL v2+; authoring input/config files that LilyPond processes is the standard, well-established case of *not* creating a derivative work of LilyPond (comparable to writing a document in a GPL word processor) — no obligation flows from LilyPond's license onto this repo's own files.
