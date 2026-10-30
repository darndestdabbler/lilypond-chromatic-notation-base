# Project work plan — sessions

**Written by `dabbler` as a fold of `activity-log.json`.**
Hand edits are overwritten by the next append. The record is the log;
this page is one view of it.

---

## Sessions

The numbered sessions are declared from `session-plan.md`; each one's task is what its own plan step declared.

| # | Session | Releasable | Declared |
| ---: | --- | --- | --- |
| 1 | Author or import the solution plan | no | 2026-10-30 |
| 2 | Challenge the plan, then break it into numbered sessions | — | not declared |

### Session 1 — Author or import the solution plan

**Releasable: no.**

Import the operator-approved wrap-up brief (docs/planning/brief.md) into the existing docs/planning/project-plan.md, amending that file rather than creating a solution-plan.md, as the brief directs. The amendment adds: the wrap-up objective (finish, clean up and document the CNB engine to 'reliable for simple exploration', release it as 1.0.0 and make the repository public under CC0) with its out-of-scope list and success criteria; the Production split the brief answers (one module, the LilyPond/Scheme source tree plus Python test tooling, no database, nothing running separately); the Handoff artifacts (a source archive produced by `git archive` plus an annotated v1.0.0 tag read from version.json); the single module's responsibility, contract and the cuts deliberately not made; the refreshed current state on 2026-10-30; and the wrap-up phases E1 (portable, honest test tooling), E2 (cruft removal and LilyPond compatibility note), E3 (guidance and README cleanup, version.json), the packaging session and the Release 1.0.0 session, each with its key deliverables, plus the constraints (session-sets kept as read-only history, golden baselines must not drift, IP posture per section 5). Stale counts and phase status in the existing sections are corrected where they contradict the brief's state.
