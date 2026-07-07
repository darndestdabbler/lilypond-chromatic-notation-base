\version "2.24.2"

%% Integration test for cnb:clef-style 'text + cnb:clef-size-semitones
%% (session set 005).
%%
%% The clef slot renders the configured register label ("4") instead of
%% the computed dozenal numeral, sized at 4 semitones. On the default
%% staff (cnb:semitones-per-staff-space = 2, lines at -4..4 = 4
%% staff-spaces tall) 4 semitones = 2 staff-spaces = half the staff
%% height, which the paired JSON spec asserts against the harvested
%% staff geometry.

\include "ChromaticNotationBase.ly"

#(set! cnb:clef-style 'text)
#(set! cnb:clef-text "4")
#(set! cnb:clef-size-semitones 4)

\include "cnb/test-ids.ly"

\relative c' {
  \key c \major
  \time 4/4
  c4 d e f |
}
