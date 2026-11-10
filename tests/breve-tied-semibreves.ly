\version "2.24.2"

%% The breve and the longa as tied semibreves (session 25).
%%
%% In repeat mode a note of duration log L <= -1 engraves as 2^(-L)
%% semibreve groups (the whole note's 4-copy stencil), left to right,
%% 1 staff space apart, with a tie bowing down in each gap
%% (cnb:build-duration-stencil, cnb/stencils.ly).
%%
%% The notehead is the Configurator's default (its exported
%% crotchet-minim path, solid, from its Default 4-8 System export) on its
%% staff of 4 semitones per staff space, lines -4 -2 2 4, with repeat on
%% (the export itself writes repeat #f). Every note is the same pitch, so
%% widths compare directly: the quarter is one head, the whole note the
%% 4-copy group, the breve 2 groups and 1 gap, the longa 4 groups and 3
%% gaps. The Configurator's handoff for session 25 reads its geometry
%% from this file's harvest.

%% Rendered as before the engine's score defaults, so the baseline holds.
#(define cnb:score-defaults #f)
\include "ChromaticNotationBase.ly"

#(set! cnb:semitones-per-staff-space 4)
#(set! cnb:staff-line-positions '(-4 -2 2 4))

#(cnb:register-path! 'crotchet-minim '(
    (moveto 0.4089 0.2039)
    (curveto 0.484 0.0533 0.3618 -0.16 0.1359 -0.2727)
    (curveto -0.09 -0.3853 -0.334 -0.3545 -0.4091 -0.2039)
    (curveto -0.4451 -0.1316 -0.4366 -0.0408 -0.3854 0.0486)
    (curveto -0.3342 0.138 -0.2445 0.2186 -0.136 0.2727)
    (curveto -0.0275 0.3268 0.0908 0.3499 0.193 0.337)
    (curveto 0.2952 0.3241 0.3729 0.2762 0.4089 0.2039)
    (closepath)))

#(cnb:register-attachment! 'crotchet-minim-attach
   '((crotchet-up . (1 . 0.3157)) (crotchet-down . (-1 . -0.3157))
     (minim-up . (1 . 0.3157)) (minim-down . (-1 . -0.3157))))

#(set! cnb:get-notehead-config
   (lambda (semitone duration key)
     `((shape        . crotchet-minim)
       (color        . ,cnb:black)
       (hollow       . #f)
       (attachment   . crotchet-minim-attach)
       (off-key-mark . #f)
       (repeat       . #t))))

\include "cnb/test-ids.ly"

{
  \time 4/1
  c''4 c''4 c''2 c''1 c''\breve |
  c''\longa |
}
