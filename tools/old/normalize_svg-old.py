#!/usr/bin/env python3
"""
normalize_svg.py — Normalize LilyPond SVG output for readability.

Takes the raw SVG produced by LilyPond (deeply nested <g> elements,
redundant wrappers, no logical grouping) and produces a clean,
human-navigable SVG with:

  Phase 1 — Collapse:   Strip empty <a> wrappers, merge single-child
                         <g> chains all the way down to drawing primitives,
                         compose transforms, push attrs to the leaf element.
  Phase 2 — Group:      Wrap tagged elements in <g id="measure-N">
                         containers. Barlines are grouped with the measure
                         they END (not the one they start). Staff symbols
                         moved to <defs> with <use> per system.
  Phase 3 — Deduplicate: Move repeated <path> shapes into <defs>,
                         replace with <use> references.

USAGE:
    python3 tools/normalize_svg.py input.svg -o normalized.svg
    python3 tools/normalize_svg.py input.svg --stats --indent
    python3 tools/normalize_svg.py input.svg --phase 1

NOTES:
    - The harvester (harvest_svg.py) works on BOTH raw and normalized SVG.
    - Transforms are composed into a single translate/scale string.
    - Measure grouping uses data-measure attributes from test-ids.ly.
"""

import sys
import os
import re
import hashlib
import argparse
from collections import defaultdict
import xml.etree.ElementTree as ET

# =========================================================================
#  SVG NAMESPACE HANDLING
# =========================================================================

SVG_NS = "http://www.w3.org/2000/svg"
XLINK_NS = "http://www.w3.org/1999/xlink"
ET.register_namespace("", SVG_NS)
ET.register_namespace("xlink", XLINK_NS)

DRAWING_TAGS = {
    f"{{{SVG_NS}}}{t}" for t in
    ("path", "rect", "line", "circle", "ellipse", "polygon", "text",
     "polyline", "image", "use")
}

G_TAG = f"{{{SVG_NS}}}g"
A_TAG = f"{{{SVG_NS}}}a"
DEFS_TAG = f"{{{SVG_NS}}}defs"
USE_TAG = f"{{{SVG_NS}}}use"
PATH_TAG = f"{{{SVG_NS}}}path"


def local_tag(element):
    """Strip namespace from element tag."""
    tag = element.tag
    return tag.split("}", 1)[1] if "}" in tag else tag


# =========================================================================
#  TRANSFORM UTILITIES
# =========================================================================

def parse_transform(transform_str):
    """Parse SVG transform -> (sx, sy, tx, ty)."""
    if not transform_str:
        return (1.0, 1.0, 0.0, 0.0)

    sx, sy, tx, ty = 1.0, 1.0, 0.0, 0.0
    for m in re.finditer(r'(translate|scale)\(\s*([^)]+)\)', transform_str):
        kind = m.group(1)
        args = [float(x.strip()) for x in re.split(r'[\s,]+', m.group(2).strip()) if x.strip()]
        if kind == 'translate':
            dx = args[0] if len(args) >= 1 else 0.0
            dy = args[1] if len(args) >= 2 else 0.0
            tx += sx * dx
            ty += sy * dy
        elif kind == 'scale':
            scx = args[0] if len(args) >= 1 else 1.0
            scy = args[1] if len(args) >= 2 else scx
            sx *= scx
            sy *= scy
    return (sx, sy, tx, ty)


def compose_transforms(outer, inner):
    """Compose two affine transforms."""
    o_sx, o_sy, o_tx, o_ty = outer
    i_sx, i_sy, i_tx, i_ty = inner
    return (o_sx * i_sx, o_sy * i_sy,
            o_sx * i_tx + o_tx, o_sy * i_ty + o_ty)


def format_transform(tf):
    """Format (sx, sy, tx, ty) as a compact SVG transform string."""
    sx, sy, tx, ty = tf
    has_scale = abs(sx - 1.0) > 1e-6 or abs(sy - 1.0) > 1e-6
    has_translate = abs(tx) > 1e-6 or abs(ty) > 1e-6

    if not has_scale and not has_translate:
        return ""

    parts = []
    if has_translate:
        parts.append(f"translate({_fmt(tx)}, {_fmt(ty)})")
    if has_scale:
        sx_s, sy_s = _fmt(sx), _fmt(sy)
        parts.append(f"scale({sx_s})" if sx_s == sy_s else f"scale({sx_s}, {sy_s})")

    return " ".join(parts)


