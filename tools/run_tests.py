#!/usr/bin/env python3
"""
run_tests.py — Integration test runner for the CNB framework.

Pipeline for each test case:
  1. Run lilypond -dbackend=svg on the input .ly file
  2. Run harvest_svg.py on the resulting SVG
  3. Load expected assertions from the JSON spec
  4. Compare actual vs expected, report pass/fail

USAGE:
    python3 tools/run_tests.py                    # run all tests in tests/
    python3 tools/run_tests.py tests/c-major.json # run a single test
    python3 tools/run_tests.py --verbose           # show all assertions
    python3 tools/run_tests.py --generate tests/c-major.ly  # generate golden JSON

TEST SPEC FORMAT (JSON):
    {
      "test_name": "C major scale, quarter notes",
      "input_file": "tests/c-major-scale.ly",
      "assertions": [
        {
          "id": "nh-1-0.000-60-0",
          "description": "Middle C, first beat",
          "expect": {
            "type":                     ["== 'notehead'"],
            "data.midi":                ["== '60'"],
            "staff_relative.vertical":  [">= -0.1", "<= 0.15"],
            "visual.color":             ["!= None"]
          }
        }
      ]
    }

ASSERTION EXPRESSIONS:
    Each property maps to an array of Python expression strings.
    Each expression is evaluated with these variables in scope:

        v       — The value of this property for this element
        el      — Dict of ALL harvested elements, keyed by id
        prop    — Helper: prop('nh-1-0.000-60-0', 'data.midi') -> value
        count   — Helper: count('notehead') -> int
        staff   — Staff geometry dict (top_line_y, bottom_line_y, etc.)
        measures — Measure boundaries dict

    All standard Python operators and builtins (abs, min, max, round,
    len, str, float, int, isinstance, etc.) are available.

    Every expression in the array must evaluate to True for the
    property to pass. Each expression reports pass/fail independently.

EXAMPLES:
    Exact match:          ["== 'notehead'"]
    Range:                [">= 0.0", "<= 1.0"]
    Tolerance:            ["abs(v - 0.5) < 0.05"]
    Cross-element:        ["abs(v - prop('nh-1-0.000-60-0', 'staff_relative.vertical')) < 0.1"]
    Relative spacing:     ["v > prop('nh-1-0.000-60-0', 'staff_relative.vertical')"]
    Same shape:           ["== prop('nh-1-0.000-60-0', 'visual.path_hash')"]
    Width comparison:     ["abs(v - prop('nh-1-0.000-60-0', 'visual.bbox.w')) < 0.5"]
    Type check:           ["isinstance(v, str)", "v.startswith('#')"]
    Existence:            ["v is not None"]
    Absence:              ["v is None"]
    Count elements:       ["count('notehead') == 8"]
    Membership:           ["v in ['#FF0000', '#0000FF', '#00FF00']"]
"""

import sys
import os
import json
import glob
import subprocess
import argparse
import time
import math
from pathlib import Path

# Add tools dir to path for harvest import
TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS_DIR)

from harvest_svg import harvest


# =========================================================================
#  ASSERTION ENGINE (eval-based)
# =========================================================================

def resolve_dotted_key(obj, dotted_key):
    """Resolve a dotted key like 'staff_relative.vertical' into a value.

    Walks nested dicts. Returns (True, value) if found, (False, None) if not.
    """
    keys = dotted_key.split(".")
    current = obj
    for key in keys:
        if isinstance(current, dict) and key in current:
            current = current[key]
        else:
            return (False, None)
    return (True, current)


def coerce_numeric(val):
    """Try to coerce a string to a number for easier comparison.

    '60' -> 60, '3.14' -> 3.14, 'notehead' -> 'notehead' (unchanged).
    """
    if isinstance(val, str):
        try:
            f = float(val)
            # Use int if it's a whole number without a decimal point in the original
            if f == int(f) and "." not in val:
                return int(f)
            return f
        except (ValueError, TypeError):
            return val
    return val


def make_prop_helper(elements_by_id):
    """Create the prop() helper function for use in eval expressions.

    prop('nh-1-0.000-60-0', 'staff_relative.vertical') -> value
    """
    def prop(element_id, dotted_key):
        el = elements_by_id.get(element_id)
        if el is None:
            raise ValueError(f"Element '{element_id}' not found")
        found, val = resolve_dotted_key(el, dotted_key)
        if not found:
            return None
        return val
    return prop


def make_count_helper(elements_by_id):
    """Create the count() helper for use in eval expressions.

    count('notehead') -> number of elements with type == 'notehead'
    """
    def count(element_type):
        return sum(1 for el in elements_by_id.values()
                   if el.get("type") == element_type)
    return count


