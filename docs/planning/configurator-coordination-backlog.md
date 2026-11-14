# Engine backlog — Configurator-coordination work items

> **CLOSED (2026-10-30).** Every item this repository owned is resolved:
> §1 by set `005-clef-configurability`, §2 by set
> `006-keysig-configurability` (2.3 cancelled), §3 by set
> `007-vector-model-removal`, and §6 by set `008-pitch-axis-hook` (see §5).
> §4 was never this repository's. Kept for source traceability; new
> coordination work goes in the session plan, not here.

**Assembled:** 2026-07-07, from the `chromatic-notation-configurator`
repo's engine-coordination records (session sets 007, 009, 010) plus one
operator request. Each item cites its source record; the source records
carry the full engine-inspection evidence (file/line references).
**Amended 2026-07-10:** §6 (pitch axis, items 6.1–6.5) added from the
Configurator's set-013 engine-coordination record, scheduled as set
`008-pitch-axis-hook`.

**Status convention:** every item below is OPEN unless listed in §5.
Items were verified open against this repo's history as of set
`004-end-to-end-pipeline-verification` (last engine set, closed
2026-07-05) — no set past 004 exists yet.

**Scheduled (2026-07-07):** every open item is now covered by an authored
session set — run them in `NNN` order per `docs/dabbler/start-here.md`:

| Backlog items | Session set |
|---|---|
| §1.1–1.4 (clefs) | `docs/session-sets/005-clef-configurability/` ✅ resolved (see §5) |
| §2.1, 2.2, 2.4 (key signatures; 2.3 cancelled) | `docs/session-sets/006-keysig-configurability/` ✅ resolved (see §5) |
| §3.1 (vector-model removal) | `docs/session-sets/007-vector-model-removal/` ✅ resolved (see §5) |
| §4 (toolkit minim anchors) | not this repo — no set (by design) |
| §6.1–6.5 (pitch axis; added 2026-07-10) | `docs/session-sets/008-pitch-axis-hook/` ✅ resolved (see §5) |

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

> **RESOLVED (2026-07-08) by set `006-keysig-configurability`** — the three
> live items (2.1, 2.2, 2.4) landed engine-side with zero golden-baseline
> drift; 2.3 was cancelled (see below). See §5 and
> `docs/session-sets/006-keysig-configurability/configurator-handoff.md` for
> the exact new engine contract. Kept here for source traceability.

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

### 2.3 Simple-mark ("dot") key-signature mode — ❌ CANCELLED (2026-07-08)
Was: an engine counterpart to the Configurator's preview-only
`style: "dot"` (one filled circle per scale degree at the same grid
positions) — flagged "Optional, only if the simple-mark style is wanted
in engraved output."

**Cancelled.** The Configurator's set 010 **session 2** UAT settled this:
the task owner evaluated the dot style (and two other simple-mark
alternatives) and **rejected all of them**, choosing the notehead-chord
note stack as the *sole* style. The Configurator's `keySignature.style`
is now a single-value vocabulary (`"notehead-chords"`) — there is no
`style: "dot"` to match, so an engine `'dot` mode has no consumer. Source:
`chromatic-notation-configurator/docs/session-sets/010-custom-key-signatures/s2-uat.md`
+ `s2-notes.md` (decision D11).

Note — NOT the same as the deferred custom-symbol work: the Configurator
separately **deferred** generalized custom-symbol key signatures
("Clairnote-style": user-defined SVG symbols + when/where rules) to a
future Configurator set (`s2-design-consult.md`). If/when that lands it
will need a *mark-list* rendering hook (the engine resolving explicit
per-key `{symbol, semitone, column}` marks), NOT a `'dot` style — so this
cancellation does not pre-empt it. Re-open as a new backlog item when that
Configurator set is scheduled.

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

