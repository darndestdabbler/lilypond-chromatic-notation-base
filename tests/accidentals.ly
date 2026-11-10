\version "2.24.2"

%% No accidental is drawn on the chromatic staff (cnb/layout.ly): every
%% pitch has its own staff position, so a sharp, flat or natural never
%% specifies pitch. LilyPond draws three kinds with two grobs:
%%   - plain and forced (es!) accidentals: Accidental
%%   - cautionary accidentals (d?): AccidentalCautionary, parenthesised
%% Before session 20 only Accidental.stencil was blanked, so a cautionary
%% accidental still printed as a parenthesised traditional glyph.
%%
%% Measure 1 has a plain cis, a cautionary d? and a forced es!. Measure 2
%% re-enables one fis's Accidental stencil with \once, as the control: it
%% proves test-ids tags accidentals and the harvester sees them, so the
%% spec's count of exactly one is not vacuous.
%%
%% Suggested accidentals (AccidentalSuggestion, also blanked in layout.ly)
%% are not exercised: cnb/test-ids.ly cannot tag them.

#(define cnb:score-defaults #f)
\include "ChromaticNotationBase.ly"

\include "cnb/test-ids.ly"

\relative c' {
  \key c \major
  \time 4/4
  c4 cis d? es! |
  \once \override Accidental.stencil = #ly:accidental-interface::print
  fis4 g a b |
}
