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
| 5 | Clean up the guidance and README for 1.0.0 | no | 2026-10-30 |
| 6 | Declare the source-archive packaging | no | 2026-10-30 |
| 7 | Release 1.0.0 (release: 1.0.0) | yes | 2026-10-31 |
| 8 | Let the test runners choose a LilyPond version | no | 2026-10-31 |
| 9 | Make the engine and the harvester work on LilyPond 2.26 | no | 2026-10-31 |
| 10 | Document LilyPond 2.26 support and bump to 1.1.0 | no | 2026-10-31 |
| 11 | Release 1.1.0 (release: 1.1.0) | yes | 2026-10-31 |
| 12 | Engrave durations and dots correctly | no | 2026-11-02 |
| 13 | The test runner cannot pass a broken render | no | 2026-11-02 |
| 14 | Harvest what is drawn, and claim only what works | no | 2026-11-03 |
| 15 | A clean public archive, and 1.1.1 | no | 2026-11-03 |
| 16 | Release 1.1.1 (release: 1.1.1) | yes | 2026-11-03 |
| 17 | Stems attached at the notehead centre | no | 2026-11-04 |
| 18 | One include makes any LilyPond score chromatic | no | 2026-11-04 |
| 19 | MusicXML smoke tier and the corpus gate | no | 2026-11-05 |
| 20 | Fix what the corpus found | no | 2026-11-05 |
| 21 | Document 1.2.0 | no | 2026-11-05 |
| 22 | Work around LilyPond issue 2383 (beam quanting on magnified staves) | no | 2026-11-05 |
| 23 | Release 1.2.0 (release: 1.2.0) | yes | 2026-11-05 |
| 24 | Clefs and key signatures engrave where the Configurator draws them | no | 2026-11-10 |
| 25 | The breve as tied semibreves | no | 2026-11-10 |
| 26 | Document 1.3.0 | no | 2026-11-10 |
| 27 | Release 1.3.0 (release: 1.3.0) | — | not declared |

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

### Session 5 — Clean up the guidance and README for 1.0.0

**Releasable: no.**

