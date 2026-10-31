"""Tests for run_tests.py's harvest baselines and LilyPond version choice
(no LilyPond needed)."""

import contextlib
import copy
import io
import json
import os
import subprocess
import tempfile
import unittest
from unittest import mock

from run_tests import (PROJECT_ROOT, baseline_dir, harvest_differences,
                       lilypond_env_var, lilypond_version, render_dir,
                       resolve_lilypond, run_single_test, save_harvest)

HARVEST = {
    "source_file": "x.svg",
    "staff": {"top_line_y": 1.0, "bottom_line_y": 5.0},
    "elements": [
        {"id": "nh-1", "type": "notehead",
         "absolute": {"x": 10.0, "y": 20.0}, "visual": {}},
        {"id": "nh-2", "type": "notehead",
         "absolute": {"x": 30.0, "y": 20.0}, "visual": {"color": "#000000"}},
    ],
}


class HarvestDifferencesTest(unittest.TestCase):

    def test_identical_harvests_have_no_differences(self):
        self.assertEqual(
            harvest_differences(HARVEST, copy.deepcopy(HARVEST)), [])

    def test_changed_property_names_element_and_property(self):
        changed = copy.deepcopy(HARVEST)
        changed["elements"][1]["absolute"]["y"] = 21.0
        self.assertEqual(harvest_differences(HARVEST, changed),
                         ["nh-2: absolute.y"])

    def test_missing_and_new_elements_are_named(self):
        changed = copy.deepcopy(HARVEST)
        changed["elements"][0]["id"] = "nh-3"
        self.assertEqual(harvest_differences(HARVEST, changed),
                         ["nh-1: no longer harvested", "nh-3: newly harvested"])


class SaveHarvestTest(unittest.TestCase):

    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.path = os.path.join(self.dir.name, "x.harvested.json")

    def tearDown(self):
        self.dir.cleanup()

    def write_baseline(self):
        with open(self.path, "w", encoding="utf-8") as f:
            json.dump(HARVEST, f, indent=2)
        with open(self.path, "rb") as f:
            return f.read()

    def read(self):
        with open(self.path, encoding="utf-8") as f:
            return json.load(f)

    def test_no_baseline_writes_and_passes(self):
        self.assertEqual(save_harvest(HARVEST, self.path), [])
        self.assertEqual(self.read(), HARVEST)

    def test_identical_harvest_passes(self):
        self.write_baseline()
        self.assertEqual(save_harvest(copy.deepcopy(HARVEST), self.path), [])

    def test_drift_fails_and_leaves_baseline_untouched(self):
        before = self.write_baseline()
        changed = copy.deepcopy(HARVEST)
        changed["elements"][0]["type"] = "rest"
        self.assertEqual(save_harvest(changed, self.path), ["nh-1: type"])
        with open(self.path, "rb") as f:
            self.assertEqual(f.read(), before)

    def test_update_baselines_writes_the_file(self):
        self.write_baseline()
        changed = copy.deepcopy(HARVEST)
        changed["elements"][0]["type"] = "rest"
        self.assertEqual(
            save_harvest(changed, self.path, update_baselines=True), [])
        self.assertEqual(self.read(), changed)


def version_output(first_line):
    """A completed `lilypond --version` whose first line is first_line."""
    return subprocess.CompletedProcess(
        ["lilypond", "--version"], 0, stdout=f"{first_line}\n\nCopyright\n")


class LilypondVersionTest(unittest.TestCase):

    def test_env_var_name(self):
        self.assertEqual(lilypond_env_var("2.26"), "CNB_LILYPOND_2_26")

    @mock.patch("run_tests.subprocess.run",
                return_value=version_output("GNU LilyPond 2.26.0 (running Guile 3.0)"))
    def test_reports_major_minor(self, _run):
        self.assertEqual(lilypond_version("lilypond"), "2.26")

    @mock.patch("run_tests.subprocess.run", side_effect=FileNotFoundError)
    def test_missing_executable_is_none(self, _run):
        self.assertIsNone(lilypond_version("lilypond"))


class ResolveLilypondTest(unittest.TestCase):

    @mock.patch.dict(os.environ, {"CNB_LILYPOND_2_26": r"D:\ly\lilypond.exe"})
    @mock.patch("run_tests.subprocess.run")
    def test_from_variable(self, run):
        self.assertEqual(resolve_lilypond("2.26"), r"D:\ly\lilypond.exe")
        run.assert_not_called()

    @mock.patch.dict(os.environ, {"CNB_LILYPOND_2_24": ""})
    @mock.patch("run_tests.subprocess.run",
                return_value=version_output("GNU LilyPond 2.24.2 (running Guile 2.2)"))
    def test_from_path(self, _run):
        self.assertEqual(resolve_lilypond("2.24"), "lilypond")

    @mock.patch.dict(os.environ, {"CNB_LILYPOND_2_26": ""})
    @mock.patch("run_tests.subprocess.run",
                return_value=version_output("GNU LilyPond 2.24.2 (running Guile 2.2)"))
    def test_failure_names_the_variable(self, _run):
        with self.assertRaises(SystemExit) as raised:
            resolve_lilypond("2.26")
        self.assertIn("CNB_LILYPOND_2_26", str(raised.exception.code))


class VersionDirectoriesTest(unittest.TestCase):

    SPEC_DIR = os.path.join("repo", "tests")

    def test_baseline_dir_for_2_24_is_beside_the_spec(self):
        self.assertEqual(baseline_dir("2.24", self.SPEC_DIR), self.SPEC_DIR)
        self.assertEqual(baseline_dir(None, self.SPEC_DIR), self.SPEC_DIR)

    def test_baseline_dir_for_2_26(self):
        self.assertEqual(baseline_dir("2.26", self.SPEC_DIR),
                         os.path.join(self.SPEC_DIR, "lilypond-2.26"))

    def test_unsupported_version_has_no_baseline(self):
        self.assertIsNone(baseline_dir("2.22", self.SPEC_DIR))

    def test_unsupported_version_skips_drift_but_runs_assertions(self):
        with tempfile.TemporaryDirectory() as spec_dir:
            open(os.path.join(spec_dir, "x.ly"), "w").close()
            spec_path = os.path.join(spec_dir, "x.json")
            with open(spec_path, "w", encoding="utf-8") as f:
                json.dump({"input_file": "x.ly", "assertions": [
                    {"id": "nh-1", "expect": {"type": ["== 'rest'"]}}]}, f)
            with mock.patch("run_tests.run_lilypond",
                            return_value=os.path.join(spec_dir, "x.svg")), \
                 mock.patch("run_tests.harvest", return_value=HARVEST), \
                 mock.patch("run_tests.save_harvest") as save, \
                 contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(
                    run_single_test(spec_path, version="2.22"), (0, 1, 1))
            save.assert_not_called()

    def test_render_dir(self):
        self.assertIsNone(render_dir(None))
        self.assertIsNone(render_dir("2.24"))
        self.assertEqual(render_dir("2.26"),
                         os.path.join(PROJECT_ROOT, "out", "lilypond-2.26"))


if __name__ == "__main__":
    unittest.main()
