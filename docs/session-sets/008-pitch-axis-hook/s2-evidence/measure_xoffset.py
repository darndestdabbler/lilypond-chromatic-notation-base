#!/usr/bin/env python3
"""Measure the set-008 session-2 x-offset acceptance cases (backlog 6.2/E13-2).

Diffs the offset render (xoffset-cases.ly, +0.85 staff spaces on the
sharper member of each shared pair, pcs {1,4,6,9,11}) against the
byte-identical control (xoffset-cases-ctrl.ly, xoff:amount 0.0 = field
omitted), adapting the Configurator 013 set's xoffset_control_diff.py.

Hard acceptance assertions (exit 0 only if all pass):
  1. every notehead/stem matches 1:1 across renders, verticals identical
     (the x-offset field must not move anything vertically);
  2. single notes: each column's stem moves exactly with its head
     (dx_stem == dx_head) — head AND stem move together;
  3. single-note dx increments within a measure: each offset column adds
     exactly +0.85 over the previous column and each non-offset column
     adds 0 — the offset head moves +0.85 inside its column AND pushes
     later columns +0.85 right (spacing accounts for the moved extent).
     Measure boundaries are reported but not asserted: LilyPond's
     elastic barline spacing redistributes slack there (measured -0.10
     at one boundary in both mechanism candidates' renders), which is
     spacing elasticity, not offset loss;
  4. chord separations (offset minus control):
       <c' cis'>  (same diatonic step, unison-treated)   +0.85
       <gis' a'>  (ADJACENT diatonic steps — absorbed in
                   the 013 spike, the 6.2 acceptance case) +0.85
       <f' fis'>  (same diatonic step)                    +0.85
       <c' g'>    (spanning control, no offset member)     0.00
  5. ledger rects under the offset below-staff heads (m5: b pc11, a pc9)
     follow the moved heads horizontally.

Usage: measure_xoffset.py xoffset-cases.harvested.json \
           xoffset-cases-ctrl.harvested.json \
           xoffset-cases.svg xoffset-cases-ctrl.svg
"""
import json
import re
import sys
import xml.etree.ElementTree as ET

XOFF = 0.85
XOFF_PCS = {1, 4, 6, 9, 11}
TOL_X = 0.02      # spacing tolerance (013 measured exact to 3 decimals)
TOL_Y = 0.005     # verticals must be identical

failures = []


def load(p):
    d = json.load(open(p, encoding="utf-8"))
    return d, {e["id"]: e for e in d["elements"]}


doff, off = load(sys.argv[1])
dctl, ctl = load(sys.argv[2])

# staff geometry (for reporting x in staff-space units it already is)
heads_off = sorted(
    (e for e in off.values() if e["type"] == "notehead"),
    key=lambda e: (int(e["data"]["measure"]), float(e["data"]["beat"]),
                   int(e["data"]["midi"])))

# --- 0. match + verticals -------------------------------------------------
if set(off) != set(ctl):
    only_o = sorted(set(off) - set(ctl))
    only_c = sorted(set(ctl) - set(off))
    failures.append(f"element id mismatch: only-offset={only_o} only-ctrl={only_c}")

for e in heads_off:
    c = ctl.get(e["id"])
    if not c:
        continue
    dy = e["absolute"]["y"] - c["absolute"]["y"]
    if abs(dy) > TOL_Y:
        failures.append(f"{e['id']}: vertical moved dy={dy:+.4f}")

# --- 1. single notes: dx table + stem-follows-head + cumulative model -----
# group heads by column (measure, beat); chords = columns with >1 head
cols = {}
for e in heads_off:
    key = (int(e["data"]["measure"]), float(e["data"]["beat"]))
    cols.setdefault(key, []).append(e)

CHORD_MEASURE = 4
print(f"{'id':24} {'pc':>2} {'dx_head':>8} {'dx_stem':>8} {'incr':>7} {'exp':>6}  note")
single_fails = 0
prev_dx, prev_measure = None, None
m5_dxs = []  # m5 head movements — the ledger rects must follow these
for key in sorted(cols):
    m, b = key
    members = cols[key]
    if m == CHORD_MEASURE:
        prev_dx, prev_measure = None, None  # chords break the chain
        continue  # chords handled below
    e = members[0]
    c = ctl[e["id"]]
    pc = (int(e["data"]["midi"]) - 60) % 12
    is_off = pc in XOFF_PCS
    dxh = e["absolute"]["x"] - c["absolute"]["x"]
    stem_id = f"st-{m}-{e['data']['beat']}-{e['data']['voice']}"
    es, cs = off.get(stem_id), ctl.get(stem_id)
    dxs = es["absolute"]["x"] - cs["absolute"]["x"] if es and cs else None

    # stem must move exactly with its head (single-note column)
    stem_ok = dxs is None or abs(dxs - dxh) < TOL_X

    # within-measure spacing increment: +0.85 for an offset column,
    # 0 for a non-offset column; measure boundaries report-only
    incr = None if prev_dx is None else dxh - prev_dx
    expected_incr = XOFF if is_off else 0.0
    same_measure = prev_measure == m
    incr_ok = (incr is None) or (not same_measure) \
        or abs(incr - expected_incr) < TOL_X
    ok = stem_ok and incr_ok
    if not ok:
        single_fails += 1
    print(f"{e['id']:24} {pc:>2} {dxh:>+8.3f} "
          f"{(f'{dxs:+8.3f}' if dxs is not None else '    none'):>8} "
          f"{(f'{incr:+7.3f}' if incr is not None else '      -')} "
          f"{expected_incr:>6.2f}"
          f"  {'offset pc' if is_off else ''}"
          f"{'' if same_measure or incr is None else ' [measure boundary]'}"
          + ("" if ok else "  <-- MISMATCH"))
    prev_dx, prev_measure = dxh, m
    if m == 5:
        m5_dxs.append(dxh)