> **RESOLVED (2026-07-09) by set `007-vector-model-removal`** — the legacy
> vector-cycling model is gone; the procedure model is the only model.
> `cnb:use-procedure-model` was kept (permanent no-op, default `#t`), so **no
> Configurator-side action is required** — the emitted
> `#(set! cnb:use-procedure-model #t)` line remains valid. See §5 and
> `docs/session-sets/007-vector-model-removal/`.

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

## 6. Pitch axis (compact-staff support) — *added 2026-07-10*

> **RESOLVED (2026-07-13) by set `008-pitch-axis-hook`** — all five items
> (6.1–6.5) landed engine-side; see §5 and
> `docs/session-sets/008-pitch-axis-hook/configurator-handoff.md` for the
> exact engine contract, the 6.2 chord-mechanism decision, and the
> cross-check flags. Kept here for source traceability.

*(Numbered §6, placed before §5, so §5 stays the stable "resolved" sink
that existing references point at.)*

Source: `chromatic-notation-configurator/docs/session-sets/013-pitch-axis-engine-discovery/s1-engine-coordination.md`
(2026-07-10; work items its §6, IDs **E13-1…E13-5** — kept as aliases
below). Design context: the Configurator's operator-approved pitch-axis
design (`chromatic-notation-configurator/docs/planning/pitch-axis-design.md`
+ `CNB-LY-EXPORT-SPEC-v1_3-draft.md`) enables compact / non-uniform pitch
axes (the Twinline family — different pitches at one vertical position,
disambiguated by shape + horizontal offset).

