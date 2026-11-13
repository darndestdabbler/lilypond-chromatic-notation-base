# Legacy vector-cycling model removal

> **Purpose:** Close backlog §3 from
> `docs/planning/configurator-coordination-backlog.md` (carried forward
> from the Configurator's set-007 handoff, item 5): remove the legacy
> vector-cycling model now that the README marks removal as unblocked —
> while **keeping `cnb:use-procedure-model` defined**, since every
> Configurator export unconditionally emits
> `#(set! cnb:use-procedure-model #t)` (LY export spec 1.2.1 §5.1).
> **Session Set:** `docs/session-sets/007-vector-model-removal/`
> **Created:** 2026-07-07
> **Workflow:** lightweight
> **Prerequisite:** None hard; scheduled after 005/006 by the
> lowest-`NNN`-first rule so the contract-surface work the Configurator is
> waiting on lands first. If 005/006 land engine changes near the stencil
> pipeline, rebase this set's inventory on the then-current code, not on
> the line references below.

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
> Rationale: refactor/removal work fully guarded by the existing unit +
> integration + golden-baseline harness; no metered calls. Two sessions:
> inventory + migration, then removal + re-verification.

---

## Project Overview

Backlog §3.1: this repo's README marks vector-model removal as
**unblocked** (engine set 004 proved the 007/004 round-trip renders a
Configurator-generated procedure-model config pixel- and hash-identical
to the golden baseline with zero hand edits). The project plan lists the
dual-model coexistence as Known Issue #2 and had deferred removal "unless
separately requested" — the Configurator set-007 handoff and this backlog
are that request.

**Where the vector model lives today (re-verify in Session 1):**

- `cnb/config.ly` — the cycling sequence vectors
  (`cnb:notehead-color-sequence`, `-shape-`, `-hollow-`, `-rotation-`,
  `-scaling-`, `-offset-sequence`, `cnb:stem-attachment-sequence`) and
  the `cnb:use-procedure-model` flag (default `#f`).
- `cnb/stencils.ly` — `cnb:build-base-stencils`, the sequence-length
  helpers, `cnb:base-stencil-vector`, and the
  `(if cnb:use-procedure-model ...)` branches (~lines 354, 396).
- `cnb/stems.ly` — vector fallback branches (~lines 68–81).
- Reference configs/tests: `Kite-4-369-Notation-Clean.ly` (vector-model
  config) vs. `Kite-4-369-Notation-Procedure.ly` (procedure-model);
  `test-unit.ly` assertions that exercise the cycling vectors; anything
  under `tests/` still rendering through the vector path.

**Hard constraints:**

1. **`cnb:use-procedure-model` stays defined.** The Configurator ALWAYS
   emits `#(set! cnb:use-procedure-model #t)`; a `set!` to an existing
   variable is harmless, but removing the variable would break every
   existing export. Flip its default to `#t` and make it a documented
   no-op (or keep a cheap guard), per the backlog's "keep the variable
   (or coordinate first)" instruction. Removing it instead requires a
   coordinated Configurator spec/exporter change — out of scope here.
2. **The golden baseline must not move.** The procedure-model rendering
   path is untouched in intent; prove it by re-running the set-004
   render → harvest → diff loop (Configurator-exported config vs. golden
   baseline) after removal, in addition to the unit + integration suites.

**Non-goals:** any behavior change to the procedure model; new settings;
duration-aware/key-aware rules; `cnb:get-staff-config` — all still
deferred per project plan §3.

---

## Sessions

### Session 1 of 2: Inventory and migration off the vector path

**Goal:** Every consumer of the vector model (configs, tests, docs) is
identified and migrated or retired, leaving the vector code paths with
zero remaining callers.

**Steps:**
1. **Pre-flight:** re-verify the inventory above (grep
   `cnb:use-procedure-model`, `-sequence`, `cnb:build-base-stencils`
   across the repo, including `tests/`, `tools/`, top-level `.ly`
   configs, README, and `docs/`). Record the true inventory in the change
   log — the removal in Session 2 executes against this list.
2. Decide and record the disposition of `Kite-4-369-Notation-Clean.ly`
   (the vector-model reference config): retire it, or migrate it to the
   procedure model — the procedure-model equivalent
   (`Kite-4-369-Notation-Procedure.ly`) already exists, so retirement
   with a README note is the expected outcome unless something still
   references the Clean variant.
3. Migrate or retire every `test-unit.ly` assertion that exercises the
   cycling vectors: keep equivalent coverage where the behavior survives
   in the procedure model (e.g. wrapping/modulo semantics), delete
   coverage of behavior that is being removed. Assertion count may drop;
   record before/after counts and why.
4. Flip `cnb:use-procedure-model`'s default to `#t` and update every
   in-repo config/test that relied on the `#f` default. Run the FULL
   unit + integration suites green. Commit. (The vector code itself is
   still present after this session — only unreferenced.)

**Creates:** none expected
**Touches:** `test-unit.ly`, `tests/`, top-level notation configs,
`cnb/config.ly` (default flip only), `README.md`
**Ends with:** zero in-repo consumers of the vector path; default is the
procedure model; full suite green; committed.
**Progress keys:** `session-001/inventory-recorded`,
`session-001/consumers-migrated`, `session-001/default-flipped`

---

### Session 2 of 2: Remove the vector code paths and re-verify the round-trip

**Goal:** The vector-cycling implementation is gone, the procedure model
is the only model, and the set-004 round-trip verification still passes
byte-stable.

**Steps:**
1. Remove the vector-model code paths per Session 1's inventory:
   the `(if cnb:use-procedure-model ...)` branches in `cnb/stencils.ly`
   and `cnb/stems.ly` (procedure branch becomes unconditional), the
   sequence vectors and their helpers, `cnb:build-base-stencils` /
   `cnb:base-stencil-vector`, and any now-dead utils. Keep
   `cnb:use-procedure-model` defined (default `#t`) with a comment
   explaining exactly why it must never be deleted (Configurator exports
   `set!` it — spec 1.2.1 §5.1).
2. Update module header comments (`cnb/stencils.ly`, `cnb/config.ly`,
   `cnb/stems.ly`, `cnb/off-key.ly` if applicable) and `README.md` so no
   doc still describes the dual-model architecture; update
   `docs/planning/project-plan.md` Known Issue #2 to resolved.
3. Run the FULL unit + integration suites green.
4. Re-run the set-004 end-to-end loop: render the Configurator-exported
   config (consumables listed in set 004's spec banner), harvest via
   `tools/harvest_svg.py`, diff against the golden baseline via
   `tools/run_tests.py` — must be as clean as set 004 left it.
5. Update `docs/planning/configurator-coordination-backlog.md`: mark item
   3.1 resolved (move to its §5 with a pointer to this set). Note in the
   change log that no Configurator-side action is required (the emitted
   `set!` line remains valid — that's the point of constraint 1). Commit.

**Creates:** none expected
**Touches:** `cnb/stencils.ly`, `cnb/stems.ly`, `cnb/config.ly`,
`cnb/utils.ly` (dead helpers only), `README.md`,
`docs/planning/project-plan.md`,
`docs/planning/configurator-coordination-backlog.md`
**Ends with:** single-model engine; full suite + round-trip verification
green; docs and backlog updated; set ready to close.
**Progress keys:** `session-002/vector-code-removed`,
`session-002/roundtrip-reverified`, `session-002/backlog-updated`

---

## End-of-set deliverables

- The legacy vector-cycling model removed from the engine; the procedure
  model is the only model.
- `cnb:use-procedure-model` still defined (default `#t`, documented
  keep-forever guard) so every existing Configurator export keeps
  working unchanged.
- Full unit + integration suites green; set-004 round-trip verification
  re-run clean against the golden baseline.
- Project plan Known Issue #2 closed; backlog §3.1 marked resolved.