def make_eval_namespace(v, elements_by_id, harvested):
    """Build the restricted namespace for eval().

    Includes:
      - v: the current property value (coerced to numeric if possible)
      - el: all elements dict
      - prop: cross-element property lookup
      - count: element type counter
      - staff: staff geometry
      - measures: measure boundaries
      - Safe builtins only (no os, subprocess, etc.)
    """
    safe_builtins = {
        "abs": abs,
        "min": min,
        "max": max,
        "round": round,
        "len": len,
        "str": str,
        "float": float,
        "int": int,
        "bool": bool,
        "isinstance": isinstance,
        "sorted": sorted,
        "any": any,
        "all": all,
        "sum": sum,
        "True": True,
        "False": False,
        "None": None,
        "math": math,
    }

    return {
        "__builtins__": safe_builtins,
        "v": v,
        "el": elements_by_id,
        "prop": make_prop_helper(elements_by_id),
        "count": make_count_helper(elements_by_id),
        "staff": harvested.get("staff", {}),
        "measures": harvested.get("measures", {}),
    }


def eval_expression(expr_raw, namespace):
    """Evaluate a single expression string.

    If the expression starts with a comparison operator (==, !=, <, >, <=, >=),
    it is prefixed with 'v ' so that "== 'notehead'" becomes "v == 'notehead'".
    This is syntactic sugar for the common case.

    Returns (passed: bool, detail: str).
    """
    expr = expr_raw.strip()

    # Syntactic sugar: if expr starts with a comparison op, prefix with 'v '
    for op in ("==", "!=", "<=", ">=", "<", ">", "in ", "not in "):
        if expr.startswith(op):
            expr = f"v {expr}"
            break

    try:
        result = eval(expr, namespace)
        return (bool(result), f"{result}")
    except Exception as e:
        return (False, f"ERROR: {type(e).__name__}: {e}")


def check_element_assertions(element, assertion, elements_by_id, harvested):
    """Check all property assertions for a single element.

    Returns a list of result dicts, one per expression evaluated.
    """
    expect = assertion.get("expect", {})
    results = []

    for prop_key, expressions in expect.items():
        # Ensure expressions is a list
        if not isinstance(expressions, list):
            expressions = [expressions]

        # Get the actual value for this property
        found, v_raw = resolve_dotted_key(element, prop_key)
        v = v_raw if found else None

        # Build eval namespace with this v
        ns = make_eval_namespace(v, elements_by_id, harvested)

        # Evaluate each expression
        for i, expr in enumerate(expressions):
            passed, detail = eval_expression(expr, ns)
            results.append({
                "passed": passed,
                "prop_key": prop_key,
                "expr_index": i,
                "expr_count": len(expressions),
                "expr_raw": expr,
                "detail": detail,
                "v_raw": v_raw,
                "v": v,
            })

    return results


# =========================================================================
#  REPORTING
# =========================================================================

def format_result_line(r, verbose=False):
    """Format a single expression result for display.

    Returns a string or None (if passing and not verbose).
    """
    if r["passed"] and not verbose:
        return None

    mark = "✓" if r["passed"] else "✗"
    idx = f"[{r['expr_index']+1}/{r['expr_count']}]" if r["expr_count"] > 1 else ""

    line = f"        {mark} {r['prop_key']} {idx} {r['expr_raw']}"

    if not r["passed"]:
        line += f"\n             v = {r['v']!r}  →  {r['detail']}"

    return line


# =========================================================================
#  LILYPOND EXECUTION
# =========================================================================

def run_lilypond(input_file, output_dir=None):
    """Run LilyPond with SVG backend on the input file.

    Runs from the project root directory so that \\include paths resolve.
    Returns path to the output SVG, or None on failure.
    """
    if output_dir is None:
        output_dir = os.path.dirname(input_file) or "."

    project_root = os.path.dirname(TOOLS_DIR)

    base = os.path.splitext(os.path.basename(input_file))[0]
    output_dir = os.path.abspath(output_dir)
    input_file = os.path.abspath(input_file)

    cmd = [
        "lilypond",
        "-dbackend=svg",
        f"--output={output_dir}/{base}",
        input_file,
    ]

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=60,
            cwd=project_root,
        )
        if result.returncode != 0:
            print(f"  LilyPond error (exit {result.returncode}):", file=sys.stderr)
            if result.stderr:
                for line in result.stderr.strip().split("\n")[-10:]:
                    print(f"    {line}", file=sys.stderr)
            return None

        # LilyPond outputs {base}.svg or {base}-page1.svg
        for suffix in [".svg", "-page1.svg"]:
            svg_path = os.path.join(output_dir, f"{base}{suffix}")
            if os.path.exists(svg_path):
                return svg_path

        # Search for any SVG matching base
        for f in os.listdir(output_dir):
            if f.startswith(base) and f.endswith(".svg"):
                return os.path.join(output_dir, f)

        print(f"  SVG not found after LilyPond run", file=sys.stderr)
        return None

    except subprocess.TimeoutExpired:
        print(f"  LilyPond timed out (60s)", file=sys.stderr)
        return None
    except FileNotFoundError:
        print(f"  lilypond not found in PATH", file=sys.stderr)
        return None


