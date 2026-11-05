\version "2.24.2"

%% Integration test for cnb:clef-style 'none (session set 005).
%%
%% With the clef style set to 'none, the cnb-clef-engraver must engrave
%% NO clef stencil at all — this is the engine-side counterpart of a
%% Configurator config with its clef disabled (the Configurator's
%% default), which previously could not match its preview because the
%% dozenal numeral was engraved unconditionally.
%%
%% The paired JSON spec asserts the clef element is absent from the SVG
%% while the noteheads render normally.

%% Rendered as before the engine's score defaults, so the baseline holds.
#(define cnb:score-defaults #f)
\include "ChromaticNotationBase.ly"

#(set! cnb:clef-style 'none)

\include "cnb/test-ids.ly"

\relative c' {
  \key c \major
  \time 4/4
  c4 d e f |
}
