#!/usr/bin/env python3
"""
harvest_svg.py â€” Extract structured musical data from LilyPond SVG output.

Parses an SVG file rendered by LilyPond (with cnb/test-ids.ly included),
walks into each tagged element's descendants accumulating nested transforms
(translate + scale) to compute absolute positions, establishes a staff-relative
coordinate system, and outputs structured JSON.

USAGE:
    python3 tools/harvest_svg.py output.svg > harvested.json
    python3 tools/harvest_svg.py output.svg -o harvested.json --pretty
    python3 tools/harvest_svg.py output.svg --elements-only

COORDINATE SYSTEMS:
    Absolute:  SVG coordinate space (points from top-left of page).
               Y increases downward (SVG convention).
    Staff-relative vertical:
               0.0 = bottom staff line, 1.0 = top staff line.
               Values > 1.0 are above the staff; < 0.0 are below.
    Measure-relative horizontal:
               0.0 = left barline, 1.0 = right barline.

LilyPond SVG structure (important for understanding the code):
    Tagged elements are <g id="nh-1-0.000-60-0" data-type="notehead" ...>
    at the top level of the SVG. They have NO transform themselves.
    Transforms are on DESCENDANT <g> elements inside, often nested 4+ deep:
        <g id="nh-...">           <- ID here, no transform
          <a>
            <g transform="scale(1.0, 1.0)">
              <g transform="scale(0.75, 0.75)">
                <g color="...">
                  <g transform="translate(18.35, 21.79)">  <- position here
                    <path .../>                             <- drawing here

    We walk DOWN into descendants, accumulating transforms as a 2D affine:
        (sx, sy, tx, ty)  where  abs_x = sx * local_x + tx
"""

import sys
import os
import json
import re
import hashlib
import argparse
import xml.etree.ElementTree as ET

# SVG namespace
SVG_NS = "http://www.w3.org/2000/svg"
XLINK_NS = "http://www.w3.org/1999/xlink"
ET.register_namespace("", SVG_NS)
ET.register_namespace("xlink", XLINK_NS)


# =========================================================================
#  TRANSFORM ACCUMULATION
# =========================================================================

def parse_transform(transform_str):
    """Parse an SVG transform string into (sx, sy, tx, ty) components.

    Handles translate(x,y) and scale(sx,sy). Multiple transforms in one
    attribute are applied left-to-right.
    Returns (sx, sy, tx, ty) where: abs = scale * local + translate.
    """
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
    """Compose two affine transforms: outer applied first, then inner.
    Result: sx = o_sx * i_sx,  tx = o_sx * i_tx + o_tx."""
    o_sx, o_sy, o_tx, o_ty = outer
    i_sx, i_sy, i_tx, i_ty = inner
    return (
        o_sx * i_sx,
        o_sy * i_sy,
        o_sx * i_tx + o_tx,
        o_sy * i_ty + o_ty,
    )


DRAWING_TAGS = {"path", "rect", "line", "circle", "ellipse", "polygon", "text"}


def get_tag_local(element):
    """Strip namespace from element tag."""
    tag = element.tag
    return tag.split("}", 1)[1] if "}" in tag else tag


def find_drawing_positions(element, current_transform=None):
    """Recursively descend into element, accumulating transforms.

    Returns list of (abs_x, abs_y, drawing_element, full_transform) tuples
    for each drawing primitive found.
    """
    if current_transform is None:
        current_transform = (1.0, 1.0, 0.0, 0.0)

    results = []

    for child in element:
        tag = get_tag_local(child)

        child_tf = parse_transform(child.get("transform", ""))
        accumulated = compose_transforms(current_transform, child_tf)

        sx, sy, tx, ty = accumulated

        if tag in DRAWING_TAGS:
            local_x, local_y = _get_local_position(child, tag)
            abs_x = sx * local_x + tx
            abs_y = sy * local_y + ty
            results.append((abs_x, abs_y, child, accumulated))

        # Always recurse
        results.extend(find_drawing_positions(child, accumulated))

    return results


def _get_local_position(element, tag):
    """Get the local-coordinate reference point of a drawing primitive."""
    try:
        if tag == "rect":
            return (float(element.get("x", 0)), float(element.get("y", 0)))
        elif tag == "line":
            x1 = float(element.get("x1", 0))
            y1 = float(element.get("y1", 0))
            x2 = float(element.get("x2", 0))
            y2 = float(element.get("y2", 0))
            return ((x1 + x2) / 2, (y1 + y2) / 2)
        elif tag == "circle":
            return (float(element.get("cx", 0)), float(element.get("cy", 0)))
        else:
            return (0.0, 0.0)
    except (ValueError, TypeError):
        return (0.0, 0.0)


