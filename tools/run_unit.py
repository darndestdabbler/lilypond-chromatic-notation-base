#!/usr/bin/env python3
"""
run_unit.py — Gate on test-unit.ly, which LilyPond runs but cannot fail.

LilyPond exits 0 even when test-unit.ly's assertions fail, so this wrapper
renders it (output into the ignored out/ folder), reads its
"TEST RESULTS: N passed, M failed" line, and exits non-zero on any failure,
a missing line, a LilyPond error or the time limit.

USAGE:
    python tools/run_unit.py
"""

import os
import re
import subprocess
import sys

from harvest_svg import configure_output

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
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    cmd = ["lilypond", f"--output={OUTPUT_DIR}/test-unit", "test-unit.ly"]
    try:
        result = subprocess.run(
            cmd, cwd=PROJECT_ROOT, capture_output=True,
            encoding="utf-8", errors="replace", timeout=TIME_LIMIT_SECONDS)
    except FileNotFoundError:
        print("lilypond not found in PATH", file=sys.stderr)
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