# =========================================================================
#  TEST EXECUTION
# =========================================================================

def run_single_test(spec_path, verbose=False):
    """Run a single test from a JSON spec file.

    Returns (passed_count, failed_count, total_assertion_count)
    """
    with open(spec_path) as f:
        spec = json.load(f)

    test_name = spec.get("test_name", os.path.basename(spec_path))
    input_file = spec.get("input_file")

    # Resolve input_file relative to spec file location
    spec_dir = os.path.dirname(os.path.abspath(spec_path))
    if not os.path.isabs(input_file):
        input_file = os.path.join(spec_dir, input_file)

    if not os.path.exists(input_file):
        project_root = os.path.dirname(TOOLS_DIR)
        input_file_alt = os.path.join(project_root, spec.get("input_file"))
        if os.path.exists(input_file_alt):
            input_file = input_file_alt
        else:
            print(f"\n✗ {test_name}")
            print(f"  Input file not found: {input_file}")
            return (0, 1, 1)

    print(f"\n● {test_name}")
    print(f"  Input: {input_file}")

    # Step 1: Run LilyPond
    svg_path = run_lilypond(input_file, output_dir=spec_dir)
    if not svg_path:
        print(f"  SKIP: LilyPond failed")
        return (0, 0, 0)

    print(f"  SVG: {svg_path}")

    # Step 2: Harvest SVG
    try:
        harvested = harvest(svg_path)
    except Exception as e:
        print(f"  Harvest error: {e}")
        return (0, 1, 1)

    element_count = len(harvested.get("elements", []))
    print(f"  Harvested: {element_count} elements, "
          f"{len(harvested.get('measures', {}))} measures")

    # Build lookup by id
    elements_by_id = {}
    for el in harvested.get("elements", []):
        elements_by_id[el["id"]] = el

    # Step 3: Check assertions
    assertions = spec.get("assertions", [])
    passed = 0
    failed = 0

    for assertion in assertions:
        # Skip comment entries (section markers)
        if "id" not in assertion:
            continue

        a_id = assertion.get("id")
        a_desc = assertion.get("description", a_id)
        expect = assertion.get("expect", {})

        # --- Handle missing elements ---
        actual = elements_by_id.get(a_id)

        if actual is None:
            # Check if this is an expected-absence assertion.
            # Convention: if ANY expression across ALL properties contains
            # "is None" or "== None", treat it as an absence check.
            absence_expected = False
            for prop_key, exprs in expect.items():
                if not isinstance(exprs, list):
                    exprs = [exprs]
                for expr in exprs:
                    if "is None" in str(expr) or "== None" in str(expr):
                        absence_expected = True
                        break
                if absence_expected:
                    break

            if absence_expected:
                print(f"    ✓ {a_desc} (absent as expected)")
                passed += 1
            else:
                print(f"    ✗ {a_desc}")
                print(f"        Element '{a_id}' not found in SVG")
                # Show available IDs with same prefix for debugging
                prefix = a_id.split("-")[0] + "-" if "-" in a_id else ""
                similar = [eid for eid in elements_by_id if eid.startswith(prefix)]
                if similar:
                    print(f"        Similar IDs: {', '.join(similar[:8])}"
                          f"{'...' if len(similar) > 8 else ''}")
                failed += 1
            continue

        # --- Evaluate all expressions for this element ---
        results = check_element_assertions(
            actual, assertion, elements_by_id, harvested)

        all_passed = all(r["passed"] for r in results)

        if all_passed:
            passed += 1
            print(f"    ✓ {a_desc}")
            if verbose:
                for r in results:
                    line = format_result_line(r, verbose=True)
                    if line:
                        print(line)
        else:
            failed += 1
            print(f"    ✗ {a_desc}")
            # Always show all results (pass and fail) when assertion fails
            for r in results:
                line = format_result_line(r, verbose=True)
                if line:
                    print(line)

    # Save harvested data alongside the spec for inspection
    harvest_path = svg_path.replace(".svg", ".harvested.json")
    with open(harvest_path, "w") as f:
        json.dump(harvested, f, indent=2, default=str)
    print(f"  Saved harvest: {harvest_path}")

    return (passed, failed, len(assertions))


