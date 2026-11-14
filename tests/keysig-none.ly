\version "2.24.2"

%% Integration test for cnb:keysig-style 'none (session set 006).
%%
%% With the key-signature style set to 'none, the
%% cnb-key-signature-engraver must engrave NO key-signature stencil at
%% all — the engine-side counterpart of a Configurator config with
%% keys.keySignature.enabled: false, which previously could not be
%% honored because the notehead-chord display was engraved
%% unconditionally.
%%
%% The paired JSON spec asserts the key-signature element is absent from
%% the SVG while the noteheads render normally.

%% Rendered as before the engine's score defaults, so the baseline holds.
#(define cnb:score-defaults #f)
\include "ChromaticNotationBase.ly"

#(set! cnb:keysig-style 'none)

\include "cnb/test-ids.ly"

\relative c' {
  \key c \major
  \time 4/4
  c4 d e f |
}
