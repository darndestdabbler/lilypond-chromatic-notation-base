#!/usr/bin/env python3
"""
run_musicxml.py — The MusicXML smoke tier: convert, include Kite, engrave.

Each tests/musicxml/*.xml and *.musicxml is converted by the musicxml2ly
that ships with the chosen LilyPond, with Frescobaldi's import defaults
(--nd --nrp --npl --no-beaming); the line
\\include "kite-4-369-from-configurator.ly" goes in after \\version; and the
result is engraved to SVG in the ignored out/musicxml/lilypond-X.Y/.

A file passes when both exit 0 and the LilyPond log has no "error:" or
"programming error" line other than those tests/musicxml/expect.json
allows for it. musicxml2ly's own warnings never fail a file.

tests/musicxml/expect.json maps a file name to
    {"allow":    [substrings of log lines that are not failures],
     "note":     "why they are allowed",
     "defect":   "the known defect that makes it fail: musicxml2ly's, or
                  the engine's with the session that fixes it",
     "lilypond": ["X.Y", ...]}      (absent: every version)
A file listed with a "defect" must still fail: its passing is an error, so
the list cannot go stale. Keys starting with "_" are comments.

USAGE:
    python tools/run_musicxml.py --lilypond-version 2.24
    python tools/run_musicxml.py --lilypond-version 2.26

--lilypond-version X.Y runs the executable CNB_LILYPOND_X_Y names, else the
lilypond on PATH if it reports X.Y (see run_tests.py). musicxml2ly is found
beside it: on Windows bin\\python.exe bin\\musicxml2ly.py in the executable's
folder, elsewhere musicxml2ly in that folder or on PATH.
"""

import argparse
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import time

from harvest_svg import configure_output
from run_tests import PROJECT_ROOT, resolve_lilypond

SMOKE_DIR = os.path.join(PROJECT_ROOT, "tests", "musicxml")
EXPECT_FILE = os.path.join(SMOKE_DIR, "expect.json")
CONVERT_FLAGS = ["--nd", "--nrp", "--npl", "--no-beaming"]
KITE_INCLUDE = '\\include "kite-4-369-from-configurator.ly"'
CONVERT_SECONDS = 120
ENGRAVE_SECONDS = 300
ERROR_LINE = re.compile(r"error:|programming error")


def find_musicxml2ly(lilypond, platform=sys.platform):
    """The argv that runs the musicxml2ly beside lilypond. Exits non-zero
    naming what is missing."""
    executable = shutil.which(lilypond) or lilypond
    bin_dir = os.path.dirname(os.path.abspath(executable))
    if platform == "win32":
        python = os.path.join(bin_dir, "python.exe")
        script = os.path.join(bin_dir, "musicxml2ly.py")
        missing = [p for p in (python, script) if not os.path.isfile(p)]
        if missing:
            sys.exit("musicxml2ly not found beside " + executable + ": no "
                     + " and no ".join(missing))
        return [python, script]
    beside = os.path.join(bin_dir, "musicxml2ly")
    if os.path.isfile(beside):
        return [beside]
    on_path = shutil.which("musicxml2ly")
    if on_path:
        return [on_path]
    sys.exit(f"musicxml2ly not found: not in {bin_dir} and not on PATH")


def _run(argv, seconds):
    """(exit code, combined output) of argv run from the project root; a
    missing program or the time limit is exit None."""
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    try:
        result = subprocess.run(argv, cwd=PROJECT_ROOT, env=env,
                                capture_output=True, encoding="utf-8",
                                errors="replace", timeout=seconds)
    except FileNotFoundError:
        return None, f"{argv[0]} not found"
    except subprocess.TimeoutExpired:
        return None, f"timed out after {seconds}s"
    return result.returncode, result.stdout + result.stderr


def add_include(text):
    """The converted score with the Kite include after its \\version line
    (at the top when it has none)."""
    lines = text.splitlines(keepends=True)
    for i, line in enumerate(lines):
        if line.lstrip().startswith("\\version"):
            return "".join(lines[:i + 1] + [KITE_INCLUDE + "\n"] + lines[i + 1:])
    return KITE_INCLUDE + "\n" + text


def convert(converter, xml_path, ly_path):
    """Convert xml_path to ly_path and add the include: (exit, log)."""
    if os.path.exists(ly_path):
        os.remove(ly_path)
    code, log = _run(converter + CONVERT_FLAGS + ["-o", ly_path, xml_path],
                     CONVERT_SECONDS)
    if code == 0:
        if not os.path.isfile(ly_path):
            return 1, log + f"\nmusicxml2ly wrote no {ly_path}"
        with open(ly_path, encoding="utf-8") as f:
            text = f.read()
        with open(ly_path, "w", encoding="utf-8") as f:
            f.write(add_include(text))
    return code, log