def _fmt(v):
    """Format a float cleanly."""
    if abs(v) < 1e-6:
        return "0"
    s = f"{v:.4f}".rstrip("0").rstrip(".")
    return s


# =========================================================================
#  ATTRIBUTE HELPERS
# =========================================================================

_VISUAL_ATTRS = {"color", "fill", "stroke", "opacity", "font-size",
                 "font-family", "font-style", "font-weight",
                 "stroke-width"}

_IDENTITY_PREFIXES = ("id", "data-", "class")


def _is_identity_attr(name):
    return any(name == p or name.startswith(p) for p in _IDENTITY_PREFIXES)


def _is_empty_a(element):
    """Is this an <a> wrapper with no meaningful href?"""
    if element.tag != A_TAG:
        return False
    href = element.get(f"{{{XLINK_NS}}}href", "")
    return href == "" or href.startswith("textedit://")


# =========================================================================
#  PHASE 1: COLLAPSE NESTING — FULLY FLAT
# =========================================================================

def collapse_nesting(root):
    """Phase 1: Aggressively flatten the SVG tree.

    1. Strip all empty <a> wrappers (LilyPond source-link artifacts).
    2. Collapse every single-child <g> chain, INCLUDING those wrapping
       drawing primitives. Transforms composed; id, data-*, color, fill
       pushed down to the leaf element.

    After this phase, <g> only exists where it groups MULTIPLE children.

    Returns (g_removed, a_removed) counts.
    """
    g_removed = 0
    a_removed = 0

    changed = True
    while changed:
        changed = False

        # Pass 1: Strip one empty <a> wrapper per iteration
        for parent in list(root.iter()):
            found = False
            for child in list(parent):
                if not _is_empty_a(child):
                    continue

                a_children = list(child)
                a_tf_str = child.get("transform", "")

                if a_tf_str and a_children:
                    a_tf = parse_transform(a_tf_str)
                    first = a_children[0]
                    existing_tf = parse_transform(first.get("transform", ""))
                    composed = compose_transforms(a_tf, existing_tf)
                    tf_str = format_transform(composed)
                    if tf_str:
                        first.set("transform", tf_str)
                    else:
                        first.attrib.pop("transform", None)

                idx = list(parent).index(child)
                parent.remove(child)
                for j, ac in enumerate(a_children):
                    parent.insert(idx + j, ac)

                a_removed += 1
                changed = True
                found = True
                break
            if found:
                break

        if changed:
            continue

        # Pass 2: Collapse one single-child <g> per iteration
        for parent in list(root.iter()):
            found = False
            for i, child in enumerate(list(parent)):
                if child.tag != G_TAG:
                    continue
                children_of_g = list(child)
                if len(children_of_g) != 1:
                    continue
                if child.text and child.text.strip():
                    continue

                inner = children_of_g[0]

                # Compose transforms
                outer_tf = parse_transform(child.get("transform", ""))
                inner_tf = parse_transform(inner.get("transform", ""))
                composed = compose_transforms(outer_tf, inner_tf)

                tf_str = format_transform(composed)
                if tf_str:
                    inner.set("transform", tf_str)
                else:
                    inner.attrib.pop("transform", None)

                # Push outer's visual attrs down (don't overwrite)
                for attr in _VISUAL_ATTRS:
                    val = child.get(attr)
                    if val is not None and inner.get(attr) is None:
                        inner.set(attr, val)

                # Push outer's identity attrs down (take priority)
                for attr, val in child.attrib.items():
                    if _is_identity_attr(attr):
                        inner.set(attr, val)

                parent.remove(child)
                parent.insert(i, inner)

                g_removed += 1
                changed = True
                found = True
                break
            if found:
                break

    return (g_removed, a_removed)


# =========================================================================
#  PHASE 2: GROUP INTO MEASURE CONTAINERS
# =========================================================================

_TYPE_PRIORITY = {
    "clef": 1,
    "key-signature": 2,
    "time-signature": 3,
    "notehead": 10,
    "stem": 11,
    "beam": 12,
    "flag": 13,
    "dots": 14,
    "accidental": 15,
    "rest": 16,
    "ledger-line": 17,
    "tie": 18,
    "slur": 19,
    "barline": 90,   # Last: closing barline at end of measure
}


