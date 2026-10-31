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
    python3 tools/run_tests.py --update-baselines  # accept changed harvests
    python3 tools/run_tests.py --lilypond-version 2.26  # LilyPond 2.26 and its baselines

LILYPOND VERSIONS:
    --lilypond-version X.Y renders with the executable CNB_LILYPOND_X_Y names,
    else the lilypond on PATH if it reports X.Y. 2.24's harvest baselines are
    tests/*.harvested.json; 2.26's are tests/lilypond-2.26/*.harvested.json,
    rendered into out/lilypond-2.26/. Another version runs the assertions but
    compares no baselines. Without the option, PATH's lilypond is compared
    with 2.24's baselines.
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
        lilypond — The LilyPond version under test, 'X.Y' ('2.24' when
                   no --lilypond-version is given)

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
import re
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

from harvest_svg import harvest, configure_output

PROJECT_ROOT = os.path.dirname(TOOLS_DIR)

# The LilyPond versions with tracked harvest baselines: 2.24's sit beside
# the specs, every other one's in a lilypond-X.Y/ folder beside them.
SUPPORTED_LILYPOND_VERSIONS = ("2.24", "2.26")
BASELINE_VERSION = "2.24"


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


def make_eval_namespace(v, elements_by_id, harvested,
                        lilypond=BASELINE_VERSION):
    """Build the restricted namespace for eval().

    Includes:
      - v: the current property value (coerced to numeric if possible)
      - el: all elements dict
      - prop: cross-element property lookup
      - count: element type counter
      - staff: staff geometry
      - measures: measure boundaries
      - lilypond: the LilyPond version under test, 'X.Y'
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
        "lilypond": lilypond,
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


def check_element_assertions(element, assertion, elements_by_id, harvested,
                             lilypond=BASELINE_VERSION):
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
        ns = make_eval_namespace(v, elements_by_id, harvested, lilypond)

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

def lilypond_env_var(version):
    """The variable naming LilyPond X.Y's executable: CNB_LILYPOND_X_Y."""
    return "CNB_LILYPOND_" + version.replace(".", "_")


def lilypond_version(executable):
    """The X.Y that an executable's --version reports, or None."""
    try:
        result = subprocess.run(
            [executable, "--version"], capture_output=True,
            encoding="utf-8", errors="replace", timeout=60)
    except (OSError, subprocess.TimeoutExpired):
        return None
    first_line = (result.stdout.splitlines() or [""])[0]
    match = re.search(r"\b(\d+\.\d+)\.\d+", first_line)
    return match.group(1) if match else None


def resolve_lilypond(version):
    """The lilypond executable for version X.Y: the one CNB_LILYPOND_X_Y
    names, else the lilypond on PATH if it reports X.Y. Exits non-zero,
    naming the variable to set, when neither does."""
    var = lilypond_env_var(version)
    if os.environ.get(var):
        return os.environ[var]
    if lilypond_version("lilypond") == version:
        return "lilypond"
    sys.exit(f"LilyPond {version} not found: set {var} to its lilypond "
             f"executable, or put LilyPond {version} on PATH")


def render_dir(version):
    """Where renders for a version go: out/lilypond-X.Y/ for any version
    but 2.24, so the tracked tests/*.svg stay 2.24's; None means the
    runner's usual place."""
    if version is None or version == BASELINE_VERSION:
        return None
    return os.path.join(PROJECT_ROOT, "out", f"lilypond-{version}")


def baseline_dir(version, spec_dir):
    """Where a version's harvest baselines live: beside the spec for 2.24
    (or no version given), in spec_dir/lilypond-X.Y/ for another supported
    version, and None -- no drift comparison -- for an unsupported one."""
    if version is None or version == BASELINE_VERSION:
        return spec_dir
    if version in SUPPORTED_LILYPOND_VERSIONS:
        return os.path.join(spec_dir, f"lilypond-{version}")
    return None


def run_lilypond(input_file, output_dir=None, lilypond="lilypond"):
    """Run LilyPond with SVG backend on the input file.

    Runs from the project root directory so that \\include paths resolve.
    Returns path to the output SVG, or None on failure.
    """
    if output_dir is None:
        output_dir = os.path.dirname(input_file) or "."

    base = os.path.splitext(os.path.basename(input_file))[0]
    output_dir = os.path.abspath(output_dir)
    os.makedirs(output_dir, exist_ok=True)
    input_file = os.path.abspath(input_file)

    # -dno-point-and-click keeps textedit:// links (which embed the absolute
    # path) out of the SVG, so a render is the same from any checkout.
    cmd = [
        lilypond,
        "-dbackend=svg",
        "-dno-point-and-click",
        f"--output={output_dir}/{base}",
        input_file,
    ]

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            encoding="utf-8",
            errors="replace",
            timeout=60,
            cwd=PROJECT_ROOT,
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
        print(f"  {lilypond} not found", file=sys.stderr)
        return None


# =========================================================================
#  HARVEST BASELINES
# =========================================================================

def _flatten(d, prefix=""):
    """Flatten nested dicts into dotted keys; an empty dict is a leaf."""
    flat = {}
    for key, value in d.items():
        if isinstance(value, dict) and value:
            flat.update(_flatten(value, f"{prefix}{key}."))
        else:
            flat[f"{prefix}{key}"] = value
    return flat


def harvest_differences(baseline, harvested):
    """Name what differs between two harvests, one line per element id
    (with its changed properties) or other top-level key. Empty when equal."""
    diffs = []
    old_els = {el["id"]: el for el in baseline.get("elements", [])}
    new_els = {el["id"]: el for el in harvested.get("elements", [])}
    for el_id in sorted(old_els.keys() | new_els.keys()):
        if el_id not in new_els:
            diffs.append(f"{el_id}: no longer harvested")
        elif el_id not in old_els:
            diffs.append(f"{el_id}: newly harvested")
        else:
            old, new = _flatten(old_els[el_id]), _flatten(new_els[el_id])
            changed = sorted(k for k in old.keys() | new.keys()
                             if old.get(k) != new.get(k))
            if changed:
                diffs.append(f"{el_id}: {', '.join(changed)}")
    for key in sorted((baseline.keys() | harvested.keys()) - {"elements"}):
        if baseline.get(key) != harvested.get(key):
            diffs.append(f"{key}: changed")
    return diffs


def save_harvest(harvested, harvest_path, update_baselines=False):
    """Write a regenerated harvest unless it drifts from the tracked one.

    With no tracked harvest yet, or with update_baselines, the file is
    written. Otherwise a drifted harvest leaves the file untouched and its
    differences are returned; an empty list means nothing was refused.
    """
    # Round-trip so the comparison sees exactly what would be written.
    harvested = json.loads(json.dumps(harvested, default=str))
    if os.path.exists(harvest_path) and not update_baselines:
        with open(harvest_path, encoding="utf-8") as f:
            diffs = harvest_differences(json.load(f), harvested)
        if diffs:
            return diffs
    with open(harvest_path, "w", encoding="utf-8") as f:
        json.dump(harvested, f, indent=2)
    return []


# =========================================================================
#  TEST EXECUTION
# =========================================================================

def run_single_test(spec_path, verbose=False, update_baselines=False,
                    lilypond="lilypond", version=None):
    """Run a single test from a JSON spec file, rendering with the lilypond
    executable for version (None: the PATH one against 2.24's baselines).

    Returns (passed_count, failed_count, total_assertion_count)
    """
    with open(spec_path, encoding="utf-8") as f:
        spec = json.load(f)

    test_name = spec.get("test_name", os.path.basename(spec_path))
    input_file = spec.get("input_file")

    # Resolve input_file relative to spec file location
    spec_dir = os.path.dirname(os.path.abspath(spec_path))
    if not os.path.isabs(input_file):
        input_file = os.path.join(spec_dir, input_file)

    if not os.path.exists(input_file):
        input_file_alt = os.path.join(PROJECT_ROOT, spec.get("input_file"))
        if os.path.exists(input_file_alt):
            input_file = input_file_alt
        else:
            print(f"\n✗ {test_name}")
            print(f"  Input file not found: {input_file}")
            return (0, 1, 1)

    print(f"\n● {test_name}")
    print(f"  Input: {input_file}")

    # Step 1: Run LilyPond
    svg_path = run_lilypond(input_file,
                            output_dir=render_dir(version) or spec_dir,
                            lilypond=lilypond)
    if not svg_path:
        print(f"  ✗ LilyPond failed")
        return (0, 1, 0)

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
            actual, assertion, elements_by_id, harvested,
            version or BASELINE_VERSION)

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

    # The version's tracked harvest is the golden baseline: drift from it
    # fails the test unless --update-baselines accepts it. An unsupported
    # version has none, and main() has warned that drift is not compared.
    harvest_dir = baseline_dir(version, spec_dir)
    if harvest_dir is None:
        return (passed, failed, len(assertions))
    os.makedirs(harvest_dir, exist_ok=True)
    harvest_path = os.path.join(
        harvest_dir,
        os.path.basename(svg_path).replace(".svg", ".harvested.json"))
    drift = save_harvest(harvested, harvest_path, update_baselines)
    if drift:
        failed += 1
        print(f"    ✗ Harvest differs from {harvest_path} (left untouched; "
              f"--update-baselines accepts an intended change):")
        for line in drift[:20]:
            print(f"        {line}")
        if len(drift) > 20:
            print(f"        ... and {len(drift) - 20} more")
    else:
        print(f"  Harvest baseline: {harvest_path}")

    return (passed, failed, len(assertions))


# =========================================================================
#  GOLDEN FILE GENERATION
# =========================================================================

def generate_golden(ly_file, output_json=None, lilypond="lilypond",
                    version=None):
    """Generate a golden harvest JSON from a .ly file.

    This is the starting point for creating test specs.
    Run on a known-good render, review the output, then write assertions.
    The render goes beside the .ly file, or into render_dir(version) for a
    version other than 2.24; by default the harvest goes to the version's
    baseline_dir (the render's folder for an unsupported version).
    """
    ly_dir = os.path.dirname(ly_file) or "."
    output_dir = render_dir(version) or ly_dir
    if output_json is None:
        json_dir = baseline_dir(version, ly_dir) or output_dir
        os.makedirs(json_dir, exist_ok=True)
        output_json = os.path.join(json_dir, os.path.basename(
            ly_file).replace(".ly", ".harvested.json"))

    print(f"Generating golden file from: {ly_file}")

    svg_path = run_lilypond(ly_file, output_dir=output_dir, lilypond=lilypond)
    if not svg_path:
        print("Failed to render SVG")
        sys.exit(1)

    harvested = harvest(svg_path)

    with open(output_json, "w", encoding="utf-8") as f:
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
    parser.add_argument("--update-baselines", action="store_true",
        help="Write regenerated harvests over the tracked ones (an intended change)")
    parser.add_argument("--lilypond-version", metavar="X.Y",
        help="Render with LilyPond X.Y (from CNB_LILYPOND_X_Y, else PATH) "
             "and compare that version's harvest baselines")

    configure_output()
    args = parser.parse_args()
    version = args.lilypond_version
    lilypond = resolve_lilypond(version) if version else "lilypond"
    if version and version not in SUPPORTED_LILYPOND_VERSIONS:
        print(f"Warning: LilyPond {version} is not supported "
              f"({', '.join(SUPPORTED_LILYPOND_VERSIONS)}); harvest drift "
              f"is not compared, assertions still run", file=sys.stderr)

    if args.generate:
        generate_golden(args.generate, lilypond=lilypond, version=version)
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
        p, f, t = run_single_test(spec_file, verbose=args.verbose,
                                  update_baselines=args.update_baselines,
                                  lilypond=lilypond, version=version)
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
