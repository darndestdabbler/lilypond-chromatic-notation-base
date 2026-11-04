# Pitch-axis hook (engine side)

> **Purpose:** Close backlog §6 (Pitch axis, items 6.1–6.5 = the
> Configurator's E13-1…E13-5): give the engine a configurable
> semitone→staff-position procedure so compact / non-uniform pitch axes
> (the Twinline family) engrave correctly, plus the `x-offset` notehead
> field, keysig/clef placement through the hook, and collision-semantics
> observation — so the Configurator's set `014-pitch-axis-implementation`
> can emit its v1.3 pitch-axis export surface instead of failing loud.
> **Session Set:** `docs/session-sets/008-pitch-axis-hook/`
> **Created:** 2026-07-10
> **Workflow:** lightweight
> **Prerequisite:** None in this repo (sets 005–007 complete).
> **Source records:** backlog §6
> (`docs/planning/configurator-coordination-backlog.md`), distilling
> `chromatic-notation-configurator/docs/session-sets/013-pitch-axis-engine-discovery/s1-engine-coordination.md`
> (GO, render-evidenced) and aligned to the Configurator's operator-approved
> design (`.../docs/planning/pitch-axis-design.md` §1.2 unit contract, §4)
> and export draft (`.../docs/planning/CNB-LY-EXPORT-SPEC-v1_3-draft.md`
> §5.4/§6.3).

---

## Session Set Configuration

```yaml
tier: lightweight
requiresUAT: false
requiresE2E: false
uatScope: none
uatStyle: ad-hoc
verificationMode: out-of-band-or-none
totalSessions: 3
# prerequisites:
#   - slug: <prerequisite-slug>
#     condition: complete
```

> **Tier:** see the tier model SSoT:
> <https://github.com/darndestdabbler/dabbler-ai-orchestration/blob/master/docs/concepts/tier-model.md>.
>
> Rationale: pure engine work, verified through the existing
> `test-unit.ly` + `tools/run_tests.py` harness plus measured SVG renders
> (the 013-spike instrument) — no metered calls. Same operator note as
> sets 005/006: this set touches the shared engine-contract surface — and
> more deeply than either (it generalizes the core placement formula) —
> so bump `verificationMode` to `dedicated-sessions` before Session 1 if
> you want the stronger gate.

---

## Project Overview

The Configurator's set 013 proved by an actual render (score-level
coercion, zero engine changes) that overriding the notehead engraver's
single placement formula propagates correctly to ledgers, stems, dots,
and articulations — everything that reads geometry back. This set makes
that a real, supported hook.

**Engine facts (from backlog §6 — re-verify in Session 1):** one primary
placement site, `cnb/noteheads.ly` ~83–109 (`Y-offset` from the linear
`cnb:semitones-per-staff-space` formula; `staff-position` never set); two
secondary semitone→vertical sites, `cnb/keysig.ly` ~217–248 and
`cnb/clefs.ly` ~203–261; chord-internal horizontal arrangement is
diatonic-`staff-position`-derived and ABSORBS stencil x-translations for
diatonic-neighbor pairs (the 013 record §3.4 measurement — the one break);
keysig stencils are cached (cache-key discipline per backlog §2 facts).

**Unit contract (from the Configurator design — do not deviate without a
handoff note):** the hook receives an absolute semitone (integer; middle
C = 0) and returns a LilyPond staff position in HALF-staff-spaces from the
staff center, the same unit as `cnb:staff-line-positions`. The exported
procedure bakes its own octave anchor in (the config's `staff.midpoint`
lands at position 0), making placement clef-independent — the hook result
is used as-is, NOT further adjusted by `middleCPosition`.

**Backward-compatibility invariant (applies to every session):** all new
settings default to today's behavior (`#f` = hook unset = the LITERAL
existing formula, kept verbatim on that path, not re-derived). With no
overrides, the golden baseline (Kite 4-369) and the set-004 round-trip
must render with **zero** assertion/pixel/hash drift. Run the full suite
via `tools/run_tests.py` before every commit.

**Cross-repo rule of engagement (as sets 005/006):** the Configurator
emits only what this engine supports. Its set `014-pitch-axis-implementation`
session 3 is blocked on items 6.1 + 6.2 landing here and consumes this
set's Session 3 `configurator-handoff.md` (exact names, defaults, units,
deviations). Export-spec version bumps happen Configurator-side; do not
edit `docs/CNB-LY-EXPORT-SPEC-v1_2.md` here.

**Non-goals:** Configurator-side work (schema, preview, exporter);
changing the linear default behavior in any observable way; multi-voice
collision REDESIGN (6.5 is observation + threshold verification, not a
collision-engine rework); ledger-rule changes (the known in-gap
preview↔engine ledger divergence stays as documented).

---

## Sessions

### Session 1 of 3: The hook (backlog 6.1 / E13-1)

