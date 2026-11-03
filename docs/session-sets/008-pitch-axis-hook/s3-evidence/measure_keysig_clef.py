#!/usr/bin/env python3
"""measure_keysig_clef.py -- set 008 session 3 acceptance measurement.

Measures keysig-clef-axis.svg (two scores, two hook anchors, one page):

  System 0 (score 1, axis anchor -4):
    - key-signature marks (G major, tonic-octave 0 -> semitones
      {7 9 11 12 14 16 18 19}) at hook positions {0..7}
    - custom clef (fractional anchor 7.5) top edge at position 0.5
      (interpolated between hook(7)=0 and hook(8)=1)
    - notes c' g' c'' g' at positions {-4, 0, 3, 0}
  System 1 (score 2, axis anchor -3): everything +1.

The differential (+1.000 between systems) is artifact-free evidence that
the keysig stencil cache invalidated on hook change (the hook joined the
cache key this session) and that the clef's engraver-applied Y-offset
re-anchors the (correctly) hook-independent cached clef stencil.

Positions are derived per system from the harvested staff-line extremes:
top line = +8, bottom line = -3 (the compact staff '(-3 -1 1 4 6 8)).

NOTE: this script assigns tagged SVG elements to systems by absolute-y
proximity itself, because the two SCORES both number their measure 1,
giving duplicate element ids (ks-1, cl-1, nh-1-...) across systems --
the harvester's id-keyed system map is clobbered by the duplicates (it
was built for single-score multi-line pages). Only the harvested
`systems` staff geometry (id-independent) is consumed.

Exit 0 iff every check passes.
"""

import json
import math
import os
import sys
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools"))

import harvest_svg  # noqa: E402

SVG = os.path.join(HERE, "keysig-clef-axis.svg")
HARVESTED = os.path.join(HERE, "keysig-clef-axis.harvested.json")

TOP_POS, BOTTOM_POS = 8, -3  # staff '(-3 -1 1 4 6 8)

PC_AXIS = [0, 0, 1, 2, 2, 3, 3, 4, 5, 5, 6, 6]
STRIDE = 7

KEYSIG_SEMIS = [7, 9, 11, 12, 14, 16, 18, 19]  # G maj, tonic-octave 0
NOTE_SEMIS = [0, 7, 12, 7]                     # c' g' c'' g'
CLEF_ANCHOR = 7.5

ABS_TOL_KS = 0.15    # bbox-center measurement of keysig marks
ABS_TOL_CLEF = 0.05  # exact rectangle top edge
ABS_TOL_NH = 0.05    # notehead representative positions
DIFF_TOL = 0.02      # system-1 minus system-0 differential

failures = []


def check(label, measured, expected, tol):
    delta = measured - expected
    ok = abs(delta) <= tol
    if not ok:
        failures.append(label)
    print(f"  {'PASS' if ok else 'FAIL'}: {label}: measured {measured:+.3f} "
          f"expected {expected:+.3f} (delta {delta:+.3f}, tol {tol})")
    return measured


def axis_pos(semi, anchor):
    pc = semi % 12
    octv = (semi - pc) // 12
    return PC_AXIS[pc] + octv * STRIDE + anchor


def interp_anchor_pos(anchor_semi, hook_anchor):
    lo = math.floor(anchor_semi)
    frac = anchor_semi - lo
    plo = axis_pos(lo, hook_anchor)
    phi = axis_pos(lo + 1, hook_anchor)
    return plo + frac * (phi - plo)


def y_to_pos(y, geom):
    span = TOP_POS - BOTTOM_POS
    return TOP_POS - (y - geom["top_line_y"]) / geom["staff_height"] * span


def cluster_centers(values, tol):
    """Cluster 1-D values; return sorted cluster means."""
    clusters = []
    for v in sorted(values):
        if clusters and v - clusters[-1][-1] <= tol:
            clusters[-1].append(v)
        else:
            clusters.append([v])
    return [sum(c) / len(c) for c in clusters]


def nearest_system(abs_y, geoms):
    return min(geoms, key=lambda s: abs(abs_y - geoms[s]["center_y"]))


def keysig_mark_positions(ks_el, geom):
    """Per-mark positions inside one ks- element: path bbox y-centers,
    clustered (each mark is drawn twice; a mark may be multiple paths)."""
    centers = []
    for _ax, _ay, prim, tf in harvest_svg.find_drawing_positions(ks_el):
        if harvest_svg.get_tag_local(prim) != "path":
            continue
        bb = harvest_svg._bbox_from_path_local(prim.get("d", ""))
        if not bb:
            continue
        sx, sy, tx, ty = tf
        y_c = sy * (bb["min_y"] + bb["max_y"]) / 2 + ty
        centers.append(y_to_pos(y_c, geom))
    # cluster within 0.4 position units (adjacent marks are 1 apart)
    return cluster_centers(centers, 0.4)