def get_representative_position(element):
    """Get the primary absolute position for a tagged element.

    Finds all drawing primitives, picks the first one (usually the
    main visual element), returns (abs_x, abs_y).
    """
    positions = find_drawing_positions(element)
    if not positions:
        return (0.0, 0.0)
    return (round(positions[0][0], 4), round(positions[0][1], 4))


# =========================================================================
#  VISUAL PROPERTY EXTRACTION (deep search)
# =========================================================================

def extract_color_deep(element):
    """Search all descendants for color/fill information."""
    for desc in element.iter():
        color = desc.get("color")
        if color and color != "currentColor":
            return color
        tag = get_tag_local(desc)
        if tag in DRAWING_TAGS:
            fill = desc.get("fill")
            if fill and fill not in ("none", "currentColor"):
                return fill
    return None


def extract_path_data_deep(element):
    """Find first <path> in descendants and return its d attribute."""
    for desc in element.iter():
        if get_tag_local(desc) == "path":
            d = desc.get("d")
            if d:
                return d
    return None


def hash_path(path_d):
    """Compute a short hash of path data for shape identity comparison."""
    if not path_d:
        return None
    normalized = re.sub(r'\s+', ' ', path_d.strip())
    return hashlib.sha256(normalized.encode()).hexdigest()[:12]


def compute_bbox_deep(element):
    """Compute bounding box from all drawing primitives, with transforms."""
    positions = find_drawing_positions(element)
    if not positions:
        return None

    all_x = []
    all_y = []

    for abs_x, abs_y, prim, transform in positions:
        sx, sy, tx, ty = transform
        tag = get_tag_local(prim)

        if tag == "path":
            local_bb = _bbox_from_path_local(prim.get("d", ""))
            if local_bb:
                all_x.extend([sx * local_bb["min_x"] + tx, sx * local_bb["max_x"] + tx])
                all_y.extend([sy * local_bb["min_y"] + ty, sy * local_bb["max_y"] + ty])
            else:
                all_x.append(abs_x)
                all_y.append(abs_y)
        elif tag == "rect":
            rx = float(prim.get("x", 0))
            ry = float(prim.get("y", 0))
            rw = float(prim.get("width", 0))
            rh = float(prim.get("height", 0))
            all_x.extend([sx * rx + tx, sx * (rx + rw) + tx])
            all_y.extend([sy * ry + ty, sy * (ry + rh) + ty])
        elif tag == "line":
            x1 = float(prim.get("x1", 0))
            y1 = float(prim.get("y1", 0))
            x2 = float(prim.get("x2", 0))
            y2 = float(prim.get("y2", 0))
            all_x.extend([sx * x1 + tx, sx * x2 + tx])
            all_y.extend([sy * y1 + ty, sy * y2 + ty])
        else:
            all_x.append(abs_x)
            all_y.append(abs_y)

    if not all_x:
        return None

    min_x, max_x = min(all_x), max(all_x)
    min_y, max_y = min(all_y), max(all_y)
    return {
        "x": round(min_x, 3),
        "y": round(min_y, 3),
        "w": round(max_x - min_x, 3),
        "h": round(max_y - min_y, 3),
    }


def _bbox_from_path_local(d):
    """Parse SVG path d-string and compute local bounding box."""
    coords = []
    tokens = re.findall(
        r'[MmLlCcHhVvSsQqTtAaZz]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?', d)

    i = 0
    cx, cy = 0, 0
    while i < len(tokens):
        token = tokens[i]
        if token in ('M', 'm', 'L', 'l'):
            relative = token.islower()
            i += 1
            while i < len(tokens) and re.match(r'[-+.\d]', tokens[i]):
                try:
                    x, y = float(tokens[i]), float(tokens[i + 1])
                    if relative:
                        cx += x; cy += y
                    else:
                        cx, cy = x, y
                    coords.append((cx, cy))
                    i += 2
                except (IndexError, ValueError):
                    break
        elif token in ('C', 'c'):
            relative = token.islower()
            i += 1
            while i + 5 < len(tokens) and re.match(r'[-+.\d]', tokens[i]):
                try:
                    pts = [float(tokens[i + j]) for j in range(6)]
                    if relative:
                        for j in range(3):
                            coords.append((cx + pts[j*2], cy + pts[j*2+1]))
                        cx += pts[4]; cy += pts[5]
                    else:
                        for j in range(3):
                            coords.append((pts[j*2], pts[j*2+1]))
                        cx, cy = pts[4], pts[5]
                    i += 6
                except (IndexError, ValueError):
                    break
        elif token in ('H', 'h'):
            i += 1
            if i < len(tokens):
                try:
                    val = float(tokens[i])
                    cx = cx + val if token == 'h' else val
                    coords.append((cx, cy)); i += 1
                except ValueError: pass
        elif token in ('V', 'v'):
            i += 1
            if i < len(tokens):
                try:
                    val = float(tokens[i])
                    cy = cy + val if token == 'v' else val
                    coords.append((cx, cy)); i += 1
                except ValueError: pass
        elif token in ('Z', 'z'):
            i += 1
        else:
            i += 1

    if not coords:
        return None
    xs = [c[0] for c in coords]
    ys = [c[1] for c in coords]
    return {"min_x": min(xs), "min_y": min(ys), "max_x": max(xs), "max_y": max(ys)}


