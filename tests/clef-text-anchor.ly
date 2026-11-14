\version "2.24.2"

%% Integration test for cnb:clef-anchor-semitones on a linear staff
%% (session 24).
%%
%% A 'text clef anchored at semitone 15.5: on the default sps-2 staff
%% with the default treble clef (middleCPosition -6) the notehead grid
%% puts semitone 15.5 at (15.5 - 12) / 2 = +1.75 staff-spaces, so the
%% label's TOP edge must land 1.75 staff-spaces above the staff center,
%% a quarter space under the top line.
%%
%% The label is a filled path markup, not a string: a string harvests
%% as one SVG <text> anchor with a 0x0 bbox, while a path harvests its
%% outline, so the top edge can be asserted. The 1x2 rectangle at
%% cnb:clef-size-semitones 4 renders 2 staff-spaces tall.

%% Rendered as before the engine's score defaults, so the baseline holds.
#(define cnb:score-defaults #f)
\include "ChromaticNotationBase.ly"

#(set! cnb:clef-style 'text)
#(set! cnb:clef-text
   (markup #:override '(filled . #t)
           #:path 0.001 '((moveto 0 0) (lineto 1 0) (lineto 1 2)
                          (lineto 0 2) (closepath))))
#(set! cnb:clef-size-semitones 4)
#(set! cnb:clef-anchor-semitones 15.5)

\include "cnb/test-ids.ly"

\relative c' {
  \key c \major
  \time 4/4
  c4 d e f |
}
