#!/usr/bin/env python3
"""
run_corpus.py — The corpus gate: the smoke tier's pipeline over real scores.

Each .xml, .musicxml and .mxl file in DIR is converted, given the Kite
include and engraved exactly as tools/run_musicxml.py does, into the ignored
out/corpus/. The run writes docs/runs/corpus-<date>.md, one row per file:
convert exit, engrave exit, seconds, musicxml2ly warning lines, LilyPond log
lines with "-inf", and SVG pages ("-" where a step failed or was not
reached); a file over --max-bytes is "skipped".

It then reads the newest docs/runs/corpus-*.md dated before today and exits
non-zero naming each file that passed there (convert and engrave exit 0)
and does not pass now.

USAGE:
    python tools/run_corpus.py D:\\MusicXML --lilypond-version 2.24
"""

import argparse
import datetime
import glob
import os
import re
import sys
import time

from harvest_svg import configure_output
from run_musicxml import (CONVERT_FLAGS, convert, engrave, find_musicxml2ly,
                          svg_pages)
from run_tests import PROJECT_ROOT, resolve_lilypond

RUNS_DIR = os.path.join(PROJECT_ROOT, "docs", "runs")
EXTENSIONS = (".xml", ".musicxml", ".mxl")
DEFAULT_MAX_BYTES = 5_000_000
COLUMNS = ["File", "Convert", "Engrave", "s", "musicxml2ly warnings",
           "`-inf`", "Pages"]
TABLE_NAME = re.compile(r"corpus-(\d{4}-\d{2}-\d{2})\.md")


def run_file(converter, lilypond, path, out_dir, max_bytes):
    """One table row (a list of COLUMNS' cells) for the score at path."""
    name = os.path.basename(path)
    if os.path.getsize(path) > max_bytes:
        return [name, "skipped", "-", "-", "-", "-", "-"]
    ly_path = os.path.join(out_dir, os.path.splitext(name)[0] + ".ly")
    start = time.time()
    convert_exit, convert_log = convert(converter, path, ly_path)
    warnings = sum("warning" in line.lower()
                   for line in convert_log.splitlines())
    if convert_exit != 0:
        return [name, str(convert_exit), "-", str(round(time.time() - start)),
                str(warnings), "-", "-"]
    engrave_exit, log = engrave(lilypond, ly_path)
    seconds = round(time.time() - start)
    if engrave_exit != 0:
        return [name, "0", str(engrave_exit), str(seconds), str(warnings),
                "-", "-"]
    inf = sum("-inf" in line for line in log.splitlines())
    pages = len(svg_pages(os.path.splitext(ly_path)[0]))
    return [name, "0", "0", str(seconds), str(warnings), str(inf), str(pages)]


def format_table(rows, version, directory, max_bytes, date):
    """The Markdown a run writes."""
    lines = [
        f"# Corpus run, {date}",
        "",
        f"LilyPond {version or '(PATH)'}, `{directory}`, musicxml2ly "
        f"`{' '.join(CONVERT_FLAGS)}`, Kite include "
        "(`kite-4-369-from-configurator.ly`), SVG backend; files over "
        f"{max_bytes} bytes skipped. Written by `tools/run_corpus.py`.",
        "",
        "| " + " | ".join(COLUMNS) + " |",
        "|---|---|---|---:|---:|---:|---:|",
    ]
    lines += ["| " + " | ".join(row) + " |" for row in rows]
    return "\n".join(lines) + "\n"


def read_table(text):
    """The rows of a corpus table, by file name."""
    rows = {}
    for line in text.splitlines():
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if (line.startswith("|") and len(cells) == len(COLUMNS)
                and cells[0] != COLUMNS[0] and not cells[0].startswith("-")):
            rows[cells[0]] = cells
    return rows


def passed(row):
    """A row passes when both its convert and engrave exits are 0."""
    return row[1] == "0" and row[2] == "0"


def regressions(before, now):
    """The files that passed in table `before` and were run, and failed, in
    `now`. A skipped file, or one new or gone, is not a regression."""
    return sorted(name for name, row in now.items()
                  if row[1] != "skipped" and not passed(row)
                  and name in before and passed(before[name]))


def previous_table(runs_dir, date):
    """The newest corpus-<date>.md in runs_dir dated before date, or None."""
    dated = sorted((m.group(1), f) for f in os.listdir(runs_dir)
                   if (m := TABLE_NAME.fullmatch(f)) and m.group(1) < date)
    return os.path.join(runs_dir, dated[-1][1]) if dated else None


def main():
    configure_output()
    parser = argparse.ArgumentParser(description="Corpus gate")
    parser.add_argument("directory", metavar="DIR")
    parser.add_argument("--max-bytes", type=int, default=DEFAULT_MAX_BYTES,
        help=f"Skip larger files (default {DEFAULT_MAX_BYTES})")
    parser.add_argument("--lilypond-version", metavar="X.Y",
        help="Run LilyPond X.Y (from CNB_LILYPOND_X_Y, else PATH)")
    args = parser.parse_args()
    if not os.path.isdir(args.directory):
        sys.exit(f"{args.directory} is not a directory")

    version = args.lilypond_version
    lilypond = resolve_lilypond(version) if version else "lilypond"
    converter = find_musicxml2ly(lilypond)
    out_dir = os.path.join(PROJECT_ROOT, "out", "corpus",
                           f"lilypond-{version}" if version else "")
    os.makedirs(out_dir, exist_ok=True)

    rows = []
    for path in sorted((p for p in glob.glob(os.path.join(args.directory, "*"))
                        if p.lower().endswith(EXTENSIONS)), key=str.lower):
        rows.append(run_file(converter, lilypond, path, out_dir,
                             args.max_bytes))
        print("  ".join(rows[-1]), flush=True)

    date = datetime.date.today().isoformat()
    os.makedirs(RUNS_DIR, exist_ok=True)
    table = os.path.join(RUNS_DIR, f"corpus-{date}.md")
    with open(table, "w", encoding="utf-8") as f:
        f.write(format_table(rows, version, args.directory, args.max_bytes,
                             date))
    print(f"Wrote {os.path.relpath(table, PROJECT_ROOT)}")

    before = previous_table(RUNS_DIR, date)
    if before is None:
        print("No earlier table to compare with")
        return 0
    with open(before, encoding="utf-8") as f:
        failed = regressions(read_table(f.read()),
                             {row[0]: row for row in rows})
    for name in failed:
        print(f"REGRESSION  {name}: passed in "
              f"{os.path.basename(before)}, fails now")
    print(f"Compared with {os.path.basename(before)}: "
          f"{len(failed)} regression(s)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
