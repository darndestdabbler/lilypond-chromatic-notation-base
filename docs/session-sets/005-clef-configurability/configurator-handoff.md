# Configurator handoff — engine clef contract (set 005)

> **Engine-side mirror** of the Configurator's
> `chromatic-notation-configurator/docs/session-sets/009-custom-clefs/s1-engine-coordination.md`.
> This is the record the Configurator repo needs to author its two clef
> follow-ons — the LY-export-spec version-note addendum and the
> emit-if-changed exporter lines — as defined by the backlog's cross-repo
> rule of engagement.
>
> **Set:** `docs/session-sets/005-clef-configurability/`
> **Sessions:** 1 (display modes / text / size) + 2 (registration / anchor /
> gutter), both committed; this is Session 3, documentation only.
> **Tier:** lightweight (no metered calls).
> **Engine repo:** `lilypond-chromatic-notation-base` @ commit `4e3dd2f`
> (set-005 S2 deliverable) plus this handoff.
> **Do NOT bump `docs/CNB-LY-EXPORT-SPEC-v1_2.md` here** — the addendum is
> synced back Configurator-side later, exactly as 1.2.1 was for set 004.

---

## 0. What changed, in one line each

Backlog §1 (Clefs) is now fully landed engine-side. Every setting defaults
to today's behavior; the golden baseline renders with **zero** drift.

| Backlog item | Engine deliverable |
|---|---|
| 1.1 disable/select dozenal display | `cnb:clef-style` (`'dozenal`/`'text`/`'none`/`'custom`) |
| 1.3 text-mode counterpart | `cnb:clef-style 'text` + `cnb:clef-text` |
| 1.4 semitone-denominated size | `cnb:clef-size-semitones` |
| 1.2 custom-clef registration + anchor + gutter | `cnb:register-clef!`, `cnb:clef-name`, `cnb:clef-gutter-semitones` |

---

## 1. New engine settings (`cnb/config.ly`)

All are score-level Scheme variables set the same way every other `cnb:`
setting is (`#(define cnb:… …)` before the score, or `#(set! cnb:… …)`).

