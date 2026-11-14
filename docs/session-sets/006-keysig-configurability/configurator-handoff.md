# Configurator handoff — key-signature engine contract (set 006)

**From:** `lilypond-chromatic-notation-base`, set
`006-keysig-configurability`, Session 1 (commit `60cce87`).
**To:** `chromatic-notation-configurator` — to author the LY export-spec
addendum and the emit-if-changed exporter lines for the
`keys.keySignature` section.
**Date:** 2026-07-08. **Tier:** lightweight (no metered calls).

> **Cross-repo rule of engagement (unchanged from set 005):** the
> `docs/CNB-LY-EXPORT-SPEC-v1_2.md` version-note addendum and the
> emit-if-changed exporter lines are authored **Configurator-side** from
> this record. This set does **not** bump the export spec. This file is
> the engine-contract source of truth for that Configurator work.

This handoff enumerates every new `cnb:` setting Session 1 landed (exact
name, type, default, units, semantics, file/line references), maps each to
the Configurator's `keySignature` fields, and — per spec step 2 — flags
every preview/engine semantic mismatch **explicitly** rather than
silently adapting either side.

---

## 1. The new engine contract (all default to today's behavior)

Every setting lives in
[`cnb/config.ly`](../../../cnb/config.ly) under the new
`KEY SIGNATURE DISPLAY SETTINGS` block (lines 165–222); the resolvers,
helpers, and cache live in [`cnb/keysig.ly`](../../../cnb/keysig.ly). With
no overrides the golden baseline is byte-identical (verified: zero
modified goldens; unit 287/287, integration 250/250).

