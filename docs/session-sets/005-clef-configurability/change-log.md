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

## Session 2 (2026-07-07) — Custom-clef registration hook

**Orchestrator:** claude-code / anthropic (lightweight tier, no metered calls)

### Registration hook — `session-002/register-clef-hook`

- `cnb/clefs.ly`: new **`cnb:register-clef!`** `(name def)` — a
  two-argument hook mirroring `cnb:register-path!` (deviation from the
  backlog's proposed single-list `'(name path-data)` shape, recorded
  for the Session 3 handoff). `def` is an alist:
  `(path . <command list>)` (required; same nested format as
  `cnb:notehead-shape-path`), `(anchor-semitones . <number>)`
  (required; float per the 009 contract), optional
  `(height-semitones . <positive number>)` (design height), optional
  `(color . "#RRGGBB")`. Definitions live in a new `cnb:clef-defs`
  hash table in `cnb/clefs.ly` (not `procedure.ly` — everything else
  clef-shaped is in this module; decision recorded). Structurally
  invalid defs (including the backlog's bare-list shape) **warn and
  are not registered** — the validator checks alist shape first so
  malformed input degrades instead of crashing `assq-ref`.
- **Selection:** `cnb:clef-style` grew a `'custom` value +
  new `cnb:config.ly` setting **`cnb:clef-name`** (symbol, default
  `#f`). New `cnb:clef-effective-style` downgrades `'custom` with a
  missing/invalid registration to `'dozenal` with a warning — a broken
  config renders today's display, never an empty clef slot or a crash.

### Anchor contract + gutter — `session-002/anchor-contract-implemented`

- **Anchor contract as implemented** (Configurator 009 s1 record:
  `anchorSemi` = FLOAT semitone of the glyph's TOP edge):
  `anchor-semitones` uses the engine's pitch-semitone coordinate — the
  same one the notehead engraver renders on (`ly:pitch-semitones`
  units, middle C = 0). Placement reuses the notehead position formula
  verbatim (pure helper `cnb:clef-anchor-y-offset`):
  `Y-offset = (anchor + 2·middleCPosition) / cnb:semitones-per-staff-space
  × staff-space`, so the top edge lands where a notehead of that pitch
  position would center, dividing through sps correctly on any staff
  design. `middleCPosition` is used as-is (includes any active ottava
  shift, exactly like noteheads — recorded for the handoff).
- The custom stencil (`cnb:build-custom-clef-stencil`) is built with
  its top edge at y = 0 (scaled uniformly, then translated by
  −top-extent); the engraver Y-offsets the grob to the anchor.
  Verified end-to-end: anchor 16 on the default sps-2 treble staff
  harvests the bbox top edge at the top staff line (8.045 vs 8.05).
- **Size precedence (recorded decision):** explicit
  `cnb:clef-size-semitones` (score-level override) > the definition's
  `height-semitones` (design height) > native path scale (1 path unit
  = 1 staff-space) — pure helper `cnb:clef-custom-target-semitones`.
  Scaling is uniform (aspect ratio preserved); font magnification
  scales the glyph exactly as the dozenal/text builders do.
- **Gutter padding:** new `cnb:config.ly` setting
  **`cnb:clef-gutter-semitones`** (default `#f` = legacy spacing).
  A number N widens the built stencil's right X-extent by
  N/sps × mag staff-spaces of blank space (`cnb:clef-apply-gutter`,
  pure math in `cnb:clef-gutter-pad`). Applies to every rendered
  style, not just `'custom` (recorded decision). Measured effect:
  4 semitones (2 staff-spaces) shifts the first notehead +1.5
  staff-space units — LilyPond's elastic spacing absorbs part of the
  extent, so the spec pins the deterministic rendered position rather
  than a naive gap = gutter equality.
- **Cache extension (spec step 3):** the Session 1 cache key grew two
  fields — the custom clef name (participates only under `'custom`,
  so dozenal/text entries are not invalidated by name switches) and
  the gutter setting. `cnb:register-clef!` **clears the whole stencil
  cache**, because re-registration mutates what an existing `'custom`
  key would render.

### Tests + docs — `session-002/tests-green`

- `test-unit.ly`: 45 new assertions — registration/lookup (incl. the
  pinned "FLOAT anchor-semitones is accepted" test mirroring the
  Configurator's, re-registration, and four invalid-def rejections),
  `'custom` style resolution + fallback, anchor math at sps-1/2/3 with
  fractional anchors and mcp interaction (anchor 16 ≡ top staff line
  on treble sps-2), size precedence, gutter math, and real stencil
  geometry via `make-path-stencil` (top edge at y = 0, height/width,
  override wins, native scale, magnification, gutter X-extent).
  **Unit suite: 254/254 passed** (was 209).
- New integration spec `tests/clef-custom.json` (+ `.ly`): a
  registered 1×2 rectangle clef at anchor 16 / height 8 / gutter 4 —
  asserts the harvested bbox top edge on the TOP staff line and bottom
  edge on the BOTTOM line (path stencils harvest real outlines, unlike
  the dozenal text anchors), exact 4-staff-space height, uniform
  width, and the gutter-shifted first-notehead x (14.762 vs 13.262
  no-gutter counterfactual, measured this session).
- **Full integration suite: 245/245 passed (343 assertions, 9 specs)**
  including both golden joy-to-the-world specs; `git status` shows no
  modified golden SVGs/harvests — **zero baseline drift** with default
  settings.
- `README.md`: `cnb:register-clef!` added to the Registration API
  table with a definition-format note; two new Engine Settings rows
  (`cnb:clef-name`, `cnb:clef-gutter-semitones`); `cnb:clef-style` /
  `cnb:clef-size-semitones` rows updated; assertion counts refreshed.