# =========================================================================
#  STAFF AND MEASURE REFERENCE FRAME
# =========================================================================

def _extract_staff_geom_from_element(el_info):
    """Extract staff geometry from a single staff-symbol element.

    Returns a staff geometry dict or None if no lines found.
    Also includes x-range of the staff lines for system boundary detection.
    """
    svg_el = el_info["_svg_element"]
    positions = find_drawing_positions(svg_el)

    line_ys = []
    line_xs = []
    for abs_x, abs_y, prim, transform in positions:
        if get_tag_local(prim) == "line":
            try:
                y1 = float(prim.get("y1", 0))
                y2 = float(prim.get("y2", 0))
                if abs(y1 - y2) < 0.1:  # horizontal line
                    line_ys.append(abs_y)
                    # Track x-range for staff boundary detection
                    sx, sy, tx, ty = transform
                    x1 = float(prim.get("x1", 0))
                    x2 = float(prim.get("x2", 0))
                    line_xs.extend([sx * x1 + tx, sx * x2 + tx])
            except (ValueError, TypeError):
                pass

    if not line_ys:
        return None

    unique_ys = sorted(set(round(y, 2) for y in line_ys))
    top_y = min(unique_ys)
    bottom_y = max(unique_ys)
    return {
        "top_line_y": round(top_y, 3),
        "bottom_line_y": round(bottom_y, 3),
        "staff_height": round(bottom_y - top_y, 3),
        "center_y": round((top_y + bottom_y) / 2.0, 3),
        "line_count": len(unique_ys),
        "line_ys": [round(y, 3) for y in unique_ys],
        "_left_x": round(min(line_xs), 3) if line_xs else 0.0,
        "_right_x": round(max(line_xs), 3) if line_xs else 0.0,
    }


def find_all_staff_geometries(tagged_elements):
    """Extract staff geometry for ALL systems (one per staff-symbol element).

    Returns a list of staff geometry dicts sorted by vertical position
    (top system first). Each dict includes a 'system' index (0-based).

    For single-system scores, returns a list with one element.
    """
    geometries = []

    for el_info in tagged_elements:
        if el_info["data-type"] != "staff-symbol":
            continue
        geom = _extract_staff_geom_from_element(el_info)
        if geom:
            geometries.append(geom)

    # Sort by center_y (top system has smallest y in SVG coordinates)
    geometries.sort(key=lambda g: g["center_y"])

    # Assign system indices
    for i, geom in enumerate(geometries):
        geom["system"] = i

    return geometries


def find_staff_geometry(tagged_elements):
    """Extract staff line positions from the first staff-symbol element.

    Legacy wrapper — returns geometry for system 0 only.
    Use find_all_staff_geometries() for multi-system support.
    """
    all_geoms = find_all_staff_geometries(tagged_elements)
    return all_geoms[0] if all_geoms else None


def assign_element_to_system(abs_y, staff_geometries):
    """Assign an element to the nearest system based on y-proximity.

    Returns the system index (0-based). If no systems, returns 0.
    """
    if not staff_geometries:
        return 0
    if len(staff_geometries) == 1:
        return 0

    best_idx = 0
    best_dist = abs(abs_y - staff_geometries[0]["center_y"])

    for i, geom in enumerate(staff_geometries[1:], 1):
        dist = abs(abs_y - geom["center_y"])
        if dist < best_dist:
            best_dist = dist
            best_idx = i

    return best_idx