**Engine facts recorded there (re-verify in the set's session 1):** the
notehead engraver is the SINGLE site where a semitone becomes a vertical
coordinate (`cnb/noteheads.ly` ~83–109: sets `Y-offset` as a plain number
from the linear `semitones-per-staff-space` formula; never touches
`staff-position`). Vertical-placement consumers — LilyPond's ledger
machinery via `cnb:ledger-positions-function` (`cnb/ledgers.ly`), dots,
articulations, stem extents/directions, collision thresholds — read the
placed GEOMETRY back, not the pitch, so a many-to-one map inserted at that
one site propagates automatically (proven by the 013 spike render: 35/35
noteheads, 7/7 ledgers, 30/30 stems exact on a Twinline-like axis with
zero engine changes). Two secondary semitone→vertical sites:
`cnb/keysig.ly` (~217–248) and `cnb/clefs.ly` (~203–261). The ONE measured
break: chord-internal horizontal arrangement is diatonic-`staff-position`-
derived — stencil-translation x-offsets are honored for unison-treated
pairs but ABSORBED for diatonic-neighbor pairs (013 record §3.4).

### 6.1 The pitch-axis hook (E13-1)
`cnb:get-pitch-staff-position` in `cnb/config.ly`, default `#f`; consulted
by the notehead engraver when set (a procedure `(semitone) →` LilyPond
staff position in half-staff-spaces, same unit as
`cnb:staff-line-positions`, octave anchor baked in by the exporter —
precedent for explicit-anchor-overrides-`middleCPosition`:
`cnb:keysig-tonic-octave`). The `#f` path keeps the LITERAL existing
formula. Acceptance: golden baseline (Kite 4-369) byte-identical with the
hook unset; a compact-axis render through the real hook matching the 013
spike's measured positions.

### 6.2 `(x-offset . N)` notehead-config field (E13-2)
Consume an optional per-(pc, duration) horizontal offset in staff-space
units from the procedure-model returned alist (Section C; the
Configurator emits it only when a pitch axis is enabled and the resolved
value is nonzero — missing field = today's behavior). Stencil translation
is the proven mechanism for single notes; the CHORD case needs a decided
mechanism (write the mapped value into `staff-position` so chord/collision
layout runs in axis space, or post-note-column-layout `X-offset`).
Acceptance evidence must include a diatonic-second shared-position chord.

### 6.3 Key-signature placement through the hook (E13-3)
`cnb/keysig.ly`'s `semi × (1/sps)` mark placement uses the hook when set,
so the notehead-chord signature lands on the compact axis. Mind the
keysig stencil-cache key (see §2 facts) — axis-dependent placement must
join the cache key or invalidate it.

### 6.4 Clef anchor through the hook (E13-4)
`cnb/clefs.ly` glyph anchoring (semitone units ÷ sps) uses the hook when
set — only observable when a custom clef and a pitch axis are enabled
together.

### 6.5 Collision-threshold semantics in axis space (E13-5)
Verify `cnb:collision-threshold` (default 2, `cnb/layout.ly` ~97–98)
against axis-space distances once 6.2's mechanism is chosen — shared
positions make geometric distance 0 the common case; multi-voice
collisions were NOT exercised by the 013 spike and need observation.

**Cross-repo dependency:** the Configurator's set
`014-pitch-axis-implementation` session 3 (exporter emission + compact
fixtures + round-trip) is **blocked on 6.1 and 6.2 landing** and consumes
this set's `configurator-handoff.md`; until then its exporter fails loud
on `pitchAxis.enabled` (no silent linear `.ly` for a compact config).

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

### §2 Key signatures — set `006-keysig-configurability` (2026-07-08)

Items **2.1, 2.2, 2.4** landed engine-side with zero golden-baseline drift
(unit 287/287, integration 250/250); **2.3 is cancelled** (see §2.3 — no
consumer for a `'dot` style). Full contract (names, types, defaults,
units, the field mappings, and the Configurator cross-check flags) is in
`docs/session-sets/006-keysig-configurability/configurator-handoff.md`.

- **2.1 disable/select the key-signature display** — `cnb:keysig-style`
  (`'chord` default / `'none`); `'none` engraves no stencil, so
  `keys.keySignature.enabled: false` is finally honored engine-side.
  Kept a symbol (not a boolean) so the valueset can grow; no `'standard`
  native escape hatch (no consumer — Configurator 010 D11/D12).
- **2.2 separator-bar styling** — `cnb:keysig-bar-color` (default
  `cnb:gold`), `cnb:keysig-bar-thickness` (default `4`, `#:draw-line`
  units), `cnb:keysig-bar-extent-semis` (default `12` = ±1 octave, in
  semitones). Maps to the Configurator's `separator.color` /
  `thicknessPct` / `extentSemis` — color is a direct hex passthrough,
  `extentSemis` is 1:1, and `thicknessPct` converts as
  `thickness = thicknessPct / (10 × semitones-per-staff-space)` (`160`→`4`
  at the default staff).
- **2.4 anchor-octave control** — `cnb:keysig-tonic-octave` (`#f` = derive
  from `middleCPosition`, today's behavior; integer = anchor at that
  `ly:make-pitch` octave). Closes the placement divergence for non-C
  tonics.

**Configurator follow-ons still owed (their side, per the rule of
engagement):** lift the "exports nothing for key signatures" pin, add the
LY export-spec addendum, and add the emit-if-changed exporter lines — see
the handoff's §3 flags, especially the **`tonicOctave − 1`** octave-
numbering offset, the `thicknessPct` unit conversion, and
`separator.enabled: false` having no direct engine toggle.

### §3 Vector-model removal — set `007-vector-model-removal` (2026-07-09)

**3.1 done.** The legacy vector-cycling model was removed from every engine
module (`config.ly` sequence vectors + `cnb:off-key-indicator`;
`stencils.ly` `build-base-stencils` / `base-stencil-vector` / modulus
helpers; `stems.ly` `stem-attachment-modulus` + vector branch; `off-key.ly`
vector detection arm + `apply-off-key-flag`; the `(if cnb:use-procedure-model …)`
branches in `stencils.ly`/`stems.ly`/`off-key.ly`/`noteheads.ly` are now
unconditional). The procedure model is the sole model.

- **Constraint honored — `cnb:use-procedure-model` kept.** It stays defined
  (default `#t`) as a permanent, documented no-op. The engine no longer
  branches on it; it exists only so the `#(set! cnb:use-procedure-model #t)`
  line every export emits (LY export spec 1.2.1 §5.1) stays a harmless
  assignment to a defined variable.
- **Constraint honored — golden baseline did not move.** The set-004
  round-trip (`tests/joy-to-the-world-configurator`) is byte-stable and
  passes (74/74); full suites green (unit 286/286, integration 246/246).
- **Default oval restored to 2 semitones.** Removing the vector model dropped
  its build-time `0.75` scaling of the default oval; that scaling is now baked
  into `cnb:notehead-shape-path`/`-hollow-path`, so the bare-default notehead
  height returns to the documented 2 semitones (the "Oval 2-024" identity).
  Real configs register their own paths and are unaffected.

**No Configurator-side action required.** The emitted `set!` line remains
valid — that is the whole point of the keep-forever constraint. Removing the
variable entirely would need a coordinated Configurator spec + exporter change
and is explicitly out of scope.

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

### §6 Pitch axis — set `008-pitch-axis-hook` (2026-07-13)

All five items (6.1–6.5 = E13-1…E13-5) landed engine-side with zero
golden-baseline drift throughout (final: unit 303/303, integration
246/246, goldens byte-identical, s1 spike parity re-verified). Full
contract (names, types, defaults, the unit contract as implemented, the
chord-mechanism decision, and the Configurator cross-check flags) is in
`docs/session-sets/008-pitch-axis-hook/configurator-handoff.md`.

- **6.1 the pitch-axis hook** — `cnb:get-pitch-staff-position`
  (default `#f` = the literal linear formula): integer absolute
  semitone → LilyPond staff position in half-staff-spaces, octave
  anchor baked in, used as-is (never `middleCPosition`-adjusted).
  Spike-parity render evidence through the REAL hook (s1: 35/35
  noteheads, 7/7 ledgers, stem flips exact).
- **6.2 `(x-offset . N)` field** — consumed for single notes and chord
  members incl. the diatonic-second shared-position case (+0.850
  measured, the 013 §3.4 absorbed pair). Mechanism decided by
  measurement after BOTH 013-record candidates failed: NoteColumn
  common + per-head residual translation on `Stem.before-line-breaking`
  (crash invariant: every stem keeps one head at relative X = 0). The
  013 §3.4 "diatonic-derived arrangement" diagnosis was corrected — the
  absorber is `Stem::calc_positioning_done` extent arithmetic.
- **6.3 keysig placement through the hook** — `cnb:keysig-note-y-offset`
  maps each displayed pitch; the hook joined the keysig stencil-cache
  key (invalidation render-proven by a two-hook +1.000 differential).
- **6.4 clef anchor through the hook** — `cnb:clef-anchor-y-offset`
  maps `anchor-semitones`; FRACTIONAL anchors interpolate between
  integer-semitone hook values (exact on linear maps; the hook is never
  called with a float). Clef stencil cache correctly hook-independent
  (engraver-applied Y-offset re-anchors the cached stencil).
- **6.5 collision semantics in axis space** — verified + documented, no
  redesign: collision machinery reads placed geometry as ROUNDED
  positions (fractional-position maps quantize); axis-distance-0
  equal-duration cross-voice pairs render both pitches with x-offset
  separation (stock merge wipes the down-stem head's DOTS — flagged);
  offsets compose additively with collision shifts.

**Configurator follow-ons still owed (their side, per the rule of
engagement, consumed by set `014-pitch-axis-implementation` session 3):**
the handoff's §5 flags — esp. the `cnb:semitones-per-staff-space`
emission value under an axis (must be `axisUnitsPerStaffSpace`; needs a
v1.3 clarification), always-explicit `cnb:keysig-tonic-octave` under an
axis, a fractional-anchor clef case in the round-trip fixture, and the
013 §3.4 causal correction in Configurator docs.
