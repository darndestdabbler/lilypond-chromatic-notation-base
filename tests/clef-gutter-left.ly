\version "2.24.2"

%% Integration test for cnb:clef-gutter-left-semitones (session 24).
%%
%% The custom 1x2 rectangle clef of tests/clef-custom.ly (anchor
%% semitone 16, height 8 semitones = the full staff at sps 2), with
%% padding on both sides:
%%   cnb:clef-gutter-left-semitones 3 — 1.5 staff-spaces of blank space
%%     before the clef's ink;
%%   cnb:clef-gutter-semitones 4      — 2 staff-spaces after it.
%%
%% The paired JSON spec asserts the gap on each side against an
%% identical render without either setting, measured per LilyPond
%% version.

%% Rendered as before the engine's score defaults, so the baseline holds.
#(define cnb:score-defaults #f)
\include "ChromaticNotationBase.ly"

#(cnb:register-clef! 'test-rect
   (list (cons 'path '((moveto 0 0) (lineto 1 0) (lineto 1 2)
                       (lineto 0 2) (closepath)))
         (cons 'anchor-semitones 16)
         (cons 'height-semitones 8)))

#(set! cnb:clef-style 'custom)
#(set! cnb:clef-name 'test-rect)
#(set! cnb:clef-gutter-left-semitones 3)
#(set! cnb:clef-gutter-semitones 4)

\include "cnb/test-ids.ly"

\relative c' {
  \key c \major
  \time 4/4
  c4 d e f |
}
