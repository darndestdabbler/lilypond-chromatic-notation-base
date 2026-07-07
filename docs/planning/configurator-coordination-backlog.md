# Engine backlog — Configurator-coordination work items

**Assembled:** 2026-07-07, from the `chromatic-notation-configurator`
repo's engine-coordination records (session sets 007, 009, 010) plus one
operator request. Each item cites its source record; the source records
carry the full engine-inspection evidence (file/line references).

**Status convention:** every item below is OPEN unless listed in §5.
Items were verified open against this repo's history as of set
`004-end-to-end-pipeline-verification` (last engine set, closed
2026-07-05) — no set past 004 exists yet.

**Scheduled (2026-07-07):** every open item is now covered by an authored
session set — run them in `NNN` order per `docs/dabbler/start-here.md`:

| Backlog items | Session set |
|---|---|
| §1.1–1.4 (clefs) | `docs/session-sets/005-clef-configurability/` ✅ resolved (see §5) |
| §2.1–2.4 (key signatures) | `docs/session-sets/006-keysig-configurability/` |
| §3.1 (vector-model removal) | `docs/session-sets/007-vector-model-removal/` |
| §4 (toolkit minim anchors) | not this repo — no set (by design) |

Each set's final session moves its items to §5 here when they resolve.

**Cross-repo rule of engagement (both repos' plans):** the Configurator
emits only what this engine supports. Whenever an item below lands as a
`cnb:` setting, two follow-ons trigger in the Configurator repo: a
version-note addendum to the LY export spec, and an emit-if-changed line
in its exporter. Until then the Configurator's corresponding config
fields are preview-only (documented as such in its coordination notes).

---

## 1. Clefs

> **RESOLVED (2026-07-07) by set `005-clef-configurability`** — all four
> items (1.1–1.4) landed engine-side; see §5 and
> `docs/session-sets/005-clef-configurability/configurator-handoff.md` for
> the exact new engine contract. Kept here for source traceability.

Source: `chromatic-notation-configurator/docs/session-sets/009-custom-clefs/s1-engine-coordination.md`
(2026-07-06). Engine facts recorded there: `cnb-clef-engraver`
(cnb/clefs.ly) replaces every Clef grob with a two-digit dozenal register
numeral computed from `middleCPosition` + ottava; unconditionally
installed in the Staff context (cnb/layout.ly); zero clef settings in
cnb/config.ly; no path-stencil hook.

### 1.1 Configurability of the existing dozenal clef engraver
A way to disable or select the dozenal display. Today it overrides every
clef unconditionally, so a Configurator config with its clef disabled
(the default) still engraves the numeral — preview and engraved output
cannot agree in the clef slot.

### 1.2 Custom-clef registration hook
E.g. `cnb:register-clef! '(name path-data)` plus settings for the anchor
position and gutter padding, mirroring the notehead path/attachment
registration pattern. Anchor contract on the Configurator side (its 009
s1 decision): `anchorSemi` = semitone of the glyph's TOP edge, stored as
a FLOAT (surveyed designs — Bravura gClef, Clairnote 2017, Express Stave
— register clefs by interior features, putting the box top at fractional
grid offsets). Until this exists the Configurator exports NOTHING for
clefs (pinned by test in its suite).

### 1.3 Text-mode counterpart
Allow a configured register label (glyph-free clef, e.g. an octave
numeral or letter) to replace the computed dozenal number — the engine
counterpart of the Configurator's `kind: "text"` clef entries.

### 1.4 Clef numeral size setting *(operator request, 2026-07-07)*
The numeral is hard-coded at ~3 staff-spaces tall
(`scale-factor = (* 3 mag)/height`, cnb/clefs.ly). Because a staff-space
spans a different number of semitones per staff design
(`cnb:semitones-per-staff-space`), the numeral's size relative to an
octave varies: ~9 semitones on an sps-3 staff, ~3 on an sps-1 staff.
Add a size setting, preferably **semitone-denominated** (the
Configurator's canonical unit) with the default equivalent to today's 3
staff-spaces, so the numeral reads consistently across staff designs.
Interim score-level workaround (no code change): the whole stencil
scales with `mag`, so `\override Staff.Clef.font-size = #N` resizes it
today.

---

## 2. Key signatures

Source: `chromatic-notation-configurator/docs/session-sets/010-custom-key-signatures/s1-engine-coordination.md`
(2026-07-07). Engine facts recorded there: `cnb-key-signature-engraver`
(cnb/keysig.ly) already renders notehead-chord key signatures — the
key's scale as two interleaved columns of real noteheads (two stacked
7th chords) with ledgers and a gold bar — unconditionally installed,
driven by the score's `\key` through the quarter-note procedure-model
config; zero keysig settings in cnb/config.ly. The Configurator's set
010 built its preview to this design and exports NOTHING for key
signatures (pinned by test); the items below are what would make its
remaining preview-side fields emittable.

### 2.1 Configurability of the key-signature engraver
A disable flag and/or style selection. Today every score with a `\key`
gets the notehead-chord display; a Configurator config with
`keys.keySignature.enabled: false` cannot suppress it engine-side.

### 2.2 Separator-bar styling settings
E.g. `cnb:keysig-bar-color` / thickness / extent. Today `cnb:gold`
(#ffd42a, cnb/colors.ly) and `thickness . 4` are hard-coded in
cnb/keysig.ly. Would let the Configurator emit its
`keySignature.separator` fields (color, thicknessPct, extentSemis) as
Section B variables.

### 2.3 Simple-mark ("dot") key-signature mode
An engine counterpart to the Configurator's preview-only
`style: "dot"` (one filled circle per scale degree at the same grid
positions). Optional — only if the simple-mark style is wanted in
engraved output.

### 2.4 Anchor-octave control
The keysig tonic octave is derived from `middleCPosition`
(cnb/keysig.ly, `cnb:keysig-pitches`). A setting would let the
Configurator emit its explicit `keySignature.placement.tonicOctave` and
close the documented placement divergence (the Configurator's preview
auto-centers the signature's octave span on the staff midpoint; the
engine anchors at middle C — the two coincide only when the tonic's
octave span centers on the staff midpoint, e.g. a C tonic with the
default 4-8 staff).

---

## 3. Carried forward from the set-007 handoff

Source: `chromatic-notation-configurator/docs/session-sets/007-end-to-end-pipeline-verification/s2-cross-repo-coordination.md`
(2026-07-05), item 5.

### 3.1 Vector-model removal
This repo's README marks the removal as **unblocked** (engine set 004:
the 007/004 round-trip renders a Configurator-generated procedure-model
config pixel- and hash-identical to the golden baseline with zero hand
edits). When removing the vector model, keep the
`cnb:use-procedure-model` variable (or coordinate first): the
Configurator ALWAYS emits `#(set! cnb:use-procedure-model #t)` (LY
export spec 1.2.1 §5.1), and a guarded assignment to an existing
variable stays harmless while removing the variable would break every
existing export.

---

## 4. Not this repo (recorded here to avoid re-triage)

- **Toolkit — minim-specific stem anchors (007 handoff item 6, "D6").**
  Owned by `inkscape-music-glyph-toolkit`: the SVG contract has one stem
  placemarker pair, so minim anchors can't be authored distinct from
  crotchet anchors (needed for repeat-mode double-notehead layouts, e.g.
  the golden Kite config's ±1.095-semitone minim offsets). The
  Configurator's importer will read `data-stem-minim-*`-style attributes
  once the toolkit defines them.

---

## 5. Already resolved (for reference — do not re-do)

### §1 Clefs — set `005-clef-configurability` (2026-07-07)

All four clef items landed engine-side with zero golden-baseline drift.
Full contract (names, types, defaults, the anchor contract as implemented,
and the Configurator cross-check flags) is in
`docs/session-sets/005-clef-configurability/configurator-handoff.md`.

- **1.1 disable/select the dozenal display** — `cnb:clef-style`
  (`'dozenal` default / `'text` / `'none` / `'custom`); `'none` engraves
  no stencil so a clef-disabled config matches its preview.
- **1.2 custom-clef registration hook** — `cnb:register-clef! name def`
  (two-arg alist form — deviation from the proposed
  `'(name path-data)`), selected via `cnb:clef-style 'custom` +
  `cnb:clef-name`; implements the 009 anchor contract
  (`anchor-semitones` = float semitone of the glyph's TOP edge, on the
  notehead middle-C = 0 axis) plus `cnb:clef-gutter-semitones`.
- **1.3 text-mode counterpart** — `cnb:clef-style 'text` + `cnb:clef-text`
  (string → bold, or markup).
- **1.4 semitone-denominated size** — `cnb:clef-size-semitones`
  (`#f` = legacy 3 staff-spaces).

**Configurator follow-ons still owed (their side, per the rule of
engagement):** lift the "exports nothing for clefs" pin, add the LY
export-spec addendum, and add the emit-if-changed exporter lines — see the
handoff's §5 flags (esp. gutter px→semitone conversion, `lilypondPath`
command-list format, and the `anchorSemi` middle-C = 0 origin).

---

The other set-007 handoff items were completed by this repo's set
`004-end-to-end-pipeline-verification`, session 2 (2026-07-05; see its
change-log.md):

- **README render-side walkthrough half** — "End-to-End Walkthrough:
  Rendering an Exported Config", cross-linked to the Configurator README.
- **E1 — stale `tests/joy-to-the-world.ly`** — golden suite migrated to
  the procedure model; compiles and passes as checked in.
- **D3 — `-0` normalization in path hashing** — `tools/harvest_svg.py`
  canonicalizes numeric tokens; golden-vs-exported harvest diff fully
  clean (191/191 elements including `path_hash`).
- **LY spec 1.2.1 sync** — this repo's `docs/CNB-LY-EXPORT-SPEC-v1_2.md`
  merged to 1.2.1 (always-emitted `cnb:use-procedure-model #t`,
  half-staff-space conversion), preserving this repo's `repeat`-field
  documentation.
