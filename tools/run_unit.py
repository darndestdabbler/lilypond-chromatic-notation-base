#!/usr/bin/env python3
"""
run_unit.py — Gate on test-unit.ly, which LilyPond runs but cannot fail.

LilyPond exits 0 even when test-unit.ly's assertions fail, so this wrapper
renders it (output into the ignored out/ folder), reads its
"TEST RESULTS: N passed, M failed" line, and exits non-zero on any failure,
a missing line, a LilyPond error or the time limit.

USAGE:
    python tools/run_unit.py
    python tools/run_unit.py --lilypond-version 2.26  # into out/lilypond-2.26/

--lilypond-version X.Y runs the executable CNB_LILYPOND_X_Y names, else the
lilypond on PATH if it reports X.Y (see run_tests.py).
"""

import argparse
import os
import re
import subprocess
import sys

from harvest_svg import configure_output
from run_tests import render_dir, resolve_lilypond

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_DIR = os.path.join(PROJECT_ROOT, "out")
TIME_LIMIT_SECONDS = 300

RESULTS_LINE = re.compile(r"TEST RESULTS:\s*(\d+)\s+passed,\s*(\d+)\s+failed")


def parse_results(log):
    """Return (passed, failed) from LilyPond's log, or None if absent."""
    match = RESULTS_LINE.search(log)
    return (int(match.group(1)), int(match.group(2))) if match else None


def main():
    configure_output()
    parser = argparse.ArgumentParser(description="Gate on test-unit.ly")
    parser.add_argument("--lilypond-version", metavar="X.Y",
        help="Run LilyPond X.Y (from CNB_LILYPOND_X_Y, else PATH)")
    version = parser.parse_args().lilypond_version
    lilypond = resolve_lilypond(version) if version else "lilypond"
    output_dir = render_dir(version) or OUTPUT_DIR
    os.makedirs(output_dir, exist_ok=True)
    cmd = [lilypond, f"--output={output_dir}/test-unit", "test-unit.ly"]
    try:
        result = subprocess.run(
            cmd, cwd=PROJECT_ROOT, capture_output=True,
            encoding="utf-8", errors="replace", timeout=TIME_LIMIT_SECONDS)
    except FileNotFoundError:
        print(f"{lilypond} not found", file=sys.stderr)
        return 1
    except subprocess.TimeoutExpired:
        print(f"LilyPond exceeded {TIME_LIMIT_SECONDS}s on test-unit.ly",
              file=sys.stderr)
        return 1

    log = result.stdout + result.stderr
    if result.returncode != 0:
        print(log[-2000:], file=sys.stderr)
        print(f"LilyPond error (exit {result.returncode})", file=sys.stderr)
        return 1

    counts = parse_results(log)
    if counts is None:
        print(log[-2000:], file=sys.stderr)
        print("No 'TEST RESULTS' line in LilyPond's output", file=sys.stderr)
        return 1

    passed, failed = counts
    if failed:
        # The failing assertions are reported in the log above the totals.
        print(log, file=sys.stderr)
    print(f"UNIT RESULTS: {passed} passed, {failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
