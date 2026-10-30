# Documentation accuracy & attribution pass

> **Purpose:** Close out Phase C: fix the README overclaim about what
> notation systems this engine actually produces, and tighten the
> Acknowledgments/attribution section per the project plan's §5 IP
> guidance.
> **Session Set:** `docs/session-sets/003-docs-attribution-pass/`
> **Created:** 2026-07-04
> **Workflow:** lightweight
> **Prerequisite:** None

---

## Session Set Configuration

```yaml
tier: lightweight
requiresUAT: false
requiresE2E: false
uatScope: none
uatStyle: ad-hoc
verificationMode: out-of-band-or-none
totalSessions: 1
# prerequisites:
#   - slug: <prerequisite-slug>
#     condition: complete
```

> **Tier:** see the tier model SSoT:
> <https://github.com/darndestdabbler/dabbler-ai-orchestration/blob/master/docs/concepts/tier-model.md>.
>
> Rationale: docs-only, no code risk; single short session per the project
> plan's own sizing ("1 short session").

---

## Project Overview

`docs/planning/project-plan.md` §5 lays out, in detail, the naming and
attribution issues this pass needs to fix: the README's overclaim that CNB
"produces" Kite, Clairnote SN, and Chromatic Lyre notation (when only Kite
has a working config in this repo); the Clairnote SN vs. `clairnote.ly`
license split (CC BY-SA 4.0 for the notation design vs. GPL v3 for Paul
Morris's separate LilyPond implementation); Chromatic Lyre's no-license
status; and the "Kite" naming collision with the unrelated xenharmonic
theorist Kite Giedraitis.

**Pre-flight check performed when this set was authored (2026-07-04): most
of this work already exists as uncommitted changes in the working tree.**
`README.md` and `cnb/articulations.ly` both currently show uncommitted
diffs that already implement the bulk of §5's guidance: the README opening
line has been rewritten to distinguish architecture from what's actually
implemented, the Acknowledgments section has been rewritten with the
CC BY-SA/GPL v3 split and the Kite disambiguation note, and
`articulations.ly`'s header comment has been reworded from "ADAPTED FROM"
to "RELATED PRIOR ART (no shared code)". A `LICENSE` file (CC0 1.0) also
already exists as a new, untracked file, referenced from the README's
License section. **None of this is committed yet.**

This session's job is therefore **verification and finish-up, not drafting
from scratch**: confirm the in-progress edits actually satisfy §5's
requirements, check whether the three sibling files §5 flags
(`cnb/beams.ly`, `cnb/stems.ly`, `cnb/ledgers.ly`) still need the same
header reword `articulations.ly` already got, then commit everything
together. If the working-tree state has changed since 2026-07-04 (e.g. the
uncommitted diffs were already committed or reverted), re-derive the actual
gap from `git status`/`git diff` at session start rather than trusting this
paragraph.

---

## Sessions

### Session 1 of 1: Verify, finish, and commit the attribution pass

**Goal:** README.md, the four flagged engine-module headers, and the
LICENSE file all satisfy the project plan §5 guidance, and the changes are
committed.

**Steps:**
1. Run `git status` and `git diff -- README.md cnb/articulations.ly` to
   confirm what's already changed in the working tree matches this spec's
   Project Overview description. If the state differs, treat `git
   diff`/`git status` as ground truth over this document.
2. Check the existing README diff against each specific §5 requirement:
   the overclaim rewrite, the CC BY-SA 4.0 (notation design) vs. GPL v3
   (`clairnote.ly`) distinction, the Chromatic Lyre no-license note, the
   Kite/Kite Giedraitis disambiguation, and the LICENSE file reference in
   the License section. Fix anything missing or inaccurate.
3. Check `cnb/beams.ly`, `cnb/stems.ly`, and `cnb/ledgers.ly` headers for
   the same "ADAPTED FROM" phrasing `cnb/articulations.ly` had before its
   already-applied fix. If any still say "ADAPTED FROM" (or otherwise
   overstate the relationship to `clairnote.ly`/`chromaticlyre.ly`), reword
   to "RELATED PRIOR ART (no shared code)" following `articulations.ly`'s
   already-fixed header as the template — but only if each file's actual
   implementation is in fact independent (per §5's finding that all four
   are); do not apply the reword to a file without confirming its content
   first.
4. Confirm the `LICENSE` file at repo root is the verbatim CC0 1.0
   Universal text.
5. Stage and commit `README.md`, `cnb/articulations.ly`, any of
   `beams.ly`/`stems.ly`/`ledgers.ly` that needed the same fix, and
   `LICENSE` together as this set's deliverable.

**Creates:** none expected (LICENSE already present, untracked — this
session commits it, doesn't author it)
**Touches:** `README.md`, `cnb/articulations.ly`, `cnb/beams.ly`,
`cnb/stems.ly`, `cnb/ledgers.ly`, `LICENSE`
**Ends with:** all §5 attribution/naming requirements verified against the
actual file contents and committed; no lingering uncommitted attribution
edits.
**Progress keys:** `session-001/attribution-verified`,
`session-001/headers-reconciled`, `session-001/committed`

---

## End-of-set deliverables

- README.md accurately distinguishes CNB's architectural flexibility from
  its one actually-implemented notation system (Kite 4-369).
- Acknowledgments section correctly attributes Clairnote SN and Chromatic
  Lyre Notation with accurate license status for each.
- Kite/Kite Giedraitis naming disambiguation is in the README.
- All four flagged engine-module headers accurately describe their
  relationship (or lack thereof) to external LilyPond implementations.
- LICENSE file present and committed.
