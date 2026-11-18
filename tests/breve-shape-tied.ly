\version "2.24.2"

%% A shape-mode breve as two tied semibreves (session 45).
%%
%% With cnb:breve-style 'tied, a breve whose resolved notehead has
%% (repeat . #f) engraves as two copies of its head, the second's left
%% edge 1 staff space after the first's right edge, and one black tie
%% below them from the first head's centre to the second's
%% (cnb:shape-mode-stencil, cnb/stencils.ly). Configurator design B.i
%% ("hollows"): the Configurator's default notehead (crotchet-minim) with
%% the cutout its default export writes, black, on its default staff of
%% 4 semitones per staff space, lines -4 -2 2 4 (the 4-8 staff), with the
%% default export's cnb:ledgers-by-semitone, at an overlap of 1/3 (which
%% 'tied does not read).
%%
%% Measure 1 is two semibreves, one head each, the reference; then a
%% breve on the staff (E5), breves on ledgers (C5 and D5) and a dotted
%% breve (E5).

%% Rendered as before the engine's score defaults, like the other specs.
#(define cnb:score-defaults #f)
\include "ChromaticNotationBase.ly"

#(set! cnb:semitones-per-staff-space 4)
#(set! cnb:staff-line-positions '(-4 -2 2 4))
#(set! cnb:multinote-overlap 1/3)
#(set! cnb:breve-style 'tied)

#(define cnb:ledgers-by-semitone
   '((0 . (-6)) (1 . (-6)) (2 . (-6 -5)) (3 . ()) (4 . ()) (5 . ())
     (6 . ()) (7 . ()) (8 . ()) (9 . ()) (10 . (-1)) (11 . ())
     (12 . (0)) (13 . (0)) (14 . (0 1)) (15 . ()) (16 . ()) (17 . ())
     (18 . ()) (19 . ()) (20 . ()) (21 . ()) (22 . (5)) (23 . ())
     (24 . (6))
     ))
#(define (cnb:ledgers-of grob)
   (assv (ly:pitch-semitones (ly:event-property (event-cause grob) 'pitch))
         cnb:ledgers-by-semitone))
\layout {
  \context {
    \Voice
    \override NoteHead.ledger-positions =
      #(lambda (grob) (let ((e (cnb:ledgers-of grob))) (if e (cdr e) '())))
    \override NoteHead.no-ledgers =
      #(lambda (grob) (let ((e (cnb:ledgers-of grob))) (and e (null? (cdr e)))))
  }
}

#(cnb:register-path! 'crotchet-minim '(
    (moveto 0.4089 0.2039)
    (curveto 0.484 0.0533 0.3618 -0.16 0.1359 -0.2727)
    (curveto -0.09 -0.3853 -0.334 -0.3545 -0.4091 -0.2039)
    (curveto -0.4451 -0.1316 -0.4366 -0.0408 -0.3854 0.0486)
    (curveto -0.3342 0.138 -0.2445 0.2186 -0.136 0.2727)
    (curveto -0.0275 0.3268 0.0908 0.3499 0.193 0.337)
    (curveto 0.2952 0.3241 0.3729 0.2762 0.4089 0.2039)
    (closepath)))

#(cnb:register-hollow! 'crotchet-minim-cutout '(
    (moveto 0.3408 0.1699)
    (curveto 0.3886 0.0808 0.226 -0.0439 0.0618 -0.1255)
    (curveto -0.1023 -0.207 -0.2914 -0.2636 -0.3409 -0.1699)
    (curveto -0.3904 -0.0763 -0.2392 0.0378 -0.0623 0.1259)
    (curveto 0.1145 0.214 0.293 0.2591 0.3408 0.1699)
    (closepath)))

#(cnb:register-attachment! 'crotchet-minim-attach
   '((crotchet-up . (1 . 0.3157)) (crotchet-down . (-1 . -0.3157))
     (minim-up . (1 . 0.3157)) (minim-down . (-1 . -0.3157))))

#(set! cnb:get-notehead-config
   (lambda (semitone duration key)
     `((shape        . crotchet-minim)
       (color        . ,cnb:black)
       (hollow       . crotchet-minim-cutout)
       (attachment   . crotchet-minim-attach)
       (off-key-mark . #f)
       (repeat       . #f))))

\include "cnb/test-ids.ly"

{
  \time 2/1
  e''1 e''1 |
  e''\breve |
  c''\breve |
  d''\breve |
  \time 3/1
  e''\breve. |
}
