\version "2.24.2"

%% Regression test for the "Improbable offset for stencil: -inf staff
%% space" programming error (session 20; found by the corpus gate in 5 of
%% 20 real scores, Ave Maria the smallest).
%%
%% The key-signature display builds its noteheads from the procedure
%% config cache, which only the notehead engraver used to fill, on its
%% first note. Here the key signature is engraved at a moment with no note
%% (the staff opens on a rest), so before the fix every notehead lookup
%% missed: each was empty-stencil, and its -inf width made the translate
%% improbable. With the Kite config the display was drawn as its
%% separator bar alone, with no width; with this default config LilyPond
%% 2.24 printed the error 14 times and then aborted on a skyline assertion
%% (exit 3). The key-signature engraver now brings the cache up to the
%% current key before it draws.
%%
%% The paired JSON spec asserts the key signature has the width of its
%% noteheads, not the zero width of the bar alone.

%% Rendered as before the engine's score defaults, like the other specs.
#(define cnb:score-defaults #f)
\include "ChromaticNotationBase.ly"

\include "cnb/test-ids.ly"

\relative c' {
  \key bes \major
  \time 4/4
  r4 c d es |
}
