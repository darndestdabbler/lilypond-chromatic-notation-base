# Session plan

> **Purpose:** the numbered sessions this repository runs, in order. The
> first two set the project up; everything after them is the work.
> **Workflow:** Full

---

## Sessions

### Session 1: Author or import the solution plan

1. Register.
2. The brief is the prompt this session was started with, or
   `docs/planning/brief.md`: what the solution is — its purpose, who uses
   it, what it must do and what is out of scope, what success looks like,
   and whether a plan or notes already exist. With neither, ask the person
   who started the session for it and write their answer to that path
   before any work. The plan's substance is theirs: do not search
   neighbouring directories for one, and do not draft one from the folder
   name. Before any module is proposed, ask them how production is split:
   what runs separately in production, and which part may talk to the
   database? Offer the default -- an application tier that calls an API
   tier, and only the API tier talks to the database. Then create — or
   import — `docs/planning/solution-plan.md`: the
   objective a reader can act on; the *Production split* they answered;
   the *Handoff artifacts*, what each separately running part is handed
   over as, with the standard command for its form -- for .NET an IIS site
   package (`dotnet publish`) or a Windows Service (a Worker Service
   published for a service host), for Java a runnable jar or a war (`mvn
   package` writing into `{output}`, which `packaging.pack` requires --
   say through a property the POM's jar or war plugin takes as its
   output directory, `-Dhandoff.dir={output}`) or an image (Spring
   Boot's `build-image`), for the database a
   SQL migration script (`dotnet ef migrations script --idempotent`); the
   real form is produced later, and a tutorial produces the easiest one to
   test; the modules, with what each is
   responsible for, the contract each exposes (what must be true going
   in, what is guaranteed coming out, how it fails), the dependency
   direction, the reason for each cut and the cuts deferred — one module
   is a fine answer, and most small solutions are one; and the phases or
   feature areas with their key deliverables, each scoped to a handful of
   focused AI sessions. A repository that already has
   `docs/planning/project-plan.md` amends that file instead.
3. Where the plan has several modules, say in it how each is a project:
   a `.csproj` listed in the root solution file for .NET, or a Maven module
   listed in the parent `pom.xml`, each reaching a sibling by project
   reference -- a `<ProjectReference>`, or a dependency at
   `${project.version}`. The first numbered session, the skeleton, writes
   the projects.

The framework then verifies the work cross-provider, runs the suites as
the run of record and closes the session. These are the framework's,
not steps to plan.

This session writes the plan and nothing else: it creates, edits or
deletes no code, project, build file, test, `dabbler.yaml` suite or
packaging.

**Creates:** `docs/planning/solution-plan.md`. A later revision is just
another plan session that amends the same file.

### Session 2: Challenge the plan, then break it into numbered sessions

1. Register.
2. Read `docs/planning/solution-plan.md` (or `docs/planning/project-plan.md`
   where that is the file this repository keeps its plan in) and challenge
   its cuts: for each
   module, whether it should exist, whether its contract is a promise
   something can prove, and whether the dependency direction hides the
   decisions most likely to change; decide each deferred cut or say why it
   stays deferred. Record the answers in the plan's rationale.
3. Break the plan into numbered sessions appended to this file. Each
   session is a focused unit of
   work one AI coding session can complete: one
   `### Session <N>: <title>` heading, and its steps as a top-level
   ordered list. Step 1 registers the session and the rest are the
   work: cross-provider verification, the run of record and the close
   are the framework's, never steps to plan. Never
   write a step that says "run the tests" without saying which run it
   means. Order sessions so earlier ones unblock later ones — a module
   before the modules that depend on it — and keep at most ~3 work steps
   per session.

   The first numbered session is the skeleton. For .NET it writes the
   solution file and every project the plan names, with their
   references; for Maven or Gradle, the parent build and every module.
   Either way it declares the test suite in `dabbler.yaml` under
   `testing.suites`, even before any tests exist, with `expensive: true`
   where its run is the run of record and a hang limit in its command --
   `dotnet test --blame-hang-timeout 5m`, or Surefire's
   `forkedProcessTimeoutInSeconds` -- so every later run inherits it,
   and adds the architecture test the plan requires -- where only the
   API tier may reach the database, that rule. Later sessions fill the
   modules in and never re-create what the skeleton made.

   Packaging and releases are sessions of their own. Where the plan
   names *Handoff artifacts*, plan one packaging session -- early, with
   project files only, or later -- that writes the `packaging:` block in
   `dabbler.yaml` and does nothing else; its check is `dabbler packaging
   --rehearse`, which runs the pack and pushes nothing. A release is a
   session with no steps, headed `### Session <N>: Release <version> (release:
   <version>)`; propose its version -- patch, minor or major by what the
   sessions it releases change -- for the person to approve with the plan.

The framework then verifies the work cross-provider, runs the suites as
the run of record and closes the session. These are the framework's,
not steps to plan.

This session writes the plan and nothing else: it creates, edits or
deletes no code, project, build file, test, `dabbler.yaml` suite or
packaging.

**Creates:** the numbered session list the rest of this repository runs,
starting with the skeleton session.

> Do NOT hand-author `sessions.json`. The first `session start`
> bootstraps it from this plan — state files are the writers' job.

### Session 3: Make the test tooling portable and gate honestly

Phase E1 of `docs/planning/project-plan.md` §7.5; the skeleton-equivalent
session (§7.7): there is nothing to scaffold, so its skeleton part is the
second suite declaration.

1. Register.
2. In `tools/run_tests.py` and `tools/harvest_svg.py`, reconfigure stdout
   and stderr to UTF-8 (falling back to ASCII where that fails), open every
   file with an explicit `encoding="utf-8"` while keeping the bytes the
   harvests are written with, render with `-dno-point-and-click`, and warn
   (without failing) when `lilypond --version` is not 2.24.x. Make golden
   drift a test failure: before writing a regenerated
   `tests/*.harvested.json`, `run_tests.py` compares it with the tracked
   copy and, when they differ, leaves the tracked file untouched, names the
   differing element ids and properties, and exits non-zero; a new
   `--update-baselines` flag writes the regenerated harvest instead, for an
   intended change. A spec with no tracked harvest yet writes one and
   passes. Prove it by running the engine-integration suite whole, as
   `python tools/run_tests.py` with no `-X utf8` and no environment
   variable set: it passes, and
   `git diff --exit-code -- "tests/*.harvested.json"` shows no change. The
   tracked `tests/*.svg` are re-baselined once, losing their `textedit://`
   links; a second run leaves `git status -- tests` clean.
   Tests for the comparison go in a new `tools/test_run_tests.py` (stdlib
   `unittest`, no LilyPond needed): identical harvests pass, a changed
   property fails naming the element, and `--update-baselines` writes the
   file.
3. Add `tools/run_unit.py`: it runs `lilypond test-unit.ly` with its output
   in an ignored folder (add the folder to `.gitignore`) and a time limit
   on the LilyPond process, parses
   `TEST RESULTS: N passed, M failed`, and exits non-zero on any failure,
   a missing line, a LilyPond error or the time limit. Declare it in
   `dabbler.yaml` as a second suite, `engine-unit`, in `command:` form
   (`python tools/run_unit.py`), covering `cnb/`, `test-unit.ly`,
   `ChromaticNotationBase.ly` and `tools/run_unit.py`. Declare a third
   suite, `engine-tooling`, for the tooling's own tests
   (`command: python -m unittest discover -s tools -p "test_*.py"`,
   `runs_whole: true`, `covers: [tools/]`, `test_roots: [tools]`,
   `test_glob: "test_*.py"`, `test_name: "test_{name}.py"`, so a change to
   `tools/run_tests.py` names `tools/test_run_tests.py`). Drop `-X utf8`
   from the engine-integration suite's command and its comment. Prove it
   by running the engine-unit suite (`python tools/run_unit.py`): it exits
   0 and reports 303 passed.
4. Write `tests/example-notes.json` from `tests/example-notes.harvested.json`,
   pruned to assertions that pin what the score is for, delete
   `tests/TODO.md`, and update the README's test counts and status banner
   to what the two suites now report. Prove it by running the
   engine-integration suite whole: it passes with the new spec counted.

### Session 4: Remove cruft and record LilyPond compatibility

Phase E2 of `docs/planning/project-plan.md` §7.5.

1. Register.
2. Delete `tools/old/` and `tools/to-transition-to-python/` (or move them
   to `docs/archive/` with a short note on what the JSX inspector was),
   stop tracking `tools/__pycache__/*.pyc` (already ignored), and stop
   tracking `test-unit.pdf` and ignore it. Prove nothing depended on them
   by running both suites, engine-integration whole and engine-unit.
3. Mark `docs/planning/configurator-coordination-backlog.md` as closed at
   the top, naming the session sets that resolved it.
4. Render one score (`tests/c-major-scale.ly`) on the newest LilyPond
   stable release and record the result — works, fails (with the first
   error), or untested and why — in the README's Requirements section. No
   engine or tooling change; 2.24.x stays the supported version. On the
   operator's machine LilyPond 2.26.0 is unpacked at
   `D:\lilypond-2.26.0-mingw-x86_64\lilypond-2.26.0\bin\lilypond.exe`
   (checked 2026-10-30: it reports "GNU LilyPond 2.26.0 (running
   Guile 3.0)"). Call it by that full path and never put it on `PATH`,
   where it would displace the 2.24.2 the suites use. Write its output to
   the ignored output folder from session 3 (`-o`), never beside the
   tracked `tests/c-major-scale.svg`. Record any `\version` or
   `convert-ly` warning it prints.

### Session 5: Clean up the guidance and README for 1.0.0

Phase E3 of `docs/planning/project-plan.md` §7.5.

1. Register.
2. Replace the placeholder `docs/planning/lessons-learned.md` with real
   lessons harvested from the `docs/session-sets/*/change-log.md` files, or
   delete it together with `lessons-archive.md` and `project-guidance.md`;
   remove the v1 `ai_router` instructions from whatever is kept.
3. README: status 1.0.0; a "Known limitations" section (LilyPond 2.24.x
   only, tested on Windows, configs are generated by the Configurator,
   clefs and key signatures follow the score); and a "Running the tests"
   section naming the two declared suites, engine-integration
   (`python tools/run_tests.py`) and engine-unit (`python tools/run_unit.py`),
   exactly as `dabbler.yaml` declares them.
4. Add a root `version.json` reading `{ "version": "1.0.0" }`; the release
   session checks its version against it.

### Session 6: Declare the source-archive packaging

1. Register.
2. Write the `packaging:` block in `dabbler.yaml` and nothing else: a
   `pack` with no `push`, whose argv is
   `["git", "archive", "--format=zip", "--output={output}/lilypond-chromatic-notation-base-1.0.0.zip", "HEAD"]`
   — or the same with `{version}` in place of `1.0.0` if the rehearsal
   accepts it (§7.7). Replace the commented example block with it. Its
   check is `dabbler packaging --rehearse`, which runs the pack and pushes
   nothing.

### Session 7: Release 1.0.0 (release: 1.0.0)

### Session 8: Let the test runners choose a LilyPond version

**Why.** 1.0.0 supports LilyPond 2.24.x only, and 2.26 is the current
stable release, so a new user is likely to have it. Measured on
2026-10-31 in a scratch worktree: with the session 9 fixes, every
engine-unit and engine-integration assertion passes on 2.26.0, but 11
of the tracked harvests differ in layout coordinates. Supporting both
versions needs a harvest baseline set per version, and suites that
prove each one. On the operator's machine 2.24.2 is on `PATH` and 2.26.0
is at `D:\lilypond-2.26.0-mingw-x86_64\lilypond-2.26.0\bin\lilypond.exe`,
named by the user environment variable `CNB_LILYPOND_2_26`.

1. Register.
2. Give `tools/run_tests.py` and `tools/run_unit.py` a
   `--lilypond-version X.Y` option. It uses the executable named by
   `CNB_LILYPOND_X_Y` (dots become underscores), or else the `lilypond`
   on `PATH` if its `--version` reports X.Y. Otherwise it exits non-zero
   with a message naming the variable to set. Without the option, both
   behave as today. The supported set is 2.24 and 2.26. The 2.24
   harvest baselines stay at `tests/*.harvested.json`, and 2.26's go in
   `tests/lilypond-2.26/`. For any version other than 2.24, renders go
   to the ignored `out/lilypond-X.Y/`, so the tracked `tests/*.svg`
   are never rewritten by a 2.26 run. For a version outside the
   supported set, warn and skip the drift comparison; assertions still
   run. Replace the "baselined on 2.24" warning with this. Tests in
   `tools/test_run_tests.py` cover: resolution from the variable, from
   `PATH`, and the failure message; the baseline path for 2.24 and for
   2.26; and the unsupported-version skip. Prove it by running the
   engine-tooling suite, then
   `python tools/run_tests.py --lilypond-version 2.24` and
   `python tools/run_unit.py --lilypond-version 2.24`. Both pass, and
   `git status -- tests` is clean.
3. Add `--lilypond-version 2.24` to the engine-integration and
   engine-unit suite commands in `dabbler.yaml`, so the run of record
   names the version it proves.

### Session 9: Make the engine and the harvester work on LilyPond 2.26

1. Register.
2. Fix the three 2.26 breaks found on 2026-10-31:
   - **`duration-length`:** `cnb:duration-category` in `cnb/utils.ly`
     calls `duration-length`, which 2.26 removed in favour of
     `ly:duration->number`, which 2.24 lacks. Pick whichever is defined,
     once at load time and not on every call.
   - **Colours:** 2.26 writes `rgba(R%, G%, B%, 100.0000%)` where 2.24
     wrote `rgb(R%, G%, B%)`, and sometimes `0%` for `0.0000%`.
     `tools/harvest_svg.py` (`extract_color_deep`) normalises an opaque
     `rgba` to the 2.24 `rgb` form, with every component at four
     decimals. A colour that is not opaque keeps its alpha. Test this in
     a new `tools/test_harvest_svg.py`.
   - **Gutter test:** `tests/clef-custom.json` asserts the first
     notehead at an absolute x of 14.762, measured on 2.24. On 2.26 the
     same note sits at 15.349. Restate the assertion so it proves the
     same 1.5-unit gutter on both versions, for example relative to the
     clef's right edge, or against a no-gutter twin spec. Do not widen
     the tolerance.

   Prove nothing changed on 2.24: all three suites pass, and
   `git diff --exit-code -- "tests/*.harvested.json"` shows no drift.
3. Run `python tools/run_tests.py --lilypond-version 2.26 --update-baselines`
   to write `tests/lilypond-2.26/*.harvested.json`. Every spec
   assertion must pass before any baseline is written. Spot-check that
   the coordinate shifts against the 2.24 baselines are consistent
   layout changes, not misplaced glyphs, and record what changed in
   §7.7 of `docs/planning/project-plan.md`. Declare two suites in
   `dabbler.yaml`:
   - `engine-integration-2.26`: `python tools/run_tests.py --lilypond-version 2.26`
   - `engine-unit-2.26`: `python tools/run_unit.py --lilypond-version 2.26`

   Both take the same fields and covers as their 2.24 counterparts.
   Prove it by running both 2.26 suites: they pass, and
   `git status -- tests` shows only the new `tests/lilypond-2.26/`
   files.

### Session 10: Document LilyPond 2.26 support and bump to 1.1.0

1. Register.
2. README:
   - Requirements says LilyPond 2.24.x or 2.26.x. Replace the "2.26 is
     not supported yet" paragraph, and the Known limitations bullet, with
     what was measured.
   - "Running the tests" names all five suites exactly as `dabbler.yaml`
     declares them. Explain `--lilypond-version` and the
     `CNB_LILYPOND_X_Y` variable, and say that a contributor with only
     one version installed runs that version's suites.
3. Set `version.json` to `{ "version": "1.1.0" }`. Add a short
   `CHANGELOG.md` with 1.0.0 (first release) and 1.1.0 (LilyPond 2.26
   support; harvest baselines per version).

### Session 11: Release 1.1.0 (release: 1.1.0)

### Session 12: Engrave durations and dots correctly

**Why.** A whole-repository audit on 2026-11-02
(`docs/planning/audit-2026-11-02.md`; finding IDs below refer to it)
found visible engraving errors that every suite passed:

- `cnb:duration-category` is computed from the full duration length, so
  dots and tuplets change the category (H2).
- It is off by one against the engine's own documented scale in
  `cnb/procedure.ly`: 0 = breve or longer, 1 = whole, 2 = half, 3 = quarter
  or shorter. The scale is also the export spec's, so a Configurator rule
  for minims hollows quarter notes (Configurator audit H4).
- Dots on ledger-line notes land 6–8 staff spaces away (H3).

1. Register.
2. Compute the category from the duration *log* alone, as
   `clamp(log + 1, 0, 3)`. That maps breve → 0, whole → 1, half → 2, and
   quarter or shorter → 3, ignoring dots and the tuplet factor. Update
   every consumer to that scale: `noteheads.ly` (repeat counts must still
   give 2 heads for a half and 4 for a whole), `off-key.ly`, `stems.ly`,
   `stencils.ly` and the cache key. Add unit tests to `test-unit.ly` for
   every duration log from −1 to 4, with and without dots, for triplets,
   and for the cache key.

   Add an integration spec, `tests/duration-rules.ly` plus its `.json`.
   It uses a small config whose procedure gives each category a different
   colour, and engraves a breve, a whole, a half, a quarter, an eighth,
   dotted versions and triplets. It asserts the colour and head count of
   each note.
3. H3: in `cnb/dots.ly`, count the notehead offset once. Add an
   integration spec with dotted notes on and off ledger lines above and
   below the staff, asserting each dot's distance from its notehead.
4. M1: stem attachment uses the config the note was engraved with, not
   the global cache at layout time, so a later `\key` change no longer
   rewrites earlier stems. Add a spec with a key-dependent config and a
   mid-score key change.

   Run all five suites. Where an existing harvest drifts, re-baseline it
   with `--update-baselines` on both versions only after checking that
   every difference is one of these three fixes. Record each re-baselined
   file and why in §7.7 of `docs/planning/project-plan.md`.

### Session 13: The test runner cannot pass a broken render

1. Register.
2. H1: before rendering, `run_tests.py` deletes any earlier output for the
   spec, including tracked `tests/{base}.svg` when rendering in place, so
   it can only harvest what this run wrote. A multi-page render
   (`{base}-1.svg`, `{base}-2.svg`, …) is harvested page by page, or fails
   with a message; it never falls back to a stale file. M5: "No test specs
   found" exits non-zero. L3: without `--lilypond-version`, detect the
   version on `PATH`, and for anything but 2.24 write to
   `out/lilypond-X.Y/` and compare against that version's baselines.
3. M3, L6: drift comparison keys repeated ids by `id` plus occurrence
   index, so an edit to the second `staff-symbol` or a duplicated ledger
   id shows as drift. An absence check passes only for a declared absence,
   never because an expression contains `is None`.
4. M4: verify that the executable named by `CNB_LILYPOND_X_Y` reports X.Y,
   and fail otherwise. L4: add `tools/run_tests.py` and
   `tools/harvest_svg.py` to the engine-unit suites' `covers:`. Each fix
   gets a test in `tools/test_run_tests.py`. Check the result the way the
   audit did, by re-running its probes: the key-signature regression plus
   `\pageBreak`, the edited duplicate ids, and the env var pointed at 2.24.
   Each must now fail.

### Session 14: Harvest what is drawn, and claim only what works

1. Register.
2. M2: `tools/harvest_svg.py` harvests the geometry of `circle`,
   `ellipse`, `polygon`, `polyline` and `text`, plus beam bounding boxes
   and shape hashes, so off-key rings and beams can drift. Add tests in
   `tools/test_harvest_svg.py`. Re-baseline both versions, and confirm the
   only changes are the newly harvested properties.
3. M6: the articulation correction never changes anything, and beam and
   stem compensation never apply on the engine's own staff. Either make
   each one work, with a spec that fails without it, or delete the dead
   code and its README claims. No half measures: what the README
   advertises must be tested.
4. M7, L1, L2: the README reports real counts (assertions, not `_comment`
   markers, for 2.24 and 2.26) and the real project tree;
   `docs/INTEGRATION-TESTING.md` describes per-version baselines and
   `--lilypond-version`; `--generate` refuses to overwrite a tracked
   baseline without `--update-baselines`; and `--keep-svg` works or is
   removed.

### Session 15: A clean public archive, and 1.1.1

1. Register.
2. L5:
   - Add `.gitattributes` `export-ignore` for `.vscode/`, `AGENTS.md`,
     `CLAUDE.md`, `docs/sessions/`, `docs/transcripts/` and
     `docs/planning/`.
   - Re-render any tracked SVG that still carries a
     `textedit://D:/Projects/...` link with `-dno-point-and-click`.
   - Replace the `c:\Users\...` path in the findings file with a
     repository-relative one.
   - Prove it with `dabbler packaging --rehearse`: list the zip, and
     `grep` it for `textedit://`, `D:\` and `Users\`. None may appear.
3. Set `version.json` to `1.1.1`, and add a `CHANGELOG.md` entry. Note
   that duration categories now follow the documented scale, so a
   hand-written config that relied on the old off-by-one numbering must
   change.

### Session 16: Release 1.1.1 (release: 1.1.1)

### Session 17: Stems attached at the notehead centre

**Why.** The operator's second reference notation, 45deg-369 (plan:
`D:\projects\chromatic-notation-musicxml-and-45deg-plan.md`, §3), attaches
every stem at the centre of a 45°-tilted ellipse, so the stem crosses the
head and, on a hollow head, the hole. The toolkit already exports a centre
anchor (`'(0 . 0)`) when the `stem-up` rect's bottom edge and the
`stem-down` rect's top edge sit on the origin, and `cnb:stem-attachment`
passes any point through. Nothing has proved what the engine draws with
it: whether the stem's far end still reaches the standard length past
the head's far edge or shrinks by half a head, and whether the stem is
drawn over the head or hidden under a false-hollow white overlay.

1. Register.
2. Add an integration spec, `tests/stem-centre.ly` plus its `.json`,
   on both versions. Its small config registers one solid and one
   true-hollow ellipse (a 4-semitone head, like Kite) whose attachment
   alist is `(0 . 0)` for all four points, and it engraves stems up and
   down, a minim, a beamed pair and a chord. Assert, per stem: its x is
   the head's centre x; its near end is at the head's centre y; its far
   end is the normal stem length beyond the head's far edge, not beyond
   the centre (lengthen when the anchor is inside the head, never
   shorten); and the stem is visible across a hollow head (draw order
   or `Stem.layer`, and the false-hollow overlay must not cover it).
   Fix what fails. Re-baseline nothing else: if an existing harvest
   drifts, the fix is wrong.
3. README, under the attachment-registration row: the anchor may be
   anywhere, including the centre; what the engine does with length and
   draw order. Note the toolkit rule (rect bottom-centre for up,
   top-centre for down) so a designer can place one.

### Session 18: One include makes any LilyPond score chromatic

**Why.** On 2026-11-04 musicxml2ly output (Frescobaldi's *Import
MusicXML* defaults, `--nd --nrp --npl --no-beaming`) engraved in Kite on
2.24.2 and 2.26.0 with one `\include` added after `\version`: 20 of 20
real scores that musicxml2ly turned into valid LilyPond, and 9 of 9
LilyPond regression files (plan §1.2–1.3). But a plain score renders the
heads at default staff size, small, and clips the instrument names at
the left margin, because `\magnifyStaff #cnb:default-magnify` and
`indent = #cnb:indent` are set by hand in every example score and not by
the engine.

1. Register.
2. Add `cnb/score-defaults.ly`, included by `ChromaticNotationBase.ly`
   unless `cnb:score-defaults` is `#f` before the include: a `\layout`
   that applies `\magnifyStaff #cnb:default-magnify` to every `Staff`,
   and a `\paper` with `indent = #cnb:indent` and whatever else every
   example score sets that a converted score lacks (compare
   `joy-to-the-world.ly`). A score's own `\paper` and `\layout` still win.
   Run both integration suites: a spec that drifts set a different value
   by hand, so that spec opts out with the flag rather than the baseline
   moving. Add a spec `tests/from-musicxml.ly` whose music is the
   committed musicxml2ly output of the Kainhofer file
   `21d-Chords-SchubertStabatMater.xml` with only the include line
   added; assert the magnified staff height and that the system's left
   edge leaves room for the instrument name.
3. README, new section "Starting from MusicXML" before the walkthrough:
   Frescobaldi *File → Import/Export → Import MusicXML* with its default
   boxes (page layout, beaming, rest positions and articulation
   directions all unchecked), the one include line, the engine's
   defaults and the opt-out flag; the three musicxml2ly failures seen on
   real scores (`cresc. = #(make-dynamic-script …)`, note names like
   `fisisisisisis`, the nested-tuplet crash) with the fix for each; and
   MusicFormats `xml2ly` as the fallback converter.

### Session 19: MusicXML smoke tier and the corpus gate

**Why.** The Kainhofer "Unofficial MusicXML test suite" (MIT; the
cuthbertLab fork is at `D:\musicxmlTestSuite-main`) exercises what the
engine touches with files small enough to run on every close. Real
scores (`D:\MusicXML`, 30 MuseScore, Finale and music21 exports, mostly
unlicensed, so never committed) take up to 82 s each and belong to a
gate run before a release. Plan §1.3 is the first corpus table.

1. Register.
2. Vendor the subset into `tests/musicxml/`, with the suite's `LICENSE`
   beside it: pitches (01a–01e), rests (02a–02c), rhythm (03a–03d),
   clefs (12a, 12b), key signatures (13a–13e), chords (21a–21h),
   noteheads (22a–22d), tuplets (23a–23f), grace notes (24a–24h), ties
   and slurs (33b, 33c, 33g, 33i, 33k), multi-part (41a–41d), multi-voice
   (42a, 42b) and lyrics (61a–61k). Not the page-layout, direction or
   notation-marking files. `tools/run_musicxml.py --lilypond-version X.Y`
   finds musicxml2ly beside the chosen `lilypond` (on Windows
   `bin\python.exe bin\musicxml2ly.py`, elsewhere `musicxml2ly` on
   `PATH`; otherwise exit non-zero naming what is missing), converts each
   file with `--nd --nrp --npl --no-beaming`, adds the Kite include,
   engraves to the ignored `out/musicxml/`, and passes a file when both
   exit 0 and the LilyPond log has no `error:` or `programming error`
   line other than those listed for that file in `tests/musicxml/expect.json`.
   A file listed there as a known musicxml2ly defect must still fail,
   and passing is reported as an error, so the list cannot go stale.
   musicxml2ly's own warnings are never failures. Declare the suite
   `engine-musicxml` in `dabbler.yaml` (`expensive`, `whole_at_close`,
   `runs_whole`, covering `cnb/`, `tests/musicxml/` and the tool), and
   its 2.26 twin. Tests in `tools/test_run_musicxml.py` cover
   resolution, the allowlist, the stale-expectation error and a missing
   converter.
3. `tools/run_corpus.py DIR [--max-bytes N] [--lilypond-version X.Y]`
   runs the same pipeline over a directory of real scores and writes
   `docs/runs/corpus-<date>.md`: file, convert exit, engrave exit,
   seconds, musicxml2ly warning count, `-inf` count, pages. It compares
   with the newest earlier table and exits non-zero when a file that
   passed before fails now. Commit plan §1.3 as
   `docs/runs/corpus-2026-11-04.md`, in that format, as the first
   baseline. `docs/INTEGRATION-TESTING.md` names this the step before
   every release session, run on `D:\MusicXML`, and says why the corpus
   itself is not in the repository.

### Session 20: Fix what the corpus found

**Why.** Two defects are the engine's, not musicxml2ly's (plan §1.3):
the plain conversions are clean of both.

1. Register.
2. `programming error: Improbable offset for stencil: -inf staff space`
   appears only with a config, in 5 of 20 scores (Ave Maria, Spring
   Waltz, Arabesque, Ständchen, BWV 140/1), always a multiple of 8, and
   not from cautionary accidentals (those files have none). Reproduce
   from the smallest (Ave Maria, 2 pages, in `D:\MusicXML`), bisect the
   converted score to a minimal spec, fix the stencil, and add the spec
   to `tests/`. Record what the trigger was in the session notes and
   the CHANGELOG.
3. Cautionary and forced accidentals (`gis?`, `c!`) print as
   parenthesised traditional glyphs: `cnb/layout.ly` blanks
   `Accidental.stencil` only, and LilyPond draws cautionary ones with
   the separate `AccidentalCautionary` grob (and suggestions with
   `AccidentalSuggestion`). Suppress those the same way, in the same
   place, and extend the accidentals spec with `?` and `!` notes
   asserting that nothing is drawn. Re-run the corpus gate
   (`tools/run_corpus.py D:\MusicXML`) and commit its table: the `-inf`
   column must be zero everywhere.

### Session 21: Document 1.2.0

1. Register.
2. README: the "Starting from MusicXML" section is final; the test
   section reports the smoke tier's real counts on 2.24 and 2.26 and
   names the corpus gate; the stem-attachment paragraph from session 17.
   `dabbler.yaml`'s header comment describes `engine-musicxml` the way it
   describes the others. `docs/INTEGRATION-TESTING.md` covers
   `run_musicxml.py` and `run_corpus.py`.
3. `CHANGELOG.md` 1.2.0: score defaults now applied by the engine and
   how to opt out (a score that set its own magnification may now be
   magnified twice: say so); `AccidentalCautionary` suppressed; the
   `-inf` stencil fix and its trigger; centre-anchored stems; the
   MusicXML tier and the corpus gate. `version.json` to `1.2.0`.

### Session 22: Work around LilyPond issue 2383 (beam quanting on magnified staves)

**Why.** Three smoke files (24c, 24d, 24e) log `programming error: No
viable beam quanting found. Using unquanted y value.`, and
`tests/musicxml/expect.json` allows it as "engine, not yet triaged". It
is LilyPond's own defect, open upstream since 2012 as
[issue 2383](https://gitlab.com/lilypond/lilypond/-/work_items/2383).
Plain LilyPond logs it whenever `StaffSymbol.staff-space` is about 1.75
or more (`\magnifyStaff #7/4` sets that), the stems point away from the
staff, and the heads sit well outside it: `\new Staff \with {
\magnifyStaff #7/4 } { \grace { a''16 a''16 } e'2 }` on 2.24.2 and 2.26.0.
The cause is in `lily/beam-quanting.cc`. `quant_range_` is computed in
global units, but the quants it filters are in staff spaces, so the
bound is scaled by the staff-space and can rise above every candidate. The
upstream fix goes to LilyPond as a merge request, outside this
repository. It would land in 2.27 or later, not in 2.24 or 2.26, so CNB
needs a workaround. Every CNB staff is magnified, by hand or by
`cnb/score-defaults.ly`. `\override Beam.details.region-size = #4`
(LilyPond's default is 2) makes the quanter generate candidates high
enough to clear the inflated bound. On 2.24 that clears the error.

1. Register.
2. Apply `Beam.details.region-size = #4` where the engine sets its own
   layout (`cnb/layout.ly`), so it holds whether or not a score uses the
   score defaults. Keep it only if all of these hold:
   - the three files engrave without the error on both versions;
   - the integration suites show no harvest drift on either version;
   - the beams it chooses for 24c–24e are no farther from the heads
     than LilyPond's unquanted fallback, measured from the harvested or
     rendered beam and stem ends and stated in the step notes.
   If any of these fails, add nothing to the engine. Instead re-label the
   three entries as LilyPond issue 2383 and go straight to step 3.
3. Remove the three `allow` entries from `tests/musicxml/expect.json`,
   so the smoke tier enforces the workaround (or, without it, re-label
   them as LilyPond issue 2383). Add a CHANGELOG 1.2.0 line. Add a
   README Known Issues entry that links issue 2383 and names the
   workaround and when it can be dropped (a LilyPond release that
   carries the fix).

### Session 23: Release 1.2.0 (release: 1.2.0)

### Session 24: Clefs and key signatures engrave where the Configurator draws them

**Why.** The Configurator's session 34 (2026-11-07) closes every gap between
its preview and the engraving that it can close on its own side. Three
remain that only the engine can close. Its LY export spec 1.3.8 records
them as known divergences (§5.4d, §5.5):

- **A text clef ignores its height.** `'custom` clefs are placed by
  `anchor-semitones`, but `'text` clefs sit at a fixed height of the
  engine's own. The Configurator draws a text clef with its top edge at
  the definition's `anchorSemi`, as it does a glyph.
- **The clef gutter is padded on one side.** `cnb:clef-gutter-semitones`
  adds blank space after the clef only. The Configurator pads both sides
  of the clef by the same amount (`clef.gutter.paddingH`).
- **The key-signature octave under a pitch axis.** With the hook set, the
  engine takes one octave for every key: `cnb:keysig-tonic-octave`, or
  else `middleCPosition`. The Configurator's automatic rule picks, for each
  tonic, the octave whose span from the tonic to the octave above is centred
  on the staff's middle, with ties going up (`CNBKeySignature.tonicSemi`).
  For the Twinline fixture (middle G) the tonics G♯, A, A♯ and B land an
  octave apart.

Every new setting defaults to today's behaviour, so every existing golden
and harvest stays byte-identical.

1. Register.
2. **Text clef anchor.** Add a setting, say `cnb:clef-anchor-semitones`
   (`#f` = today's fixed placement). It puts a `'text` clef's top edge at
   that semitone through the same path a `'custom` clef's `anchor-semitones`
   takes (the hook under an axis, `middleCPosition` otherwise), fractional
   values included. Add an integration spec on both LilyPond versions,
   linear and with the hook, that asserts the label's top edge.
3. **Padding before the clef.** Add a setting, say
   `cnb:clef-gutter-left-semitones` (`#f` = none), that adds blank space
   before the clef, in the same units as `cnb:clef-gutter-semitones`. Add a
   spec asserting the gap on each side.
4. **Key-signature octave per tonic.** Add an automatic mode for
   `cnb:keysig-tonic-octave`, say `'centred`, that picks each key's octave
   as the Configurator's rule does, around the semitone the staff centres
   on: the semitone the hook sends to staff position 0, or the middle line
   on a linear staff. Add a spec on the Twinline geometry checking all
   twelve tonics against the Configurator's choice.
5. README rows for the three settings, and a CHANGELOG line. Write
   `docs/session-sets/024-configurator-gaps/configurator-handoff.md`, in
   the form of the earlier handoffs. It gives each setting's name, default,
   units and measured behaviour, so the Configurator can export them (its
   plan's "Export what engine session 24 adds").

### Session 25: The breve as tied semibreves

**Why.** In repeat mode the semibreve and the breve both engrave as 4
heads (`cnb:build-duration-stencil`, `cnb/stencils.ly`), so the two cannot
be told apart. Doubling to 8 heads for the breve strings too many heads
together. The Configurator's operator prefers a breve written as tied
semibreves (Configurator session 42), and chose (Configurator session 44,
2026-11-10) to keep the breve as one note whose stencil is the composite,
not to split the music into real tied notes. Dots, spacing, the per-pitch
`repeat` field and the duration category the procedure gets all stay as
they are. Configurator session 44 draws the same composite in its preview,
and its engine round trip waits on this session.

This deliberately changes what a breve engraves in repeat mode, so the
goldens and harvests that contain one change.

1. Register.
2. **The composite.** In repeat mode (the config's `repeat` is not `#f`), a
   note of duration log L ≤ −1 (breve −1, longa −2, maxima −3) engraves as
   2^(−L) of today's semibreve stencils (the 4-copy whole-note stencil),
   left to right, 1 staff space apart. Each gap holds
   `(make-tie-stencil (cons x1 0) (cons x2 0) 0.12 DOWN)`, from the left
   group's right edge x1 to the right group's left edge x2, at the head's
   centre line, bowing down, with LilyPond's default height limit (1.0) and
   ratio (0.33). The procedure still gets duration category 0 for all
   three. The stencil cache keeps the longa and the maxima apart from the
   breve. With `repeat` `#f` nothing changes, and whole notes and shorter
   values are unchanged.
3. **Specs.** Add an integration spec on 2.24 and 2.26 asserting the
   engraved width of a breve (2 groups and 1 gap) and a longa (4 groups and
   3 gaps), and that a whole note keeps its width. Regenerate the harvests
   and goldens that contain breves (`tests/duration-rules.ly` among them) on
   both versions. Add a `test-unit.ly` case for the composite's group count
   by duration log.
4. A README line beside the repeat counts, and a CHANGELOG line. Write
   `docs/session-sets/025-breve-tied-semibreves/configurator-handoff.md`, in
   the form of the earlier handoffs. It gives the composite's measured
   geometry for the default Configurator notehead at 4 semitones per staff
   space: each group's width, the gap, the tie's end points, its bow height
   and thickness, and the whole stencil's X and Y extents.

### Session 26: Document 1.3.0

**Why.** A release packs what is on the trunk and never bumps the
version, so `version.json` must read the release's version before the
release session starts (the start of session 27 refuses otherwise). 1.3.0
is a minor release: sessions 24 and 25 add behaviour (three settings, the
breve as tied semibreves) and change no default but the breve's repeat-mode
stencil.

1. Register.
2. `version.json` to `1.3.0`. Confirm the `CHANGELOG.md` 1.3.0 section
   covers sessions 24 and 25, and make the two Configurator handoffs
   (`docs/session-sets/024-configurator-gaps/`,
   `docs/session-sets/025-breve-tied-semibreves/`) name session 27 as the
   release.

### Session 27: Release 1.3.0 (release: 1.3.0)

### Session 28: The breve's tie below the noteheads

**Why.** In the Configurator's session-45 try-out the operator found the
breve's tie wrong (2026-11-11, Configurator session 46): it should be
below the noteheads, not in the gap between the two semibreve groups on
the heads' centre line. Ideally one tie spans from the centre of the first
notehead of the first group to the centre of the last notehead of the last
group. Configurator session 46 draws the same tie in its preview, and its
engine round trip waits on this session.

This changes what a breve (and a longa or maxima) engraves in repeat mode,
so the goldens and harvests that contain one change.

1. Register.
2. **The tie.** In `cnb:build-duration-stencil` (`cnb/stencils.ly`), for
   `groups` above 1, one
   `(make-tie-stencil (cons xa y0) (cons xb y0) 0.12 DOWN)` replaces the
   ties in the gaps: `xa` is the centre of the first head of the first
   group, `xb` the centre of the last head of the last group, and `y0` the
   bottom of the group stencil's Y extent, so the tie runs below the heads
   and curves down as LilyPond's ties under a note do, with LilyPond's
   default height limit (1.0) and ratio (0.33). The groups and the 1 staff
   space gaps between them are unchanged, so the X extent is too. The tie
   stays black (it is added after the head is coloured). With `repeat`
   `#f`, and for whole notes and shorter values, nothing changes.
3. **Specs.** The integration specs on 2.24 and 2.26 assert that the
   breve's and the longa's width are unchanged and give their new lower Y
   extent. Regenerate the harvests and goldens that contain breves on both
   versions, and update the `test-unit.ly` case.
4. A README line beside the repeat counts, a `CHANGELOG.md` 1.3.1 section,
   and `version.json` to `1.3.1`: a patch release, one stencil corrected
   and nothing added. Write
   `docs/session-sets/028-breve-tie-below/configurator-handoff.md`, in the
   form of the earlier handoffs. It gives the measured tie for the default
   Configurator notehead at 4 semitones per staff space (its end points,
   lowest point and thickness, and the whole stencil's X and Y extents) and
   names session 29 as the release.

### Session 29: Release 1.3.1 (release: 1.3.1)

### Session 30: Key signatures from a mark list

**Why.** The Configurator's key-signature designer (its session 47, the
operator-approved design `docs/planning/key-signature-designer-design.md`
§9 in the Configurator repository) lets a designer choose a signature once
for every key: scale notes with their own looks, four stacking rules, gold
stems between the stacks, and the signature on the staff's middle, its
bottom or top line set, or every line set; later, traditional sharps or
flats. The engine's `'chord` style draws only today's two-column stack.
Configurator session 48 computes every other signature as an explicit list
of marks (`CNBKeySignature.marks`), so the engine needs the **mark-list
hook** this repository's backlog §2.3 says such signatures need
(`docs/planning/configurator-coordination-backlog.md`). Configurator
session 49 exports it and its engine round trip waits on this session.

The key's identity is settled: Configurator session 48's probe read, from
real `\key` events with an engraver acknowledging each KeySignature grob,
the context's `tonic` (note name and alteration) and the seven pitch
classes from `keyAlterations`, for F♯ and G♭ major (one set of pitch
classes, two spellings), B♭ major, a key change, the signature repeated at
a system start and a `\transpose`d score.

This adds a style and changes no existing output.

1. Register.
2. **The setting.** `cnb:keysig-style 'marks` and `cnb:keysig-marks`, a
   list with one entry per key. An entry's key is the tonic's note name and
   alteration (as `\key` gives them) and the key's sorted pitch classes, so
   C major and A minor are told apart by their tonic, and F♯ and G♭ major
   by their spelling. An entry gives its **columns** (each one's x offset
   in staff spaces from the signature's start), its **bars** (each one's x,
   its two ends in engine semitones, its colour and thickness in staff
   spaces) and its **marks** (each one's engine semitone, middle C = 0, its
   column, and either `head` with the shape, hollow and colour names
   Section A registers, a sized variant where it has a size, or `sharp` or
   `flat`). Two marks at one semitone in neighbouring columns are a double
   notehead and need nothing of their own. The engine computes no layout:
   the offsets are the Configurator's.
3. **Drawing.** The key-signature engraver draws the entry for the score's
   `\key`: each head through its registered stencil, with each head
   column's ledger lines beneath it, sharps and flats from Emmentaler
   (`accidentals.sharp`, `accidentals.flat`) with no ledgers, and the bars
   beneath the marks. A key change draws the new key's marks and no
   cancelling naturals. A key not in the table draws no signature, and the
   engine warns naming it; it does not fall back to the scale stack.
   `'chord` and `'none` are unchanged.
4. **The space around it.** Measure the space before the signature and
   after its last column with the mark list, for two, three and four
   columns, and give it in the handoff, so the Configurator's preview puts
   the first note where the engraving does (its 0.75, 3.5 and 4.8636 staff
   spaces are measured for `'chord`'s two columns).
5. **Tests.** Unit and integration specs for a key change, an enharmonic
   pair, a transposed score, the signature at each system start, a double
   notehead, three and four columns with their bars, sharps and flats, and
   a key the table lacks; goldens and integration specs on LilyPond 2.24
   and 2.26. Existing goldens stay byte-identical.
6. A README section, a `CHANGELOG.md` 1.4.0 section, and `version.json` to
   `1.4.0`: a minor release, a setting added and no existing output
   changed. Write
   `docs/session-sets/030-keysig-mark-list/configurator-handoff.md`, in the
   form of the earlier handoffs: the format as landed, a worked entry, the
   measured spacing of item 4, and session 31 as the release.

### Session 31: A key's pitch classes with double sharps and flats

**Why.** Session 30 found that `cnb:get-key-pitch-classes`
(`cnb/procedure.ly`) misreads a key with double sharps or flats: `\key
dis \major` gives `(2 2 3 7 7 8 10)`, with repeated pitch classes, in place
of `(0 2 3 5 7 8 10)`. It changes the list in place, replacing every pitch
class equal to a letter's natural one, so an alteration that lands on
another letter's natural pitch class (E♯ on F, F𝄪 on G) can be overwritten
by a later one, depending on the order of `keyAlterations`. Every key with
at most seven sharps or flats happens to read correctly in the order
LilyPond gives (session 30 checked C♯, C♭, F♯ and G♭ major and A♯, A♭ and
G♯ minor from real `\key` events). A key with double sharps or flats is
read wrongly. That reaches the configuration procedure's `key` argument
(and so off-key marks), and a missing key's warning under `'marks`. The
operator asked for the fix before the release.

1. Register.
2. **The fix.** `cnb:get-key-pitch-classes` gives each of the seven
   letters its pitch class from its own alteration (natural when the alist
   has none), `(natural + 2 × alteration) mod 12`, in letter order C to B
   as today, accepting the `((octave . step) . alteration)` form it
   accepts now. No other function changes.
3. **Tests.** `test-unit.ly`'s `cnb:get-key-pitch-classes` group keeps its
   cases and adds D♯ major and its order-reversed alist, a double-flat key
   (F♭ major), C♯ and C♭ major in LilyPond's order and reversed, and
   `cnb:keysig-marks-key` for D♯ major. Every existing golden stays
   byte-identical on LilyPond 2.24 and 2.26 (no existing spec has a
   double-sharp or double-flat key).
4. A line in `CHANGELOG.md`'s unreleased 1.4.0 section. Correct
   `docs/session-sets/030-keysig-mark-list/configurator-handoff.md`: every
   key's pitch classes are now read correctly (D♯ major's warning gives
   `(0 2 3 5 7 8 10)`), and session 32 is the release.

### Session 32: Release 1.4.0 (release: 1.4.0)