# =========================================================================
#  GOLDEN FILE GENERATION
# =========================================================================

def generate_golden(ly_file, output_json=None):
    """Generate a golden harvest JSON from a .ly file.

    This is the starting point for creating test specs.
    Run on a known-good render, review the output, then write assertions.
    """
    if output_json is None:
        output_json = ly_file.replace(".ly", ".harvested.json")

    print(f"Generating golden file from: {ly_file}")
    output_dir = os.path.dirname(ly_file) or "."

    svg_path = run_lilypond(ly_file, output_dir=output_dir)
    if not svg_path:
        print("Failed to render SVG")
        sys.exit(1)

    harvested = harvest(svg_path)

    with open(output_json, "w") as f:
        json.dump(harvested, f, indent=2, default=str)

    element_count = len(harvested.get("elements", []))
    print(f"Harvested {element_count} elements → {output_json}")
    print(f"\nTo create a test spec, write a JSON file with assertions")
    print(f"referencing element IDs from the harvest. Example IDs found:")

    for el in harvested.get("elements", [])[:20]:
        el_type = el.get("type", "?")
        sr = el.get("staff_relative", {})
        vert = sr.get("vertical", "?")
        horiz = sr.get("horizontal", "?")
        if isinstance(vert, float):
            vert = f"{vert:.3f}"
        if isinstance(horiz, float):
            horiz = f"{horiz:.3f}"
        el_id = str(el.get('id', '?'))
        el_type = str(el.get('type', '?'))
        vert = str(vert) if vert is not None else "?"
        horiz = str(horiz) if horiz is not None else "?"
        print(f"  {el_id:40s}  {el_type:18s}  vert={vert:>7s}  horiz={horiz}")
    if element_count > 20:
        print(f"  ... and {element_count - 20} more")

    # Staff geometry
    staff = harvested.get("staff", {})
    if staff.get("top_line_y") is not None:
        print(f"\nStaff geometry:")
        print(f"  top_line_y:    {staff['top_line_y']}")
        print(f"  bottom_line_y: {staff['bottom_line_y']}")
        print(f"  staff_height:  {staff['staff_height']}")
        print(f"  line_count:    {staff['line_count']}")

    # Measure boundaries
    measures = harvested.get("measures", {})
    if measures:
        print(f"\nMeasure boundaries:")
        for m_num in sorted(measures.keys(), key=lambda x: int(x) if x.isdigit() else 0):
            m = measures[m_num]
            print(f"  Measure {m_num}: x=[{m['left_x']:.1f}, {m['right_x']:.1f}] "
                  f"width={m['width']:.1f}")


# =========================================================================
#  CLI
# =========================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Run CNB integration tests")
    parser.add_argument("paths", nargs="*",
        help="Test spec JSON files or directories (default: tests/)")
    parser.add_argument("-v", "--verbose", action="store_true",
        help="Show all assertion details including passes")
    parser.add_argument("--keep-svg", action="store_true",
        help="Keep SVG files after tests")
    parser.add_argument("--generate", metavar="FILE.ly",
        help="Generate golden harvest JSON from a .ly file")

    args = parser.parse_args()

    if args.generate:
        generate_golden(args.generate)
        return

    # Find test specs
    spec_files = []
    paths = args.paths or ["tests/"]

    for path in paths:
        if os.path.isfile(path) and path.endswith(".json"):
            spec_files.append(path)
        elif os.path.isdir(path):
            spec_files.extend(sorted(
                f for f in glob.glob(os.path.join(path, "*.json"))
                if not f.endswith(".harvested.json")))
        else:
            print(f"Warning: Skipping '{path}' (not a .json file or directory)")

    if not spec_files:
        print("No test specs found.")
        print("  Create test specs in tests/ directory, or run with --generate")
        sys.exit(0)

    n = len(spec_files)
    print(f"╔══════════════════════════════════════════╗")
    print(f"║  CNB Integration Test Runner             ║")
    print(f"║  {n} test spec(s) found{' ' * max(0, 21 - len(str(n)))}║")
    print(f"╚══════════════════════════════════════════╝")

    total_passed = 0
    total_failed = 0
    total_assertions = 0
    start_time = time.time()

    for spec_file in spec_files:
        p, f, t = run_single_test(spec_file, verbose=args.verbose)
        total_passed += p
        total_failed += f
        total_assertions += t

    elapsed = time.time() - start_time

    print(f"\n{'='*50}")
    print(f"  RESULTS: {total_passed} passed, {total_failed} failed "
          f"({total_assertions} assertions)")
    print(f"  Time: {elapsed:.1f}s")
    print(f"{'='*50}")

    sys.exit(1 if total_failed > 0 else 0)


if __name__ == "__main__":
    main()
