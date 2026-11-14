\version "2.24.2"

%% Stems attached at the notehead centre (session 17).
%%
%% The 45deg-369 reference notation attaches every stem at the centre of
%% a 45-degree-tilted ellipse, so the stem crosses the head and, on a
%% hollow head, the hole. This config registers one solid and one
%% true-hollow ellipse in 45deg-369's proportions (rx 5.82, ry 9.70, hole
%% rx 2.91, ry 8.73, at 12 units per staff space), 4 semitones tall like
%% Kite, on Kite's 3-6-9 staff, with the centre (0 . 0) for all four
%% attachment points. Even semitones are solid, odd ones hollow.
%%
%% Measure 1: crotchets with stems up and down on each head.
%% Measure 2: a minim, a beamed pair of quavers and a two-note chord.

%% Rendered as before the engine's score defaults, so the baseline holds.
#(define cnb:score-defaults #f)
\include "ChromaticNotationBase.ly"

#(set! cnb:semitones-per-staff-space 3)
#(set! cnb:staff-line-positions '(-6 -4 -2 2 4 6))

#(cnb:register-path! 'tilted-ellipse '(
    (moveto -0.3429 0.3429)
    (curveto -0.0273 0.6586 0.3822 0.761 0.5716 0.5716)
    (curveto 0.761 0.3822 0.6586 -0.0273 0.3429 -0.3429)
    (curveto 0.0273 -0.6586 -0.3822 -0.761 -0.5716 -0.5716)
    (curveto -0.761 -0.3822 -0.6586 0.0273 -0.3429 0.3429)
    (closepath)))

#(cnb:register-hollow! 'tilted-ellipse-hole '(
    (moveto -0.1715 0.1715)
    (curveto 0.1126 0.4556 0.4197 0.6091 0.5144 0.5144)
    (curveto 0.6091 0.4197 0.4556 0.1126 0.1715 -0.1715)
    (curveto -0.1126 -0.4556 -0.4197 -0.6091 -0.5144 -0.5144)
    (curveto -0.6091 -0.4197 -0.4556 -0.1126 -0.1715 0.1715)
    (closepath)))

#(cnb:register-attachment! 'centre
   '((crotchet-up . (0 . 0)) (crotchet-down . (0 . 0))
     (minim-up . (0 . 0)) (minim-down . (0 . 0))))

#(set! cnb:get-notehead-config
   (lambda (semitone duration key)
     `((shape        . tilted-ellipse)
       (color        . ,cnb:black)
       (hollow       . ,(if (odd? semitone) 'tilted-ellipse-hole #f))
       (attachment   . centre)
       (off-key-mark . #f)
       (repeat       . #t))))

\include "cnb/test-ids.ly"

{
  \time 4/4
  a'4 d''4 aes'4 ees''4 |
  a'2 g'8[ g'8] <f' bes'>4 |
}
