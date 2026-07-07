# Change log — 005-clef-configurability

## Session 1 (2026-07-07) — Clef display modes, text mode, and semitone-denominated size

**Orchestrator:** claude-code / anthropic (lightweight tier, no metered calls)

### Pre-flight — `session-001/preflight-verified`

- All six backlog engine facts re-verified against the working tree with
  **zero drift**: engraver replaces every Clef grob from
  `middleCPosition` + ottava (`cnb/clefs.ly`); unconditional Staff
  install (`cnb/layout.ly:46`); zero clef settings in `cnb/config.ly`;
  no path hook; size hard-coded `(/ (* 3 mag) height)` (was
  `cnb/clefs.ly:124`); cache keyed only `(middleCPosition . ottava)`
  (was `cnb/clefs.ly:108`).
- Checked the Configurator's 009 s1 coordination record for the
  `'standard` (LilyPond native glyph) escape hatch the spec asked about:
  **not requested** — its clef kinds are `glyph`/`text` only, so the
  value set was kept to `'dozenal`/`'text`/`'none`. Decision recorded
  for the Session 3 handoff.
- Noted: `test-unit.ly` did not include `cnb/clefs.ly` at all (the
  module was previously untested); the include was added this session.

### Style + text settings — `session-001/clef-style-and-text`

- `cnb/config.ly`: new **`cnb:clef-style`** (symbol, default
  `'dozenal` = today's behavior). `'text` renders the configured label
  instead of the computed numeral; `'none` engraves **no stencil** (the
  engraver sets `stencil = #f`), so a Configurator config with its clef
  disabled finally matches its preview. Unrecognized values warn and
  fall back to `'dozenal` (`cnb:clef-resolved-style`, `cnb/clefs.ly`).
- `cnb/config.ly`: new **`cnb:clef-text`** (default `""`), consumed
  when style is `'text`. Contract: a **string renders bold** (matching
  the dozenal numeral's weight) at the glyph's natural aspect ratio; a
  **markup is used as-is** for full styling control. A zero-height
  label (e.g. the default `""`) renders as-is unscaled to avoid a
  divide-by-zero. Non-string/non-markup values warn and render nothing.
- `cnb/clefs.ly` restructured: stencil construction split into
  `cnb:build-dozenal-clef-stencil` / `cnb:build-text-clef-stencil`;
  both share the same vertical placement (`-.5 * mag` translate +
  engraver `Y-offset`).

### Size setting — `session-001/clef-size-semitones`

- `cnb/config.ly`: new **`cnb:clef-size-semitones`** (default `#f` =
  legacy 3 staff-spaces — deliberately NOT a fixed semitone number,
  since 3 staff-spaces spans `(* 3 cnb:semitones-per-staff-space)`
  semitones and a fixed default would change behavior on non-default
  staves). A number N renders the numeral/text N semitones tall
  regardless of `cnb:semitones-per-staff-space`. Math isolated in the
  pure helper `cnb:clef-target-height` (`cnb/clefs.ly`); applies to
  both `'dozenal` and `'text` styles; scales with font magnification
  exactly as the legacy path did.
- **Cache-key rework** (the spec's stale-stencil warning): the clef
  stencil cache key grew from `(middleCPosition . ottava)` to a list of
  every input the stencil depends on — style, middleCPosition, ottava,
  text label (participates only under `'text`, so dozenal entries are
  not invalidated by label edits), size setting,
  `cnb:semitones-per-staff-space`, and font magnification. Including
  mag also fixes a latent pre-existing staleness (two clefs at
  different `font-size` previously shared one cached stencil).

### Tests + docs — `session-001/tests-green`

- `test-unit.ly`: now includes `cnb/clefs.ly`; 30 new assertions
  (dozenal register mapping for all seven standard clefs + ottava
  offsets; the three setting defaults; style resolution incl. the
  bogus-value fallback; size math at sps-1/sps-2/sps-3, default vs
  explicit, fractional results, magnification interaction, and the
  9-semitones-at-sps-3 ≡ legacy equivalence). **Unit suite: 209/209
  passed** (was 179).
- New integration specs: `tests/clef-none.json` (clef element absent
  from the SVG, noteheads unaffected), `tests/clef-text-size.json`
  (text label renders in the clef slot, positioned left of the first
  notehead), `tests/clef-size-dozenal.json` (8 semitones on the sps-2
  staff = 4/3 of legacy → harvested clef bbox width 1.102 → 1.469).
  Observability caveat recorded in the specs: a single-`<text>` stencil
  harvests as an anchor point (0×0 bbox), so text-mode SIZE is asserted
  via the dozenal display's size-proportional bbox width instead.
- **Full integration suite: 239/239 passed (332 expressions, 8 specs)**
  including both golden joy-to-the-world specs; `git status` confirms
  the re-rendered golden SVGs/harvests are **byte-identical** — zero
  baseline drift with default settings.
- `README.md`: three new rows in the Engine Settings table; unit
  assertion count refreshed to 209.
