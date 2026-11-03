"""Tests for harvest_svg.py's colour normalisation (no LilyPond needed)."""

import unittest
import xml.etree.ElementTree as ET

from harvest_svg import extract_color_deep, normalize_color


class NormalizeColorTest(unittest.TestCase):

    def test_opaque_rgba_becomes_rgb(self):
        self.assertEqual(
            normalize_color("rgba(100.0000%, 83.1373%, 16.4706%, 100.0000%)"),
            "rgb(100.0000%, 83.1373%, 16.4706%)")

    def test_short_zero_is_written_at_four_decimals(self):
        self.assertEqual(normalize_color("rgba(0%, 0.0000%, 100%, 100%)"),
                         "rgb(0.0000%, 0.0000%, 100.0000%)")

    def test_translucent_rgba_keeps_its_alpha(self):
        self.assertEqual(normalize_color("rgba(0%, 50%, 100.0000%, 50%)"),
                         "rgba(0.0000%, 50.0000%, 100.0000%, 50.0000%)")

    def test_2_24_rgb_is_unchanged(self):
        color = "rgb(31.3725%, 70.5882%, 91.3725%)"
        self.assertEqual(normalize_color(color), color)

    def test_other_colour_is_unchanged(self):
        self.assertEqual(normalize_color("#000000"), "#000000")


class ExtractColorDeepTest(unittest.TestCase):

    def test_normalises_a_2_26_group_colour(self):
        group = ET.fromstring(
            '<g color="rgba(0.0000%, 0%, 0.0000%, 100.0000%)"><path d="M0 0"/></g>')
        self.assertEqual(extract_color_deep(group),
                         "rgb(0.0000%, 0.0000%, 0.0000%)")

    def test_normalises_a_fill(self):
        path = ET.fromstring('<path fill="rgba(100%, 0%, 0%, 100%)" d="M0 0"/>')
        self.assertEqual(extract_color_deep(path),
                         "rgb(100.0000%, 0.0000%, 0.0000%)")


if __name__ == "__main__":
    unittest.main()
