\version "2.24.2"

%% Integration test for cnb:clef-size-semitones on the dozenal clef
%% (session set 005).
%%
%% The default clef height is 3 staff-spaces, which on the default
%% staff (cnb:semitones-per-staff-space = 2) is 6 semitones. This score
%% sets 8 semitones = 4 staff-spaces, i.e. 4/3 of the legacy size.
%%
%% The dozenal display is two text stencils whose horizontal separation
%% is the scaled left-digit width, so the harvested clef bbox WIDTH is
%% proportional to the size setting (the bbox height is only the fixed
%% digit-anchor offset — see the paired JSON spec's description). The
%% paired spec asserts the width grew by exactly 4/3 over the
%% default-render width measured from tests/c-major-scale.json's
%% harvest (1.102).

\include "ChromaticNotationBase.ly"

#(set! cnb:clef-size-semitones 8)

\include "cnb/test-ids.ly"

\relative c' {
  \key c \major
  \time 4/4
  c4 d e f |
}
