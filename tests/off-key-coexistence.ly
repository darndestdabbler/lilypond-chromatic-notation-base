\version "2.24.2"

%% Regression test for callback chaining (Known Issue #1, session set 002).
%%
%% Both cnb/off-key.ly and cnb/test-ids.ly hook grob callbacks on the same
%% score. Before the fix, each module installed its after-line-breaking
%% callback with a bare ly:grob-set-property!, so whichever module ran
%% last silently clobbered the other's hook. Both now register through
%% cnb:chain-after-line-breaking! (cnb/utils.ly).
%%
%% This score activates BOTH modules at once:
%%   - test-ids.ly tags every grob with SVG ids/data attributes
%%   - off-key.ly ('dot mode) adds a dot stencil to off-key noteheads
%%
%% The F# in measure 1 is off-key in C major. The paired JSON spec asserts
%% that its notehead carries BOTH effects: the test-id tag (id + data-*)
%% AND the off-key dot (a taller bounding box than in-key noteheads).
%%
%% Measure 2 adds a beam, a slur, and a tie so that test-ids.ly's three
%% chained after-line-breaking hooks (Beam/Tie/Slur) all execute too.

\include "ChromaticNotationBase.ly"

%% Enable the vector-model off-key indicator (default is 'none)
#(set! cnb:off-key-indicator 'dot)

\include "cnb/test-ids.ly"

\relative c' {
  \key c \major
  \time 4/4
  c4 d fis g |
  a8[ b] c4( d) e~ |
  e1 |
}
