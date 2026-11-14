\version "2.24.2"

%% A repeated minim's stem on one of its heads (session 43).
%%
%% With cnb:multinote-stem-on-head #t, cnb:stem-attachment (cnb/stems.ly)
%% places a repeated minim's attachment point on one head of its group,
%% as a single head's stem is placed: the last head when the stem is up,
%% the first when it is down.
%%
%% On the Configurator's default staff of 4 semitones per staff space,
%% lines -4 -2 2 4, repeat on, at an overlap of 1/3, two heads by pitch:
%%   C5 (even semitones): the Configurator's default crotchet-minim head
%%     with its side attachment, as in tests/multinote-overlap.ly;
%%   C#5 (odd semitones): the Configurator tutorial's diamond, solid,
%%     with a centred attachment, (0 . 0).
%% Measure 1 has stems up, measure 2 stems down: a crotchet and a minim
%% of each head.

%% Rendered as before the engine's score defaults, so the baseline holds.
#(define cnb:score-defaults #f)
\include "ChromaticNotationBase.ly"

#(set! cnb:semitones-per-staff-space 4)
#(set! cnb:staff-line-positions '(-4 -2 2 4))
#(set! cnb:multinote-overlap 1/3)
#(set! cnb:multinote-stem-on-head #t)

#(cnb:register-path! 'crotchet-minim '(
    (moveto 0.4089 0.2039)
    (curveto 0.484 0.0533 0.3618 -0.16 0.1359 -0.2727)
    (curveto -0.09 -0.3853 -0.334 -0.3545 -0.4091 -0.2039)
    (curveto -0.4451 -0.1316 -0.4366 -0.0408 -0.3854 0.0486)
    (curveto -0.3342 0.138 -0.2445 0.2186 -0.136 0.2727)
    (curveto -0.0275 0.3268 0.0908 0.3499 0.193 0.337)
    (curveto 0.2952 0.3241 0.3729 0.2762 0.4089 0.2039)
    (closepath)))

#(cnb:register-path! 'diamond '(
    (moveto 0 0.5)
    (lineto 0.75 0)
    (lineto 0 -0.5)
    (lineto -0.75 0)
    (closepath)))

#(cnb:register-attachment! 'crotchet-minim-attach
   '((crotchet-up . (1 . 0.3157)) (crotchet-down . (-1 . -0.3157))
     (minim-up . (1 . 0.3157)) (minim-down . (-1 . -0.3157))))

#(cnb:register-attachment! 'centre
   '((crotchet-up . (0 . 0)) (crotchet-down . (0 . 0))
     (minim-up . (0 . 0)) (minim-down . (0 . 0))))

#(set! cnb:get-notehead-config
   (lambda (semitone duration key)
     `((shape        . ,(if (odd? semitone) 'diamond 'crotchet-minim))
       (color        . ,cnb:black)
       (hollow       . #f)
       (attachment   . ,(if (odd? semitone) 'centre 'crotchet-minim-attach))
       (off-key-mark . #f)
       (repeat       . #t))))

\include "cnb/test-ids.ly"

{
  \time 6/4
  \stemUp   c''4 c''2 cis''4 cis''2 |
  \stemDown c''4 c''2 cis''4 cis''2 |
}
