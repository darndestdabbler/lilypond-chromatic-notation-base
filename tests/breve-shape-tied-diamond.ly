\version "2.24.2"

%% A shape-mode breve as two tied semibreves, on the tutorial's diamond
%% (session 45).
%%
%% With cnb:breve-style 'tied, a breve whose resolved notehead has
%% (repeat . #f) engraves as two copies of its head, the second's left
%% edge 1 staff space after the first's right edge, and one black tie
%% below them from the first head's centre to the second's
%% (cnb:shape-mode-stencil, cnb/stencils.ly). Configurator design B.i
%% ("hollows") on the Configurator tutorial's notation (its
%% docs/playbook/tutorial/downloads/tutorial.ly): the diamond with its
%% cutout, red (#cc0000) on the C-major off-key pitch classes (C sharp
%% here) and black elsewhere, 2 semitones per staff space, lines
%% -9 -7 -5 -3 3 5 7 9 (the 3-5-7-9 staff), with the tutorial's
%% cnb:ledgers-by-semitone, at an overlap of 1/3 (which 'tied does not
%% read).
%%
%% Measure 1 is two semibreves, one head each, the reference; then a
%% breve on the staff (E5), breves on ledgers (B4, black, and C sharp 5,
%% red, its tie black) and a dotted breve (E5).

%% Rendered as before the engine's score defaults, like the other specs.
#(define cnb:score-defaults #f)
\include "ChromaticNotationBase.ly"

#(set! cnb:semitones-per-staff-space 2)
#(set! cnb:staff-line-positions '(-9 -7 -5 -3 3 5 7 9))
#(set! cnb:multinote-overlap 1/3)
#(set! cnb:breve-style 'tied)

#(define cnb:ledgers-by-semitone
   '((0 . (-13 -11)) (1 . (-11)) (2 . ()) (3 . ()) (4 . ()) (5 . ())
     (6 . ()) (7 . ()) (8 . ()) (9 . ()) (10 . ()) (11 . (-1))
     (12 . (-1 1)) (13 . (1)) (14 . ()) (15 . ()) (16 . ()) (17 . ())
     (18 . ()) (19 . ()) (20 . ()) (21 . ()) (22 . ()) (23 . (11))
     (24 . (11 13))
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

#(cnb:register-path! 'diamond '(
    (moveto 0 0.5)
    (lineto 0.75 0)
    (lineto 0 -0.5)
    (lineto -0.75 0)
    (closepath)))

#(cnb:register-hollow! 'diamond-cutout '(
    (moveto 0 0.375)
    (lineto 0.375 0)
    (lineto 0 -0.375)
    (lineto -0.375 0)
    (closepath)))

#(cnb:register-attachment! 'diamond-attach
   '((crotchet-up . (0.0867 . 0.9259)) (crotchet-down . (-0.0867 . -0.9259))
     (minim-up . (0.0867 . 0.9259)) (minim-down . (-0.0867 . -0.9259))))

#(cnb:register-color! 'fire-engine-red-cc0000 "#cc0000")
#(cnb:register-color! 'black-000000 "#000000")

#(set! cnb:get-notehead-config
   (lambda (semitone duration key)
     `((shape        . diamond)
       (color        . ,(if (memv (modulo semitone 12) '(1 3 6 8 10))
                            'fire-engine-red-cc0000
                            'black-000000))
       (hollow       . diamond-cutout)
       (attachment   . diamond-attach)
       (off-key-mark . #f)
       (repeat       . #f))))

\include "cnb/test-ids.ly"

{
  \time 2/1
  e''1 e''1 |
  e''\breve |
  b'\breve |
  cis''\breve |
  \time 3/1
  e''\breve. |
}