Phase E3 of docs/planning/project-plan.md section 7.5: clean up the guidance and README for 1.0.0. The three guidance files under docs/planning (lessons-learned.md, lessons-archive.md, project-guidance.md) are untouched v1 templates whose only content is TODO placeholders and ai_router instructions, and the session-set change-logs record no lessons to harvest, so this session deletes all three (the plan's second option), which removes the v1 ai_router instructions with them; nothing outside the planning records that describe this task links to them. It then updates README.md: the status banner reads 1.0.0; a new "Known limitations" section states LilyPond 2.24.x only, tested on Windows, configs are generated by the Configurator, and clefs and key signatures follow the score; and the existing Testing section becomes "Running the tests", naming the declared suites exactly as dabbler.yaml declares them -- engine-integration (`python tools/run_tests.py`) and engine-unit (`python tools/run_unit.py`), plus the Python tooling's own engine-tooling suite. Finally it adds a root version.json reading { "version": "1.0.0" } for the release session to check against.

### Session 6 — Declare the source-archive packaging

**Releasable: no.**

Declare this repository's source-archive packaging in dabbler.yaml: replace the commented example packaging block with a real `packaging:` block whose `pack` argv is ["git", "archive", "--format=zip", "--output={output}/lilypond-chromatic-notation-base-{version}.zip", "HEAD"] and which declares no `push`. The `{version}` placeholder is used in place of the literal 1.0.0 because a rehearsal in a scratch clone accepted it (it resolved to 1.0.0 and the pack exited 0). The step is proved by `dabbler packaging --rehearse`, which runs the pack and pushes nothing.

### Session 7 — Release 1.0.0 (release: 1.0.0)

**Releasable: yes.**

Release 1.0.0: the framework packs and publishes what is on the trunk.

### Session 8 — Let the test runners choose a LilyPond version

**Releasable: no.**

Give tools/run_tests.py and tools/run_unit.py a --lilypond-version X.Y option. run_tests.py gains small helpers that both runners use: the variable name for a version (CNB_LILYPOND_X_Y), the version a lilypond executable reports (X.Y from the first line of --version), resolution of the executable (the variable's value, else the lilypond on PATH if it reports X.Y, else exit non-zero with a message naming the variable to set), the render directory (out/lilypond-X.Y/ for any version other than 2.24, so tracked tests/*.svg are never rewritten by such a run) and the harvest baseline directory (beside the spec for 2.24, tests/lilypond-2.26/ for 2.26, none for a version outside the supported set {2.24, 2.26}). The LilyPond executable is passed to run_lilypond instead of the hard-coded name. For an unsupported version run_tests.py warns once and skips the drift comparison while every assertion still runs; this replaces the old 'baselined on 2.24' warning, which is removed. Without the option both runners behave as today: lilypond from PATH, renders beside the spec (run_unit.py into out/), drift compared with tests/*.harvested.json. Tests in tools/test_run_tests.py cover resolution from the variable, from PATH, and the failure message; the baseline path for 2.24 and 2.26; and the unsupported-version skip. Then dabbler.yaml's engine-integration and engine-unit suite commands gain --lilypond-version 2.24 so the run of record names the version it proves.

### Session 9 — Make the engine and the harvester work on LilyPond 2.26

**Releasable: no.**

Make the CNB engine and its SVG harvester work on LilyPond 2.26 without changing anything on 2.24. In cnb/utils.ly, cnb:duration-category picks ly:duration->number (2.26) or duration-length (2.24) once at load time. In tools/harvest_svg.py, extract_color_deep rewrites an opaque rgba(...) colour to the 2.24 rgb(R%, G%, B%) form with every component at four decimals, while a colour that is not opaque keeps its alpha. A new tools/test_harvest_svg.py tests this. The clef-custom gutter assertion is restated as the operator decided on 2026-10-31. Measured from a no-gutter twin, the 2-staff-space gutter moves the first notehead +1.5 on 2.24 but the full +2.0 on 2.26, so no assertion that ignores the version can keep the 0.1 tolerance. tools/run_tests.py therefore exposes the LilyPond version under test to spec expressions as `lilypond` (2.24 when no version is given), tested in tools/test_run_tests.py. tests/clef-custom.json then asserts the first notehead's distance from the clef's right edge per version (9.117 on 2.24, 9.704 on 2.26), with the tolerance unchanged. 2.24 is proved unchanged: all three suites pass and the tracked tests/*.harvested.json do not drift. Then the 2.26 baselines tests/lilypond-2.26/*.harvested.json are written with --update-baselines after every assertion passes. Their coordinate shifts against 2.24 are spot-checked and recorded in section 7.7 of docs/planning/project-plan.md. Finally, engine-integration-2.26 and engine-unit-2.26 are declared in dabbler.yaml with the same fields and covers as their 2.24 counterparts.

### Session 10 — Document LilyPond 2.26 support and bump to 1.1.0

**Releasable: no.**

Document the LilyPond 2.26 support that session 9 delivered and bump the release version to 1.1.0. In README.md, Requirements names LilyPond 2.24.x or 2.26.x (tested with 2.24.2 and 2.26.0), and the "2.26 is not supported yet" paragraph and the Known limitations bullet are replaced with what was measured: all suites pass on both versions, each version has its own harvest baselines (tests/*.harvested.json for 2.24, tests/lilypond-2.26/*.harvested.json for 2.26), and 2.26 lays scores out slightly differently (uniform vertical staff offset, small horizontal spacing shifts after the clef and key signature, the clef gutter's full width), as recorded in section 7.7 of docs/planning/project-plan.md. "Running the tests" lists all five suites exactly as dabbler.yaml declares them, explains --lilypond-version X.Y and the CNB_LILYPOND_X_Y variable (else the lilypond on PATH that reports X.Y), and says that a contributor with only one version installed runs that version's suites. version.json becomes { "version": "1.1.0" }, the README status line says 1.1.0, and a short CHANGELOG.md records 1.0.0 (first release) and 1.1.0 (LilyPond 2.26 support; harvest baselines per version).

### Session 11 — Release 1.1.0 (release: 1.1.0)

**Releasable: yes.**

Release 1.1.0: the framework packs and publishes what is on the trunk.

### Session 12 — Engrave durations and dots correctly

**Releasable: no.**

Fix three engraving errors from the 2026-11-02 audit (H2, H3, M1) that every suite passed. H2: cnb:duration-category (cnb/utils.ly) is recomputed from the duration log alone as clamp(log + 1, 0, 3), so breve -> 0, whole -> 1, half -> 2 and quarter or shorter -> 3, the scale cnb/procedure.ly and the export spec already document; dots and the tuplet factor no longer change it. The consumers follow that scale: the repeat rule in cnb/stencils.ly (still 4 heads for whole and breve, 2 for a half, 1 for a quarter or shorter) and the cache-key comments; noteheads.ly, off-key.ly and stems.ly pass the category straight to the lookup and are confirmed. test-unit.ly gains unit tests for every duration log from -1 to 4, with and without dots, triplets and the cache key, and a new integration spec tests/duration-rules.ly/.json engraves breve, whole, half, quarter, eighth, dotted notes and triplets under a config that colours each category differently, asserting each note's colour and head count. H3: cnb/dots.ly stops counting the notehead's offset twice when it moves a dot off a ledger line, proved by a spec with dotted notes on and off ledger lines above and below the staff asserting each dot's distance from its notehead. M1: the notehead acknowledger captures the attachment record from the config current at acknowledge time onto the grob (as it already does for x-offset) and cnb:stem-attachment reads it from there, so a later \key change no longer rewrites earlier stems, proved by a spec with a key-dependent attachment and a mid-score key change. Finally all five suites run; any existing harvest that drifts is re-baselined on both versions only after every difference is checked to be one of these three fixes, and each re-baselined file (or that none drifted) is recorded in section 7.7 of docs/planning/project-plan.md.

### Session 13 — The test runner cannot pass a broken render

**Releasable: no.**

Close the audit's holes in the integration test runner so it cannot pass a broken render. In tools/run_tests.py: run_lilypond deletes every earlier render of the spec ({base}.svg and {base}-N.svg, including the tracked tests/{base}.svg) before LilyPond runs, so it can only harvest what this run wrote, and a multi-page render ({base}-1.svg, {base}-2.svg, ...) fails with a message instead of falling back to a stale file (H1); the default spec path is PROJECT_ROOT/tests, and a named path that does not exist or an empty spec list exits non-zero (M5); without --lilypond-version the runner detects the version of the lilypond on PATH and uses that version's render folder and baselines, so anything but 2.24 renders into out/lilypond-X.Y/ (L3); harvest_differences keys elements by id plus occurrence index, so an edit to a repeated id's later occurrence, or a newly duplicated id, shows as drift (M3);an element counts as absent-as-expected only when its assertion declares "absent": true, never because an expression contains `is None`, and an assertion with nothing to check fails (L6), with the two specs that use absence (clef-none, keysig-none) and the documented convention moved to the marker; resolve_lilypond checks that the executable CNB_LILYPOND_X_Y names reports X.Y and exits naming the variable otherwise (M4). dabbler.yaml adds tools/run_tests.py and tools/harvest_svg.py to both engine-unit suites' covers (L4). Each fix gets a test in tools/test_run_tests.py, and the audit's probes (key-signature regression plus \pageBreak, edited duplicate ids, CNB_LILYPOND_2_26 pointed at 2.24) are re-run outside the tracked tree and must each fail.

### Session 14 — Harvest what is drawn, and claim only what works

**Releasable: no.**

Make the harvester see what LilyPond draws, and make the README claim only what works and is tested. M2: tools/harvest_svg.py adds the extents of circle (cx±r, cy±r), ellipse (cx±rx, cy±ry), polygon and polyline (their points) to an element's bbox, so beams get a real bounding box, and records a new visual.shape_hash over the geometry of an element's non-path primitives (circle r, ellipse rx/ry, polygon and polyline points, text string, font family, weight, size and anchor, each with its accumulated scale), so an added or removed off-key ring, a changed beam or a changed text clef drifts; path_hash, representative positions and text's anchor-only bbox contribution are unchanged. Tests go in tools/test_harvest_svg.py. Both versions' baselines are re-baselined, and a check proves against b1c8fa0 that only bbox and shape_hash changed, and bbox only on elements that now carry a shape_hash. M6: the articulation Y-offset correction (cnb/articulations.ly) and the beam and stem compressed-staff compensation (cnb/beams.ly, the compensation half of cnb/stems.ly) are deleted rather than repaired, since the engine never sets staff-space and the proximity rule never yields an articulation adjustment, so they do nothing on the engine's own staff; their overrides, includes and README claims go with them, and every render is unchanged. M7, L1, L2: the runner counts only assertions that have an id and reports harvest drift separately from assertion failures; --generate refuses to overwrite an existing baseline without --update-baselines; the never-read --keep-svg goes. The README states the real assertion counts for 2.24 and 2.26 and the real project tree, docs/INTEGRATION-TESTING.md describes per-version baselines, --lilypond-version, CNB_LILYPOND_X_Y, drift and --update-baselines, the --generate refusal and shape_hash, and the dabbler.yaml comment's counts are corrected.

**Amended after acceptance:**

- 2026-11-03 — step 'docs-tell-the-truth': its checks: The check's bare 'scores/' substring test matched the external URL github.com/scaleshift-scores/... in the README acknowledgments, not a scores/ folder; it now looks for a scores/ entry in the project tree ('── scores/'). Every other assertion of the check is unchanged. (claude-code (anthropic, claude-opus-5-5))

### Session 15 — A clean public archive, and 1.1.1

**Releasable: no.**

Make the public source zip clean (audit L5) and set the version to 1.1.1. The findings file docs/session-sets/004-end-to-end-pipeline-verification/findings.md stops naming this machine's paths: its `c:\Users\denmi\source\repos\` path, and the `d:\Projects\chromatic-notation-configurator` paths in the same sentence and in its export command, become the sibling-relative `../chromatic-notation-configurator`. The five tracked evidence SVGs under docs/session-sets/008-pitch-axis-hook/s*-evidence/ that carry `textedit://D:/Projects/...` links are re-rendered from their own .ly files with LilyPond 2.24 and `-dno-point-and-click`; a trial render showed each comes out identical to the tracked file once links are removed, and a check proves that against fe23380. The literal strings the plan's grep looks for also occur in two tooling files that would ship: the `textedit://` in a tools/run_tests.py comment is reworded, and the `D:\ly\lilypond.exe` fixture in tools/test_run_tests.py becomes a path with no drive letter. A new .gitattributes marks `.vscode/`, `AGENTS.md`, `CLAUDE.md`, `docs/sessions/`, `docs/transcripts/` and `docs/planning/` export-ignore. The proof is `dabbler packaging --rehearse` (the pack runs) and, because that pack archives HEAD and the session's work is committed only at the land, a check that archives the working tree the same way (`git archive --format=zip` of a tree written from a temporary index) and asserts that none of those paths is in the zip and that no entry contains `textedit://`, `D:\` or `Users\`. Finally version.json becomes 1.1.1 and CHANGELOG.md gains a 1.1.1 entry summarising sessions 12 to 15, stating that duration categories now follow the documented scale (breve 0, whole 1, half 2, quarter or shorter 3), so a hand-written config that relied on the old off-by-one numbering must change.

### Session 16 — Release 1.1.1 (release: 1.1.1)

**Releasable: yes.**

Release 1.1.1: the framework packs and publishes what is on the trunk.

### Session 17 — Stems attached at the notehead centre

**Releasable: no.**

Prove that a stem anchored at the notehead centre, '(0 . 0), engraves well, and fix what does not. A new integration spec, tests/stem-centre.ly with tests/stem-centre.json, is baselined on LilyPond 2.24 and 2.26. Its small config registers one solid and one true-hollow 45-degree-tilted ellipse, each 4 semitones tall like Kite, with (0 . 0) for all four attachment points. It engraves stems up and down, a minim, a beamed pair and a chord. Per stem it asserts four things. The stem's x is the head's centre x. Its near end is at the head's centre y. Its far end is at LilyPond's standard stem length from the head's centre. The stem is drawn after (over) its head, so neither a true hole nor a false-hollow white overlay can hide it. The operator decided the length rule on 2026-11-04. LilyPond measures the far end from the head's centre whatever the anchor, and Kite's (0 . 0.9) anchors and the existing key-change test's (0 . 0) anchors already rely on that. So the engine keeps that length instead of lengthening inside-head anchors, and no existing harvest drifts. A 4-semitone centre-anchored stem therefore shows exactly as far past its head as a Kite stem does. The known defect is draw order: cnb/layout.ly puts NoteHead on layer 999 above stems. The fix draws stems above noteheads, and the only effect on existing tests is the element order inside their tracked SVGs. To assert draw order, the integration runner gains an order(id) helper: an element's index in the harvest, which is SVG document order. The README, under the attachment-registration row, says an anchor may be anywhere including the centre, what the engine does with length and draw order, and the toolkit rule a designer places an anchor by. Its headline test counts are refreshed.

**Amended after acceptance:**

- 2026-11-04 — step 'stem-centre': its files: The runner rewrites a harvest whose content matches its baseline, so drawing stems above noteheads reorders the elements of every existing tests/*.harvested.json and tests/lilypond-2.26/*.harvested.json. Element content is unchanged (verified against HEAD: same element set, same top-level keys); drift detection is order-insensitive and reports 0 drifted on 2.24 and 2.26. (claude-code (anthropic, claude-opus-5-5))
- 2026-11-04 — the non-goal 'No existing harvest baseline (tests/*.harvested.json, tests/lilypond-2.26/*.harvested.json) is re-baselined; existing tracked SVGs change only in element order', dropped: Operator decision 2026-11-04: Stem.layer moves every stem later in the SVG, and the harvest records SVG document order, so every harvest baseline and tracked SVG reorders with no value changed (element sets and all other fields verified identical to HEAD in all 28 harvests; all 14 SVGs have the same lines). The non-goal's intent, no drift in harvested values, still holds (0 drifted on 2.24 and 2.26); the reviewer is asked to judge it on that. (claude-code (anthropic, claude-opus-5-5))

### Session 18 — One include makes any LilyPond score chromatic

**Releasable: no.**

Make one include line enough for a converted score. Add cnb/score-defaults.ly, included by ChromaticNotationBase.ly, which applies \magnifyStaff #cnb:default-magnify to every Staff through a top-level \layout, and gives instrument names room through a top-level \paper with a fixed indent (25 mm) and short-indent (12 mm). The plan said `indent = #cnb:indent`, but cnb/layout.ly already sets that, and its 0 is what clips the names, so the operator chose fixed room in score-defaults (decided 2026-11-04 while planning). cnb:indent and layout.ly stay unchanged. The file applies both blocks unless the score defines `cnb:score-defaults` as #f before the include. A score's own \paper and \layout still win. Prototyping showed \magnifyStaff is idempotent (a hand-magnified score is not magnified twice), but every existing spec drifts: the plain ones change size, and the joy/example-notes ones pick up the short-indent. So each of the 16 tests/*.ly opts out with the flag, and no baseline moves. Add the spec tests/from-musicxml.ly: the musicxml2ly output (--nd --nrp --npl --no-beaming, LilyPond 2.24.2) of the Kainhofer file 21d-Chords-SchubertStabatMater.xml, verbatim except for the include lines after \version (ChromaticNotationBase.ly, plus cnb/test-ids.ly, which the harvest needs). It asserts the magnified staff height (7/4 of the base staff) and that the system's left edge sits at least the margin plus the 25 mm indent from the page edge, which leaves room for an instrument name. The file itself has none, because musicxml2ly drops Finale's placeholder 'MusicXML Part'. Commit its baselines for 2.24 and 2.26. Finally, add a README section, "Starting from MusicXML", before the walkthrough: the Frescobaldi import and its default boxes, the one include line, the engine's defaults and the opt-out flag, the three musicxml2ly failures with their fixes, and MusicFormats xml2ly as the fallback.

### Session 19 — MusicXML smoke tier and the corpus gate

**Releasable: no.**

Add a MusicXML smoke tier and a pre-release corpus gate. Vendor into tests/musicxml/, beside the suite's MIT LICENSE, the 71 files of the cuthbertLab fork of the Kainhofer Unofficial MusicXML test suite (D:\musicxmlTestSuite-main) that fall in the plan's ranges: 01a-01e (with 01ea), 02a-02c, 03a-03d (the fork splits 03a into 03aa/03ab), 12a/12b (12aa-12ad, 12b), 13a-13e (with 13aa-13ac), 21a-21h (21a-21g; 21g is .musicxml), 22a-22d, 23a-23f, 24a-24h (the fork has 24a-24f), 33b/33c/33g/33i (the fork has no 33k), 41a-41d, 42a/42b and 61a-61k. Add tools/run_musicxml.py --lilypond-version X.Y: it resolves lilypond as run_tests.py does, finds musicxml2ly beside it (on Windows bin\python.exe bin\musicxml2ly.py in the lilypond executable's folder, elsewhere musicxml2ly on PATH, else exits non-zero naming what is missing), converts each file with --nd --nrp --npl --no-beaming, inserts \include "kite-4-369-from-configurator.ly" after \version, engraves (SVG, from the project root) into the ignored out/musicxml/lilypond-X.Y/, and passes a file when both exit 0 and the LilyPond log has no 'error:' or 'programming error' line other than those tests/musicxml/expect.json allows for that file. A file listed there as a known musicxml2ly defect must still fail, and its passing is reported as an error. An entry may name the LilyPond versions it applies to, since 2.24's and 2.26's musicxml2ly differ. musicxml2ly's warnings never fail a file. Declare the suites engine-musicxml and engine-musicxml-2.26 in dabbler.yaml (expensive, whole_at_close, runs_whole), covering cnb/, tests/musicxml/ and tools/run_musicxml.py, plus ChromaticNotationBase.ly and kite-4-369-from-configurator.ly, which every converted file includes. Add tools/run_corpus.py DIR [--max-bytes N] [--lilypond-version X.Y], which runs the same convert and engrave over DIR's .xml/.musicxml/.mxl files (larger than --max-bytes, default 5 MB: a 'skipped' row), writes docs/runs/corpus-<today>.md with file, convert exit, engrave exit, seconds, musicxml2ly warning count, -inf count and pages, compares with the newest earlier docs/runs/corpus-*.md by file name, and exits non-zero when a file that passed there (both exits 0) fails now. Commit plan section 1.3 (D:\Projects\chromatic-notation-musicxml-and-45deg-plan.md) as docs/runs/corpus-2026-11-04.md in that format, one row per corpus file by file name, as the first baseline. docs/INTEGRATION-TESTING.md gets a short section naming the corpus gate the step before every release session, run on D:\MusicXML, and saying why the corpus is not in the repository. Tests: tools/test_run_musicxml.py (converter resolution, the allowlist, the stale-defect error, a missing converter) and tools/test_run_corpus.py (reading a table, the regression comparison), neither needing LilyPond.

### Session 20 — Fix what the corpus found

**Releasable: no.**

Fix the two engine defects the corpus found. (1) The '-inf staff space' stencil offset: the key-signature engraver builds its notehead-chord display from the procedure config cache, which only the notehead engraver fills (cnb:handle-key-change, on its first note). When the first key signature of a score is engraved before any notehead -- the top staff opens on a rest or a spacer, or a staff has no notes at all (Ave Maria's spacer-only second voice) -- every lookup misses, cnb:get-keysig-note-stencil returns empty-stencil, its width is -inf, and the translate of each keysig notehead and of the separator bar is improbable (8 lines for a two-accidental key); the display renders as the bar alone, and on rest-only staves (smoke files 02a-02c) LilyPond aborts. The key-signature engraver will call cnb:handle-key-change before building its stencil, so the cache always matches the key being drawn. The minimal spec tests/keysig-before-first-note (one staff, \key bes \major, opening on a rest) asserts the display has width; the four 'engine, session 20' defect entries in tests/musicxml/expect.json (02a, 02b, 02c, 41b), which now engrave cleanly, are removed so the smoke tier does not report them stale; the trigger goes in a CHANGELOG 'Unreleased' entry and in the step notes. (2) cnb/layout.ly blanks AccidentalCautionary.stencil and AccidentalSuggestion.stencil beside Accidental.stencil; a new accidentals spec (tests/accidentals) renders a plain sharp, a cautionary d? and a forced es! and asserts none is drawn, with one Accidental re-enabled by a \once override as a control proving the harvester sees accidentals. (3) Re-run tools/run_corpus.py D:\MusicXML and commit its table docs/runs/corpus-2026-11-05.md, whose -inf column is zero for every engraved file.

### Session 21 — Document 1.2.0

**Releasable: no.**

Document release 1.2.0. README: confirm the "Starting from MusicXML" section is final against session 18's list (Frescobaldi import defaults, the one include line, the engine's score defaults and the cnb:score-defaults opt-out, the three musicxml2ly failures with their fixes, MusicFormats xml2ly as fallback); bring the status line to 1.2.0 with the unit and integration counts the suites print on 2.24 and 2.26; add engine-musicxml and engine-musicxml-2.26 to the suites table and a short MusicXML smoke tier subsection with its real file counts on both versions and its known-failure allowlist, naming the corpus gate (tools/run_corpus.py, before every release session); list the new tools, tests/musicxml/ and docs/runs/ in the project tree and cnb/score-defaults.ly in the module order; and confirm the session 17 stem-attachment paragraph under the Registration API. dabbler.yaml's header comment gains a paragraph describing engine-musicxml and its 2.26 twin as it describes the other suites. docs/INTEGRATION-TESTING.md gains a MusicXML smoke tier section covering tools/run_musicxml.py (converter resolution, flags, the include, out/musicxml/, the pass rule, the expect.json allow/defect/lilypond format and the stale-defect error) and completes its corpus gate section on tools/run_corpus.py (DIR, --max-bytes, --lilypond-version, the table, the comparison with the newest earlier table). CHANGELOG.md turns its Unreleased entry into 1.2.0 and adds: score defaults applied by the engine and the opt-out, with the honest caveat that a staff sized by \magnifyStaff is not magnified twice but a score sized any other way (set-global-staff-size, fontSize or staff-space overrides) is now magnified on top of that; AccidentalCautionary and AccidentalSuggestion suppressed; centre-anchored stems; the MusicXML smoke tier and the corpus gate; the -inf stencil fix and its trigger stays as written. version.json goes to 1.2.0.

### Session 22 — Work around LilyPond issue 2383 (beam quanting on magnified staves)

**Releasable: no.**

Settle the three grace-note smoke allowances (24c, 24d, 24e: 'No viable beam quanting found') as LilyPond issue 2383, not an engine defect. Before this plan, a trial in a scratch copy of the repository applied the session plan's workaround, Beam.details.region-size = #4 in cnb/layout.ly. It cleared the error in all three files on 2.24 and 2.26, with no integration drift. But measured against the staff's top line, it placed every affected grace beam about 3.4 global units (about two staff spaces at 7/4) farther from the heads than LilyPond's unquanted fallback. The fallback is within 0.3 units of where a LilyPond master build carrying the upstream fix puts the same beam. The workaround fails the plan's third condition, so this session adds nothing to the engine. It re-labels the three expect.json entries as LilyPond issue 2383 with the trigger, keeping their allow lists so the smoke tier still passes. It adds a README Known Issues entry linking the issue: why there is no workaround, what the fallback looks like, and that the allowance can go once a LilyPond release carries the fix. It adds a CHANGELOG 1.2.0 line.

### Session 23 — Release 1.2.0 (release: 1.2.0)

**Releasable: yes.**

Release 1.2.0: the framework packs and publishes what is on the trunk.

### Session 24 — Clefs and key signatures engrave where the Configurator draws them

**Releasable: no.**

Close the three engraving gaps the Configurator's LY export spec 1.3.8 records as engine-only (§5.4d, §5.5), each behind a new setting whose default is today's behaviour, so every tracked golden and harvest stays byte-identical. (1) cnb:clef-anchor-semitones (#f = today's fixed placement): a number puts a 'text clef's top edge at that semitone, through cnb:clef-anchor-y-offset, the path a 'custom clef's anchor-semitones already takes (the pitch-axis hook when set, with fractional anchors interpolated; the linear middleCPosition formula otherwise); the text stencil is then built with its top edge at y = 0, as a custom one is, and the setting joins the clef stencil-cache key. (2) cnb:clef-gutter-left-semitones (#f = none): blank space before the clef's ink, in the same units as cnb:clef-gutter-semitones, for every rendered style, also in the cache key. (3) A 'centred value for cnb:keysig-tonic-octave: for each key, the tonic octave whose span [t, t+12] is centred on the staff's centre semitone M, ties going up — the Configurator's CNBKeySignature.tonicSemi rule, k = floor((M - 6 - pc)/12 + 1/2) — where M is the lowest semitone the hook sends nearest staff position 0, or -2 x middleCPosition on a linear staff (12 under the treble clef, the Configurator's default midpoint). New pure helpers get unit tests in test-unit.ly on 2.24 and 2.26. Integration specs (tests/*.ly + .json, with their tracked SVG and 2.24/2.26 harvest baselines) assert: a text clef's top edge at a fractional anchor on a linear staff and under the Twinline hook (the label is a path markup, because a plain string harvests as a 0x0 text anchor); the gap before and after a custom path clef with both gutters set, measured per LilyPond version; and, on the Twinline geometry (sps 2, lines -6 -3 -1 1 4 6, the Configurator fixture's hook, middle G), all twelve tonics' signature marks against the Configurator's choice, with a short separator bar so the harvested key-signature bbox is the marks'. Then README rows for the three settings, a CHANGELOG line under a new 1.3.0 heading (the release the plan already schedules as session 26), and docs/session-sets/024-configurator-gaps/configurator-handoff.md giving each setting's name, default, units and measured behaviour for the Configurator's export.

**Amended after acceptance:**

- 2026-11-10 — step 'keysig-centred': its files: Fixing a pre-existing bug the twelve-tonic spec exposed, approved by the operator: the key-signature stencil cache was keyed on the context property keySignature, which LilyPond 2.24/2.26 never set, so every signature after the first in a file drew the first one's marks (tracked golden stem-attachment-key-change showed G major as C major). The cache now keys on the grob's alteration-alist and the tonic; that golden's SVG and both harvests change, correctly, despite the non-goal that no existing golden changes. (claude-code (anthropic, claude-opus-5-5))

### Session 25 — The breve as tied semibreves

**Releasable: no.**

In repeat mode (the config's repeat is not #f), engrave a note of duration log L <= -1 (breve -1, longa -2, maxima -3) as 2^(-L) of today's semibreve stencil (the 4-copy whole-note stencil), left to right, 1 staff space apart, each gap holding (make-tie-stencil (cons x1 0) (cons x2 0) 0.12 DOWN) from the left group's right edge to the right group's left edge, with LilyPond's default height limit and ratio. A pure helper in cnb/utils.ly gives the group count by duration log (1 for a whole or shorter); cnb:build-duration-stencil builds the composite from it; the stencil cache key gains the group count (an optional argument of cnb:make-cache-key whose default leaves every existing key unchanged) so the longa and the maxima are cached apart from the breve. The procedure still gets duration category 0 for all three; dots, spacing, the per-pitch repeat field and repeat #f are untouched, and whole notes and shorter engrave as before. test-unit.ly tests the group count by duration log, the new cache keys, and the composite's width for 2 and 4 groups. tests/duration-rules (the one tracked golden with a breve) gets its breve assertion updated and its SVG and 2.24/2.26 harvests regenerated. A new integration spec, tests/breve-tied-semibreves, drawn with the Configurator's default notehead (its exported crotchet-minim path) at 4 semitones per staff space with repeat on, asserts on 2.24 and 2.26 the width of a breve (2 groups and 1 gap) and a longa (4 groups and 3 gaps) against the whole note, and that the whole note keeps its width. Then a README line beside the repeat counts, a CHANGELOG line under 1.3.0, and docs/session-sets/025-breve-tied-semibreves/configurator-handoff.md giving the composite's measured geometry for that notehead: each group's width, the gap, the tie's end points, its bow height and thickness, and the whole stencil's X and Y extents.

### Session 26 — Document 1.3.0

**Releasable: no.**

Prepare the 1.3.0 release: set version.json to 1.3.0 so the release session 27 can start, confirm the existing CHANGELOG.md 1.3.0 section already covers sessions 24 (the three clef/key-signature settings and the key-change fix) and 25 (the breve as tied semibreves), and correct the two Configurator handoffs (docs/session-sets/024-configurator-gaps/ and docs/session-sets/025-breve-tied-semibreves/) so they name session 27, not session 26, as the release.
