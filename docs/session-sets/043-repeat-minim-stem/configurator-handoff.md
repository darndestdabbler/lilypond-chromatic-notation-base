# Configurator handoff — a repeated minim's stem on one of its heads (session 43)

**From:** `lilypond-chromatic-notation-base`, session 43 ("A repeated
minim's stem on one of its noteheads").
**To:** `chromatic-notation-configurator`: its session 72, whose preview
draws the rule and whose export writes `cnb:multinote-stem-on-head` in
repeat mode, and its session 73, whose engine round trip waits on the
release.
**Date:** 2026-11-14. **Release:** ships in engine 1.9.0 (session 44).

> **Cross-repo rule of engagement (unchanged since set 005):** export-spec
> changes are authored **Configurator-side** from this record. This
> session does not touch the Configurator's LY export spec. This file is
> the engine-contract source of truth for that work.

**The name is the engine's.** Configurator session 72 was to settle the
setting's name and value and write a brief for this session, but it had
not run when this session started. By the operator's decision of
2026-11-14 the engine named the setting: one boolean. A centred stem
follows the same rule as a side stem, with no side chosen once.
Configurator session 72 writes this name and value.

---

## 1. The rule

| | |
|---|---|
| Setting | `#(set! cnb:multinote-stem-on-head #t)` after the include, `#t` or `#f` |
| Default | `#f`: a repeated minim's attachment point is read across the whole group of heads, exactly as in 1.8.0 |
| `#t` | a repeated minim's stem attaches to one head of its group as a single head's stem does: the **last** head when the stem is up, the **first** when it is down |
| Centred stem | the same rule: a point at x = 0 stands on the centre of the chosen head |
| Applies when | the setting is `#t`, the resolved config's `repeat` is not `#f`, and the note is a minim (duration log 1) |
| Point used | the config's `minim-up` or `minim-down` point, as before; only where it lands changes |

### The formula

The minim's stencil is two copies of the head, the second starting s after
the first ([`cnb:build-duration-stencil`](../../../cnb/stencils.ly#L173)):

| Overlap | s |
|---|---|
| a number | (1 − overlap) × w |
| `#f` | w + `cnb:multinote-padding` |

Here w is one head's X width (its stencil extent), and the group is s + w
wide. A point (x . y) in the head's normalised coordinates (±1 = the
head's edges) goes on head k (k = 1 for the last head, stem up; k = 0 for
the first, stem down) and is handed to LilyPond in the group's
coordinates as

    x' = (2ks + w(1 + x)) / (s + w) − 1,   y' = y

([`cnb:stem-on-head`](../../../cnb/stems.ly)). A point at the head's
outer edge stays at the group's outer edge (x = 1 up and x = −1 down give
x' = x), so a side stem lands where it did before.

**One correction for a centred point.** LilyPond moves a stem whose
attachment x is not 0 by half its thickness toward the head, and leaves a
stem at x = 0 centred (Stem's offset callback). A crotchet's centred stem
is therefore centred on its head. The minim's x' is not 0, so the engine
adds dir × t / W to it, where t is the stem's thickness, W the group's
X width (both as engraved) and dir +1 up, −1 down. That cancels LilyPond's
move, and the minim's centred stem is centred on its head as the
crotchet's is. Any point whose x is not 0 is moved by LilyPond on the
crotchet and the minim alike, so it needs no correction. The preview should
draw the same thing: the stem stands on the chosen head where the
crotchet's stands on its one head.

**Unchanged:** crotchets and shorter; a single head (`repeat` `#f`); every
note with the setting `#f`; the stem's y, its length and its far end
(still LilyPond's standard length from the head's centre); the repeated
stencils, their overlap, padding and cache; semibreves and longer, which
have no stem. A file without the setting engraves byte-identically.

**Needs engine 1.9.0.** A file that sets `cnb:multinote-stem-on-head`
fails on an older engine (the variable is unbound there).

---

## 2. Measured stems at an overlap of 1/3

Measured 2026-11-14 with a probe outside the tree that reads each stem
when it is drawn. **Identical on LilyPond 2.24.2 and 2.26.0.** Units are
staff spaces before magnification. x = 0 is the first head's centre (its
path's origin) and y = 0 the head's centre line. A stem is 0.13 wide
(1.3 × the 0.1 staff line). Semitones are staff spaces × the notation's
semitones per staff space. Every note has `repeat` on,
`cnb:multinote-overlap 1/3` and `cnb:multinote-stem-on-head #t`. Each
minim's ends are its crotchet's.

### The default Configurator notehead (4 semitones per staff space)

The Default 4-8 System export's `crotchet-minim` head, solid, with its side
attachment `(1 . 0.3157)` up and `(-1 . -0.3157)` down. One head is
−0.4311 .. 0.4311, the minim's group −0.4311 .. 1.0059 (s = 0.5748).

| Note | Stem | x (ss) | x (semitones) | Ends y (ss) | Ends y (semitones) |
|---|---|---|---|---|---|
| Crotchet | up | 0.3011 .. 0.4311 | 1.2043 .. 1.7243 | 0.1075 .. 3.3333 | 0.430 .. 13.333 |
| Minim | up, on the last head | 0.8759 .. 1.0059 | 3.5035 .. 4.0235 | 0.1075 .. 3.3333 | 0.430 .. 13.333 |
| Crotchet | down | −0.4311 .. −0.3011 | −1.7245 .. −1.2045 | −3.3333 .. −0.1075 | −13.333 .. −0.430 |
| Minim | down, on the first head | −0.4311 .. −0.3011 | −1.7245 .. −1.2045 | −3.3333 .. −0.1075 | −13.333 .. −0.430 |

A side stem lands at the group's outer edge, where it did with the
setting `#f`.

### Kite 4-369 (3 semitones per staff space)

`kite-4-369-from-configurator.ly`, kite-up and kite-down alike. One head
is −0.6668 .. 0.6668 (w = 1.3335), the minim's group −0.6668 .. 1.5558
(s = 0.8890). Its last head's centre is at 0.8890.

**With its exported points:** crotchets `(0 . 0.9)` up and `(0 . -0.9)`
down, minims `(-0.365 . 0.9)` up and `(0.365 . -0.9)` down. The minim
points were set for placement across the group, so on one head the stem
stands 0.3084 off the head's centre, toward the other head:

| Note | Stem | x (ss) | centre (ss) | x (semitones) | Ends y (ss) | Ends y (semitones) |
|---|---|---|---|---|---|---|
| Crotchet | up | −0.0650 .. 0.0650 | 0 | −0.195 .. 0.195 | 0.6001 .. 3.5 | 1.800 .. 10.5 |
| Minim | up, on the last head | 0.5156 .. 0.6456 | 0.5806 | 1.5469 .. 1.9369 | 0.6001 .. 3.5 | 1.800 .. 10.5 |
| Crotchet | down | −0.0650 .. 0.0650 | 0 | −0.195 .. 0.195 | −3.5 .. −0.6001 | −10.5 .. −1.800 |
| Minim | down, on the first head | 0.2434 .. 0.3734 | 0.3084 | 0.7301 .. 1.1201 | −3.5 .. −0.6001 | −10.5 .. −1.800 |

**With its minim points set to its crotchet points,** `(0 . 0.9)` and
`(0 . -0.9)`, the minim's stem is centred on its head:

| Note | Stem | x (ss) | centre (ss) | x (semitones) | Ends y (ss) |
|---|---|---|---|---|---|
| Minim | up, on the last head | 0.8240 .. 0.9540 | 0.8890 | 2.4720 .. 2.8620 | 0.6001 .. 3.5 |
| Minim | down, on the first head | −0.0650 .. 0.0650 | 0 | −0.195 .. 0.195 | −3.5 .. −0.6001 |

Which minim points a repeat-mode export writes is the Configurator's
choice. The engine places whichever it is given by the formula above.

### The tutorial's diamonds (2 semitones per staff space)

The diamond of the Configurator's
`docs/playbook/tutorial/downloads/tutorial.ly` (1.5 wide, 1 tall), solid,
with its attachment `(0.0867 . 0.9259)` up and `(-0.0867 . -0.9259)`
down. The tutorial itself has `repeat` `#f`; here it is on. One head is
−0.7500 .. 0.7500, the minim's group −0.7500 .. 1.7501 (s = 1.0001), and
the last head's centre is at 1.0001.

| Note | Stem | x (ss) | centre (ss) | x (semitones) | Ends y (ss) | Ends y (semitones) |
|---|---|---|---|---|---|---|
| Crotchet | up | −0.0650 .. 0.0650 | 0 | −0.130 .. 0.130 | 0.4630 .. 3.5 | 0.926 .. 7.0 |
| Minim | up, on the last head | 0.9351 .. 1.0651 | 1.0001 | 1.8702 .. 2.1302 | 0.4630 .. 3.5 | 0.926 .. 7.0 |
| Crotchet | down | −0.0650 .. 0.0650 | 0 | −0.130 .. 0.130 | −3.5 .. −0.4630 | −7.0 .. −0.926 |
| Minim | down, on the first head | −0.0650 .. 0.0650 | 0 | −0.130 .. 0.130 | −3.5 .. −0.4630 | −7.0 .. −0.926 |

With the setting `#f` (measured on 2.24) the minim's stems stood near the
group's centre (0.5000), in the notch between the two diamonds: up at
0.4784 .. 0.6084, down at 0.3917 .. 0.5217.

---

## 3. Verification status

- `engine-unit` and `engine-unit-2.26`: 530 assertions, all passing,
  including `cnb:stem-on-head` for a side and a centred point, up and
  down, at an overlap of 1/3 and `#f`, and `cnb:repeated-minim-head-width`.
- `engine-integration` and `engine-integration-2.26`: 441 assertions, all
  passing. The new spec `tests/stem-repeat-minim` engraves the default
  head and a centred diamond at 1/3, up and down: each minim's stem stands
  on its chosen head where the crotchet's stands on its one head. No other
  golden or harvest changed.
- Engine 1.9.0 is released by session 44.