def main():
    with open(HARVESTED, encoding="utf-8") as f:
        h = json.load(f)

    assert h["num_systems"] == 2, f"expected 2 systems, got {h['num_systems']}"
    geoms = {s["system"]: s for s in h["systems"]}

    root = ET.parse(SVG).getroot()

    # Collect tagged elements straight from the SVG; assign to systems by
    # the y of their own drawing primitives (ids duplicate across scores).
    by_sys = {0: {"ks": [], "cl": [], "nh": []},
              1: {"ks": [], "cl": [], "nh": []}}
    for el in root.iter():
        el_id = el.get("id", "")
        kind = el_id.split("-", 1)[0] if el_id else ""
        if kind not in ("ks", "cl", "nh"):
            continue
        ax, ay = harvest_svg.get_representative_position(el)
        sysi = nearest_system(ay, geoms)
        by_sys[sysi][kind].append((el_id, ax, ay, el))

    results = {}
    for sysi, anchor in ((0, -4), (1, -3)):
        geom = geoms[sysi]
        print(f"\n=== System {sysi} (score {sysi+1}, axis anchor {anchor}) ===")
        res = {}

        # --- key signature marks ---
        ks_els = by_sys[sysi]["ks"]
        assert len(ks_els) == 1, \
            f"system {sysi}: expected 1 ks element, got {len(ks_els)}"
        marks = keysig_mark_positions(ks_els[0][3], geom)
        expected_marks = [axis_pos(s, anchor) for s in KEYSIG_SEMIS]
        print(f"  keysig marks found: {len(marks)} "
              f"(expected {len(expected_marks)})")
        if len(marks) != len(expected_marks):
            failures.append(f"system {sysi}: keysig mark count "
                            f"{len(marks)} != {len(expected_marks)}")
        res["marks"] = []
        for semi, exp, meas in zip(KEYSIG_SEMIS, expected_marks,
                                   sorted(marks)):
            res["marks"].append(check(
                f"sys{sysi} keysig mark semi {semi} at position {exp}",
                meas, exp, ABS_TOL_KS))

        # --- clef top edge ---
        cl_els = by_sys[sysi]["cl"]
        assert len(cl_els) == 1, \
            f"system {sysi}: expected 1 cl element, got {len(cl_els)}"
        bb = harvest_svg.compute_bbox_deep(cl_els[0][3])
        top_pos = y_to_pos(bb["y"], geom)  # bbox y = min y = top edge
        exp_clef = interp_anchor_pos(CLEF_ANCHOR, anchor)
        res["clef"] = check(
            f"sys{sysi} clef top edge (fractional anchor {CLEF_ANCHOR})",
            top_pos, exp_clef, ABS_TOL_CLEF)

        # --- noteheads ---
        nh_els = sorted(by_sys[sysi]["nh"], key=lambda e: e[1])
        assert len(nh_els) == len(NOTE_SEMIS), \
            (f"system {sysi}: expected {len(NOTE_SEMIS)} noteheads, "
             f"got {len(nh_els)}")
        res["notes"] = []
        for (el_id, _ax, ay, _el), semi in zip(nh_els, NOTE_SEMIS):
            pos = y_to_pos(ay, geom)
            res["notes"].append(check(
                f"sys{sysi} note semi {semi} ({el_id})",
                pos, axis_pos(semi, anchor), ABS_TOL_NH))

        results[sysi] = res

    # --- differential: everything must shift exactly +1 (cache proof) ---
    print("\n=== Differential system1 - system0 (must be +1.000) ===")
    for i in range(len(KEYSIG_SEMIS)):
        check(f"keysig mark {i} shift",
              results[1]["marks"][i] - results[0]["marks"][i], 1.0, DIFF_TOL)
    check("clef top edge shift", results[1]["clef"] - results[0]["clef"],
          1.0, DIFF_TOL)
    for i in range(len(NOTE_SEMIS)):
        check(f"note {i} shift",
              results[1]["notes"][i] - results[0]["notes"][i], 1.0, DIFF_TOL)

    print(f"\n{'=' * 60}")
    if failures:
        print(f"RESULT: FAIL ({len(failures)} failed checks)")
        for f_ in failures:
            print(f"  - {f_}")
        return 1
    print("RESULT: PASS (all keysig marks, clef anchors, noteheads, "
          "and +1 differentials exact)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
