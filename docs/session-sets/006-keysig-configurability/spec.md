# Key-signature configurability (engine side)

> **Purpose:** Close the live items of backlog §2 (Key signatures) from
> `docs/planning/configurator-coordination-backlog.md`: make the
> notehead-chord key-signature display disableable, make the separator bar
> styleable, and add anchor-octave control — so the Configurator's
> `keySignature` config fields stop being preview-only and its exporter
> can emit `cnb:` keysig settings.
> **Scope revised 2026-07-08:** backlog item **2.3 (simple-mark "dot"
> style) was cancelled** — the Configurator's set 010 session 2 rejected
> all simple-mark styles and ships the note stack as its sole style, so an
> engine `'dot` mode has no consumer. This set therefore covers items 2.1,
> 2.2, and 2.4 in **two** sessions (was three). See the backlog §2.3
> cancellation note and the Configurator's `010-.../s2-notes.md` (D11).
> **Session Set:** `docs/session-sets/006-keysig-configurability/`
> **Created:** 2026-07-07
> **Workflow:** lightweight
> **Prerequisite:** None (independent of set 005; runs after it only by
> the lowest-`NNN`-first rule)

---

## Session Set Configuration

```yaml
tier: lightweight
requiresUAT: false
requiresE2E: false
uatScope: none
uatStyle: ad-hoc
verificationMode: out-of-band-or-none
totalSessions: 2
# prerequisites:
#   - slug: <prerequisite-slug>
#     condition: complete
```

> **Tier:** see the tier model SSoT:
> <https://github.com/darndestdabbler/dabbler-ai-orchestration/blob/master/docs/concepts/tier-model.md>.
>
> Rationale: pure engine work, verified through the existing
> `test-unit.ly` + `tools/run_tests.py` harness — no metered calls. Two
> sessions: enable/style + separator-bar styling + anchor-octave settings,
> then the cross-repo handoff record. Same operator note as set 005: this
> set touches the shared engine-contract surface; bump `verificationMode`
> to `dedicated-sessions` before Session 1 if you want the stronger gate.

---

## Project Overview

Source: `docs/planning/configurator-coordination-backlog.md` §2, which
distills the Configurator repo's
`docs/session-sets/010-custom-key-signatures/s1-engine-coordination.md`
(2026-07-07).

**Engine facts (as recorded in the backlog — re-verify in Session 1):**
`cnb-key-signature-engraver` (`cnb/keysig.ly`) renders every `\key` as two
interleaved columns of real noteheads (two stacked 7th chords) with
ledgers and a gold separator bar; it is unconditionally installed in the
Staff context (`cnb/layout.ly`); there are zero keysig settings in
`cnb/config.ly`. Hard-coded styling: `cnb:gold` (#ffd42a,
`cnb/colors.ly`) and `thickness . 4` in `cnb/keysig.ly` (~lines 231–234);
the bar's vertical extent is ±1 octave (`cnb:spaces-per-octave`). The
tonic octave is derived from `middleCPosition` in `cnb:keysig-pitches`.
The keysig stencil cache is keyed only by `keySignature`
(`cnb/keysig.ly` ~line 256) — every new setting must join the cache key
or invalidate the cache, or stale stencils will leak across configs.

**Why now:** the Configurator's set 010 built its preview to this design
and pinned (by test) that it exports NOTHING for key signatures until the
engine offers these settings. A config with
`keys.keySignature.enabled: false` cannot currently suppress the display
engine-side.

**Known placement divergence to close (item 2.4):** the Configurator's
preview auto-centers the signature's octave span on the staff midpoint;
the engine anchors at middle C. The two coincide only when the tonic's
octave span happens to center on the staff midpoint (e.g. a C tonic with
the default 4-8 staff). An explicit tonic-octave setting lets the
Configurator emit its `keySignature.placement.tonicOctave` and close the
divergence.

**Backward-compatibility invariant (applies to every session):** all new
settings default to today's behavior. With no overrides, the golden
baseline must render with **zero** assertion/pixel/hash drift. Run the
full suite via `tools/run_tests.py` before every commit.

**Cross-repo rule of engagement:** as in set 005 — the export-spec
version-note addendum and emit-if-changed exporter lines are authored
Configurator-side from this set's Session 3 handoff record. Do not bump
`docs/CNB-LY-EXPORT-SPEC-v1_2.md`'s version here.

**Non-goals:** clef work (set 005), vector-model removal (set 007), any
change to the chord-construction rules themselves (which chords the modes
map to), Configurator-side work.

---

## Sessions

### Session 1 of 2: Enable/style switch, separator-bar styling, and anchor-octave

**Goal:** The key-signature display can be suppressed, the separator
bar's color/thickness/extent are settable, and the tonic octave is
explicitly anchorable. (Backlog items 2.1, 2.2, 2.4. Item 2.3 — the
simple-mark "dot" style — is CANCELLED; see the scope note above.)

**Steps:**
1. **Pre-flight:** re-verify the engine facts above against
   `cnb/keysig.ly`, `cnb/layout.ly`, `cnb/config.ly`. Reconcile and note
   any drift in the change log before coding.