def _find_preamble_right_edge(tagged_elements, system_staff_geom=None):
    """Find the right edge of the measure-1 preamble (time sig, key sig, clef).

    The first measure has no left barline. Its musical content starts after
    whatever preamble elements are present. We cascade through:
        1. Right edge of time signature (rightmost preamble element)
        2. Right edge of key signature
        3. Right edge of clef
        4. Staff left edge (fallback)

    If system_staff_geom is provided, only considers preamble elements
    near that system (for multi-system support). When a system starts
    mid-piece, preamble elements may have measure != "1".

    Returns the x-coordinate of the right edge of the rightmost preamble
    element found, or None if nothing is found.
    """
    preamble_types = ("time-signature", "key-signature", "clef")
    right_edges = []

    for el_info in tagged_elements:
        if el_info["data-type"] not in preamble_types:
            continue

        # If we have system info, only consider preamble elements near this system
        if system_staff_geom is not None:
            dist = abs(el_info["_abs_y"] - system_staff_geom["center_y"])
            # Allow elements within 2x staff height of the system center
            max_dist = max(system_staff_geom["staff_height"] * 2, 20.0)
            if dist > max_dist:
                continue

        bbox = compute_bbox_deep(el_info["_svg_element"])
        if bbox and bbox["w"] > 0:
            right_edges.append(bbox["x"] + bbox["w"])
        else:
            positions = find_drawing_positions(el_info["_svg_element"])
            if positions:
                max_x = max(pos[0] for pos in positions)
                right_edges.append(max_x)

    if right_edges:
        return max(right_edges)
    return None


def find_measure_boundaries(tagged_elements, staff_geom):
    """Find measure boundaries from barline x-positions.

    Legacy single-system wrapper. For multi-system, use
    find_measure_boundaries_multi().
    """
    return find_measure_boundaries_multi(
        tagged_elements, [staff_geom] if staff_geom else [],
        {el["id"]: 0 for el in tagged_elements})


def find_measure_boundaries_multi(tagged_elements, staff_geometries, element_systems):
    """Find measure boundaries per-system from barline x-positions.

    In LilyPond, bl-N marks the LEFT edge of measure N (the barline
    where measure N begins). Barlines are grouped by system so that
    only barlines within the same system are paired as consecutive
    boundaries.

    Args:
        tagged_elements: all tagged elements
        staff_geometries: list of staff geometry dicts (one per system)
        element_systems: dict mapping element id -> system index

    Returns:
        dict mapping measure number (str) -> boundary dict with
        left_x, right_x, width, and system index.
    """
    if not staff_geometries:
        return {}

    # Group barlines by system
    barlines_by_system = {}
    for el_info in tagged_elements:
        if el_info["data-type"] != "barline":
            continue
        sys_idx = element_systems.get(el_info["id"], 0)
        measure = el_info["data"].get("measure", "?")
        barlines_by_system.setdefault(sys_idx, []).append({
            "measure": measure,
            "x": el_info["_abs_x"],
        })

    measures = {}

    for sys_idx in sorted(barlines_by_system.keys()):
        sys_barlines = sorted(barlines_by_system[sys_idx], key=lambda b: b["x"])
        sys_geom = staff_geometries[sys_idx] if sys_idx < len(staff_geometries) else None

        if not sys_barlines:
            continue

        # Find the left boundary for the first measure on this system.
        # System 0: use preamble right edge (time sig, key sig, clef).
        # System N>0: use preamble right edge for that system (courtesy
        # clef/key sig at start of system), fall back to staff left edge.
        sys_elements = [el for el in tagged_elements
                        if element_systems.get(el["id"], 0) == sys_idx]

        first_measure_left = _find_preamble_right_edge(
            sys_elements, sys_geom)

        if first_measure_left is None and sys_geom:
            # Fallback: use staff left edge from the staff geometry
            first_measure_left = sys_geom.get("_left_x")

        if first_measure_left is None:
            # Last resort: find staff-symbol lines on this system
            for el_info in sys_elements:
                if el_info["data-type"] == "staff-symbol":
                    positions = find_drawing_positions(el_info["_svg_element"])
                    xs = []
                    for abs_x, abs_y, prim, transform in positions:
                        if get_tag_local(prim) == "line":
                            sx, sy, tx, ty = transform
                            x1 = float(prim.get("x1", 0))
                            xs.append(sx * x1 + tx)
                    if xs:
                        first_measure_left = min(xs)
                    break

        # First measure on this system: preamble/staff edge -> first barline
        if first_measure_left is not None and sys_barlines:
            first_bl = sys_barlines[0]
            first_measure_num = _measure_before(first_bl["measure"])
            measures[first_measure_num] = {
                "left_x": round(first_measure_left, 3),
                "right_x": round(first_bl["x"], 3),
                "width": round(first_bl["x"] - first_measure_left, 3),
                "system": sys_idx,
            }

        # Consecutive barline pairs define subsequent measures
        for i in range(len(sys_barlines) - 1):
            bl_this = sys_barlines[i]
            bl_next = sys_barlines[i + 1]
            m_num = bl_this["measure"]
            measures[m_num] = {
                "left_x": round(bl_this["x"], 3),
                "right_x": round(bl_next["x"], 3),
                "width": round(bl_next["x"] - bl_this["x"], 3),
                "system": sys_idx,
            }

    return measures


