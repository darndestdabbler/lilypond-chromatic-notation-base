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

from run_tests import (PROJECT_ROOT, baseline_dir, check_element_assertions,
                       generate_golden, harvest_differences,
                       lilypond_env_var, lilypond_version, main,
                       make_eval_namespace, render_dir, resolve_lilypond,
                       run_lilypond, run_single_test, save_harvest)

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

    REPEATED = {"elements": [
        {"id": "staff-symbol", "absolute": {"x": 0.0}},
        {"id": "staff-symbol", "absolute": {"x": 0.0}},
        {"id": "ll-1", "absolute": {"y": 4.0}},
    ]}

    def test_later_occurrence_of_a_repeated_id_is_compared(self):
        changed = copy.deepcopy(self.REPEATED)
        changed["elements"][1]["absolute"]["x"] = 10.0
        self.assertEqual(harvest_differences(self.REPEATED, changed),
                         ["staff-symbol[1]: absolute.x"])

    def test_newly_duplicated_id_is_drift(self):
        changed = copy.deepcopy(self.REPEATED)
        changed["elements"].append({"id": "ll-1", "absolute": {"y": 4.0}})
        self.assertEqual(harvest_differences(self.REPEATED, changed),
                         ["ll-1[1]: newly harvested"])


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

    @mock.patch.dict(os.environ, {"CNB_LILYPOND_2_26": "/opt/lilypond/bin/lilypond"})
    @mock.patch("run_tests.subprocess.run",
                return_value=version_output("GNU LilyPond 2.26.0 (running Guile 3.0)"))
    def test_from_variable(self, run):
        self.assertEqual(resolve_lilypond("2.26"), "/opt/lilypond/bin/lilypond")
        self.assertEqual(run.call_args.args[0],
                         ["/opt/lilypond/bin/lilypond", "--version"])

    @mock.patch.dict(os.environ, {"CNB_LILYPOND_2_26": "/opt/lilypond/bin/lilypond"})
    @mock.patch("run_tests.subprocess.run",
                return_value=version_output("GNU LilyPond 2.24.2 (running Guile 2.2)"))
    def test_variable_naming_another_version_fails(self, _run):
        with self.assertRaises(SystemExit) as raised:
            resolve_lilypond("2.26")
        self.assertIn("CNB_LILYPOND_2_26", raised.exception.code)
        self.assertIn("reports LilyPond 2.24, not 2.26", raised.exception.code)

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


class LilypondInExpressionsTest(unittest.TestCase):

    ELEMENTS = {el["id"]: el for el in HARVEST["elements"]}
    ASSERTION = {"id": "nh-1", "expect": {"type": ["lilypond == '2.26'"]}}

    def test_namespace_defaults_to_2_24(self):
        ns = make_eval_namespace(None, self.ELEMENTS, HARVEST)
        self.assertEqual(ns["lilypond"], "2.24")

    def test_expression_reads_the_version(self):
        el = self.ELEMENTS["nh-1"]
        for version, passed in (("2.26", True), ("2.24", False)):
            [result] = check_element_assertions(
                el, self.ASSERTION, self.ELEMENTS, HARVEST, version)
            self.assertIs(result["passed"], passed)

    def _run(self, version):
        with tempfile.TemporaryDirectory() as spec_dir:
            open(os.path.join(spec_dir, "x.ly"), "w").close()
            spec_path = os.path.join(spec_dir, "x.json")
            with open(spec_path, "w", encoding="utf-8") as f:
                json.dump({"input_file": "x.ly", "assertions": [
                    {"id": "nh-1",
                     "expect": {"type": ["lilypond == '2.24'"]}}]}, f)
            with mock.patch("run_tests.run_lilypond",
                            return_value=os.path.join(spec_dir, "x.svg")),                  mock.patch("run_tests.harvest", return_value=HARVEST),                  mock.patch("run_tests.save_harvest", return_value=[]),                  contextlib.redirect_stdout(io.StringIO()):
                return run_single_test(spec_path, version=version)

    def test_run_single_test_defaults_to_2_24(self):
        self.assertEqual(self._run(None), (1, 0, 1, 0))

    def test_run_single_test_passes_its_version(self):
        self.assertEqual(self._run("2.26"), (0, 1, 1, 0))