def _resolve_measure_for_grouping(element):
    """Determine which measure group an element belongs to.

    Barlines: data-measure is N (the measure they START), but visually
    they're the right edge of measure N-1. Group with N-1.
    Staff-symbols: handled separately (go to defs).
    """
    dtype = element.get("data-type", "")

    if dtype == "staff-symbol":
        return None

    measure = element.get("data-measure")

    if dtype == "barline" and measure is not None:
        try:
            m = int(measure)
            return str(m - 1) if m > 1 else measure
        except ValueError:
            pass

    return measure


def group_by_measure(root):
    """Phase 2: Wrap tagged elements into measure containers.

    - Barlines grouped with the measure they END (bl-N -> measure N-1).
    - Staff-symbol moved to <defs>, <use> per system inserted before
      each system's first measure group.
    - Elements sorted within each measure by type priority.

    Two-pass approach:
      Pass 1: Collect tagged elements, create staff <defs> from the one
              tagged staff-symbol, group everything into measure <g>s.
      Pass 2: Detect system breaks from measure y-positions. Insert
              a staff <use> before each system's first measure.

    Returns the number of elements grouped.
    """
    tagged = []           # (parent, element, group_measure)
    staff_element = None  # (parent, element) — only the first tagged one
    LINE_TAG = f"{{{SVG_NS}}}line"

    for parent in list(root.iter()):
        for child in list(parent):
            el_id = child.get("id", "")
            if not el_id:
                continue

            dtype = child.get("data-type", "")

            if dtype == "staff-symbol":
                if staff_element is None:
                    staff_element = (parent, child)
                # Don't remove yet — we need the parent chain intact for
                # computing absolute transforms. Removal happens below.
                continue

            group_m = _resolve_measure_for_grouping(child)
            if group_m is not None:
                tagged.append((parent, child, group_m))

    if not tagged:
        return 0

    # --- Find or create <defs> ---
    defs = root.find(DEFS_TAG)
    if defs is None:
        defs = ET.Element(DEFS_TAG)
        root.insert(0, defs)

    # --- Create staff-lines def from the tagged staff-symbol ---
    staff_def_id = None  # set if we successfully create a def

    if staff_element is not None:
        _, staff_el = staff_element
        lines = [ch for ch in staff_el if ch.tag == LINE_TAG]

        if lines:
            # Compute center y and normalize lines to y=0
            line_ys = [float(ln.get("y1", 0)) for ln in lines]
            center_y = (min(line_ys) + max(line_ys)) / 2.0
            staff_tf = parse_transform(staff_el.get("transform", ""))

            staff_def = ET.SubElement(defs, G_TAG)
            staff_def_id = "staff-lines"
            staff_def.set("id", staff_def_id)
            for attr, val in staff_el.attrib.items():
                if attr in ("id", "transform"):
                    continue
                staff_def.set(attr, val)

            for ln in sorted(lines, key=lambda l: float(l.get("y1", 0))):
                y = float(ln.get("y1", 0))
                norm_line = ET.SubElement(staff_def, LINE_TAG)
                for attr, val in ln.attrib.items():
                    if attr in ("y1", "y2"):
                        norm_line.set(attr, _fmt(y - center_y))
                    else:
                        norm_line.set(attr, val)

    # --- Compute absolute y for system break detection ---
    # Elements may be inside multi-child system wrapper <g> elements
    # that survived Phase 1 collapse. We need absolute y-coordinates
    # to detect system breaks (large downward jumps).
    parent_map = {}
    for p in root.iter():
        for child in p:
            parent_map[child] = p

    def _absolute_y(elem):
        """Compute absolute y by composing ancestor transforms."""
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
        return tf[3]

    # Pre-compute absolute ys while elements are still in the tree
    element_abs_y = {}
    for _, elem, _ in tagged:
        element_abs_y[id(elem)] = _absolute_y(elem)

    # --- Compute the staff <use> transform ---
    # The <use> references the normalized template (lines centered at y=0).
    # Its transform must position + scale lines in the system wrapper's
    # LOCAL coordinate space.
    #
    # The staff-symbol element's OWN transform (after Phase 1 collapse of
    # inner <g>s) maps local line positions to its parent's space:
    #   parent_y = staff_sy * local_y + staff_ty
    #
    # The <use> needs: (staff_sx, staff_sy, staff_tx, staff_sy*center_y + staff_ty)
    #
    # Because LilyPond uses the same internal layout for every system
    # (only the system wrapper's page-level translate differs), this
    # transform is identical for all systems.
    staff_use_tf = None
    staff_parent_abs_tf = None  # for adjusting when sys_parent != staff_parent
    if staff_element is not None and staff_def_id is not None:
        _, staff_el = staff_element
        staff_el_tf = parse_transform(staff_el.get("transform", ""))
        s_sx, s_sy, s_tx, s_ty = staff_el_tf
        staff_local_center_y = s_sy * center_y + s_ty
        staff_use_tf = (s_sx, s_sy, s_tx, staff_local_center_y)

        # Compute the staff element's parent's absolute transform.
        # staff_use_tf is correct when placed in this parent.
        staff_parent = staff_element[0]  # (parent, child) tuple
        sp_abs_tf = (1.0, 1.0, 0.0, 0.0)
        node = staff_parent
        sp_ancestors = []
        while node is not None and node is not root:
            sp_ancestors.append(node)
            node = parent_map.get(node)
        sp_ancestors.reverse()
        for anc in sp_ancestors:
            anc_tf = parse_transform(anc.get("transform", ""))
            sp_abs_tf = compose_transforms(sp_abs_tf, anc_tf)
        staff_parent_abs_tf = sp_abs_tf

    # Now remove the staff-symbol from the tree (deferred from above)
    if staff_element is not None:
        s_parent, s_el = staff_element
        try:
            s_parent.remove(s_el)
        except ValueError:
            pass

    # --- Remove tagged elements from parents ---
    # Track each element's original parent for reinsertion.
    element_parent = {}
    for parent, elem, _ in tagged:
        element_parent[id(elem)] = parent
        try:
            parent.remove(elem)
        except ValueError:
            pass

    # --- Group by measure ---
    by_measure = defaultdict(list)
    for _, elem, group_m in tagged:
        by_measure[group_m].append(elem)

    sorted_measures = sorted(by_measure.keys(),
                             key=lambda m: (int(m) if m.isdigit() else 0, m))

    measure_median_y = {}
    for m_num in sorted_measures:
        ys = [element_abs_y.get(id(el), 0) for el in by_measure[m_num]]
        if ys:
            measure_median_y[m_num] = sorted(ys)[len(ys) // 2]

    # --- Detect system breaks from absolute y-positions ---
    system_starts = [sorted_measures[0]] if sorted_measures else []

    for i in range(1, len(sorted_measures)):
        prev_y = measure_median_y.get(sorted_measures[i - 1], 0)
        curr_y = measure_median_y.get(sorted_measures[i], 0)
        if curr_y - prev_y > 50:
            system_starts.append(sorted_measures[i])

    system_start_set = set(system_starts)

    # --- Determine each measure's system parent ---
    # Each measure's elements came from a specific parent (system wrapper).
    # Use the most common parent among the measure's elements.
    def _measure_parent(m_num):
        from collections import Counter
        parents = [element_parent.get(id(el)) for el in by_measure[m_num]]
        parents = [p for p in parents if p is not None]
        if not parents:
            return root
        return Counter(parents).most_common(1)[0][0]

    # --- Build measure groups per system ---
    grouped = 0
    sys_idx = 0
    num_systems = len(system_starts)

    for m_num in sorted_measures:
        sys_parent = _measure_parent(m_num)

        # Insert staff <use> before the first measure of each system
        if m_num in system_start_set and staff_def_id is not None:
            if staff_use_tf is not None:
                # Determine if we need to adjust the transform.
                # staff_use_tf is correct for the staff element's parent.
                # If sys_parent is different (e.g., wrapper collapsed),
                # convert absolute staff center to sys_parent's local space.
                use_tf = staff_use_tf  # default: same parent type
                if (staff_parent_abs_tf is not None
                        and sys_parent is not staff_element[0]):
                    # Compute sys_parent's absolute transform
                    sp_tf = (1.0, 1.0, 0.0, 0.0)
                    node = sys_parent
                    sp_anc = []
                    while node is not None and node is not root:
                        sp_anc.append(node)
                        node = parent_map.get(node)
                    sp_anc.reverse()
                    for anc in sp_anc:
                        anc_tf = parse_transform(anc.get("transform", ""))
                        sp_tf = compose_transforms(sp_tf, anc_tf)
                    sp_sx, sp_sy, sp_tx, sp_ty = sp_tf

                    # Absolute staff center for this system.
                    # System 1: exact from staff geometry.
                    # Others: estimate from median element positions.
                    sptf = staff_parent_abs_tf
                    s_sx, s_sy, s_tx, s_ty = staff_use_tf
                    if sys_idx == 0:
                        abs_center = sptf[1] * s_ty + sptf[3]
                    else:
                        abs_center = measure_median_y.get(m_num, 0)

                    # Convert to sys_parent's local space
                    local_ty = ((abs_center - sp_ty) / sp_sy
                                if abs(sp_sy) > 1e-9 else abs_center)
                    local_tx = ((sptf[0] * s_tx + sptf[2] - sp_tx) / sp_sx
                                if abs(sp_sx) > 1e-9
                                else sptf[0] * s_tx + sptf[2])
                    local_sy = (sptf[1] * s_sy / sp_sy
                                if abs(sp_sy) > 1e-9 else s_sy)
                    local_sx = (sptf[0] * s_sx / sp_sx
                                if abs(sp_sx) > 1e-9 else s_sx)
                    use_tf = (local_sx, local_sy, local_tx, local_ty)

                use = ET.Element(USE_TAG)
                use.set(f"{{{XLINK_NS}}}href", f"#{staff_def_id}")
                use.set("id", f"staff-symbol-{sys_idx}" if num_systems > 1
                         else "staff-symbol")
                use.set("data-type", "staff-symbol")
                use.set("transform", format_transform(use_tf))
                sys_parent.append(use)

            sys_idx += 1

        # Create the measure group in this system's parent
        elements = by_measure[m_num]

        m_group = ET.SubElement(sys_parent, G_TAG)
        m_group.set("id", f"measure-{m_num}")
        m_group.set("data-measure", m_num)

        elements.sort(key=lambda el: (
            _TYPE_PRIORITY.get(el.get("data-type", ""), 50),
            el.get("id", ""),
        ))

        for elem in elements:
            m_group.append(elem)
            grouped += 1

    return grouped, system_starts


# =========================================================================
#  PHASE 3: DEDUPLICATE PATHS INTO <defs>/<use>
# =========================================================================

def _hash_path_d(d):
    """Hash a path d-attribute for shape identity."""
    if not d:
        return None
    normalized = re.sub(r'\s+', ' ', d.strip())
    return hashlib.sha256(normalized.encode()).hexdigest()[:16]


def deduplicate_paths(root):
    """Phase 3: Move repeated <path> shapes into <defs>, replace with <use>.

    Only deduplicates paths used 2+ times. Returns (defs_created, uses_created).
    """
    defs = root.find(DEFS_TAG)
    if defs is None:
        defs = ET.Element(DEFS_TAG)
        root.insert(0, defs)

    defs_el_ids = set(id(el) for el in defs.iter())

    all_paths = []
    for parent in list(root.iter()):
        if id(parent) in defs_el_ids:
            continue
        for child in list(parent):
            if child.tag == PATH_TAG and id(child) not in defs_el_ids:
                d = child.get("d", "")
                if d:
                    all_paths.append((parent, child, d))

    by_hash = defaultdict(list)
    for parent, path_el, d in all_paths:
        by_hash[_hash_path_d(d)].append((parent, path_el, d))

    defs_created = 0
    uses_created = 0

    for h, group in by_hash.items():
        if len(group) < 2:
            continue

        _, first_path, canonical_d = group[0]
        def_id = f"shape-{h}"

        def_path = ET.SubElement(defs, PATH_TAG)
        def_path.set("id", def_id)
        def_path.set("d", canonical_d)

        for attr in ("fill", "stroke", "stroke-width"):
            val = first_path.get(attr)
            if val is not None and all(p.get(attr) == val for _, p, _ in group):
                def_path.set(attr, val)

        defs_created += 1

        for parent, path_el, d in group:
            use = ET.Element(USE_TAG)
            use.set(f"{{{XLINK_NS}}}href", f"#{def_id}")

            for attr, val in path_el.attrib.items():
                if attr == "d":
                    continue
                if attr in ("fill", "stroke", "stroke-width") and def_path.get(attr) == val:
                    continue
                use.set(attr, val)

            idx = list(parent).index(path_el)
            parent.remove(path_el)
            parent.insert(idx, use)
            uses_created += 1

    return (defs_created, uses_created)


# =========================================================================
#  STATISTICS
# =========================================================================

def compute_stats(root, label=""):
    total = g_count = a_count = drawing_count = max_depth = single_child_g = 0

    def walk(el, depth):
        nonlocal total, g_count, a_count, drawing_count, max_depth, single_child_g
        total += 1
        max_depth = max(max_depth, depth)
        if el.tag == G_TAG:
            g_count += 1
            if len(list(el)) == 1:
                single_child_g += 1
        elif el.tag == A_TAG:
            a_count += 1
        if el.tag in DRAWING_TAGS:
            drawing_count += 1
        for child in el:
            walk(child, depth + 1)

    walk(root, 0)

    path_hashes = set()
    for el in root.iter():
        if el.tag == PATH_TAG:
            d = el.get("d", "")
            if d:
                path_hashes.add(_hash_path_d(d))

    return {
        "label": label, "total_elements": total, "g_elements": g_count,
        "single_child_g": single_child_g, "a_elements": a_count,
        "drawing_primitives": drawing_count, "max_depth": max_depth,
        "unique_path_shapes": len(path_hashes),
    }


def format_stats(before, after):
    lines = []
    lines.append(f"  {'Metric':<28s}  {'Before':>8s}  {'After':>8s}  {'Diff':>8s}")
    lines.append(f"  {'─'*28}  {'─'*8}  {'─'*8}  {'─'*8}")
    for key in ("total_elements", "g_elements", "single_child_g",
                "a_elements", "drawing_primitives", "max_depth",
                "unique_path_shapes"):
        b, a = before[key], after[key]
        d_str = f"{a - b:+d}" if a != b else "—"
        nice = key.replace("_", " ").title()
        lines.append(f"  {nice:<28s}  {b:>8d}  {a:>8d}  {d_str:>8s}")
    return "\n".join(lines)


# =========================================================================
#  MAIN PIPELINE
# =========================================================================

def normalize(root, phases=None):
    if phases is None:
        phases = {1, 2, 3}
    results = {}
    if 1 in phases:
        g_removed, a_removed = collapse_nesting(root)
        results["phase1"] = {"g_collapsed": g_removed, "a_stripped": a_removed}
    if 2 in phases:
        grouped, system_starts = group_by_measure(root)
        results["phase2"] = {
            "elements_grouped": grouped,
            "system_starts": system_starts,
            "num_systems": len(system_starts),
        }
    if 3 in phases:
        defs_created, uses_created = deduplicate_paths(root)
        results["phase3"] = {"defs_created": defs_created, "uses_created": uses_created}
    return results


def main():
    parser = argparse.ArgumentParser(
        description="Normalize LilyPond SVG output for readability.")
    parser.add_argument("svg_file", help="Input SVG file")
    parser.add_argument("-o", "--output", help="Output SVG file (default: stdout)")
    parser.add_argument("--phase", type=int, nargs="+",
                        help="Run only specific phases (1, 2, 3)")
    parser.add_argument("--stats", action="store_true",
                        help="Show before/after statistics")
    parser.add_argument("--indent", action="store_true",
                        help="Indent output XML")

    args = parser.parse_args()

    if not os.path.exists(args.svg_file):
        print(f"Error: File not found: {args.svg_file}", file=sys.stderr)
        sys.exit(1)

    tree = ET.parse(args.svg_file)
    root = tree.getroot()

    phases = set(args.phase) if args.phase else {1, 2, 3}

    if args.stats:
        before = compute_stats(root, "before")

    results = normalize(root, phases)

    if args.stats:
        after = compute_stats(root, "after")
        print("Normalization statistics:", file=sys.stderr)
        print(format_stats(before, after), file=sys.stderr)
        p2 = results.get("phase2", {})
        if p2.get("system_starts"):
            starts = p2["system_starts"]
            print(f"\n  Systems: {len(starts)}, "
                  f"staff <use> before measures {starts}",
                  file=sys.stderr)

    if args.indent:
        ET.indent(root, space="  ")

    if args.output:
        tree.write(args.output, xml_declaration=True, encoding="UTF-8")
        print(f"Wrote normalized SVG to {args.output}", file=sys.stderr)
    else:
        ET.dump(root)


if __name__ == "__main__":
    main()
