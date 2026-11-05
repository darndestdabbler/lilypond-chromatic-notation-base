"""Tests for run_musicxml.py's converter resolution, include insertion and
judging against tests/musicxml/expect.json (no LilyPond needed)."""

import json
import os
import tempfile
import unittest
from unittest import mock

from run_musicxml import (KITE_INCLUDE, add_include, error_lines,
                          find_musicxml2ly, judge, load_expectations)


def touch(*parts):
    path = os.path.join(*parts)
    open(path, "w").close()
    return path


class FindMusicxml2lyTest(unittest.TestCase):

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.bin = self.tmp.name
        self.addCleanup(self.tmp.cleanup)

    def test_windows_uses_bundled_python_beside_lilypond(self):
        lilypond = touch(self.bin, "lilypond.exe")
        python = touch(self.bin, "python.exe")
        script = touch(self.bin, "musicxml2ly.py")
        self.assertEqual(find_musicxml2ly(lilypond, platform="win32"),
                         [python, script])

    def test_windows_bare_name_resolved_through_path(self):
        lilypond = touch(self.bin, "lilypond.exe")
        python = touch(self.bin, "python.exe")
        script = touch(self.bin, "musicxml2ly.py")
        with mock.patch("run_musicxml.shutil.which", return_value=lilypond):
            self.assertEqual(find_musicxml2ly("lilypond", platform="win32"),
                             [python, script])

    def test_windows_missing_converter_names_it(self):
        lilypond = touch(self.bin, "lilypond.exe")
        touch(self.bin, "python.exe")
        with self.assertRaises(SystemExit) as caught:
            find_musicxml2ly(lilypond, platform="win32")
        self.assertIn("musicxml2ly.py", str(caught.exception.code))

    def test_elsewhere_prefers_the_one_beside_lilypond(self):
        lilypond = touch(self.bin, "lilypond")
        beside = touch(self.bin, "musicxml2ly")
        self.assertEqual(find_musicxml2ly(lilypond, platform="linux"), [beside])

    def test_elsewhere_falls_back_to_path(self):
        lilypond = touch(self.bin, "lilypond")
        with mock.patch("run_musicxml.shutil.which",
                        side_effect=lambda name: "/usr/bin/musicxml2ly"
                        if name == "musicxml2ly" else None):
            self.assertEqual(find_musicxml2ly(lilypond, platform="linux"),
                             ["/usr/bin/musicxml2ly"])

    def test_elsewhere_missing_converter_exits_naming_it(self):
        lilypond = touch(self.bin, "lilypond")
        with mock.patch("run_musicxml.shutil.which", return_value=None):
            with self.assertRaises(SystemExit) as caught:
                find_musicxml2ly(lilypond, platform="linux")
        self.assertIn("musicxml2ly not found", str(caught.exception.code))


class AddIncludeTest(unittest.TestCase):

    def test_after_version_line(self):
        text = '\\version "2.24.2"\n% converted\n{ c4 }\n'
        self.assertEqual(add_include(text),
                         '\\version "2.24.2"\n' + KITE_INCLUDE
                         + '\n% converted\n{ c4 }\n')

    def test_at_top_without_version(self):
        self.assertEqual(add_include("{ c4 }\n"), KITE_INCLUDE + "\n{ c4 }\n")


class ErrorLinesTest(unittest.TestCase):

    def test_errors_and_programming_errors_only(self):
        log = ("warning: barcheck failed\n"
               "x.ly:3:1: error: syntax error\n"
               "programming error: Improbable offset\n"
               "continuing, cross fingers\n")
        self.assertEqual(error_lines(log), ["x.ly:3:1: error: syntax error",
                                            "programming error: Improbable offset"])


class JudgeTest(unittest.TestCase):

    BEAM = "programming error: No viable beam quanting found."

    def test_clean_file_passes(self):
        self.assertEqual(judge(0, 0, "warning: ignored\n", None), (True, ""))

    def test_error_line_fails(self):
        passed, reason = judge(0, 0, self.BEAM + "\n", None)
        self.assertFalse(passed)
        self.assertIn("beam quanting", reason)

    def test_allowed_error_line_passes(self):
        entry = {"allow": ["No viable beam quanting"]}
        self.assertEqual(judge(0, 0, self.BEAM + "\n", entry), (True, ""))

    def test_allow_does_not_cover_other_errors(self):
        entry = {"allow": ["No viable beam quanting"]}
        log = self.BEAM + "\nprogramming error: Improbable offset\n"
        self.assertFalse(judge(0, 0, log, entry)[0])

    def test_nonzero_exit_fails_even_when_errors_allowed(self):
        entry = {"allow": ["No viable beam quanting"]}
        self.assertFalse(judge(0, 1, self.BEAM + "\n", entry)[0])

    def test_converter_failure_fails(self):
        self.assertEqual(judge(1, None, "ValueError", None),
                         (False, "musicxml2ly exit 1"))

    def test_known_defect_that_still_fails_passes(self):
        passed, reason = judge(1, None, "ValueError", {"defect": "shlex crash"})
        self.assertTrue(passed)
        self.assertIn("shlex crash", reason)

    def test_known_defect_that_passes_is_a_stale_expectation(self):
        passed, reason = judge(0, 0, "", {"defect": "shlex crash"})
        self.assertFalse(passed)
        self.assertIn("stale expectation", reason)


class LoadExpectationsTest(unittest.TestCase):

    def test_version_scoped_entries_and_comments(self):
        entries = {"_comment": "x",
                   "a.xml": {"defect": "d", "lilypond": ["2.24"]},
                   "b.xml": {"allow": ["e"]}}
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "expect.json")
            with open(path, "w", encoding="utf-8") as f:
                json.dump(entries, f)
            self.assertEqual(sorted(load_expectations(path, "2.24")),
                             ["a.xml", "b.xml"])
            self.assertEqual(sorted(load_expectations(path, "2.26")), ["b.xml"])


if __name__ == "__main__":
    unittest.main()