class DeclaredAbsenceTest(unittest.TestCase):
    """A missing element passes only an assertion declaring "absent": true."""

    def run_assertion(self, assertion):
        """run_single_test's (passed, failed, assertions, drifted) for one
        assertion against HARVEST, which has nh-1 and nh-2 but no cl-1."""
        return run_spec([assertion])

    def test_declared_absence_passes_when_missing(self):
        self.assertEqual(
            self.run_assertion({"id": "cl-1", "absent": True}), (1, 0, 1, 0))

    def test_declared_absence_fails_when_present(self):
        self.assertEqual(
            self.run_assertion({"id": "nh-1", "absent": True}), (0, 1, 1, 0))

    def test_is_none_expression_does_not_excuse_a_missing_element(self):
        self.assertEqual(self.run_assertion(
            {"id": "cl-1", "expect": {"visual.color": ["v is None"],
                                      "type": ["== 'clef'"]}}), (0, 1, 1, 0))

    def test_assertion_with_nothing_to_check_fails(self):
        self.assertEqual(self.run_assertion({"id": "nh-1"}), (0, 1, 1, 0))
        self.assertEqual(
            self.run_assertion({"id": "nh-1", "expect": {}}), (0, 1, 1, 0))


def run_spec(assertions, drift=()):
    """run_single_test on a spec of assertions against HARVEST, with
    save_harvest reporting drift."""
    with tempfile.TemporaryDirectory() as spec_dir:
        open(os.path.join(spec_dir, "x.ly"), "w").close()
        spec_path = os.path.join(spec_dir, "x.json")
        with open(spec_path, "w", encoding="utf-8") as f:
            json.dump({"input_file": "x.ly", "assertions": assertions}, f)
        with mock.patch("run_tests.run_lilypond",
                        return_value=os.path.join(spec_dir, "x.svg")), \
             mock.patch("run_tests.harvest", return_value=HARVEST), \
             mock.patch("run_tests.save_harvest", return_value=list(drift)), \
             contextlib.redirect_stdout(io.StringIO()):
            return run_single_test(spec_path)


class CountsTest(unittest.TestCase):
    """Only assertions with an id are counted, and drift apart from them."""

    NOTEHEAD = {"id": "nh-1", "expect": {"type": ["== 'notehead'"]}}

    def test_comment_markers_are_not_counted(self):
        self.assertEqual(
            run_spec([{"_comment": "section"}, self.NOTEHEAD,
                      {"_comment": "another"}]), (1, 0, 1, 0))

    def test_drift_is_counted_apart_from_assertions(self):
        self.assertEqual(run_spec([self.NOTEHEAD], drift=["nh-1: absolute.x"]),
                         (1, 0, 1, 1))