| # | Setting | Type | Default | Meaning |
|---|---------|------|---------|---------|
| 2.1 | `cnb:keysig-style` | symbol | `'chord` | `'chord` = today's notehead-chord display; `'none` = suppress the key signature entirely (engraver sets `stencil #f`). Unknown values warn and fall back to `'chord`. |
| 2.2a | `cnb:keysig-bar-color` | color (hex string) | `cnb:gold` (`"#ffd42a"`) | Separator-bar color. |
| 2.2b | `cnb:keysig-bar-thickness` | number | `4` | Separator-bar thickness in LilyPond `#:draw-line` thickness units (multiples of output line-thickness; ≈ 0.1 staff-space per unit, so `4` ≈ 0.4 staff-space before magnification). Scaled by font `mag` like the rest of the display. |
| 2.2c | `cnb:keysig-bar-extent-semis` | number | `12` | Vertical **half**-extent of the bar in **semitones**: the bar spans `-N…+N` semitones around the staff center. `12` reproduces today's ±1-octave geometry on **any** staff (divided through `cnb:semitones-per-staff-space`). |
| 2.4 | `cnb:keysig-tonic-octave` | `#f` \| integer | `#f` | `#f` = derive the tonic octave from `middleCPosition` (today's middle-C anchoring). An integer anchors the tonic notehead at that LilyPond `ly:make-pitch` octave (**0 = the octave starting at middle C**), ignoring `middleCPosition`. |

Item **2.3 (simple-mark "dot" style) is CANCELLED** — no engine mode was
added; the Configurator ships the note stack as its sole style (set-010
s2 D11). `cnb:keysig-style` stays a **symbol** (not a boolean) so the
valueset can grow when a consumer for a new style appears.

### Deviations from the backlog's proposed shapes

- **No `'standard` (LilyPond-native sharps/flats) escape hatch.** Spec
  step 2 said "add only if cheap [and wanted]." The Configurator's set-010
  (D11/D12) ships the notehead chord as its sole style and defers richer
  custom signatures — **no consumer exists**, so it was not added. Add a
  `'standard` value here only when a consumer does.
- **Bar extent is expressed in semitones** (`cnb:keysig-bar-extent-semis`,
  default `12`), not staff-spaces, deliberately to align 1:1 with the
  Configurator's `separator.extentSemis`.
- **Bar thickness stays in `#:draw-line` units** (default `4`), not
  staff-spaces or percent — see the conversion in §2.

### Key implementation facts (file/line)

- **Style resolver:** `cnb:keysig-resolved-style`
  ([`cnb/keysig.ly:56`](../../../cnb/keysig.ly)) — validates the symbol,
  warns + falls back to `'chord`.
- **`'none` suppression:** in the engraver
  ([`cnb/keysig.ly:336`](../../../cnb/keysig.ly)) — when the resolved
  style is `'none`, the grob's `stencil` is set to `#f` (mirroring the
  clef engraver's `'none`). `'none` **never reaches the cache**.
- **Bar half-extent helper:** `cnb:keysig-bar-half-extent`
  ([`cnb/keysig.ly:69`](../../../cnb/keysig.ly)) =
  `cnb:keysig-bar-extent-semis / cnb:semitones-per-staff-space`.
- **Bar draw:** `#:with-color cnb:keysig-bar-color` +
  `#:override thickness cnb:keysig-bar-thickness` +
  `#:draw-line 0 . (2 × bar-y-max)`
  ([`cnb/keysig.ly:264-267`](../../../cnb/keysig.ly)). The bar is drawn
  through the horizontal **middle** of the two columns
  (`x = max-notehead-x-offset − width/2`,
  [`cnb/keysig.ly:258`](../../../cnb/keysig.ly)), **beneath** the
  noteheads — confirming set-010 s2 D10. (The nearby "at the right edge"
  code comment is misleading; the code is authoritative.)
- **Tonic-octave anchor:** `cnb:keysig-pitches` gained a fourth
  `tonic-octave-override` parameter
  ([`cnb/keysig.ly:97-108`](../../../cnb/keysig.ly)); an integer replaces
  the derived starting octave (`ly:make-pitch` octave), otherwise the
  `middleCPosition`-derived octave is used. The engraver passes
  `cnb:keysig-tonic-octave`.
- **Cache key rework:** `cnb:get-key-signature-stencil`'s cache key was
  expanded from the bare `keySignature` to a composite covering **every**
  stencil input — `keySignature`, `middleCPosition`, font `mag`,
  `cnb:semitones-per-staff-space`, and all four new settings
  ([`cnb/keysig.ly:301-308`](../../../cnb/keysig.ly)) — closing the
  documented stale-stencil leak.

---

## 2. Field mapping: Configurator `keys.keySignature` → engine setting

Configurator defaults are read from
`chromatic-notation-configurator/cnb/src/cnb-config.js:171-185`.

| Configurator field | Default | Engine setting | Conversion |
|--------------------|---------|----------------|------------|
| `keySignature.enabled: false` | `false` | `cnb:keysig-style` | `false` → `'none`; `true` → `'chord` (the engine default — emit nothing or `'chord`). |
| `keySignature.style: "notehead-chords"` | `"notehead-chords"` | `cnb:keysig-style` | Single-value vocab; maps to `'chord`. No separate emission needed while it is the only style. |
| `separator.color` | `"#ffd42a"` | `cnb:keysig-bar-color` | **Direct** — engine colors are hex strings; emit the hex verbatim. Default `#ffd42a` = `cnb:gold`. |
| `separator.thicknessPct` | `160` | `cnb:keysig-bar-thickness` | **`thickness = thicknessPct / (10 × semitones-per-staff-space)`** — see below. At the default staff (sps 4): `160 / 40 = 4`. |
| `separator.extentSemis` | `12` | `cnb:keysig-bar-extent-semis` | **Direct 1:1** (both are semitone half-extents). |
| `placement.tonicOctave` | `null` | `cnb:keysig-tonic-octave` | `null` → `#f`. **Integer → `tonicOctave − 1`** (octave-numbering offset — see §3.2). |
| `placement.rule: "scale-from-tonic"` | `"scale-from-tonic"` | *(none)* | Engine hard-implements this rule; no setting. |
| `separator.enabled` | `true` | *(none)* | **No engine bar-only toggle — see §3.3.** |
| `gutter.paddingH` | `12` | *(none)* | Preview-only; the engine bar contributes no gutter width (set-010 D10). |
| `dot.radiusPct` | — | *(none)* | Preview-only; item 2.3 cancelled — no engine dot mode. |

### thicknessPct conversion — derivation

The Configurator's `thicknessPct` is in **semitone units** (160% of a
semitone = 0.4 staff-space at the default staff's 4 semitones/space —
`cnb-config.js:167-168`). The engine's `cnb:keysig-bar-thickness` is a
**`#:draw-line` thickness** (≈ 0.1 staff-space per unit), independent of
`semitones-per-staff-space`. Equating the physical staff-space thickness:

