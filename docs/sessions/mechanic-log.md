# Mechanic log

## 2026-11-04 -- session 17 (stems attached at the notehead centre)

**The stop.** Phase `verify`, kind `verification`, code
`provider-unreachable`: the rendered `session-verification` prompt was
1,898,445 chars (~474,611 tokens) against an input budget of 217,600
tokens, so the reviewer call never ran. All three steps had finished.

**Diagnosis.** Most of the diff was order-only churn. The session's
`\override Stem.layer = #1000` in `cnb/layout.ly` draws stems after
noteheads, so every rendered SVG lists its elements in a new order. The 14
tracked `tests/*.svg` legitimately change with that (~0.43M chars). The 28
tracked harvest baselines (`tests/*.harvested.json` and
`tests/lilypond-2.26/*.harvested.json`) also changed (~1.22M chars), but
only in element order: content and every non-element field matched HEAD,
and both suites reported 0 harvests drifted. The cause was
`save_harvest` in `tools/run_tests.py`: it rewrote a tracked baseline
whenever the regenerated harvest had no differences, and
`harvest_differences` ignores element order, so a reordered-but-equal
harvest was written over the tracked one.

**What changed.**

- `tools/run_tests.py` `save_harvest`: a tracked baseline is now never
  rewritten unless `update_baselines` is set. With no differences it is
  left untouched; on drift it is left untouched and the differences are
  returned (unchanged); with no baseline yet it is written (unchanged).
  Docstring updated to say so.
- `tools/test_run_tests.py` `SaveHarvestTest`: new
  `test_reordered_equal_harvest_leaves_baseline_byte_identical` proves an
  equal harvest with its elements reversed returns `[]` and leaves the
  baseline file byte-for-byte unchanged. The existing no-baseline, identical,
  drift and update-baselines tests are kept as they were.
- The 28 existing harvest baselines restored to HEAD. The two new,
  untracked baselines `tests/stem-centre.harvested.json` and
  `tests/lilypond-2.26/stem-centre.harvested.json` are untouched.

No gate, test, verdict, `cnb/layout.ly`, spec, README or SVG was changed.

**Evidence.** `python -m unittest discover -s tools -p "test_*.py"`: 70
tests OK. `tools/run_tests.py --lilypond-version 2.24` and `--lilypond-version
2.26`: each 311 passed, 0 failed, 0 harvests drifted, and afterwards none of
the 28 baselines shows as modified.

**Why this fix.** The baseline rewrite was a defect (a harvest that matches
its baseline should not touch it), and removing it takes the order-only
churn out of the session's diff so the review prompt fits. The operator
chose this fix over raising the verify evidence cap or rerouting the
reviewer to a model with a larger window.
