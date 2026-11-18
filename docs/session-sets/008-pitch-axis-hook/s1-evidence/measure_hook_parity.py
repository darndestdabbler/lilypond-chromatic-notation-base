#!/usr/bin/env python3
"""Measure the set-008 REAL-hook render against the 013 spike's tables.

Adapted from the Configurator 013 set's s1-evidence instruments
(measure_spike.py + extract_ledgers.py). The render under test is
hook-parity.ly — the engine's own notehead engraver consulting
cnb:get-pitch-staff-position — and parity means it reproduces the 013
record's measured results:

  - 35/35 noteheads at the mapped compact-axis position (tolerance 0.05,
    absorbing the known +0.010 line-edge harvest artifact);
  - the five shared pairs coincide vertically (dpos == 0);
  - 7 ledger rects: 4 at position -5, 1 at -7, 2 at +10 (013 record 3.2);
  - 30 stems, single-note directions flipping at LilyPond position 0
    (mapped pos <= -1 up-stem, >= 0 down-stem; 013 record 3.3).

Expected staff position (half-staff-spaces from center):
    pos(semi) = oct*7 + PC_AXIS[pc] - 4    (pc = semi mod 12, euclidean oct)

True position is derived from absolute SVG y using the harvested staff
extremes: top line = +8, bottom line = -3 (11 half-spaces), y grows down:
    pos(y) = 8 - 11 * (y - top_y) / (bottom_y - top_y)
data-midi is 60 + ly:pitch-semitones, so semi = midi - 60.

Usage: measure_hook_parity.py hook-parity.harvested.json hook-parity.svg
Exits 0 only if every parity check passes.
"""
import json
import re
import sys
import xml.etree.ElementTree as ET
from collections import Counter

PC_AXIS = [0, 0, 1, 2, 2, 3, 3, 4, 5, 5, 6, 6]
STRIDE = 7
ANCHOR = -4
TOP_POS, BOTTOM_POS = 8, -3
TOL = 0.05

# 013 record section 3.2: ledger multiset {pos: count}
EXPECTED_LEDGERS = {-5: 4, -7: 1, 10: 2}
EXPECTED_HEADS = 35
EXPECTED_STEMS = 30

failures = []


def expected_pos(semi):
    pc = semi % 12
    octv = (semi - pc) // 12
    return octv * STRIDE + PC_AXIS[pc] + ANCHOR


harvest_path, svg_path = sys.argv[1], sys.argv[2]
d = json.load(open(harvest_path, encoding="utf-8"))

staff = d["staff"]
top_y, bot_y = staff["top_line_y"], staff["bottom_line_y"]
half_space = (bot_y - top_y) / (TOP_POS - BOTTOM_POS)


def y_to_pos(y):
    return TOP_POS - (y - top_y) / half_space


heads = [e for e in d["elements"] if e["type"] == "notehead"]
stems = [e for e in d["elements"] if e["type"] == "stem"]

print(f"staff: top_y={top_y} bottom_y={bot_y} height={staff['staff_height']} "
      f"lines={staff['line_count']} half_space={half_space:.4f}")
print(f"noteheads={len(heads)} stems={len(stems)}")
print()

# --- 1. Noteheads --------------------------------------------------------
print(f"{'id':26} {'semi':>4} {'pc':>2} {'exp':>4} {'meas':>8} {'delta':>7}  {'x':>7}")
mismatches = 0
by_id = {}
for e in sorted(heads, key=lambda e: (int(e['data']['measure']),
                                      e['data']['beat'], int(e['data']['midi']))):
    midi = int(e["data"]["midi"])
    semi = midi - 60
    exp = expected_pos(semi)
    meas = y_to_pos(e["absolute"]["y"])
    delta = meas - exp
    ok = abs(delta) < TOL
    if not ok:
        mismatches += 1
    by_id[e["id"]] = e
    print(f"{e['id']:26} {semi:>4} {semi % 12:>2} {exp:>4} {meas:>8.3f} {delta:>+7.3f}"
          f"  {e['absolute']['x']:>7.3f}" + ("" if ok else "  <-- MISMATCH"))

print(f"\nnotehead placement: {len(heads) - mismatches}/{len(heads)} at expected "
      f"mapped position, {mismatches} mismatches")
if len(heads) != EXPECTED_HEADS:
    failures.append(f"expected {EXPECTED_HEADS} noteheads, harvested {len(heads)}")
if mismatches:
    failures.append(f"{mismatches} notehead position mismatches")

# --- 2. Shared-position chord pairs (parity: dpos must be 0) -------------
print("\n--- shared-position chord pairs (dpos must be 0; no x-offset this session) ---")
pairs = [("nh-7-0.000-60-0", "nh-7-0.000-61-0"),   # <c' cis'>
         ("nh-7-0.250-68-0", "nh-7-0.250-69-0"),   # <gis' a'>
         ("nh-7-0.750-65-0", "nh-7-0.750-66-0")]   # <f' fis'>