```
staff-space = 0.1 × thickness            (engine)
staff-space = (thicknessPct/100) / S     (Configurator; S = semitones-per-staff-space)
⇒  thickness = thicknessPct / (10 × S)
```

- **Anchor (exact, byte-verified):** `thicknessPct 160`, `S 4` → `thickness 4`
  = today's bar.
- **Off-anchor scaling** relies on the ~0.1-staff-space-per-`#:draw-line`-unit
  basis (an empirical LilyPond constant, matching set-010's SVG
  measurement of 0.4 staff-space at `thickness 4`). Before pinning
  non-default thickness by test, the Configurator team should confirm one
  non-default value against an actual engine render.

---

## 3. Flagged preview/engine semantic mismatches

Per spec step 2, these are surfaced explicitly, not silently adapted.

### 3.1 — `style` / `enabled` are two Configurator fields, one engine symbol

The Configurator has both `keySignature.enabled` (bool) and
`keySignature.style` (`"notehead-chords"`). The engine collapses these
into one symbol `cnb:keysig-style`: `enabled:false` → `'none`;
`enabled:true` + `style:"notehead-chords"` → `'chord`. When the
Configurator adds a second style, both sides will need a value-by-value
map — today it is 1:1.

### 3.2 — `tonicOctave` uses a different octave-numbering convention (−1 offset)

**The integer conventions differ by 1.** The Configurator numbers octaves
so that its `absoluteSemi(pc, oct) = pc + oct·12` with grid **semitone 12
= middle C** — i.e. **octave 1 = the middle-C register**
(`cnb-key-signature.js:157-169`, `cnb-music.js:54`). The engine uses the
raw `ly:make-pitch` octave where **octave 0 = the middle-C register**
(verified: `test-unit.ly` — C tonic explicit `2` → tonic semitones `24`;
derived at `mcp 0` → octave `0`). Therefore:

```
cnb:keysig-tonic-octave = placement.tonicOctave − 1
```

The exporter **must apply this −1 offset**; emitting the raw `tonicOctave`
would misplace the signature by an octave. (`null`/auto needs no emission
— engine default `#f` already middle-C-anchors, and the Configurator's
auto rule lands its C-tonic on semitone 12 to match.)

**Residual clef caveat:** the engine's on-staff vertical position is
`(pitch-semitones + 2·middleCPosition)` (`cnb/keysig.ly:223,247`), so the
octave anchor fixes the *register* but `middleCPosition` (clef) still
shifts the display. The Configurator preview models placement against a
fixed `staff.midpoint`, not `middleCPosition`. The −1 mapping is verified
for the **default clef**; non-default clefs interact with the set-005 clef
surface and should be render-verified before the Configurator pins them.

### 3.3 — `separator.enabled: false` has no direct engine toggle

The engine can suppress the **whole** key signature (`'none`) but has no
bar-only on/off switch. If the Configurator needs to honor
`separator.enabled: false` while still drawing the noteheads, the only
current lever is `cnb:keysig-bar-thickness 0` (a zero-width `#:draw-line`
— **not yet verified to render invisibly**). Options for the Configurator
team: (a) treat `separator.enabled:false` as preview-only for now; (b)
emit `thickness 0` after verifying it against a render; or (c) request a
dedicated engine `cnb:keysig-bar-visible` flag in a future engine set.
Flagged, not adapted.

### 3.4 — preview-only fields with no engine counterpart

`gutter.paddingH`, `dot.radiusPct`, and `placement.rule` (beyond the sole
`"scale-from-tonic"`) have no engine setting and should not be emitted.

---

## 4. Verification status

- **Unit** (`test-unit.ly`): 287/287 passing (+33 this set), including
  `cnb:keysig-resolved-style` default/`'none`/fallback,
  `cnb:keysig-bar-half-extent` at sps 1/2/3, and the tonic-octave math
  (derived tracks `middleCPosition`; explicit anchors and ignores it;
  non-C (D) tonic keeps its note name under both modes).
- **Integration** (`tools/run_tests.py`): 250/250 passing (+2 specs) —
  `keysig-none` (the `key-signature` SVG element is absent under `'none`,
  noteheads still render) and `keysig-bar-style` (blue + extent-24 bbox
  reach the rendered stencil).
- **Golden baseline byte-stable** with default settings (zero modified
  `tests/*.svg` / `*.harvested.json`).

Session 2 (this record) re-runs both suites before commit (spec step 3).