class VersionDirectoriesTest(unittest.TestCase):

    SPEC_DIR = os.path.join("repo", "tests")

    def test_baseline_dir_for_2_24_is_beside_the_spec(self):
        self.assertEqual(baseline_dir("2.24", self.SPEC_DIR), self.SPEC_DIR)
        self.assertEqual(baseline_dir(None, self.SPEC_DIR), self.SPEC_DIR)

    def test_baseline_dir_for_2_26(self):
        self.assertEqual(baseline_dir("2.26", self.SPEC_DIR),
                         os.path.join(self.SPEC_DIR, "lilypond-2.26"))

    def test_baseline_dir_for_any_other_version(self):
        self.assertEqual(baseline_dir("2.27", self.SPEC_DIR),
                         os.path.join(self.SPEC_DIR, "lilypond-2.27"))

    def test_any_other_version_fails_on_drift_from_its_baseline(self):
        with tempfile.TemporaryDirectory() as spec_dir:
            open(os.path.join(spec_dir, "x.ly"), "w").close()
            spec_path = os.path.join(spec_dir, "x.json")
            with open(spec_path, "w", encoding="utf-8") as f:
                json.dump({"input_file": "x.ly", "assertions": [
                    {"id": "nh-1", "expect": {"type": ["== 'notehead'"]}}]}, f)
            os.makedirs(os.path.join(spec_dir, "lilypond-2.27"))
            baseline = copy.deepcopy(HARVEST)
            baseline["elements"][0]["absolute"]["x"] = 11.0
            with open(os.path.join(spec_dir, "lilypond-2.27",
                                   "x.harvested.json"), "w",
                      encoding="utf-8") as f:
                json.dump(baseline, f)
            with mock.patch("run_tests.run_lilypond",
                            return_value=os.path.join(spec_dir, "x.svg")), \
                 mock.patch("run_tests.harvest", return_value=HARVEST), \
                 contextlib.redirect_stdout(io.StringIO()) as out:
                self.assertEqual(
                    run_single_test(spec_path, version="2.27"), (1, 0, 1, 1))
            self.assertIn("nh-1: absolute.x", out.getvalue())

    @mock.patch("run_tests.subprocess.run",
                return_value=subprocess.CompletedProcess([], 1, "", "boom"))
    def test_run_lilypond_creates_the_render_dir(self, _run):
        with tempfile.TemporaryDirectory() as root:
            out = os.path.join(root, "out", "lilypond-2.26")
            with contextlib.redirect_stderr(io.StringIO()):
                run_lilypond(os.path.join(root, "x.ly"), output_dir=out)
            self.assertTrue(os.path.isdir(out))

    def test_generate_renders_2_26_outside_tests(self):
        with tempfile.TemporaryDirectory() as tests_dir:
            ly_file = os.path.join(tests_dir, "example.ly")
            svg_file = os.path.join(tests_dir, "example.svg")
            with open(svg_file, "w", encoding="utf-8") as f:
                f.write("sentinel")
            with mock.patch("run_tests.run_lilypond",
                            return_value="example.svg") as render, \
                 mock.patch("run_tests.harvest", return_value={
                     **HARVEST, "staff": {"top_line_y": 1.0,
                                          "bottom_line_y": 5.0,
                                          "staff_height": 4.0,
                                          "line_count": 5}}), \
                 contextlib.redirect_stdout(io.StringIO()):
                generate_golden(ly_file, version="2.26")
            self.assertEqual(render.call_args.kwargs["output_dir"],
                             render_dir("2.26"))
            self.assertTrue(os.path.isfile(os.path.join(
                tests_dir, "lilypond-2.26", "example.harvested.json")))
            with open(svg_file, encoding="utf-8") as f:
                self.assertEqual(f.read(), "sentinel")

    GOLDEN = {**HARVEST, "staff": {"top_line_y": 1.0, "bottom_line_y": 5.0,
                                   "staff_height": 4.0, "line_count": 5}}

    def generate_over(self, update_baselines):
        """generate_golden over an existing baseline; (render mock, the
        baseline's contents afterwards)."""
        with tempfile.TemporaryDirectory() as tests_dir:
            ly_file = os.path.join(tests_dir, "example.ly")
            baseline = os.path.join(tests_dir, "example.harvested.json")
            with open(baseline, "w", encoding="utf-8") as f:
                f.write("{}")
            with mock.patch("run_tests.run_lilypond",
                            return_value="example.svg") as render, \
                 mock.patch("run_tests.harvest", return_value=self.GOLDEN), \
                 contextlib.redirect_stdout(io.StringIO()):
                try:
                    generate_golden(ly_file, version="2.24",
                                    update_baselines=update_baselines)
                except SystemExit as exit_:
                    self.assertIn("--update-baselines", str(exit_.code))
            with open(baseline, encoding="utf-8") as f:
                return render, json.load(f)

    def test_generate_refuses_an_existing_baseline(self):
        render, written = self.generate_over(update_baselines=False)
        render.assert_not_called()
        self.assertEqual(written, {})

    def test_generate_overwrites_with_update_baselines(self):
        _render, written = self.generate_over(update_baselines=True)
        self.assertEqual(written, self.GOLDEN)

    def test_render_dir(self):
        self.assertIsNone(render_dir(None))
        self.assertIsNone(render_dir("2.24"))
        self.assertEqual(render_dir("2.26"),
                         os.path.join(PROJECT_ROOT, "out", "lilypond-2.26"))


