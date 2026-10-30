#!/usr/bin/env python3
"""
debug_normalize.py — Diagnostic dump for normalize_svg system detection.

Run on a LilyPond SVG (with test-ids) to see exactly what Phase 1
produces and why Phase 2's system detection succeeds or fails.

USAGE:
    python3 debug_normalize.py JoyToTheWorld-Kite-4-369-Clean.svg

Produces a detailed report showing:
  - Tree structure after Phase 1 collapse
  - All tagged elements with local vs absolute y
  - Measure y-values and system break detection
  - Staff element details
"""

import sys
import os
import xml.etree.ElementTree as ET

# Import from normalize_svg (same directory)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from normalize_svg import (
    collapse_nesting, parse_transform, compose_transforms,
    SVG_NS, XLINK_NS, G_TAG, DEFS_TAG,
)


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 debug_normalize.py <input.svg>")
        sys.exit(1)

    svg_path = sys.argv[1]
    tree = ET.parse(svg_path)
    root = tree.getroot()

    print("=" * 70)
    print(f"  DEBUG NORMALIZE: {os.path.basename(svg_path)}")
    print("=" * 70)

    # --- Count elements before Phase 1 ---
    total_before = sum(1 for _ in root.iter())
    print(f"\nBefore Phase 1: {total_before} total elements")

    # --- Run Phase 1 ---
    result = collapse_nesting(root)
    total_after = sum(1 for _ in root.iter())
    print(f"After Phase 1:  {total_after} total elements")
    if isinstance(result, tuple):
        print(f"  Collapsed <g>: {result[0]}, Stripped <a>: {result[1]}")
    else:
        print(f"  Result: {result}")

    # =====================================================================
    #  SECTION 1: Tree structure after Phase 1
    # =====================================================================
    print("\n" + "=" * 70)
    print("  SECTION 1: Tree structure after Phase 1 (depth <= 3)")
    print("=" * 70)

    def show_tree(elem, depth=0, max_depth=3, parent_path=""):
        if depth > max_depth:
            return
        tag = elem.tag.split("}")[-1] if "}" in elem.tag else elem.tag
        el_id = elem.get("id", "")
        dtype = elem.get("data-type", "")
        tf = elem.get("transform", "")
        n_children = len(list(elem))

        indent = "  " * depth
        label = f"<{tag}"
        if el_id:
            label += f' id="{el_id}"'
        if dtype:
            label += f' data-type="{dtype}"'
        if tf:
            label += f' transform="{tf}"'
        label += f">  ({n_children} children)"

        print(f"{indent}{label}")

        for child in elem:
            show_tree(child, depth + 1, max_depth)

    show_tree(root)

    # =====================================================================
    #  SECTION 2: All tagged elements — local and absolute y
    # =====================================================================
    print("\n" + "=" * 70)
    print("  SECTION 2: Tagged elements — local vs absolute y")
    print("=" * 70)

    # Build parent map
    parent_map = {}
    for p in root.iter():
        for child in p:
            parent_map[child] = p

    def absolute_transform(elem):
        """Compute absolute transform by composing ancestor chain."""
        tf = (1.0, 1.0, 0.0, 0.0)
        ancestors = []
        node = elem
        while node is not None and node is not root:
            ancestors.append(node)
            node = parent_map.get(node)
        ancestors.reverse()
        for anc in ancestors:
            anc_tf = parse_transform(anc.get("transform", ""))
            tf = compose_transforms(tf, anc_tf)
        return tf

    # Find tagged elements
    tagged = []
    staff_elements = []

    for parent in root.iter():
        for child in parent:
            el_id = child.get("id", "")
            if not el_id:
                continue
            dtype = child.get("data-type", "")
            if dtype == "staff-symbol":
                staff_elements.append((parent, child))
                continue
            measure = child.get("data-measure", "")
            if not measure and not dtype:
                continue
            tagged.append((parent, child))

    print(f"\nFound {len(tagged)} tagged elements, "
          f"{len(staff_elements)} staff-symbol(s)")

    # Show staff element details
    for i, (sp, se) in enumerate(staff_elements):
        sp_tag = sp.tag.split("}")[-1]
        sp_tf = sp.get("transform", "none")
        se_tf = se.get("transform", "none")
        abs_tf = absolute_transform(se)
        n_lines = sum(1 for ch in se
                      if ch.tag.split("}")[-1] == "line")
        print(f"\n  Staff-symbol #{i}:")
        print(f"    Parent: <{sp_tag} transform=\"{sp_tf}\">")
        print(f"    Element transform: \"{se_tf}\"")
        print(f"    Absolute transform: sx={abs_tf[0]:.4f} sy={abs_tf[1]:.4f} "
              f"tx={abs_tf[2]:.4f} ty={abs_tf[3]:.4f}")
        print(f"    Line children: {n_lines}")

        # Show ancestor chain
        chain = []
        node = se
        while node is not None and node is not root:
            ntag = node.tag.split("}")[-1]
            ntf = node.get("transform", "")
            nid = node.get("id", "")
            chain.append(f"<{ntag} id=\"{nid}\" tf=\"{ntf}\">")
            node = parent_map.get(node)
        chain.reverse()
        print(f"    Ancestor chain: {' > '.join(chain)}")

    # Show tagged elements grouped by parent
    from collections import defaultdict, Counter
    by_parent = defaultdict(list)
    for parent, elem in tagged:
        by_parent[id(parent)].append((parent, elem))

    print(f"\n  Tagged elements come from {len(by_parent)} distinct parent(s):")
    for pid, items in by_parent.items():
        parent = items[0][0]
        p_tag = parent.tag.split("}")[-1]
        p_tf = parent.get("transform", "none")
        p_id = parent.get("id", "")
        abs_tf = absolute_transform(parent)
        print(f"\n  Parent: <{p_tag} id=\"{p_id}\" transform=\"{p_tf}\">")
        print(f"    Parent absolute tf: sx={abs_tf[0]:.4f} sy={abs_tf[1]:.4f} "
              f"tx={abs_tf[2]:.4f} ty={abs_tf[3]:.4f}")
        print(f"    Contains {len(items)} tagged elements")

        # Show first few elements
        for _, elem in items[:5]:
            el_id = elem.get("id", "")
            dtype = elem.get("data-type", "")
            measure = elem.get("data-measure", "")
            local_tf = parse_transform(elem.get("transform", ""))
            abs_elem_tf = absolute_transform(elem)
            print(f"      {el_id:40s}  m={measure:>3s}  "
                  f"local_ty={local_tf[3]:>10.3f}  "
                  f"abs_ty={abs_elem_tf[3]:>10.3f}")
        if len(items) > 5:
            print(f"      ... and {len(items) - 5} more")

    # =====================================================================
    #  SECTION 3: Measure y-values and system detection
    # =====================================================================
    print("\n" + "=" * 70)
    print("  SECTION 3: Measure median y-values and system breaks")
    print("=" * 70)

    # Group by measure
    by_measure = defaultdict(list)
    for _, elem in tagged:
        m = elem.get("data-measure", "")
        dtype = elem.get("data-type", "")
        # Barline grouping: bl-N -> measure N-1
        if dtype == "barline" and m:
            try:
                mi = int(m)
                m = str(mi - 1) if mi > 1 else m
            except ValueError:
                pass
        if m:
            abs_y = absolute_transform(elem)[3]
            by_measure[m].append((elem, abs_y))

    sorted_measures = sorted(by_measure.keys(),
                             key=lambda x: (int(x) if x.isdigit() else 0, x))

    measure_median_y = {}
    for m_num in sorted_measures:
        ys = [y for _, y in by_measure[m_num]]
        ys.sort()
        median = ys[len(ys) // 2]
        measure_median_y[m_num] = median

    print(f"\n  {'Measure':>8s}  {'#Elems':>6s}  {'Min Y':>10s}  "
          f"{'Median Y':>10s}  {'Max Y':>10s}  {'Δ from prev':>12s}  Break?")
    print("  " + "-" * 75)

    prev_y = None
    for m_num in sorted_measures:
        ys = sorted([y for _, y in by_measure[m_num]])
        median = measure_median_y[m_num]
        delta = ""
        is_break = ""
        if prev_y is not None:
            d = median - prev_y
            delta = f"{d:+.3f}"
            if d > 50:
                is_break = " *** SYSTEM BREAK ***"
        print(f"  {m_num:>8s}  {len(ys):>6d}  {ys[0]:>10.3f}  "
              f"{median:>10.3f}  {ys[-1]:>10.3f}  {delta:>12s}{is_break}")
        prev_y = median

    # Count systems
    system_starts = [sorted_measures[0]] if sorted_measures else []
    for i in range(1, len(sorted_measures)):
        prev = measure_median_y.get(sorted_measures[i - 1], 0)
        curr = measure_median_y.get(sorted_measures[i], 0)
        if curr - prev > 50:
            system_starts.append(sorted_measures[i])

    print(f"\n  Systems detected: {len(system_starts)}")
    print(f"  System starts: {system_starts}")

    # =====================================================================
    #  SECTION 4: Raw element y-values (first 3 per measure)
    # =====================================================================
    print("\n" + "=" * 70)
    print("  SECTION 4: Individual element y-values (first 3 per measure)")
    print("=" * 70)

    for m_num in sorted_measures:
        items = by_measure[m_num]
        print(f"\n  Measure {m_num} ({len(items)} elements):")
        for elem, abs_y in items[:3]:
            el_id = elem.get("id", "")
            local_tf = parse_transform(elem.get("transform", ""))
            parent = parent_map.get(elem)
            p_tf = parent.get("transform", "none") if parent is not None else "root"
            print(f"    {el_id:40s}  local_ty={local_tf[3]:>10.3f}  "
                  f"abs_y={abs_y:>10.3f}  parent_tf=\"{p_tf}\"")
        if len(items) > 3:
            print(f"    ... ({len(items) - 3} more)")

    print("\n" + "=" * 70)
    print("  DONE")
    print("=" * 70)


if __name__ == "__main__":
    main()
