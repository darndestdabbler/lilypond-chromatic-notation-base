"""Tests for run_corpus.py's tables and regression comparison (no LilyPond
needed)."""

import os
import tempfile
import unittest

from run_corpus import (format_table, passed, previous_table, read_table,
                        regressions)

ROWS = [
    ["a.xml", "0", "0", "8", "53", "8", "6"],
    ["big.xml", "skipped", "-", "-", "-", "-", "-"],
    ["bad.xml", "0", "1", "1", "6", "-", "-"],
    ["crash.xml", "1", "-", "-", "-", "-", "-"],
]


def table(rows):
    return {row[0]: row for row in rows}


class ReadTableTest(unittest.TestCase):

    def test_round_trip_of_a_written_table(self):
        text = format_table(ROWS, "2.24", "D:\\MusicXML", 5000000, "2026-11-05")
        self.assertEqual(read_table(text), table(ROWS))

    def test_ignores_prose_header_and_rule(self):
        text = ("# Corpus run\n\nSome | prose\n\n"
                "| File | Convert | Engrave | s | musicxml2ly warnings | `-inf` | Pages |\n"
                "|---|---|---|---:|---:|---:|---:|\n"
                "| a.xml | 0 | 0 | 8 | 53 | 8 | 6 |\n")
        self.assertEqual(list(read_table(text)), ["a.xml"])

    def test_the_committed_baseline_reads(self):
        path = os.path.join(os.path.dirname(os.path.dirname(
            os.path.abspath(__file__))), "docs", "runs", "corpus-2026-11-04.md")
        with open(path, encoding="utf-8") as f:
            rows = read_table(f.read())
        self.assertEqual(len(rows), 30)
        self.assertEqual(sum(passed(r) for r in rows.values()), 20)


class RegressionsTest(unittest.TestCase):

    def test_pass_turned_fail_is_a_regression(self):
        now = table([["a.xml", "0", "1", "8", "53", "-", "-"]])
        self.assertEqual(regressions(table(ROWS), now), ["a.xml"])

    def test_fail_still_failing_and_fixed_are_not(self):
        now = table([["bad.xml", "0", "1", "1", "6", "-", "-"],
                     ["crash.xml", "0", "0", "1", "0", "0", "1"]])
        self.assertEqual(regressions(table(ROWS), now), [])

    def test_new_file_failing_is_not_a_regression(self):
        now = table([["new.xml", "1", "-", "-", "-", "-", "-"]])
        self.assertEqual(regressions(table(ROWS), now), [])

    def test_skipped_now_is_not_a_regression(self):
        now = table([["a.xml", "skipped", "-", "-", "-", "-", "-"]])
        self.assertEqual(regressions(table(ROWS), now), [])


class PreviousTableTest(unittest.TestCase):

    def test_newest_dated_before_today(self):
        with tempfile.TemporaryDirectory() as tmp:
            for name in ("corpus-2026-11-04.md", "corpus-2026-12-01.md",
                         "corpus-2026-11-05.md", "notes.md"):
                open(os.path.join(tmp, name), "w").close()
            self.assertEqual(previous_table(tmp, "2026-11-05"),
                             os.path.join(tmp, "corpus-2026-11-04.md"))
            self.assertIsNone(previous_table(tmp, "2026-11-04"))


if __name__ == "__main__":
    unittest.main()
