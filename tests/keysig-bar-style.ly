\version "2.24.2"

%% Integration test for the separator-bar styling settings (session set
%% 006): cnb:keysig-bar-color, cnb:keysig-bar-thickness, and
%% cnb:keysig-bar-extent-semis. Each replaces a value that used to be
%% hard-coded in cnb/keysig.ly (cnb:gold, thickness 4, ±1 octave).
%%
%% This score overrides the bar to a distinct blue, a heavier thickness,
%% and a larger vertical extent. The paired JSON spec asserts the
%% key-signature element renders in the overridden color and that its
%% bounding box is TALLER than the default (extent drives the bar height),
%% confirming the settings reach the rendered stencil.

\include "ChromaticNotationBase.ly"

#(set! cnb:keysig-bar-color (rgb-color 0 0 1))   %% pure blue, not gold
#(set! cnb:keysig-bar-thickness 8)               %% double the default
#(set! cnb:keysig-bar-extent-semis 24)           %% ±2 octaves (double default)

\include "cnb/test-ids.ly"

\relative c' {
  \key c \major
  \time 4/4
  c4 d e f |
}
