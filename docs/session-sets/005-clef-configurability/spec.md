# Clef configurability & custom-clef registration (engine side)

> **Purpose:** Close backlog §1 (Clefs) from
> `docs/planning/configurator-coordination-backlog.md`: make the dozenal
> clef display configurable (disable / select / size), add a text-mode
> register label, and add a custom-clef path registration hook — so the
> Configurator's clef config fields stop being preview-only and its
> exporter can start emitting `cnb:` clef settings.
> **Session Set:** `docs/session-sets/005-clef-configurability/`
> **Created:** 2026-07-07
> **Workflow:** lightweight
> **Prerequisite:** None (backlog items verified open as of 2026-07-07;
> engine facts below re-verified in Session 1's pre-flight step)

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
> Rationale: pure engine work (Scheme + `.ly`), fully verifiable through the
> repo's existing `test-unit.ly` + `tools/run_tests.py` harness — no metered
> calls needed. Three sessions: display modes & size, registration hook,
> then the cross-repo handoff record. **Note for the operator:** the project
> plan's tier note says to consider `verificationMode: dedicated-sessions`
> for sets touching the shared engine-contract surface with the
> Configurator — this set does. It is authored `out-of-band-or-none` to
> match every prior set in this repo; bump it before starting Session 1 if
> you want the stronger gate.

---

## Project Overview

Source: `docs/planning/configurator-coordination-backlog.md` §1, which
distills the Configurator repo's
`docs/session-sets/009-custom-clefs/s1-engine-coordination.md` (2026-07-06)
plus one operator request (numeral size, 2026-07-07).

**Engine facts (as recorded in the backlog — re-verify in Session 1):**
`cnb-clef-engraver` (`cnb/clefs.ly`) replaces every Clef grob with a
two-digit dozenal register numeral computed from `middleCPosition` +
ottava; it is unconditionally installed in the Staff context
(`cnb/layout.ly`); there are zero clef settings in `cnb/config.ly`; there
is no path-stencil hook. The numeral is hard-coded at ~3 staff-spaces tall
(`scale-factor = (/ (* 3 mag) height)`, `cnb/clefs.ly` ~line 124). The
clef stencil cache is keyed only by `(middleCPosition . ottava)`
(`cnb/clefs.ly` ~line 108) — every new setting added by this set must
either join the cache key or invalidate the cache, or stale stencils will
leak across configs.

**Why now:** the Configurator's set 009 pinned (by test) that it exports
NOTHING for clefs until this engine offers configurability. Its clef
config fields are preview-only, and a config with the clef disabled (its
default) still engraves the numeral — preview and engraved output cannot
agree in the clef slot.

**Backward-compatibility invariant (applies to every session):** all new
settings default to today's behavior. With no overrides, the golden
baseline (`joy-to-the-world` via `Kite-4-369-Notation-Procedure.ly`) must
render with **zero** assertion/pixel/hash drift. Run the full suite via
`tools/run_tests.py` before every commit.

**Cross-repo rule of engagement (backlog header):** each item that lands
as a `cnb:` setting triggers two follow-ons in the Configurator repo (an
LY-export-spec version-note addendum and an emit-if-changed exporter
line). Those are authored **Configurator-side** — this set's job is to
land the engine settings and hand over an exact record of them (Session
3). Do not bump `docs/CNB-LY-EXPORT-SPEC-v1_2.md`'s version here; the
addendum is synced back later, as was done for 1.2.1 in set 004.

**Non-goals:** key-signature settings (set 006), vector-model removal
(set 007), any Configurator-side exporter/preview work, minim-specific
stem anchors (owned by `inkscape-music-glyph-toolkit`, backlog §4).

---

## Sessions

### Session 1 of 3: Clef display modes, text mode, and semitone-denominated size

**Goal:** The dozenal clef display can be disabled, replaced with a
configured text label, or kept as-is; its size is settable in semitones.
(Backlog items 1.1, 1.3, 1.4.)

**Steps:**
1. **Pre-flight:** re-verify the engine facts above against `cnb/clefs.ly`,
   `cnb/layout.ly`, `cnb/config.ly` (files drift; the backlog was assembled
   2026-07-07). Reconcile and note any drift in the change log before
   coding.
2. Add a clef style setting to `cnb/config.ly` — proposed
   `cnb:clef-style`, a symbol: `'dozenal` (default — today's behavior),
   `'text` (render the configured label instead of the computed numeral,
   item 1.3), `'none` (suppress the clef entirely — engrave no stencil, so
   a Configurator config with its clef disabled finally matches its
   preview). Naming/valueset may be adjusted at execution time; record the
   final contract for Session 3. Check the Configurator's 009 coordination
   record for whether a `'standard` (LilyPond's native glyph) escape hatch
   is wanted; add it only if cheap.
3. Add the text-mode label setting (proposed `cnb:clef-text`, a string or
   markup) consumed when `cnb:clef-style` is `'text` — the engine
   counterpart of the Configurator's `kind: "text"` clef entries.
4. Add the size setting (item 1.4), **semitone-denominated** (the
   Configurator's canonical unit) — proposed `cnb:clef-size-semitones`,
   default `#f` meaning "legacy: 3 staff-spaces" (which is
   `(* 3 cnb:semitones-per-staff-space)` semitones, so the default cannot
   be a fixed number without changing behavior on non-default staves).
   When set to a number N, the numeral/text renders N semitones tall
   regardless of `cnb:semitones-per-staff-space`.
5. Rework `cnb:get-clef-stencil`'s cache so the key incorporates (or the
   cache is invalidated by) the new settings — see the cache-key warning
   in the Project Overview.
6. Add `test-unit.ly` assertions (defaults preserved; each style value;
   size math at sps-1/sps-2/sps-3) and, where observable, harvest-level
   assertions. Run the FULL suite; confirm zero golden-baseline drift with
   defaults. Document the settings in `README.md`. Commit.

**Creates:** none (new files only if repo convention demands)
**Touches:** `cnb/config.ly`, `cnb/clefs.ly`, `cnb/layout.ly` (only if the
engraver install needs gating), `test-unit.ly`, `README.md`
**Ends with:** style/text/size settings live with today's behavior as the
default; full suite green; committed.
**Progress keys:** `session-001/preflight-verified`,
`session-001/clef-style-and-text`, `session-001/clef-size-semitones`,
`session-001/tests-green`

---

### Session 2 of 3: Custom-clef registration hook

**Goal:** A Configurator-exported config can register a custom clef glyph
(path data) with an anchor and gutter padding, and select it for display.
(Backlog item 1.2.)

**Steps:**
1. Add a registration hook — proposed
   `cnb:register-clef! '(name path-data)` — mirroring the notehead
   path/attachment registration pattern (named definition tables +
   hash-table registration in `cnb/procedure.ly`; path format as in
   `cnb:notehead-shape-path`, `cnb/config.ly`). Add a selection mechanism
   (e.g. a `'custom` value for `cnb:clef-style` plus a
   `cnb:clef-name` setting, or a name argument — decide at execution
   time and record the final contract).
2. Implement the **anchor contract** decided by the Configurator's 009 s1
   record: `anchorSemi` is the semitone position of the glyph's **TOP
   edge**, stored as a **FLOAT** (surveyed clef designs register by
   interior features, putting the box top at fractional grid offsets).
   Placement must land the rendered glyph's top edge at that semitone on
   any staff design (i.e. it must divide through
   `cnb:semitones-per-staff-space` correctly). Add a gutter-padding
   setting for horizontal spacing after the clef.
3. Extend the stencil cache handling from Session 1 to cover registered
   clefs (registration mutates what a cached key would render).
4. Add `test-unit.ly` assertions: registration + lookup, fractional
   `anchorSemi` placement at more than one `cnb:semitones-per-staff-space`
   value, gutter padding, and interaction with the size setting (define
   precedence: explicit size vs. path's natural size — record the
   decision). Run the FULL suite; zero golden-baseline drift with
   defaults. Document in `README.md`. Commit.

**Creates:** none expected
**Touches:** `cnb/clefs.ly`, `cnb/config.ly`, `cnb/procedure.ly` (only if
the registration tables live there), `test-unit.ly`, `README.md`
**Ends with:** custom clefs registrable and renderable with the agreed
anchor contract; full suite green; committed.
**Progress keys:** `session-002/register-clef-hook`,
`session-002/anchor-contract-implemented`, `session-002/tests-green`

---

### Session 3 of 3: Configurator handoff record

**Goal:** The Configurator repo has everything it needs to author the LY
export-spec addendum and the emit-if-changed exporter lines for clefs.

**Steps:**
1. Write `docs/session-sets/005-clef-configurability/configurator-handoff.md`
   (the engine-side mirror of the Configurator's
   `s1-engine-coordination.md` convention): every new/changed `cnb:`
   setting with its exact name, type, default, semantics, the anchor
   contract as implemented, file/line references, and any deviations from
   the backlog's proposed shapes decided during Sessions 1–2.
2. Cross-check the handoff against the Configurator's set-009 records at
   `d:\Projects\chromatic-notation-configurator` (note: the repo moved —
   do not use the old `source\repos` path) so its preview semantics and
   the engine semantics are stated compatibly; flag any mismatch
   explicitly rather than silently adapting either side.
3. Re-run the FULL unit + integration suites once more; confirm the golden
   baseline is still byte-stable with default settings.
4. Update `docs/planning/configurator-coordination-backlog.md`: mark items
   1.1–1.4 resolved (move to its §5 with a pointer to this set). Commit.

**Creates:** `docs/session-sets/005-clef-configurability/configurator-handoff.md`
**Touches:** `docs/planning/configurator-coordination-backlog.md`
**Ends with:** handoff record committed; backlog updated; full suite
green; set ready to close.
**Progress keys:** `session-003/handoff-recorded`,
`session-003/backlog-updated`

---

## End-of-set deliverables

- Clef display configurable: style (`dozenal`/`text`/`none`[/`custom`]),
  text label, semitone-denominated size — all defaulting to today's
  behavior with zero golden-baseline drift.
- Custom-clef registration hook implementing the 009-agreed anchor
  contract (`anchorSemi` = float semitone of the glyph's top edge) plus
  gutter padding.
- Unit/integration coverage for every new setting.
- `configurator-handoff.md` enumerating the exact new engine contract for
  the Configurator's follow-on addendum + exporter work.
- Backlog §1 items marked resolved.