**Goal:** `cnb:get-pitch-staff-position` exists, defaults off, and a
compact axis renders through the REAL hook exactly as the 013 spike
measured.

**Steps:**
1. **Pre-flight:** re-verify the backlog §6 engine facts against
   `cnb/noteheads.ly`, `cnb/config.ly`, `cnb/ledgers.ly`, `cnb/layout.ly`.
   Reconcile and note any drift in the change log before coding.
2. Add `cnb:get-pitch-staff-position` to `cnb/config.ly` (default `#f`,
   documented with the unit contract above).
3. Consult it in the notehead engraver: when a procedure, `Y-offset`
   derives from `(hook note-semis)` (half-staff-spaces → staff-space
   conversion at the site); when `#f`, the literal existing formula runs
   unchanged. Decide and document whether the hook path ALSO writes the
   mapped value into `staff-position` now or defers that to Session 2's
   6.2 mechanism decision (they interact — record the reasoning either way).
4. Evidence: (a) golden baseline + full suites, zero drift, hook unset;
   (b) a compact-axis test score through the real hook using the 013
   spike's exact map (pc→position [0,0,1,2,2,3,3,4,5,5,6,6], stride 7,
   staff `'(-3 -1 1 4 6 8)`, middle C → −4) rendered with
   `-dbackend=svg` + `cnb/test-ids.ly`, harvested and measured
   (`tools/harvest_svg.py`; derive positions from staff-line extremes),
   and compared against the 013 record's measured tables (35 noteheads,
   7 ledgers, stem directions flipping at position 0).

**Progress keys:** `session-001/hook-landed`, `session-001/spike-parity`

### Session 2 of 3: x-offset field + collision semantics (backlog 6.2, 6.5 / E13-2, E13-5)

**Goal:** the procedure-model alist's optional `(x-offset . N)` field
moves noteheads (and their stems) horizontally by N staff spaces — for
single notes AND chord members, including the diatonic-neighbor case the
013 spike showed being absorbed — and collision-threshold semantics on a
compact axis are verified and documented.

**Steps:**
1. Read the optional `x-offset` field where the notehead config alist is
   consumed (missing = 0 = today's behavior, byte-identical).
2. Decide the chord mechanism (the 013 record's two candidates: write
   mapped values into `staff-position` so chord/collision layout runs in
   axis space, or post-note-column-layout `X-offset`); implement; record
   the decision + rejected alternative for the handoff.
3. Acceptance evidence: single offset note (head AND stem move together,
   spacing accounts for the moved extent); unison-treated shared-position
   chord; **a diatonic-second shared-position chord** (e.g. `<gis' a'>`
   with the sharper member offset) — measured, not eyeballed.
4. 6.5: exercise `cnb:collision-threshold` and multi-voice collisions on
   the compact axis (shared positions → geometric distance 0); verify or
   adjust semantics; document findings (this is observation/verification —
   surface anything needing redesign as a new backlog item rather than
   expanding this set).
5. Golden baseline + full suites, zero drift with no offsets configured.

**Progress keys:** `session-002/x-offset`, `session-002/collision-semantics`

### Session 3 of 3: Keysig + clef through the hook; handoff (backlog 6.3, 6.4 / E13-3, E13-4)

**Goal:** the two secondary placement sites follow the axis, and the
Configurator gets its handoff record.

**Steps:**
1. `cnb/keysig.ly`: mark placement uses the hook when set; the stencil
   cache key gains the axis dependency (or the cache is invalidated on
   hook change) — the backlog §2 cache-key discipline.
2. `cnb/clefs.ly`: glyph anchoring uses the hook when set (custom clef +
   pitch axis together).
3. Golden baseline + full suites, zero drift with the hook unset; a
   compact-axis render with a `\key` and a custom clef as positive
   evidence.
4. Write `configurator-handoff.md` (the sets-005/006 shape): exact
   setting names, types, defaults, the unit contract as implemented, the
   6.2 chord-mechanism decision, any deviations from the Configurator's
   v1.3 draft (its §5.4b compiled-procedure form and §6.3 field semantics
   were written against this plan — flag every mismatch), and the
   cross-check flags for their exporter session. Move backlog §6 items to
   §5 as resolved.
5. Final session: `change-log.md`.

**Progress keys:** `session-003/keysig-clef-through-hook`, `session-003/handoff`

---

## End-of-set deliverables

- `cnb:get-pitch-staff-position` (default `#f`, literal old formula on the
  unset path) with spike-parity render evidence.
- `(x-offset . N)` consumed for single notes and chords, diatonic-second
  acceptance case included; collision semantics verified/documented.
- Keysig and clef placement through the hook, cache discipline kept.
- Zero golden-baseline drift throughout with the hook unset.
- `configurator-handoff.md` unblocking the Configurator's set 014
  session 3; backlog §6 moved to §5.
