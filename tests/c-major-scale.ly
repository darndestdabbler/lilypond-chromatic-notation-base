\version "2.24.2"

%% Test input: C major scale, one octave, quarter notes
%% This is a minimal score for validating the CNB rendering pipeline.

%% Rendered as before the engine's score defaults, so the baseline holds.
#(define cnb:score-defaults #f)
\include "ChromaticNotationBase.ly"
\include "cnb/test-ids.ly"

\relative c' {
  \key c \major
  \time 4/4
  c4 d e f |
  g a b c |
}
