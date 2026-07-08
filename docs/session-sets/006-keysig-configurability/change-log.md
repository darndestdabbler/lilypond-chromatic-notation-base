# Change log — 006-keysig-configurability

## Session 1 (2026-07-08) — Enable/style switch, separator-bar styling, and anchor-octave

**Orchestrator:** claude-code / anthropic (lightweight tier, no metered calls)

### Pre-flight — `session-001/preflight-verified`

All engine facts from the spec's Project Overview re-verified against the
working tree with **zero drift**:

- `cnb-key-signature-engraver` (`cnb/keysig.ly`) renders every `\key` as
  two interleaved columns of real noteheads plus a gold separator bar
  (`cnb:keysig-markup-list`, and the engraver at the file tail).
- Unconditionally installed in the `Staff` context
  (`cnb/layout.ly:49`, `\consists \cnb-key-signature-engraver`).
- Zero key-signature settings in `cnb/config.ly` (confirmed no
  `cnb:keysig-*` defines existed).
- Hard-coded styling: `cnb:gold` (`#ffd42a`, `cnb/colors.ly:47`) and
  `thickness . 4` in the bar markup (`cnb/keysig.ly`, ~line 233 before
  this session's edits).
- Bar vertical extent was `±(cnb:spaces-per-octave)` = ±1 octave
  (`bar-y-max`/`bar-y-min` in `cnb:keysig-markup-list`).
- Tonic octave derived from `middleCPosition` via `octaves-above-mid-c`
  in `cnb:keysig-pitches`.
- Stencil cache keyed **only** by `keySignature` (`assoc-ref`), the
  documented leak risk.
- Confirmed against the Configurator's set-010 s2 D10 note that the bar
  draws through the horizontal **middle** of the two columns
  (`x-offset = max-notehead-x-offset − max-notehead-width/2`), not the
  right edge — the "at the right edge" code comment is misleading; the
  code is authoritative.

**`'standard` escape-hatch decision (spec step 2):** checked the
Configurator's set-010 records (`s2-notes.md` D11/D12). The Configurator
ships the notehead chord as its **sole** key-signature style and defers
richer custom signatures to a future set — there is **no consumer** for a
LilyPond-native sharps/flats escape hatch. Per the spec's "add only if
cheap [and wanted]", `'standard` was **not** added; `cnb:keysig-style`
stays a symbol (`'chord`/`'none`) so the valueset can grow when a consumer
appears. Decision recorded here for the Session 2 handoff.

**Test-harness note:** `test-unit.ly` did not include `cnb/keysig.ly` (the
module's pure helpers were untested); the include was added this session
so the new resolvers/geometry/pitch helpers are unit-tested.

### Style enable/suppress switch — `session-001/keysig-style-setting`

- `cnb/config.ly`: new **`cnb:keysig-style`** (symbol, default `'chord` =
  today's notehead-chord display). `'none` suppresses the key signature
  entirely — the engraver sets `stencil = #f` (mirroring the clef
  engraver's `'none`), so a Configurator config with
  `keys.keySignature.enabled: false` is finally honored engine-side.
  Unrecognized values warn and fall back to `'chord`
  (`cnb:keysig-resolved-style`, `cnb/keysig.ly`).

### Separator-bar styling — `session-001/bar-styling-settings`

Three new `cnb/config.ly` settings replace the hard-coded bar values;
each default reproduces today's geometry exactly:

- **`cnb:keysig-bar-color`** (default `cnb:gold`) → the bar color
  (`#:with-color` in `cnb:keysig-markup-list`). Maps to the
  Configurator's `keySignature.separator.color`.
- **`cnb:keysig-bar-thickness`** (default `4`) → the bar's
  `#:draw-line` thickness (multiples of output line-thickness, ≈ 0.4
  staff-space before magnification; the bar is scaled by `mag` like the
  rest of the display). Maps to `separator.thicknessPct` — the exact
  unit conversion is deferred to the Session 2 handoff record.
- **`cnb:keysig-bar-extent-semis`** (default `12`) → the bar's vertical
  **half**-extent in **semitones**, via new helper
  `cnb:keysig-bar-half-extent` = `extent-semis / semitones-per-staff-space`.
  The default `12` reproduces `±(cnb:spaces-per-octave)` — today's ±1
  octave — on **any** staff, because it divides through
  `cnb:semitones-per-staff-space` exactly like note positions. Maps to
  `separator.extentSemis`.

### Tonic-octave anchor (item 2.4) — `session-001/tonic-octave-setting`

- `cnb/config.ly`: new **`cnb:keysig-tonic-octave`** (default `#f` =
  derive from `middleCPosition`, today's behavior). An integer anchors
  the tonic notehead at that LilyPond `ly:make-pitch` octave (`0` = the
  octave starting at middle C), ignoring `middleCPosition`, so the
  Configurator can emit `keySignature.placement.tonicOctave` and close
  the documented preview/engine placement divergence for non-C tonics.
- `cnb:keysig-pitches` gained a fourth parameter `tonic-octave-override`;
  when it is an integer it replaces the derived starting `current-octave`,
  otherwise the derivation is unchanged. The engraver passes
  `cnb:keysig-tonic-octave`.

### Cache rework — `session-001/tonic-octave-setting`

- `cnb:get-key-signature-stencil`'s cache key was expanded from the bare
  `keySignature` to a composite list covering **every** stencil input:
  `keySignature`, `middleCPosition`, font `mag`,
  `cnb:semitones-per-staff-space`, and all four new settings
  (`cnb:keysig-tonic-octave`, `cnb:keysig-bar-color`,
  `cnb:keysig-bar-thickness`, `cnb:keysig-bar-extent-semis`). This closes
  the documented leak (a stale stencil would otherwise persist across
  setting changes, or across two staves with different clefs/mags). The
  cache still uses `assoc-ref`/`assoc-set!` (`equal?`), correct for the
  list key. `'none` never reaches the cache — the engraver suppresses it
  first.

### Tests, docs, verification — `session-001/tests-green`

- **Unit** (`test-unit.ly`, +33 assertions → **287 passed, 0 failed**):
  keysig setting defaults; `cnb:keysig-resolved-style` (default/`'none`/
  fallback); `cnb:keysig-bar-half-extent` (default reproduces
  `cnb:spaces-per-octave` at sps 1/2/3; non-default extents); and
  `cnb:keysig-pitches` tonic-octave math — derived tracks
  `middleCPosition`, explicit override anchors and ignores it, semitone
  shift is whole octaves only, and a non-C (D) tonic keeps its note name
  under both anchoring modes (the placement-divergence case).
- **Integration** (`tools/run_tests.py`, +2 specs → **250 passed, 0
  failed**, 353 assertions): `keysig-none` (the `key-signature` element
  is absent from the SVG under `'none`, noteheads still render);
  `keysig-bar-style` (overriding color→blue and extent→24 semitones makes
  the harvested `key-signature` element render blue with a taller bbox —
  `bbox.h` 12.5 → 24.0 — confirming the settings reach the stencil).
- **Zero golden drift:** every pre-existing `tests/*.svg` and
  `*.harvested.json` is byte-identical after the change (git status shows
  no modified goldens); defaults render exactly as before.
- `README.md`: five new rows in the configuration-variables table.

**Touches:** `cnb/config.ly`, `cnb/keysig.ly`, `test-unit.ly`,
`README.md`. **Creates:** `tests/keysig-none.{ly,json}`,
`tests/keysig-bar-style.{ly,json}` (+ rendered SVG/harvest artifacts).
`cnb/layout.ly` needed **no** change — the `'none` suppression lives in
the engraver, as with the clef module.

## Session 2 (2026-07-08) — Configurator handoff record

**Orchestrator:** claude-code / anthropic (lightweight tier, no metered calls)

### Handoff record — `session-002/handoff-recorded`

Wrote `configurator-handoff.md` enumerating the exact new engine contract
from Session 1 (every `cnb:keysig-*` setting with name/type/default/units/
semantics and `cnb/config.ly` + `cnb/keysig.ly` file/line references) and
mapping each to the Configurator's `keys.keySignature` fields. Cross-checked
against the Configurator's set-010 records
(`d:/Projects/chromatic-notation-configurator/.../010-custom-key-signatures/`,
`s1-engine-coordination.md`, `s2-notes.md` D10–D12, and
`cnb/src/cnb-config.js:171-185` / `cnb/src/cnb-key-signature.js:157-169`).

**Field mappings resolved (the two deferred from S1, plus new flags):**

- **`separator.thicknessPct` → `cnb:keysig-bar-thickness`:** derived
  `thickness = thicknessPct / (10 × semitones-per-staff-space)`; anchor
  `160 / 40 = 4` at the default staff is exact/byte-verified, off-anchor
  scaling rests on the ~0.1-staff-space-per-`#:draw-line`-unit basis
  (matches set-010's SVG measurement of 0.4 staff-space at `thickness 4`).
- **`placement.tonicOctave` → `cnb:keysig-tonic-octave`:** flagged an
  **octave-numbering mismatch** — the Configurator numbers octaves so its
  `absoluteSemi(pc, oct) = pc + oct·12` puts middle C at octave **1**
  (grid semitone 12); the engine uses the raw `ly:make-pitch` octave where
  middle C is octave **0**. The exporter must emit
  `cnb:keysig-tonic-octave = placement.tonicOctave − 1`. Verified against
  `test-unit.ly` (C tonic explicit `2` → semitones `24`; derived at `mcp 0`
  → octave `0`). Residual `middleCPosition` (clef) dependence noted for
  non-default clefs.
- **`separator.enabled: false`:** no direct engine bar-only toggle;
  flagged with the `cnb:keysig-bar-thickness 0` workaround (unverified) as
  an option for the Configurator side. `gutter.paddingH`, `dot.radiusPct`,
  and non-`"scale-from-tonic"` `placement.rule` values are preview-only.
- **`separator.color`:** direct hex passthrough (engine colors are hex
  strings; `#ffd42a` = `cnb:gold`). **`separator.extentSemis`:** 1:1.

### Backlog updated — `session-002/backlog-updated`

`docs/planning/configurator-coordination-backlog.md`: §2 gained a RESOLVED
header note; a new §5 subsection records items **2.1, 2.2, 2.4** resolved
by this set (with the contract summary and the Configurator follow-ons
still owed). Item **2.3** remains recorded as cancelled (spec revision,
2026-07-08).

### Verification (lightweight tier, out-of-band-or-none)

Full suites re-run green — **unit 287/287**, **integration 250/250** (353
assertions, 11 specs). Golden baseline **byte-stable** with default
settings: `git status` shows zero modified `tests/*.svg` / `*.harvested.json`
(the regenerated `test-unit.pdf` build artifact was reverted to keep this
commit scoped to docs).

**Per the cross-repo rule of engagement, this set does NOT bump
`docs/CNB-LY-EXPORT-SPEC-v1_2.md`** — the export-spec addendum and the
emit-if-changed exporter lines are authored Configurator-side from this
handoff.

**Creates:** `configurator-handoff.md`. **Touches:**
`docs/planning/configurator-coordination-backlog.md`,
`docs/session-sets/006-keysig-configurability/change-log.md`.
