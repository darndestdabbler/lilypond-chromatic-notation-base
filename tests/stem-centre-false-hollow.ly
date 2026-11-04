\version "2.24.2"

%% Stems attached at the notehead centre, false-hollow mode (session 17).
%%
%% tests/stem-centre.ly renders true hollows, whose hole is a real cutout.
%% Here cnb:false-hollow is #t: a hollow head is the coloured ellipse with
%% a white ellipse painted over it, in the same notehead stencil. A stem
%% anchored at the centre crosses that white hole, so it must be painted
%% after the head (Stem.layer above NoteHead.layer, cnb/layout.ly), or the
%% overlay would hide it. Same shapes and attachment as stem-centre.ly;
%% every note here is hollow (odd semitones).

\include "ChromaticNotationBase.ly"

#(set! cnb:semitones-per-staff-space 3)
#(set! cnb:staff-line-positions '(-6 -4 -2 2 4 6))
#(set! cnb:false-hollow #t)

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
  \time 3/4
  a'4 ees''4 a'4 |
}