2. Add a keysig style setting to `cnb/config.ly` — proposed
   `cnb:keysig-style`, a symbol: `'chord` (default — today's notehead-chord
   display) and `'none` (suppress entirely, so
   `keys.keySignature.enabled: false` becomes emittable). Keep the setting
   a symbol (not a boolean) so the valueset can grow for future styles —
   NOT `'dot` (cancelled), but the deferred Configurator custom-symbol
   work would extend it. Check the Configurator's 010 record for whether a
   `'standard` (LilyPond native sharps/flats) escape hatch is wanted; add
   only if cheap. Record the final contract.
3. Add separator-bar settings — proposed `cnb:keysig-bar-color` (default
   `cnb:gold`), `cnb:keysig-bar-thickness` (default `4`), and
   `cnb:keysig-bar-extent-semis` (default: today's ±1 octave, i.e. `12`
   semitones each way — express the default so non-default
   `cnb:semitones-per-staff-space` staves keep today's geometry). Align
   naming/units with the Configurator's `keySignature.separator` fields
   (color, thicknessPct, extentSemis) — where units differ (e.g.
   `thicknessPct`), state the engine unit precisely for the handoff. NB
   the Configurator (set 010 s2, engine-render-verified) confirmed the bar
   draws through the horizontal MIDDLE of the two note columns at
   `thickness . 4` (= 0.4 staff-space) and ±1 octave — its default
   `separator.thicknessPct` is `160` (0.4 staff-space at the default staff's
   4 semitones/space); record that mapping for the handoff.
4. Add the anchor-octave setting (item 2.4) — proposed
   `cnb:keysig-tonic-octave`, default `#f` meaning "derive from
   `middleCPosition`" (today's behavior in `cnb:keysig-pitches`); an
   explicit integer anchors the signature's tonic octave so the
   Configurator can emit `keySignature.placement.tonicOctave` and close
   the documented placement divergence (see Project Overview).
5. Rework `cnb:get-key-signature-stencil`'s cache so the key incorporates
   (or the cache is invalidated by) ALL the new settings (style, the three
   bar settings, tonic octave) — see the cache-key warning above.
6. Add `test-unit.ly` assertions (defaults preserved; `'none` emits no
   stencil; bar color/thickness/extent each observable in harvest output
   where feasible; explicit vs. derived tonic octave, including a non-C
   tonic where the placement divergence is visible). Run the FULL suite;
   zero golden-baseline drift with defaults. Document in `README.md`.
   Commit.

**Creates:** none expected
**Touches:** `cnb/config.ly`, `cnb/keysig.ly`, `cnb/layout.ly` (only if
the engraver install needs gating), `test-unit.ly`, `README.md`
**Ends with:** style switch + bar styling + tonic-octave anchor live,
defaults byte-stable; full suite green; committed.
**Progress keys:** `session-001/preflight-verified`,
`session-001/keysig-style-setting`, `session-001/bar-styling-settings`,
`session-001/tonic-octave-setting`, `session-001/tests-green`

---

### Session 2 of 2: Configurator handoff record

**Goal:** The Configurator repo has everything it needs to author the LY
export-spec addendum and emit-if-changed exporter lines for key
signatures.

**Steps:**
1. Write `docs/session-sets/006-keysig-configurability/configurator-handoff.md`:
   every new/changed `cnb:` setting with exact name, type, default,
   units, semantics, file/line references, and any deviations from the
   backlog's proposed shapes — including how engine units map to the
   Configurator's `separator.thicknessPct` / `extentSemis` /
   `placement.tonicOctave` fields.
2. Cross-check against the Configurator's set-010 records; flag any
   preview/engine semantic mismatch explicitly rather than silently
   adapting either side.
3. Re-run the FULL unit + integration suites; confirm the golden baseline
   is still byte-stable with default settings.
4. Update `docs/planning/configurator-coordination-backlog.md`: mark items
   2.1, 2.2, 2.4 resolved (move to its §5 with a pointer to this set);
   2.3 is already recorded as cancelled. Commit.

**Creates:** `docs/session-sets/006-keysig-configurability/configurator-handoff.md`
**Touches:** `docs/planning/configurator-coordination-backlog.md`
**Ends with:** handoff record committed; backlog updated; full suite
green; set ready to close.
**Progress keys:** `session-002/handoff-recorded`,
`session-002/backlog-updated`

---

## End-of-set deliverables

- Key-signature display configurable: style (`'chord`/`'none`), separator
  bar color/thickness/extent, explicit tonic-octave anchor — all
  defaulting to today's behavior with zero golden-baseline drift. (No
  `'dot` style — item 2.3 cancelled; the note stack is the sole style.)
- The documented preview/engine placement divergence closable via the
  tonic-octave setting.
- Unit/integration coverage for every new setting.
- `configurator-handoff.md` enumerating the exact new engine contract.
- Backlog items 2.1, 2.2, 2.4 marked resolved (2.3 cancelled).
