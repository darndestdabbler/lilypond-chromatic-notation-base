# Callback chaining fix — `after-line-breaking` on NoteHead

> **Purpose:** Resolve Known Issue #1: `cnb/test-ids.ly` and
> `cnb/off-key.ly` both directly overwrite `after-line-breaking` on
> NoteHead grobs, so whichever module runs last silently clobbers the
> other's hook.
> **Session Set:** `docs/session-sets/002-callback-chaining-fix/`
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
> Rationale: a contained engine-code fix with an existing test harness to
> validate against; no UI, no metered-call need, single session is enough.

---

## Project Overview

**Confirmed still open when this set was authored (2026-07-04):** both
`cnb/off-key.ly:280` (and `:304`) and `cnb/test-ids.ly:494` (also `:519`,
`:523` for Tie/Slur) call `ly:grob-set-property!` directly on
`after-line-breaking`, overwriting rather than composing with whatever the
other module already set. `test-ids.ly`'s own header comment (lines ~57-69)
already documents the collision risk in prose — it just isn't fixed in
code. Whichever module's engraver runs later in a given file wins; the
other's callback never fires.

**Scope:** implement callback chaining (wrap the existing callback, don't
replace it) so both `off-key.ly`'s off-key-mark stencil callback and
`test-ids.ly`'s ID-tagging callbacks can coexist on the same grob property.
This affects at minimum NoteHead (both files), and also Beam/Tie/Slur in
`test-ids.ly` if those interfaces are ever shared with another module's
`after-line-breaking` hook — but the concrete, confirmed collision to fix is
NoteHead.

**Non-goal:** this set does not remove the legacy vector-cycling model or
touch duration/key-aware rules — deferred per the project plan §3.

---

## Sessions

### Session 1 of 1: Chain `after-line-breaking` callbacks instead of overwriting them

**Goal:** `off-key.ly` and `test-ids.ly` can both hook a NoteHead's
`after-line-breaking` without one silently clobbering the other.

**Steps:**
1. Read the current `after-line-breaking` assignments in `cnb/off-key.ly`
   (`:280`, `:304`) and `cnb/test-ids.ly` (`:494`, `:519`, `:523`) to confirm
   exactly which grob interfaces and callback lambdas are involved.
2. Add a small chaining helper (e.g. in `cnb/utils.ly`, alongside this
   engine's other shared procedures) that takes a grob's existing
   `after-line-breaking` value (if any) and a new callback, and returns a
   composed callback that invokes both — existing-first or new-first,
   whichever preserves each callback's own invariants (check `off-key.ly`'s
   "WHY after-line-breaking?" comment at `:79` and `test-ids.ly`'s
   equivalent rationale for ordering constraints before picking an order).
3. Update `off-key.ly`'s and `test-ids.ly`'s NoteHead assignments to go
   through the chaining helper instead of a bare
   `ly:grob-set-property! grob 'after-line-breaking ...`.
4. Add a regression test (in `test-unit.ly` if it can exercise grob
   callbacks directly, otherwise as a small addition to the
   `tools/run_tests.py` / `harvest_svg.py` integration pipeline) that
   renders a score with both modules active and asserts both effects are
   present on the same NoteHead (e.g. both the test-id tag and the off-key
   stencil mark appear where expected).
5. Run the full existing suite (163 unit assertions + the 72/72 integration
   tests) to confirm no regressions, then run the new regression test.
6. Commit.

**Creates:** possibly a new chaining helper procedure in `cnb/utils.ly` (no
new file — added to the existing module unless the maintainer's convention
in this repo is otherwise)
**Touches:** `cnb/off-key.ly`, `cnb/test-ids.ly`, `cnb/utils.ly`,
`test-unit.ly` and/or the `tools/` test pipeline
**Ends with:** a passing regression test demonstrating both `off-key.ly`'s
and `test-ids.ly`'s `after-line-breaking` hooks fire on the same grob; full
existing suite still green; change committed.
**Progress keys:** `session-001/chaining-helper-added`,
`session-001/collision-fixed`, `session-001/regression-test-passing`

---

## End-of-set deliverables

- Callback chaining helper shared by both modules.
- Regression test proving both hooks coexist correctly on NoteHead.
- Known Issue #1 closed out (or, if not fully closeable in one session,
  documented with the remaining gap and why).