def _measure_before(barline_measure_str):
    """Given a barline's measure number (the measure it STARTS),
    return the measure number that precedes it (which is the measure
    that the first slot on the system belongs to).

    bl-N marks the start of measure N, so the measure before bl-N
    is measure N-1. For system 0, this is "1" when bl-2 is first.
    """
    try:
        m = int(barline_measure_str)
        return str(m - 1)
    except (ValueError, TypeError):
        return "1"


def compute_staff_relative(abs_x, abs_y, staff_geom, measures, measure_num,
                           system=0):
    """Compute staff-relative coordinates for a point."""
    result = {"measure": measure_num, "system": system}

    if staff_geom and staff_geom["staff_height"] > 0:
        height = staff_geom["staff_height"]
        result["vertical"] = round(
            (staff_geom["bottom_line_y"] - abs_y) / height, 4)

        center_y = staff_geom["center_y"]
        if staff_geom["line_count"] > 1:
            space = height / (staff_geom["line_count"] - 1)
            result["staff_spaces_from_center"] = round(
                (center_y - abs_y) / space, 3)
        else:
            result["staff_spaces_from_center"] = 0.0
    else:
        result["vertical"] = None
        result["staff_spaces_from_center"] = None

    measure_key = str(measure_num)
    if measure_key in measures:
        m = measures[measure_key]
        if m["width"] > 0:
            result["horizontal"] = round(
                (abs_x - m["left_x"]) / m["width"], 4)
        else:
            result["horizontal"] = 0.0
    else:
        result["horizontal"] = None

    return result


# =========================================================================
#  MAIN HARVEST PIPELINE
# =========================================================================

ID_PREFIXES = ("nh-", "st-", "dt-", "ac-", "fl-", "bm-",
               "rs-", "bl-", "cl-", "ks-", "ts-", "ll-",
               "ti-", "sl-",
               "staff-symbol")


def find_tagged_elements(root):
    """Find all elements with IDs matching our patterns."""
    results = []

    for element in root.iter():
        el_id = element.get("id", "")
        if not el_id:
            continue
        if not any(el_id.startswith(p) for p in ID_PREFIXES):
            continue

        abs_x, abs_y = get_representative_position(element)

        data = {}
        for attr, val in element.attrib.items():
            if attr.startswith("data-"):
                data[attr[5:]] = val

        results.append({
            "id": el_id,
            "data-type": data.get("type", "unknown"),
            "data": data,
            "_abs_x": abs_x,
            "_abs_y": abs_y,
            "_svg_element": element,
        })

    return results