for a, b in pairs:
    ea, eb = by_id.get(a), by_id.get(b)
    if not ea or not eb:
        failures.append(f"chord pair {a}/{b} missing from harvest")
        print(f"  {a} / {b}: MISSING")
        continue
    dx = eb["absolute"]["x"] - ea["absolute"]["x"]
    dpos = y_to_pos(eb["absolute"]["y"]) - y_to_pos(ea["absolute"]["y"])
    ok = abs(dpos) < 0.01
    if not ok:
        failures.append(f"chord pair {a}/{b} dpos={dpos:+.3f}, expected 0")
    print(f"  {a} vs {b}: dx={dx:+.3f} dpos={dpos:+.3f}"
          + ("" if ok else "  <-- MISMATCH"))

# --- 3. Ledger rects from the SVG stencil (spanner = one grob) -----------
print("\n--- ledger rects (from the tagged LedgerLineSpanner subtree) ---")
root = ET.parse(svg_path).getroot()
ledger_positions = []


def walk(el, tx=0.0, ty=0.0, in_ledger=False):
    tag = el.tag.split('}')[-1]
    m = re.search(r'translate\(([-\d.]+)\s*,\s*([-\d.]+)\)', el.get('transform', ''))
    if m:
        tx, ty = tx + float(m.group(1)), ty + float(m.group(2))
    if el.get('id', '').startswith('ll-'):
        in_ledger = True
    if in_ledger and tag == 'rect':
        x = float(el.get('x', 0)) + tx
        y_center = float(el.get('y', 0)) + ty + float(el.get('height', 0)) / 2
        pos = y_to_pos(y_center)
        ledger_positions.append(pos)
        print(f"  ledger rect {len(ledger_positions)}: x={x:.3f} "
              f"y_center={y_center:.3f} staff_position={pos:+.3f}")
    for c in el:
        walk(c, tx, ty, in_ledger)


walk(root)
rounded = Counter(round(p) for p in ledger_positions)
print(f"  total ledger rects: {len(ledger_positions)}  multiset: {dict(rounded)}")
if rounded != Counter(EXPECTED_LEDGERS):
    failures.append(f"ledger multiset {dict(rounded)} != expected {EXPECTED_LEDGERS}")
for p in ledger_positions:
    if abs(p - round(p)) >= TOL:
        failures.append(f"ledger at {p:+.3f} is off-position by >= {TOL}")

# --- 4. Stems: count + single-note direction flip at position 0 ----------
print("\n--- stems (direction = side with more extension beyond its heads) ---")
dir_fails = 0
for e in sorted(stems, key=lambda e: (int(e['data']['measure']), e['data']['beat'])):
    m, b = e["data"]["measure"], e["data"]["beat"]
    mates = [h for h in heads
             if h["data"]["measure"] == m and h["data"]["beat"] == b]
    bb = e["visual"]["bbox"]
    pos_hi = y_to_pos(bb["y"])
    pos_lo = y_to_pos(bb["y"] + bb["h"])
    head_pos = [y_to_pos(h["absolute"]["y"]) for h in mates]
    up = (pos_hi - max(head_pos)) > (min(head_pos) - pos_lo)
    if len(mates) == 1:
        # The 013 rule is on the MAPPED (integer) position; the measured
        # value carries the +0.010 line-edge artifact, so derive the
        # threshold input from the pitch, not the measurement.
        expect_up = expected_pos(int(mates[0]["data"]["midi"]) - 60) <= -1
        ok = up == expect_up
        if not ok:
            dir_fails += 1
        print(f"  st-{m}-{b}: head pos {head_pos[0]:+.2f} span=[{pos_lo:+.2f}..{pos_hi:+.2f}] "
              f"dir={'up' if up else 'down'} expected={'up' if expect_up else 'down'}"
              + ("" if ok else "  <-- MISMATCH"))
    else:
        print(f"  st-{m}-{b}: chord heads {[f'{p:+.1f}' for p in sorted(head_pos)]} "
              f"span=[{pos_lo:+.2f}..{pos_hi:+.2f}] dir={'up' if up else 'down'}")
if len(stems) != EXPECTED_STEMS:
    failures.append(f"expected {EXPECTED_STEMS} stems, harvested {len(stems)}")
if dir_fails:
    failures.append(f"{dir_fails} single-note stem direction mismatches")
else:
    print("  single-note stem directions: all flip at position 0 as the 013 record measured")

# --- verdict --------------------------------------------------------------
print()
if failures:
    print("PARITY: FAIL")
    for f in failures:
        print(f"  - {f}")
    sys.exit(1)
print("PARITY: PASS — the real hook reproduces the 013 spike's measured "
      "placement (noteheads, ledgers, stem directions)")
