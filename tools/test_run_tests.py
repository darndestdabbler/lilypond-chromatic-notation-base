"""Tests for run_tests.py's harvest baseline comparison (no LilyPond needed)."""

import copy
import json
import os
import tempfile
import unittest

from run_tests import harvest_differences, save_harvest

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


if __name__ == "__main__":
    unittest.main()
