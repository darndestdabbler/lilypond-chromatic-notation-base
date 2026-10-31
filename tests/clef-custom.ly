\version "2.24.2"

%% Integration test for the custom-clef registration hook (session set
%% 005, session 2; Configurator set-009 anchor contract).
%%
%% Registers a 1×2 rectangle path as a custom clef and selects it:
%%   anchor-semitones 16 — on the default sps-2 staff with the default
%%     treble clef (middleCPosition -6) the pitch grid puts semitone 16
%%     at +2 staff-spaces, i.e. exactly the TOP staff line, so the
%%     glyph's top edge must land on the top line.
%%   height-semitones 8 — 4 staff-spaces at sps-2: the glyph spans the
%%     staff exactly, so its bottom edge must land on the bottom line.
%%   cnb:clef-gutter-semitones 4 — 2 staff-spaces of blank space after
%%     the clef, observable as extra distance to the first notehead.
%%
%% The paired JSON spec asserts the harvested clef bbox (a path stencil
%% harvests real outline geometry, unlike the dozenal text anchors).

\include "ChromaticNotationBase.ly"

#(cnb:register-clef! 'test-rect
   (list (cons 'path '((moveto 0 0) (lineto 1 0) (lineto 1 2)
                       (lineto 0 2) (closepath)))
         (cons 'anchor-semitones 16)
         (cons 'height-semitones 8)))

#(set! cnb:clef-style 'custom)
#(set! cnb:clef-name 'test-rect)
#(set! cnb:clef-gutter-semitones 4)

\include "cnb/test-ids.ly"

\relative c' {
  \key c \major
  \time 4/4
  c4 d e f |
}
