\version "2.24.2"

%% Integration test for the magnification a config sets (session 35).
%%
%% A plain score, with no \magnifyStaff of its own and the engine's score
%% defaults on, includes the engine and then set!s cnb:default-magnify to
%% 1, as an exported config does after its \include. The score defaults
%% read the variable when each staff starts, so the staff engraves at 1.
%% Before session 35 they read it when the engine was included, and the
%% staff engraved at the default 7/4 whatever the config said.

\include "ChromaticNotationBase.ly"

#(set! cnb:default-magnify 1)

\include "cnb/test-ids.ly"

{
  \time 4/4
  c'4 e' g' c'' |
}
