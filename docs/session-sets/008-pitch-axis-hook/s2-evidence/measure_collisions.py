#!/usr/bin/env python3
"""Measure the set-008 session-2 multi-voice collision cases (backlog 6.5/E13-5).

Observation instrument for collision-cases.ly: two voices on the compact
axis (the 013 spike's map), cross-voice simultaneities at axis distances
0, 1, 2, 4, 7, plus a shared-position pair whose sharper member carries
the +0.85 x-offset, and a shared-pair chord in voice 1.

With the 6.2 mechanism landed, NoteCollision/Stem meshing runs on the
PLACED axis geometry (Stem::note_head_positions reads rounded geometric
positions), and cnb:collision-threshold (default 2) is compared against
AXIS-space distances in half-staff-spaces.

Hard sanity assertions (exit 0 only if all pass):
  1. every expected notehead is present at its mapped axis position
     (tolerance 0.05) — a missing head means LilyPond MERGED (suicided)
     a cross-voice pair member: pitch loss on a many-to-one axis;
  2. the axis-distance-0 pairs (m1 b1 cis'/c', m1 b2 a'/gis') keep
     visible horizontal separation (|dx| >= 0.3 staff spaces);
  3. verticals exact for every head (the collision machinery must not
     move anything vertically).

Everything else (column shift amounts per axis distance, stem
directions) is printed as the observation table for the change-log.

Usage: measure_collisions.py collision-cases.harvested.json
"""
import json
import sys

TOP_POS, BOTTOM_POS = 8, -3
TOL = 0.05

# (measure, beat) -> list of (voice-sorted) expected entries:
#   (label, midi, expected axis position, has-offset)
EXPECTED = {
    (1, 0.00): [("cis'", 61, -4, True),  ("c'", 60, -4, False)],
    (1, 0.25): [("a'",   69,  1, True),  ("gis'", 68, 1, False)],
    (1, 0.50): [("d'",   62, -3, False), ("c'", 60, -4, False)],
    (1, 0.75): [("e'",   64, -2, False), ("c'", 60, -4, False)],
    (2, 0.00): [("g'",   67,  0, False), ("c'", 60, -4, False)],
    (2, 0.25): [("dis'", 63, -2, False), ("cis'", 61, -4, True)],
    (2, 0.50): [("c''",  72,  3, False), ("c'", 60, -4, False)],
    (2, 0.75): [("gis'", 68,  1, False), ("a'", 69, 1, True), ("c'", 60, -4, False)],
}
SEPARATION_BEATS = [(1, 0.00), (1, 0.25)]  # axis-distance-0 pairs

failures = []

d = json.load(open(sys.argv[1], encoding="utf-8"))
staff = d["staff"]
top_y, bot_y = staff["top_line_y"], staff["bottom_line_y"]
half_space = (bot_y - top_y) / (TOP_POS - BOTTOM_POS)


def y_to_pos(y):
    return TOP_POS - (y - top_y) / half_space


heads = [e for e in d["elements"] if e["type"] == "notehead"]
stems = [e for e in d["elements"] if e["type"] == "stem"]
n_expected = sum(len(v) for v in EXPECTED.values())
print(f"noteheads harvested: {len(heads)} (expected {n_expected}); stems: {len(stems)}")
if len(heads) != n_expected:
    failures.append(
        f"{n_expected - len(heads)} notehead(s) missing — cross-voice merge "
        f"(pitch loss) or harvest failure")

by_key = {}
for e in heads:
    k = (int(e["data"]["measure"]), round(float(e["data"]["beat"]), 2),
         int(e["data"]["midi"]))
    by_key[k] = e

print(f"\n{'beat':10} {'note':5} {'midi':>4} {'exp':>4} {'meas':>8} "
      f"{'x':>8} {'voice':>6}  offset?")
for (m, b), entries in sorted(EXPECTED.items()):
    xs = {}
    for label, midi, exp, has_off in entries:
        e = by_key.get((m, b, midi))
        if not e:
            failures.append(f"m{m} b{b} {label} (midi {midi}): MISSING from render")
            print(f"m{m}-{b:<7} {label:5} {midi:>4} {exp:>4} {'MISSING':>8}")
            continue
        meas = y_to_pos(e["absolute"]["y"])
        x = e["absolute"]["x"]
        xs[label] = x
        if abs(meas - exp) >= TOL:
            failures.append(
                f"m{m} b{b} {label}: vertical {meas:+.3f} != expected {exp:+d}")
        print(f"m{m}-{b:<7} {label:5} {midi:>4} {exp:>4} {meas:>+8.3f} "
              f"{x:>8.3f} {e['data']['voice']:>6}  {'+0.85' if has_off else ''}")
    if len(xs) >= 2:
        labels = [en[0] for en in entries if en[0] in xs]
        pairs = [(labels[i], labels[j])
                 for i in range(len(labels)) for j in range(i + 1, len(labels))]
        for a, bl in pairs:
            print(f"{'':10} dx({a} vs {bl}) = {xs[a] - xs[bl]:+.3f}")
        if (m, b) in SEPARATION_BEATS:
            a, bl = labels[0], labels[1]
            if abs(xs[a] - xs[bl]) < 0.3:
                failures.append(
                    f"m{m} b{b}: shared-position pair {a}/{bl} separation "
                    f"{xs[a] - xs[bl]:+.3f} < 0.3 — visually indistinguishable")

print("\nstems (x, direction by bbox extension):")
for e in sorted(stems, key=lambda e: (int(e["data"]["measure"]),
                                      float(e["data"]["beat"]),
                                      e["data"]["voice"])):
    m, b = e["data"]["measure"], e["data"]["beat"]
    bb = e["visual"]["bbox"]
    print(f"  st-{m}-{b} v{e['data']['voice']}: x={e['absolute']['x']:8.3f} "
          f"span_pos=[{y_to_pos(bb['y'] + bb['h']):+.2f}..{y_to_pos(bb['y']):+.2f}]")

print()
if failures:
    print("COLLISION OBSERVATION: FAIL")
    for f in failures:
        print(f"  - {f}")
    sys.exit(1)
print("COLLISION OBSERVATION: PASS — all heads present at mapped positions, "
      "shared-position cross-voice pairs visibly separated, verticals exact")
