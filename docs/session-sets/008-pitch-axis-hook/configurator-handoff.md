# Configurator handoff — pitch-axis engine contract (set 008)

**From:** `lilypond-chromatic-notation-base`, set `008-pitch-axis-hook`,
Sessions 1–3 (E13-1…E13-5 = backlog §6, items 6.1–6.5).
**To:** `chromatic-notation-configurator` — set
`014-pitch-axis-implementation` session 3 (exporter emission, compact
fixtures, round-trip), which is blocked on this record.
**Date:** 2026-07-13. **Tier:** lightweight (no metered calls).

> **Cross-repo rule of engagement (unchanged from sets 005/006):** export
> spec changes are authored **Configurator-side**; the adopted
> `docs/CNB-LY-EXPORT-SPEC-v1_3.md` was written against this set's *plan*
> — §4 below flags every place where what actually landed deviates from
> or under-specifies what that spec assumed. This file is the
> engine-contract source of truth for the set-014 exporter work.

---

## 1. The engine contract (everything defaults to today's behavior)

With no overrides the golden baseline is byte-identical (verified every
session; final: unit **303/303**, integration **246/246** (349
assertions), zero modified files under `tests/` after a full re-render).

| Surface | Type | Default | Meaning |
|---------|------|---------|---------|
| `cnb:get-pitch-staff-position` ([`cnb/config.ly`](../../../cnb/config.ly)) | `#f` \| procedure | `#f` | The pitch-axis hook. A procedure receives the note's **absolute semitone** (an **exact integer**; middle C = 0, `ly:pitch-semitones`) and returns the LilyPond staff position in **half-staff-spaces from the staff center** (the `cnb:staff-line-positions` unit). The octave anchor is **baked in** (the config's `staff.midpoint` lands at position 0); the result is used **as-is**, never adjusted by `middleCPosition`. May be many-to-one and non-uniform; fractional return values are legal (see §5.2). On `#f`, the literal pre-hook linear formula runs unchanged at every site. |
| `(x-offset . N)` field (procedure-model alist, Section C) | number | *(absent = 0)* | Offsets the notehead (and everything anchored to it) **N staff spaces** horizontally, positive = right. Missing field ⇒ byte-identical to today. Present non-number ⇒ warning + 0 (never a silent move). Works for single notes AND chord members, including diatonic-second shared-position pairs (the 013 §3.4 absorbed case — measured +0.850 exact). |

### Where the hook is consulted (all three semitone→vertical sites)