def svg_pages(output_base):
    """The SVG pages LilyPond wrote for output_base ({base}.svg or
    {base}-N.svg)."""
    name = re.compile(re.escape(os.path.basename(output_base)) + r"(-\d+)?\.svg")
    folder = os.path.dirname(output_base)
    return sorted(f for f in os.listdir(folder) if name.fullmatch(f))


def engrave(lilypond, ly_path):
    """Engrave ly_path to SVG beside it, earlier pages removed: (exit, log)."""
    base = os.path.splitext(ly_path)[0]
    for page in svg_pages(base):
        os.remove(os.path.join(os.path.dirname(base), page))
    return _run([lilypond, "-dbackend=svg", "-dno-point-and-click",
                 f"--output={base}", ly_path], ENGRAVE_SECONDS)


def error_lines(log):
    """The LilyPond log's "error:" and "programming error" lines."""
    return [line.strip() for line in log.splitlines() if ERROR_LINE.search(line)]


def load_expectations(path, version):
    """expect.json's entries that apply to LilyPond version, by file name."""
    with open(path, encoding="utf-8") as f:
        entries = json.load(f)
    return {name: entry for name, entry in entries.items()
            if not name.startswith("_")
            and (version is None or "lilypond" not in entry
                 or version in entry["lilypond"])}


def judge(convert_exit, engrave_exit, log, entry):
    """(passed, reason) for one file under its expect.json entry, if any.
    A listed defect passes only by failing; its passing fails the run."""
    entry = entry or {}
    allow = entry.get("allow", [])
    errors = [line for line in error_lines(log)
              if not any(a in line for a in allow)]
    clean = convert_exit == 0 and engrave_exit == 0 and not errors
    if "defect" in entry:
        if clean:
            return False, ("stale expectation: listed as a known defect "
                           f"({entry['defect']}) but it passes; remove its "
                           "entry from tests/musicxml/expect.json")
        return True, "known defect: " + entry["defect"]
    if convert_exit != 0:
        return False, f"musicxml2ly exit {convert_exit}"
    if engrave_exit != 0:
        return False, f"LilyPond exit {engrave_exit}: " + "; ".join(errors[:3])
    if errors:
        return False, "; ".join(errors[:3])
    return True, ""


def output_dir(version):
    """Where the converted scores and their SVGs go."""
    parts = [PROJECT_ROOT, "out", "musicxml"]
    if version:
        parts.append(f"lilypond-{version}")
    return os.path.join(*parts)


def smoke_files():
    """The vendored MusicXML files, sorted."""
    return sorted(glob.glob(os.path.join(SMOKE_DIR, "*.xml"))
                  + glob.glob(os.path.join(SMOKE_DIR, "*.musicxml")))


def main():
    configure_output()
    parser = argparse.ArgumentParser(description="MusicXML smoke tier")
    parser.add_argument("--lilypond-version", metavar="X.Y",
        help="Run LilyPond X.Y (from CNB_LILYPOND_X_Y, else PATH)")
    version = parser.parse_args().lilypond_version
    lilypond = resolve_lilypond(version) if version else "lilypond"
    converter = find_musicxml2ly(lilypond)
    expectations = load_expectations(EXPECT_FILE, version)
    out = output_dir(version)
    os.makedirs(out, exist_ok=True)

    files = smoke_files()
    unknown = sorted(set(expectations) - {os.path.basename(f) for f in files})
    for name in unknown:
        print(f"FAIL  {name}: expect.json names a file not in tests/musicxml")

    failed = 0
    start = time.time()
    for xml_path in files:
        name = os.path.basename(xml_path)
        ly_path = os.path.join(out, os.path.splitext(name)[0] + ".ly")
        convert_exit, log = convert(converter, xml_path, ly_path)
        engrave_exit = None
        if convert_exit == 0:
            engrave_exit, log = engrave(lilypond, ly_path)
        passed, reason = judge(convert_exit, engrave_exit, log,
                               expectations.get(name))
        failed += not passed
        print(f"{'ok  ' if passed else 'FAIL'}  {name}"
              + (f": {reason}" if reason else ""))

    print(f"RESULTS: {len(files) - failed} passed, {failed} failed "
          f"({len(files)} files, {time.time() - start:.0f}s)")
    return 1 if failed or unknown else 0


if __name__ == "__main__":
    sys.exit(main())
