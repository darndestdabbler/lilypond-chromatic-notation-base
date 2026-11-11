"""Tests for run_unit.py's results parsing (no LilyPond needed)."""

import unittest

from run_unit import parse_results


class ParseResultsTest(unittest.TestCase):

    def test_passing_line(self):
        log = "====\n  TEST RESULTS: 303 passed, 0 failed\n====\n"
        self.assertEqual(parse_results(log), (303, 0))

    def test_failing_line(self):
        log = "  TEST RESULTS: 300 passed, 3 failed\nwarning: 3 TEST(S) FAILED!\n"
        self.assertEqual(parse_results(log), (300, 3))

    def test_missing_line(self):
        self.assertIsNone(parse_results("Processing `test-unit.ly'\n"))


if __name__ == "__main__":
    unittest.main()