| Setting | Type | Default | Semantics | Defined |
|---|---|---|---|---|
| `cnb:clef-style` | symbol | `'dozenal` | What the clef engraver renders. `'dozenal` = today's computed two-digit register numeral. `'text` = render `cnb:clef-text`. `'none` = engrave **no stencil** (`stencil = #f`). `'custom` = render the registered glyph named by `cnb:clef-name`. Any other value warns → `'dozenal`. `'custom` with a missing/invalid registration warns → `'dozenal`. | [config.ly:121](../../../cnb/config.ly#L121) |
| `cnb:clef-text` | string **or** markup | `""` | The label rendered when `cnb:clef-style` is `'text`. A **string** renders **bold** (matching the numeral weight) at its natural aspect; a **markup** is used as-is for full styling control (font/color). Non-string/non-markup warns and renders nothing. Ignored unless style is `'text`. | [config.ly:127](../../../cnb/config.ly#L127) |
| `cnb:clef-size-semitones` | `#f` or number | `#f` | Clef display height in **semitones**. `#f` = legacy 3 staff-spaces = `(* 3 cnb:semitones-per-staff-space)` semitones (kept as `#f`, not a fixed number, so non-default staves don't change). Number N = render N semitones tall regardless of `cnb:semitones-per-staff-space`. Applies to `'dozenal`, `'text`, and (as an override) `'custom`. | [config.ly:144](../../../cnb/config.ly#L144) |
| `cnb:clef-name` | symbol or `#f` | `#f` | Which registered custom clef to display when style is `'custom`. Names a definition registered with `cnb:register-clef!`. Ignored unless style is `'custom`. | [config.ly:150](../../../cnb/config.ly#L150) |
| `cnb:clef-gutter-semitones` | `#f` or number | `#f` | Extra blank horizontal space **after** the clef (right edge only), denominated in **semitones** — N widens the built stencil's right X-extent by `N / cnb:semitones-per-staff-space` staff-spaces of blank space. `#f` = legacy spacing. Applies to **every** rendered style, not only `'custom`. | [config.ly:162](../../../cnb/config.ly#L162) |

---

## 2. Registration hook (`cnb/clefs.ly`)

### Signature — DEVIATION from the backlog's proposed shape

The backlog (§1.2) and the Configurator's 009 s1 record both assumed
`cnb:register-clef! '(name path-data)` (a single-list argument). **As
implemented it is a two-argument call** mirroring `cnb:register-path!`
(noteheads), which is the established registration idiom in this engine:

```scheme
#(cnb:register-clef! 'my-clef
   (list
     (cons 'path             <command list>)      ; required
     (cons 'anchor-semitones <number>)            ; required (float)
     (cons 'height-semitones <positive number>)   ; optional (design height)
     (cons 'color            "#RRGGBB")))          ; optional
```

- `name` — a **symbol**. Non-symbol names are rejected.
- `def` — an **alist**. Structurally invalid defs (including the backlog's
  bare `'(name path-data)` shape) **warn and are not registered**; the
  validator checks alist shape before `assq-ref`, so malformed input
  degrades to `'dozenal` at engrave time instead of crashing.
- Re-registering a name **clears the whole stencil cache** (a cached
  `'custom` stencil for that name would otherwise keep rendering the old
  definition).

Defined at [clefs.ly:240](../../../cnb/clefs.ly#L240); definitions live in the
`cnb:clef-defs` hash table [clefs.ly:210](../../../cnb/clefs.ly#L210) (kept in
`clefs.ly`, **not** `procedure.ly` — everything else clef-shaped is in this
module; recorded decision). Validator: `cnb:clef-def-valid?`
[clefs.ly:219](../../../cnb/clefs.ly#L219).

### Definition fields

| Field | Required | Type | Meaning |
|---|---|---|---|
| `path` | yes | non-empty command list | Glyph outline in the **same nested command format as `cnb:notehead-shape-path`** (consumed by `cnb:flatten-path` → `make-path-stencil`). **The engine consumes only this format — not raw SVG `d` strings.** |
| `anchor-semitones` | yes | number (float) | Semitone position of the glyph's **top edge** (the 009 contract). See §3. |
| `height-semitones` | no | positive number | Design height in semitones. Overridden by an explicit `cnb:clef-size-semitones`. Absent → path renders at native scale (1 path unit = 1 staff-space). |
| `color` | no | `"#RRGGBB"` string | Fills the glyph; absent → default ink color. |

---

## 3. Anchor contract as implemented

**Matches the Configurator's 009 s1 decision:** `anchor-semitones` is the
semitone position of the glyph's **TOP edge**, stored as a **FLOAT**. The
pinned-in-both-repos test "FLOAT anchor-semitones is accepted" is mirrored
in this engine's unit suite.

**Coordinate origin (engine picked a concrete binding — see §5.A):** the
semitone axis is the one the notehead engraver renders on
([cnb/noteheads.ly]): `ly:pitch-semitones` units, **middle C = 0**, combined
with the context's `middleCPosition`. Placement reuses the notehead position
formula verbatim (`cnb:clef-anchor-y-offset`,
[clefs.ly:259](../../../cnb/clefs.ly#L259)):

```
Y-offset (staff-spaces) = (anchor-semitones + 2·middleCPosition)
                          / cnb:semitones-per-staff-space
```

then multiplied by the staff's `staff-space`, exactly as noteheads are. So
the glyph's top edge lands where a notehead of that pitch position would
center, dividing through `cnb:semitones-per-staff-space` correctly on **any**
staff design. `middleCPosition` is used **as-is** (it already includes any
active ottava shift, exactly like noteheads).

The custom stencil is built with its top edge at `y = 0`
(`cnb:build-custom-clef-stencil`, [clefs.ly:342](../../../cnb/clefs.ly#L342)):
scaled uniformly (aspect preserved), then translated by `−top-extent`; the
engraver then Y-offsets the grob to the anchor. Verified end-to-end: anchor
16 on the default sps-2 treble staff harvests the bbox top edge on the top
staff line (8.045 vs 8.05).

---

## 4. Size & gutter precedence (recorded decisions)

**Size precedence** (`cnb:clef-custom-target-semitones`,
[clefs.ly:268](../../../cnb/clefs.ly#L268)):

```
explicit cnb:clef-size-semitones  >  def height-semitones  >  native path scale
    (score-level override)            (design height)          (1 unit = 1 SP)
```

For `'dozenal`/`'text`, `cnb:clef-size-semitones = #f` → legacy 3
staff-spaces; a number → that many semitones tall
(`cnb:clef-target-height`, [clefs.ly:172](../../../cnb/clefs.ly#L172)).
Everything scales with font magnification (`\override Staff.Clef.font-size`)
exactly as the legacy path did.

**Gutter** applies to every rendered style, right edge only, blank ink
(`cnb:clef-apply-gutter` [clefs.ly:375](../../../cnb/clefs.ly#L375), math in
`cnb:clef-gutter-pad` [clefs.ly:179](../../../cnb/clefs.ly#L179)). LilyPond's
elastic spacing absorbs part of the extent, so a config should not expect
`gap == gutter`; the integration spec pins the deterministic rendered
first-notehead position instead.

**Stencil cache** (`cnb:get-clef-stencil`,
[clefs.ly:385](../../../cnb/clefs.ly#L385)): the key now covers every input
the stencil depends on — `style`, `middleCPosition`, `ottava`, the text label
(only under `'text`), the custom name (only under `'custom`),
`cnb:clef-size-semitones`, `cnb:clef-gutter-semitones`,
`cnb:semitones-per-staff-space`, and font magnification. This also fixed a
latent pre-existing bug (two clefs at different `font-size` previously shared
one cached stencil).

---

## 5. Cross-check against the Configurator's set-009 records

Checked against
`d:\Projects\chromatic-notation-configurator/docs/session-sets/009-custom-clefs/`
(the repo moved — the old `source\repos` path is stale). Compatible mappings
first, then the points the Configurator's exporter/spec author **must**
reconcile — flagged rather than silently adapted, per the spec.

### Field mapping (Configurator → engine)

| Configurator (preview/config) | Engine setting | Notes |
|---|---|---|
| `clef.enabled: false` | `cnb:clef-style 'none` | Disabled clef → no stencil. |
| `clef.glyphs[name].kind: "glyph"` | `cnb:clef-style 'custom` + `cnb:clef-name` + `cnb:register-clef!` | Registered path glyph. |
| `clef.glyphs[name].kind: "text"` | `cnb:clef-style 'text` + `cnb:clef-text` | Register label. |
| (engine native register numeral) | `cnb:clef-style 'dozenal` (default) | The Configurator has **no `kind` for this** — it is the engine's built-in device. A config that never touches the clef → engine default `'dozenal`. |
| `anchorSemi` (float, top edge) | `anchor-semitones` (float, top edge) | Same semantics. **Origin caveat — see A.** |
| `semitoneHeight` (glyph) | def `height-semitones` | Both semitone-denominated. |
| `textHeightSemis` (text) | `cnb:clef-size-semitones` (or def height for custom) | Both semitone-denominated. |
| `svgPath` + `lilypondPath` | def `path` | Engine consumes **only** the `lilypondPath`-format command list — **see C.** |
| `color`, `fontFamily` (text) | markup passed to `cnb:clef-text` | Engine text-mode has no separate color/font settings — **see D.** |
| `gutter.paddingH` (px, both sides) | `cnb:clef-gutter-semitones` (semitones, right only) | **Unit AND sidedness differ — see B.** |

### Flags for the Configurator author

**A. `anchorSemi` origin binding.** The Configurator's records define
`anchorSemi` only in its internal semitone-grid (validated as any finite
number, warning outside −24…72) and do **not** pin it to a pitch origin. The
engine binds it concretely to `ly:pitch-semitones` with **middle C = 0** plus
`middleCPosition` (§3) — the same grid the engine's noteheads use. Since the
Configurator's preview grid is the notehead grid, the two coincide **iff** the
Configurator exports `anchorSemi` on that middle-C-= 0 notehead axis.
**Action:** the exporter must emit `anchor-semitones` on the middle-C = 0
semitone axis (no offset). Confirm the Configurator's `semiToY` grid origin
equals middle C = 0 before emitting; if it doesn't, add the constant offset in
the exporter, not the engine.

**B. Gutter unit + sidedness mismatch (real divergence).** Configurator
`gutter.paddingH` is in **pixels** and applied on **both** sides (preview
width = glyphPixelWidth + 2·paddingH). Engine `cnb:clef-gutter-semitones` is
in **semitones** and applied to the **right edge only** (blank space after the
clef; left spacing is LilyPond's default). **Action:** the exporter must
(1) convert px → semitones, and (2) decide the mapping for a both-sides
preview padding onto a right-only engine gutter (likely emit `paddingH`
converted, accepting the left-side preview padding has no engine analogue, or
document the asymmetry). This is the one field where preview and engine do not
share a unit.

**C. Path format.** The engine's `path` field is the **nested command-list
format** (same as `cnb:notehead-shape-path`), consumed by `cnb:flatten-path`.
It does **not** parse raw SVG `d` strings. The Configurator's glyph entries
carry both `svgPath` and a (currently `null`) `lilypondPath` slot — the
exporter must populate `lilypondPath` in this engine's command-list format and
emit **that**, not `svgPath`. The engine **self-measures** the path's extent
to derive scale, so `naturalHeight`/`naturalWidth`/`viewBoxMinX`/`viewBoxMinY`
are preview-internal and need **not** be exported (vertical viewBox offset is
normalized away by the top-edge-at-y=0 construction; horizontal placement is
the fixed clef X-offset).

**D. Text-mode color/font.** The engine's `cnb:clef-text` renders a plain
string **bold in the current ink color**. The Configurator's text entries
carry `color` (default `#000000`) and `fontFamily` (default `Georgia,
serif`). **Action:** to reproduce those, the exporter emits `cnb:clef-text` as
a **markup** (e.g. `\markup \override #'(font-name . "Georgia") \with-color
#(rgb-color …) …`) rather than a bare string. A bare string is fine when
default weight/color suffice.

**E. No `'standard` escape hatch — consistent.** The Configurator never
requested a native-LilyPond-glyph clef kind, and the engine did not add one
(value set kept to `'dozenal`/`'text`/`'none`/`'custom`). No action.

**F. No preview-vs-engine placement divergence** analogous to the keysig
`tonicOctave` case. Because the Configurator exports nothing for clefs today,
there is no engine-rendered clef to diverge from; once emission lands, the
anchor contract (§3) is the shared placement law. The one Configurator-side
approximation on record — text numerals' cap-height sitting slightly below the
anchor — is a preview rendering detail, not an engine contract point.

### The pin this unblocks

The Configurator's suite pins **"clef-enabled config exports identically to
clef-disabled"** (`cnb/tests/cnb-clef-tests.js`, "exporter is blind to the
clef section — no engine hook") — i.e. it exports nothing for clefs until this
engine offers configurability. That engine hook now exists (this set). The
Configurator can lift that pin and author its emit-if-changed exporter lines
against the settings in §1–§2.

---

## 6. Verification state

- **Unit suite:** 254/254 assertions pass (`test-unit.ly` via
  `tools/run_tests.py`), including the mirrored "FLOAT anchor-semitones is
  accepted" pin, four invalid-def rejections, style/anchor/size/gutter math,
  and real stencil geometry.
- **Integration suite:** 245/245 assertions, 9 specs, including both golden
  `joy-to-the-world` specs. New specs: `tests/clef-none.json`,
  `tests/clef-text-size.json`, `tests/clef-size-dozenal.json`,
  `tests/clef-custom.json`.
- **Golden baseline:** byte-stable with default settings across Sessions 1–2
  (re-confirmed this session — see the commit for this handoff).

---

## 7. Exact provenance

- Engine settings: `cnb/config.ly` lines 104–162.
- Engine logic: `cnb/clefs.ly` (registration/anchor/size/gutter/cache
  `cnb:clef-*` at lines 140–468; engraver from 439).
- Session decisions: `docs/session-sets/005-clef-configurability/change-log.md`
  (Sessions 1 & 2).
- Configurator source of truth cross-checked:
  `chromatic-notation-configurator/docs/session-sets/009-custom-clefs/`
  (`s1-engine-coordination.md`, `s1-notes.md`) and `cnb/src/cnb-clef.js`,
  `cnb/src/cnb-config.js`, `cnb/tests/cnb-clef-tests.js`.
