"""Tests for harvest_svg.py (no LilyPond needed)."""

import unittest
import xml.etree.ElementTree as ET

from harvest_svg import (compute_bbox_deep, extract_color_deep, hash_shapes,
                         normalize_color)


def placed(inner):
    """A tagged group drawing inner at scale 2 and translate (10, 20)."""
    return ET.fromstring(
        '<g id="x"><g transform="scale(2, 2)"><g transform="translate(5, 10)">'
        f'{inner}</g></g></g>')


class ComputeBboxDeepTest(unittest.TestCase):

    def test_circle(self):
        self.assertEqual(compute_bbox_deep(placed('<circle cx="1" cy="2" r="0.5"/>')),
                         {"x": 11.0, "y": 23.0, "w": 2.0, "h": 2.0})

    def test_ellipse(self):
        self.assertEqual(
            compute_bbox_deep(placed('<ellipse cx="0" cy="0" rx="1" ry="0.25"/>')),
            {"x": 8.0, "y": 19.5, "w": 4.0, "h": 1.0})

    def test_polygon(self):
        self.assertEqual(
            compute_bbox_deep(placed('<polygon points="2 -0.5 2 0.5 0 0.4 0,-0.4"/>')),
            {"x": 10.0, "y": 19.0, "w": 4.0, "h": 2.0})

    def test_polyline(self):
        self.assertEqual(
            compute_bbox_deep(placed('<polyline points="0,0 3,1 1,-1"/>')),
            {"x": 10.0, "y": 18.0, "w": 6.0, "h": 4.0})

    def test_text_counts_only_its_anchor(self):
        self.assertEqual(
            compute_bbox_deep(placed('<text font-size="2.2"><tspan>4</tspan></text>')),
            {"x": 10.0, "y": 20.0, "w": 0.0, "h": 0.0})


class HashShapesTest(unittest.TestCase):

    def test_none_when_only_paths(self):
        self.assertIsNone(hash_shapes(placed('<path d="M0 0L1 1"/>')))

    def test_circle_radius_changes_the_hash(self):
        self.assertNotEqual(hash_shapes(placed('<circle r="0.5"/>')),
                            hash_shapes(placed('<circle r="0.6"/>')))

    def test_polygon_points_change_the_hash(self):
        self.assertNotEqual(hash_shapes(placed('<polygon points="0 0 2 0 2 1"/>')),
                            hash_shapes(placed('<polygon points="0 0 2 0 2 1.5"/>')))

    def test_text_string_changes_the_hash(self):
        self.assertNotEqual(hash_shapes(placed('<text><tspan>4</tspan></text>')),
                            hash_shapes(placed('<text><tspan>5</tspan></text>')))

    def test_a_ring_beside_a_path_is_seen(self):
        path = '<path d="M0 0L1 1"/>'
        ring = '<circle cx="0" cy="0" r="0.7" fill="none"/>'
        self.assertIsNotNone(hash_shapes(placed(path + ring)))

    def test_number_formatting_does_not_change_the_hash(self):
        self.assertEqual(hash_shapes(placed('<polygon points="0 0 2.0000 -0.0000"/>')),
                         hash_shapes(placed('<polygon points="0 0 2 0"/>')))

    def test_position_does_not_change_the_hash(self):
        self.assertEqual(
            hash_shapes(ET.fromstring('<g><g transform="translate(1, 1)"><circle r="1"/></g></g>')),
            hash_shapes(ET.fromstring('<g><g transform="translate(9, 4)"><circle r="1"/></g></g>')))


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