def harvest(svg_path):
    """Main harvest function. Parse SVG and extract structured data.

    Supports multi-system scores: detects all systems, assigns elements
    to their nearest system, and computes staff-relative coordinates
    using the correct system's staff geometry and measure boundaries.
    """
    tree = ET.parse(svg_path)
    root = tree.getroot()

    # --- Detect normalized SVGs ---
    # normalize_svg.py moves staff lines into <defs> as <use> references,
    # which breaks staff geometry extraction (no inline <line> children).
    # Detect this and fail early with a clear message.
    for el in root.iter():
        el_id = el.get("id", "")
        if el_id == "staff-lines" or el_id.startswith("staff-lines-"):
            raise ValueError(
                f"Cannot harvest normalized SVG: '{svg_path}' contains "
                f"<defs id=\"{el_id}\"> from normalize_svg.py. "
                f"The harvester requires raw LilyPond SVG output. "
                f"Run LilyPond again or use the original (non-normalized) SVG."
            )

    raw_elements = find_tagged_elements(root)

    # --- Multi-system detection ---
    staff_geometries = find_all_staff_geometries(raw_elements)
    num_systems = len(staff_geometries)

    # Assign each element to a system
    element_systems = {}
    for el in raw_elements:
        if el["data-type"] == "staff-symbol":
            # Staff symbols are assigned by matching their geometry
            el_geom = _extract_staff_geom_from_element(el)
            if el_geom:
                # Find the system whose center_y is closest
                sys_idx = assign_element_to_system(
                    el_geom["center_y"], staff_geometries)
            else:
                sys_idx = 0
        else:
            sys_idx = assign_element_to_system(
                el["_abs_y"], staff_geometries)
        element_systems[el["id"]] = sys_idx

    # Compute measure boundaries per-system
    measures = find_measure_boundaries_multi(
        raw_elements, staff_geometries, element_systems)

    # For the legacy "staff" key, use system 0
    staff_geom_0 = staff_geometries[0] if staff_geometries else None

    # --- Build output ---
    output_elements = []
    for el in raw_elements:
        el_id = el["id"]
        abs_x = el["_abs_x"]
        abs_y = el["_abs_y"]
        svg_el = el["_svg_element"]
        data = el["data"]
        measure_num = data.get("measure", "1")
        sys_idx = element_systems.get(el_id, 0)

        # Use this element's system's staff geometry
        el_staff_geom = (staff_geometries[sys_idx]
                         if sys_idx < len(staff_geometries)
                         else staff_geom_0)

        staff_rel = compute_staff_relative(
            abs_x, abs_y, el_staff_geom, measures, measure_num,
            system=sys_idx)

        color = extract_color_deep(svg_el)
        path_d = extract_path_data_deep(svg_el)
        bbox = compute_bbox_deep(svg_el)

        element_record = {
            "id": el_id,
            "type": el["data-type"],
            "data": data,
            "absolute": {
                "x": round(abs_x, 3),
                "y": round(abs_y, 3),
            },
            "staff_relative": staff_rel,
            "visual": {},
        }

        if color:
            element_record["visual"]["color"] = color
        if path_d:
            element_record["visual"]["path_hash"] = hash_path(path_d)
        if bbox:
            element_record["visual"]["bbox"] = bbox

        output_elements.append(element_record)

    # Build systems array for output
    systems_output = []
    for geom in staff_geometries:
        sys_info = {
            "system": geom["system"],
            "top_line_y": geom["top_line_y"],
            "bottom_line_y": geom["bottom_line_y"],
            "staff_height": geom["staff_height"],
            "center_y": geom["center_y"],
            "line_count": geom["line_count"],
        }
        # Collect measures belonging to this system
        sys_measures = {k: v for k, v in measures.items()
                        if v.get("system") == geom["system"]}
        sys_info["measures"] = sys_measures
        systems_output.append(sys_info)

    result = {
        "source_file": os.path.basename(svg_path),
        "num_systems": num_systems,
        "staff": {
            "top_line_y": staff_geom_0["top_line_y"] if staff_geom_0 else 0.0,
            "bottom_line_y": staff_geom_0["bottom_line_y"] if staff_geom_0 else 0.0,
            "staff_height": staff_geom_0["staff_height"] if staff_geom_0 else 0.0,
            "center_y": staff_geom_0["center_y"] if staff_geom_0 else 0.0,
            "line_count": staff_geom_0["line_count"] if staff_geom_0 else 0,
        },
        "systems": systems_output,
        "measures": measures,
        "elements": output_elements,
    }

    return result


# =========================================================================
#  CLI
# =========================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Extract structured musical data from LilyPond SVG output.")
    parser.add_argument("svg_file", help="Path to SVG file")
    parser.add_argument("-o", "--output", help="Output JSON file (default: stdout)")
    parser.add_argument("--pretty", action="store_true",
                        help="Pretty-print JSON output")
    parser.add_argument("--elements-only", action="store_true",
                        help="Output only the elements array")

    args = parser.parse_args()

    if not os.path.exists(args.svg_file):
        print(f"Error: File not found: {args.svg_file}", file=sys.stderr)
        sys.exit(1)

    result = harvest(args.svg_file)

    if args.elements_only:
        result = result["elements"]

    indent = 2 if args.pretty else None
    json_str = json.dumps(result, indent=indent, default=str)

    if args.output:
        with open(args.output, "w") as f:
            f.write(json_str)
            f.write("\n")
        elem_count = len(result.get('elements', result) if isinstance(result, dict) else result)
        print(f"Wrote {elem_count} elements to {args.output}", file=sys.stderr)
    else:
        print(json_str)


if __name__ == "__main__":
    main()