if single_fails:
    failures.append(f"{single_fails} single-note mismatches "
                    f"(head+stem joint movement / within-measure spacing increments)")
else:
    print("single notes: every offset head+stem moved +0.85 together and "
          "pushed later columns +0.85 within the measure, 0 mismatches")

# --- 2. chord separations --------------------------------------------------
print("\nchord-internal separations (head-to-head dx within one chord):")
CHORDS = [
    ("<c' cis'>  same diatonic step",      "nh-4-0.000-60-0", "nh-4-0.000-61-0", XOFF),
    ("<gis' a'>  ADJACENT diatonic steps", "nh-4-0.250-68-0", "nh-4-0.250-69-0", XOFF),
    ("<c' g'>    spanning control",        "nh-4-0.500-60-0", "nh-4-0.500-67-0", 0.0),
    ("<f' fis'>  same diatonic step",      "nh-4-0.750-65-0", "nh-4-0.750-66-0", XOFF),
]
for label, a, b, expected in CHORDS:
    if a not in off or b not in off or a not in ctl or b not in ctl:
        failures.append(f"chord {label}: missing heads in a render")
        print(f"  {label:36} MISSING")
        continue
    so = off[b]["absolute"]["x"] - off[a]["absolute"]["x"]
    sc = ctl[b]["absolute"]["x"] - ctl[a]["absolute"]["x"]
    eff = so - sc
    ok = abs(eff - expected) < TOL_X
    if not ok:
        failures.append(f"chord {label}: offset effect {eff:+.3f}, expected {expected:+.2f}")
    print(f"  {label:36} sep(offset)={so:+.3f} sep(control)={sc:+.3f} "
          f"effect={eff:+.3f} expected={expected:+.2f}"
          + ("" if ok else "  <-- MISMATCH"))

# --- 3. ledgers follow offset heads (m5) ------------------------------------
def ledger_rects(svg_path):
    root = ET.parse(svg_path).getroot()
    rects = []

    def walk(el, tx=0.0, ty=0.0, in_ledger=False):
        tag = el.tag.split("}")[-1]
        mm = re.search(r"translate\(([-\d.]+)\s*,\s*([-\d.]+)\)",
                       el.get("transform", ""))
        if mm:
            tx, ty = tx + float(mm.group(1)), ty + float(mm.group(2))
        if el.get("id", "").startswith("ll-"):
            in_ledger = True
        if in_ledger and tag == "rect":
            rects.append((float(el.get("x", 0)) + tx,
                          float(el.get("y", 0)) + ty
                          + float(el.get("height", 0)) / 2))
        for ch in el:
            walk(ch, tx, ty, in_ledger)

    walk(root)
    return sorted(rects)


lo, lc = ledger_rects(sys.argv[3]), ledger_rects(sys.argv[4])
print(f"\nledger rects: offset render {len(lo)}, control {len(lc)}")
if len(lo) != len(lc):
    failures.append(f"ledger rect count differs: {len(lo)} vs {len(lc)}")
else:
    for i, ((xo, yo), (xc, yc)) in enumerate(zip(lo, lc), 1):
        dx = xo - xc
        follows = any(abs(dx - d) < TOL_X for d in m5_dxs)
        print(f"  rect {i}: x {xc:8.3f} -> {xo:8.3f}  (dx={dx:+.3f})  "
              f"y_center {yo:.3f}" + ("" if follows else "  <-- MISMATCH"))
        if abs(yo - yc) > TOL_Y:
            failures.append(f"ledger rect {i} moved vertically")
        if not follows:
            failures.append(f"ledger rect {i} dx={dx:+.3f} matches no m5 head movement")

# --- verdict ----------------------------------------------------------------
print()
if failures:
    print("X-OFFSET ACCEPTANCE: FAIL")
    for f in failures:
        print(f"  - {f}")
    sys.exit(1)
print("X-OFFSET ACCEPTANCE: PASS — single notes (head+stem+spacing), the "
      "unison-treated pair, and the diatonic-second pair all honor "
      "(x-offset . 0.85); verticals untouched")
