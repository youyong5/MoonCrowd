#!/usr/bin/env python3
"""Regression checks for numeric portability without accepting corrupt fixtures."""
import copy
import json
import unittest
from generate_oracle import ROOT, compare_reference


class ReferenceVerificationTests(unittest.TestCase):
    def setUp(self):
        self.fresh = json.loads((ROOT / 'tests/fixtures/rvo2.json').read_text())
        self.saved = copy.deepcopy(self.fresh)

    def test_small_compiler_drift_is_bounded(self):
        self.saved['expected']['0']['0'][0][0] += 5e-6
        count, maximum = compare_reference(self.saved, self.fresh)
        self.assertEqual(count, 9216)
        self.assertLessEqual(maximum, 1e-5)

    def test_excess_drift_is_rejected(self):
        self.saved['expected']['0']['0'][0][0] += 2e-5
        with self.assertRaises(ValueError):
            compare_reference(self.saved, self.fresh)

    def test_nonfinite_values_are_rejected(self):
        for value in (float('nan'), float('inf'), '0', True):
            with self.subTest(value=value):
                self.saved['expected']['0']['0'][0][0] = value
                with self.assertRaises(ValueError):
                    compare_reference(self.saved, self.fresh)

    def test_missing_component_is_rejected(self):
        self.saved['expected']['0']['0'][0].pop()
        with self.assertRaises(ValueError):
            compare_reference(self.saved, self.fresh)

    def test_scenario_and_tolerance_changes_are_rejected(self):
        for key, value in (('tolerance', 0.01), ('generator_seed', 1)):
            with self.subTest(key=key):
                changed = copy.deepcopy(self.saved)
                changed[key] = value
                with self.assertRaises(ValueError):
                    compare_reference(changed, self.fresh)
        self.saved['cases'][0]['agents'][0]['position'][0] += 1e-10
        with self.assertRaises(ValueError):
            compare_reference(self.saved, self.fresh)


if __name__ == '__main__':
    unittest.main()
