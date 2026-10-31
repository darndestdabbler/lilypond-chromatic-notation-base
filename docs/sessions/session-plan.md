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