1. **Noteheads** — [`cnb/noteheads.ly:249-282`](../../../cnb/noteheads.ly):
   `Y-offset = (hook semi) × 0.5 × staff-space`. The hook path also
   writes the mapped value into `staff-position` — for
   property/geometry **consistency only** (see §3, "staff-position
   write").
2. **Key-signature marks** (6.3 / E13-3) —
   `cnb:keysig-note-y-offset`
   ([`cnb/keysig.ly:90-95`](../../../cnb/keysig.ly)): each displayed
   pitch maps through `(hook semi) × 0.5 × mag`. The hook **joined the
   keysig stencil-cache key**
   ([`cnb/keysig.ly:327-336`](../../../cnb/keysig.ly)) — procedures
   compare by identity, so re-setting the hook invalidates (render-
   verified: same key + same staff under two hooks produced two
   correctly-placed signatures, +1.000 differential exact). Keysig
   ledgers follow automatically (the ledger helper recovers positions
   from the placed y).
3. **Custom-clef anchors** (6.4 / E13-4) — `cnb:clef-anchor-y-offset`
   ([`cnb/clefs.ly:287-297`](../../../cnb/clefs.ly)): the registered
   glyph's top edge lands at the hook position of its
   `anchor-semitones`. **Fractional anchors interpolate** — see §2.
   The clef stencil cache deliberately does **not** include the hook
   (placement is engraver-applied `Y-offset`, never baked into the
   cached stencil; render-verified — the cached stencil was reused
   across two hooks and re-anchored correctly). `'dozenal`/`'text`
   clefs are register displays centered on the staff and do not move
   with the axis.

---

## 2. Fractional clef anchors under the hook (engine-decided semantics)

The set-009 anchor contract makes `anchor-semitones` a **float**
(interior-feature registration ⇒ fractional top anchor,
`anchor = markedPitchSemi + k`), but the hook's input contract is
**integer** semitones — the v1.3 §5.4b compiled form uses exact-integer
`modulo` arithmetic and would crash on a float. The engine therefore
never passes a fraction to the hook; a fractional anchor interpolates
linearly between its neighboring integer semitones:

```
pos(a) = hook(⌊a⌋) + (a − ⌊a⌋) × (hook(⌊a⌋+1) − hook(⌊a⌋))
```

Properties (unit-tested + render-measured):

- **Exact on any linear map** — reduces symbol-for-symbol to the linear
  formula, so the v1.3 degeneracy invariant holds through clefs too.
- **Collapsed neighbors stay put** — an anchor between two semitones
  that share one axis position stays at that shared position.
- Negative anchors use the same euclidean neighbor arithmetic as the
  compiled procedure.
- Render-verified: anchor `7.5` on the 013 spike axis → top edge at
  position 0.5 (measured +0.510, the known +0.01 harvest artifact).

**Cross-check flag for set 014:** when the exporter emits a compiled
clef registration alongside a pitch axis, include one fractional-anchor
case in the round-trip fixture and assert the interpolated position.

---

## 3. The 6.2 chord mechanism — what landed and why (E13-2)

**Both candidate mechanisms named in the Configurator's 013 record §3.4
fail; the landed mechanism is a third design.** Full measured
falsification chain in the set's
[`change-log.md`](change-log.md) (Session 2) and `s2-evidence/`.

- **Landed:** the notehead acknowledger captures
  `x-offset × staff-space` into the custom grob property `cnb-x-offset`;
  `cnb:apply-note-x-offsets` (chained on `Stem.before-line-breaking`,
  [`cnb/layout.ly`](../../../cnb/layout.ly)) forces `positioning-done`
  to completion, then translates the **NoteColumn** by the **common**
  component (the least-displaced head's offset) and each head by its
  **residual**. Head, stem, flag, and ledgers move together; spacing
  accounts for the moved extent.
- **Rejected A — write mapped values into `staff-position` so chord
  layout "runs in axis space":** measurement disproved the premise —
  chord arrangement reads placed *geometry*, not `staff-position`; the
  offset was still absorbed for `<gis' a'>`.
  **Correction to the 013 record §3.4 for Configurator docs:** the
  absorber is NOT a "diatonic-`staff-position`-derived arrangement" —
  it is `Stem::calc_positioning_done`'s extent-based edge-alignment +
  parity-reversal arithmetic, which keeps or cancels a stencil
  translation depending on stem direction and reversal order.
- **Rejected B — the `X-offset` grob property:** silently discarded for
  chord members (the arrangement materializes the offset cache first)
  and single-note stems don't follow the head.
- **Two discovered crash modes (LilyPond 2.24.2, multi-voice):**
  mutating grobs while `positioning-done` is being evaluated, and
  translating **every** head of a stem from any phase (root cause:
  `stem.cc note_head_positions(filter=true)` + unguarded indexing in
  `check_meshing_chords`). **Crash invariant kept by the landed
  mechanism:** the least-displaced head's residual is 0, so every stem
  keeps one head at relative X = 0. No exporter action needed — any
  combination of per-member `x-offset` values is safe — but do not ask
  the engine team to "simplify" the residual split away.
- **`staff-position` write (hook path, noteheads only): kept**, with
  the corrected rationale — arrangement/collision read geometry, so the
  write exists only to keep the property from disagreeing with placed
  geometry for direct property readers. It plays no role in the
  x-offset mechanism and never drives vertical placement.

Acceptance (s2, measured vs byte-identical control): 19 single columns
move head+stem +0.850 **together**; chord separation effects
`<c' cis'>` +0.851, `<gis' a'>` +0.850 (the absorbed case),
`<f' fis'>` +0.850, spanning `<c' g'>` 0.000; ledgers follow; verticals
untouched.

---

## 4. Deviations / under-specifications vs the adopted v1.3 spec

Flagged explicitly, not silently adapted (sets-005/006 discipline).

### 4.1 — §5.4a's "remaining consumers migrate" claim is too strong; the sps VALUE under an axis must be pinned

v1.3 §5.4a says that after E13-3/E13-4 the engine's remaining consumers
of `cnb:semitones-per-staff-space` "migrate to the hook". **Placement
consumers did; LENGTH consumers remain, by design.** Settings expressed
in semitone units are *intervals*, and an absolute-pitch hook cannot map
intervals on a non-uniform axis. Still dividing by
`cnb:semitones-per-staff-space` engine-side:

- `cnb:clef-size-semitones` and `cnb:clef-gutter-semitones`
  ([`cnb/clefs.ly`](../../../cnb/clefs.ly) target-height/gutter math,
  incl. custom-clef `height-semitones` scaling);
- `cnb:keysig-bar-extent-semis`
  ([`cnb/keysig.ly:69-70`](../../../cnb/keysig.ly)).

§5.4a leaves the **emitted value** of `cnb:semitones-per-staff-space`
under an axis unspecified ("still emitted per v1.2.1"). Per the design
§1.2 substitution rule (the axis unit takes over the semitone's role in
every semitone→staff-space conversion; thicknessPct is already
"expressed against the grid unit — one axis unit under a pitch axis"),
**the exporter should emit `cnb:semitones-per-staff-space =
pitchAxis.axisUnitsPerStaffSpace` when the axis is enabled**, making the
engine's remaining ÷sps length conversions ÷axis-units — and the
semitone-unit settings' meaning under an axis becomes "grid units",
consistent with §5.3a/§4.4a. Emitting the linear
`staff.semitonesPerStaffSpace` instead would mis-size clef heights,
clef gutters, and the keysig bar extent. Degeneracy: linear configs are
unchanged either way. **This needs a v1.3 erratum/clarification
Configurator-side.**

### 4.2 — keysig pitch SELECTION is still `middleCPosition`-derived when `cnb:keysig-tonic-octave` is `#f`

The hook governs keysig mark **placement**; **which octave** the
displayed chords sit in is unchanged set-006 semantics — derived from
`middleCPosition` when `cnb:keysig-tonic-octave` is `#f`, explicit
integer otherwise. Under an axis (placement now clef-independent), a
derived selection would reintroduce clef dependence into *which*
pitches are shown. **The exporter should always emit an explicit
`cnb:keysig-tonic-octave` when a pitch axis is enabled** (the set-006
§3.2 −1 octave-numbering offset applies unchanged).

### 4.3 — §5.4b compiled-procedure form: verified compatible, one caveat

The engine calls the hook **only with exact integers** at all three
sites (keysig marks use `ly:pitch-semitones` of displayed pitches; clef
anchors decompose fractions per §2), so the compiled `modulo`/`floor`
arithmetic is safe as drafted. Fractional **positions** returned by the
procedure are accepted engine-side, but see §5.2: collision analysis
quantizes them.

### 4.4 — §6.3 field semantics: confirmed as implemented

Missing field = 0 = byte-identical; staff-space units, negative = left;
zero-omission and axis-gating are exporter-side rules the engine is
agnostic to; the resolved offset joining the Section C grouping key is
consistent with how the engine reads the field per (pc, duration-
category) clause. The "engine decides the mechanism" sentence should be
read with §3 above: **both** mechanisms it names were falsified; the
landed mechanism is the column+residual translation.

---

## 5. Carried cross-check flags for the set-014 exporter session

1. **Collision analysis quantizes to integer positions.** The collision
   machinery reads placed geometry back as **rounded** staff positions,
   so `cnb:collision-threshold` compares axis-space distances rounded to
   integers. Fractional-position maps will collide/merge on the rounded
   grid (s2 finding; surface in Configurator validation if fractional
   positions are combined with tight collision thresholds).
2. **Dot-wipe at axis distance 0.** Cross-voice equal-duration pairs at
   one axis position render both pitches (no head wiped; x-offset is
   the separation) — but stock merge logic wipes the **down-stem
   head's dots**. A dotted cross-voice shared-position pair loses the
   down voice's dot (upstream LilyPond behavior; document, don't fix).
3. **Barline-elastic spacing.** Within-measure x-offset spacing
   accumulation is exact; LilyPond redistributes ~0.10 staff-space at
   measure boundaries (spacing elasticity, not offset loss). Round-trip
   fixtures should not assert exact cross-barline accumulation.
4. **013 record §3.4 causal correction** (§3 above) — update any
   Configurator doc that repeats the "diatonic-derived arrangement"
   diagnosis.
5. **Fractional clef anchor on an axis** — include one in the
   round-trip fixture (§2).
6. **`cnb:semitones-per-staff-space` emission value under an axis**
   (§4.1) — needs a spec clarification before the exporter emits.
7. **Explicit `cnb:keysig-tonic-octave` under an axis** (§4.2).

---

## 6. Verification status (final build)

- **Unit** (`test-unit.ly`): **303/303** (+12 this session): clef-anchor
  hook path (integer, mcp-independence, fractional interpolation between
  distinct and collapsed neighbors, negative/euclidean, linear-
  degeneracy) and keysig placement helper (linear formula ×3, hook path
  ×3).
- **Integration** (`tools/run_tests.py`): **246/246** (349 assertions,
  10 specs), re-run after all edits.
- **Golden baseline byte-identical** with the hook unset (`git status
  -- tests/` clean after a full suite re-render).
- **s1 spike parity re-verified PASS on the final build** (35/35
  noteheads, 7/7 ledgers, stem flips at position 0).
- **s3 positive evidence** (`s3-evidence/`, transcript exit 0):
  `keysig-clef-axis.ly` — two scores, two hook anchors (−4/−3), same
  `\key g \major` + fractional-anchor custom clef on the 013 spike
  staff. Measured (`measure_keysig_clef.py`): keysig marks 8/8 at
  mapped positions {0..7} / {1..8}; clef top edge 0.5 / 1.5; notes
  exact; **all 13 differentials +1.000 exact** (keysig cache
  invalidation on hook change + clef stencil reuse with per-score
  re-anchoring proven in one render).
