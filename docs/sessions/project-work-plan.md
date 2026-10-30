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
| 2 | Challenge the plan, then break it into numbered sessions | no | 2026-10-30 |
| 3 | Make the test tooling portable and gate honestly | no | 2026-10-30 |
| 4 | Remove cruft and record LilyPond compatibility | no | 2026-10-30 |
| 5 | Clean up the guidance and README for 1.0.0 | — | not declared |
| 6 | Declare the source-archive packaging | — | not declared |
| 7 | Release 1.0.0 (release: 1.0.0) | — | not declared |

### Session 1 — Author or import the solution plan

**Releasable: no.**

Import the operator-approved wrap-up brief (docs/planning/brief.md) into the existing docs/planning/project-plan.md, amending that file rather than creating a solution-plan.md, as the brief directs. The amendment adds: the wrap-up objective (finish, clean up and document the CNB engine to 'reliable for simple exploration', release it as 1.0.0 and make the repository public under CC0) with its out-of-scope list and success criteria; the Production split the brief answers (one module, the LilyPond/Scheme source tree plus Python test tooling, no database, nothing running separately); the Handoff artifacts (a source archive produced by `git archive` plus an annotated v1.0.0 tag read from version.json); the single module's responsibility, contract and the cuts deliberately not made; the refreshed current state on 2026-10-30; and the wrap-up phases E1 (portable, honest test tooling), E2 (cruft removal and LilyPond compatibility note), E3 (guidance and README cleanup, version.json), the packaging session and the Release 1.0.0 session, each with its key deliverables, plus the constraints (session-sets kept as read-only history, golden baselines must not drift, IP posture per section 5). Stale counts and phase status in the existing sections are corrected where they contradict the brief's state.

### Session 2 — Challenge the plan, then break it into numbered sessions

**Releasable: no.**

Challenge the cuts of docs/planning/project-plan.md (this repository's plan file; there is no solution-plan.md) and record the answers as a new rationale subsection, section 7.7: whether the single module should exist and tools/ stay uncut; whether each contract clause is a promise something can prove (the golden-harvest no-drift promise is provable only by `git diff --exit-code -- tests` after the integration run, because tools/run_tests.py rewrites tests/*.harvested.json in place and compares nothing, so E1 chooses -dno-point-and-click over an ignored output folder to keep the tracked tree as the drift detector; the unit suite cannot fail today and E1 fixes that); whether the dependency direction hides the decisions most likely to change (the LilyPond version and the Configurator's export contract); and that the only deferred cut, splitting tools/, stays deferred. The challenge also records two planning corrections found in the 3.27.0 router: the release preflight refuses a release while any session since the last release closed without a VERIFIED verdict, so the brief's `Policy: fast` lines are not carried into E2/E3; and the tracked tools/__pycache__/*.pyc files are cruft E2 removes alongside the brief's list. Then append the numbered sessions to docs/sessions/session-plan.md: Session 3 (E1, portable and honest test tooling, also the skeleton-equivalent session that declares the second suite, since this repository has no solution or build files to scaffold), Session 4 (E2, cruft removal and LilyPond compatibility note), Session 5 (E3, guidance and README cleanup plus version.json 1.0.0), Session 6 (packaging: the pack-only `packaging:` block, checked with `dabbler packaging --rehearse`), and Session 7: Release 1.0.0 (release: 1.0.0), with no steps, proposed as a major version because it is the first release. Each work session has a Register step and at most three work steps, and every step that runs a suite names which one.

### Session 3 — Make the test tooling portable and gate honestly

**Releasable: no.**

Make the CNB test tooling portable and make it gate honestly. tools/run_tests.py and tools/harvest_svg.py reconfigure stdout/stderr to UTF-8 (falling back to ASCII-safe replacement), open every file with encoding="utf-8" while keeping the bytes harvests are written with, render with -dno-point-and-click, and warn without failing when lilypond --version is not 2.24.x. run_tests.py turns golden drift into a test failure: it compares each regenerated tests/*.harvested.json with the tracked copy, and on a difference leaves the file untouched, names the differing element ids and properties, and exits non-zero; --update-baselines writes the regenerated harvest instead, and a spec with no harvest yet writes one and passes. Tests for that comparison go in tools/test_run_tests.py (stdlib unittest, no LilyPond). The tracked tests/*.svg are re-baselined once without their textedit:// links. A new tools/run_unit.py runs lilypond test-unit.ly into an ignored out/ folder under a time limit, parses the TEST RESULTS line and exits non-zero on any failure, a missing line, a LilyPond error or the time limit; dabbler.yaml declares it as the engine-unit suite, adds an engine-tooling suite for the tooling's own unittest tests, and drops -X utf8 from engine-integration. Finally tests/example-notes.json is written from its harvest, pruned to assertions that pin what the score is for, tests/TODO.md is deleted, and the README's test counts and status banner are brought to what the two suites report.

**Amended after acceptance:**

- 2026-10-30 — step 'portable-runner': its files: tools/__pycache__/harvest_svg.cpython-311.pyc is still tracked (session 4 untracks it) and Python regenerates it whenever harvest_svg.py changes, so editing harvest_svg.py changes it (claude-code (anthropic, claude-opus-5-5))

### Session 4 — Remove cruft and record LilyPond compatibility

**Releasable: no.**

Remove the repository's cruft and record how the engine fares on the newest LilyPond. Delete tools/old/ and tools/to-transition-to-python/ outright (git history keeps them), stop tracking tools/__pycache__/*.pyc (already ignored) and test-unit.pdf, and ignore /test-unit.pdf; prove nothing depended on them by running the engine-integration suite whole and the engine-unit suite. Mark docs/planning/configurator-coordination-backlog.md closed at its top, naming the session sets that resolved it (005-clef-configurability, 006-keysig-configurability, 007-vector-model-removal, 008-pitch-axis-hook; §4 was never this repository's). Render tests/c-major-scale.ly once with LilyPond 2.26.0, called by its full path D:\lilypond-2.26.0-mingw-x86_64\lilypond-2.26.0\bin\lilypond.exe with its output in the ignored out/ folder, and record in the README's Requirements section whether it works, fails (with the first error) or is untested and why, including any \version or convert-ly warning it prints; 2.24.x stays the supported version.