class FreshRenderTest(unittest.TestCase):
    """run_lilypond harvests only what this run wrote, and one page of it."""

    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.out = self.dir.name

    def tearDown(self):
        self.dir.cleanup()

    def render(self, *written):
        """run_lilypond on x.ly with a LilyPond that writes `written`."""
        def lilypond(cmd, **_kwargs):
            for name in written:
                open(os.path.join(self.out, name), "w").close()
            return subprocess.CompletedProcess(cmd, 0, "", "")
        stderr = io.StringIO()
        with mock.patch("run_tests.subprocess.run", side_effect=lilypond), \
             contextlib.redirect_stderr(stderr):
            svg = run_lilypond(os.path.join(self.out, "x.ly"),
                               output_dir=self.out)
        return svg, stderr.getvalue()

    def touch(self, name):
        open(os.path.join(self.out, name), "w").close()

    def test_stale_render_is_deleted_and_not_harvested(self):
        for name in ("x.svg", "x-1.svg", "x-custom.svg"):
            self.touch(name)
        svg, err = self.render()
        self.assertIsNone(svg)
        self.assertIn("SVG not found", err)
        self.assertEqual(os.listdir(self.out), ["x-custom.svg"])

    def test_multi_page_render_fails(self):
        svg, err = self.render("x-1.svg", "x-2.svg")
        self.assertIsNone(svg)
        self.assertIn("2 pages (x-1.svg, x-2.svg)", err)

    def test_fresh_single_page_is_returned(self):
        self.touch("x.svg")
        svg, _err = self.render("x.svg")
        self.assertEqual(svg, os.path.join(self.out, "x.svg"))


class MainTest(unittest.TestCase):

    def run_main(self, *argv):
        """main()'s exit code with argv, its output swallowed."""
        with mock.patch("sys.argv", ["run_tests.py", *argv]), \
             mock.patch("run_tests.configure_output"), \
             contextlib.redirect_stdout(io.StringIO()), \
             contextlib.redirect_stderr(io.StringIO()), \
             self.assertRaises(SystemExit) as raised:
            main()
        return raised.exception.code

    def spec_dir(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        return tmp.name

    @mock.patch("run_tests.resolve_lilypond", return_value="lilypond")
    def test_no_specs_exits_non_zero(self, _resolve):
        self.assertEqual(
            self.run_main("--lilypond-version", "2.24", self.spec_dir()), 1)

    @mock.patch("run_tests.resolve_lilypond", return_value="lilypond")
    def test_missing_path_exits_non_zero(self, _resolve):
        code = self.run_main("--lilypond-version", "2.24",
                             os.path.join(self.spec_dir(), "no-such.json"))
        self.assertIn("no-such.json", code)

    @mock.patch("run_tests.resolve_lilypond", return_value="lilypond")
    @mock.patch("run_tests.run_single_test", return_value=(1, 0, 1, 1))
    def test_drift_alone_fails_the_run(self, _run_test, _resolve):
        spec_dir = self.spec_dir()
        open(os.path.join(spec_dir, "x.json"), "w").close()
        self.assertEqual(
            self.run_main("--lilypond-version", "2.24", spec_dir), 1)

    @mock.patch("run_tests.lilypond_version", return_value="2.26")
    @mock.patch("run_tests.run_single_test", return_value=(1, 0, 1, 0))
    def test_version_less_run_uses_path_version(self, run_test, _version):
        spec_dir = self.spec_dir()
        open(os.path.join(spec_dir, "x.json"), "w").close()
        self.assertEqual(self.run_main(spec_dir), 0)
        self.assertEqual(run_test.call_args.kwargs["version"], "2.26")

    @mock.patch("run_tests.lilypond_version", return_value=None)
    def test_version_less_run_without_lilypond_exits(self, _version):
        self.assertIn("No lilypond on PATH", self.run_main(self.spec_dir()))


if __name__ == "__main__":
    unittest.main()
