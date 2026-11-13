\version "2.24.2"

%% The dozenal clef sized about the staff's middle line (session 41).
%%
%% With cnb:clef-size-semitones set, the dozenal numeral's vertical
%% offsets (the left digit's -.5 translate and the engraver's -1
%% Y-offset) are multiplied by its height over 3 staff spaces, so the
%% numeral is scaled about the middle line: at H staff spaces its top
%% is 1.4418 x H/3 and its bottom -1.5582 x H/3 from it.
%%
%% The staff is the Configurator's default, 4 semitones per staff space,
%% lines -4 -2 2 4, and the size is its automatic one there: 8.172
%% semitones = 2.043 staff spaces. The paired spec compares the harvest
%% with the 3-staff-space numeral of tests/c-major-scale.json.

%% Rendered as before the engine's score defaults, so the baseline holds.
#(define cnb:score-defaults #f)
\include "ChromaticNotationBase.ly"

#(set! cnb:semitones-per-staff-space 4)
#(set! cnb:staff-line-positions '(-4 -2 2 4))
#(set! cnb:clef-size-semitones 8.172)

\include "cnb/test-ids.ly"

\relative c' {
  \key c \major
  \time 4/4
  c4 d e f |
}
