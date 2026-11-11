# Change log — 003-docs-attribution-pass

## Session 1 (2026-07-04) — Verify, finish, and commit the attribution pass

**Orchestrator:** claude-code / anthropic (lightweight tier, no metered calls)

### Verification pass (Steps 1–2) — `session-001/attribution-verified`

- Working-tree state matched the spec's 2026-07-04 pre-flight description
  exactly: uncommitted diffs on `README.md` and `cnb/articulations.ly`,
  plus an untracked `LICENSE` file. No re-derivation needed.
- Checked the README diff against each §5 requirement — all present and
  accurate:
  - **Overclaim rewrite:** opening line no longer says CNB "can produce"
    Kite/Clairnote SN/Chromatic Lyre; it now distinguishes the
    config-driven architecture from the one implemented system
    (Kite 4-369) and states no Clairnote SN / Chromatic Lyre config
    exists here and neither author has reviewed or endorsed the project.
  - **License split:** Acknowledgments distinguishes Clairnote SN's
    notation design + site content (CC BY-SA 4.0) from Paul Morris's
    separate `clairnote.ly` implementation (GPL v3).
  - **Chromatic Lyre:** notes `chromaticlyre.ly` carries no license
    header.
  - **Kite disambiguation:** naming note (plus an inline pointer from the
    opening paragraph) states this repo's Kite notation is original and
    unrelated to Kite Giedraitis's xenharmonic work.
  - **LICENSE reference:** License section links the `LICENSE` file and
    keeps the LilyPond-GPL-doesn't-reach-input-files note.
- Swept the rest of the README for residual overclaims (`Clairnote`,
  `Lyre`, `Kite`, `produce`): remaining hits are unrelated (pipeline
  correctness in the status note, SVG harvesting caveat) or config-file
  references. Nothing needed fixing — the in-progress edits were complete
  as found.

### Sibling-header check (Step 3) — `session-001/headers-reconciled`

- `cnb/articulations.ly` already carries the "RELATED PRIOR ART (no
  shared code)" reword (part of the pre-existing uncommitted diff).
- Read every Clairnote/Chromatic Lyre mention in `cnb/beams.ly`,
  `cnb/stems.ly`, `cnb/ledgers.ly` in context. None say "ADAPTED FROM"
  or claim derived code — all describe shared *technique* dictated by
  the math or LilyPond's grob API ("do this same compensation",
  "same pattern Clairnote uses" for LilyPond's required quoted-callback
  eval mechanism, and the `1.1` numeric fudge factor §5 already assessed
  as a bare tuning constant). **No changes were needed to the three
  sibling files** — the spec's conditional reword did not apply.

### LICENSE check (Step 4)

- Confirmed `LICENSE` at repo root is the verbatim CC0 1.0 Universal
  legal code (full text: Statement of Purpose, §§1–4, no alterations).

### Commit (Step 5) — `session-001/committed`

- Committed `README.md`, `cnb/articulations.ly`, and `LICENSE` together
  as the set deliverable (`a672a3e`, "Fix README overclaim and tighten
  attribution per project plan §5").
- `cnb/beams.ly` / `cnb/stems.ly` / `cnb/ledgers.ly` intentionally not
  touched (verified clean, see above). The unrelated `test-unit.pdf`
  working-tree modification (binary, byte-identical size — regeneration
  artifact from set 002's test runs) was left uncommitted as out of
  scope.

### Deliverables status

All five end-of-set deliverables satisfied: accurate README claim scope,
correct per-system attribution/licensing, Kite disambiguation present,
all four flagged module headers accurate, LICENSE committed.
