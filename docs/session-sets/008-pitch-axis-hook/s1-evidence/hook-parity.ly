\version "2.24.2"

%% ============================================================================
%% SESSION EVIDENCE — set 008 session 1 (pitch-axis hook, backlog 6.1/E13-1)
%%
%% The Configurator's 013 spike proved compact-axis placement by a
%% score-level COERCION (re-setting Y-offset after the engine's engraver).
%% This score renders the SAME axis, SAME staff, and SAME music through the
%% REAL engine hook landed this session:
%%
%%   #(set! cnb:get-pitch-staff-position (lambda (semitone) ...))
%%
%% No score-level engraver, no post-placement override — the engine's own
%% notehead acknowledger consults the hook. Measured positions must match
%% the 013 record's tables (35 noteheads, 7 ledger rects, stem directions
%% flipping at LilyPond position 0).
%%
%% NOTE: the spike's +0.85 x-offset disambiguation is deliberately ABSENT —
%% the (x-offset . N) field is Session 2 work (backlog 6.2/E13-2). Vertical
%% positions are identical between the spike's offset and control renders
%% (013 record §3.1), so parity is checked against the same tables.
%%
%% This file is session-record evidence, not a product fixture.
%% ============================================================================

\include "ChromaticNotationBase.ly"
\include "cnb/test-ids.ly"

%% Isolate the placement question: no clef, no key signature (as the spike).
#(set! cnb:clef-style 'none)
#(set! cnb:keysig-style 'none)

%% Compact staff: 3 lines per octave at axis positions {1,3,5} within the
%% 7-position octave, two octaves of staff shown.
%% Axis anchor: middle C (ly:pitch-semitones = 0) at LilyPond position -4.
#(set! cnb:staff-line-positions '(-3 -1 1 4 6 8))

%% --- The compact pitch axis (Twinline-like: 12 pcs on 7 positions) ------
%% pc:        0  1  2  3  4  5  6  7  8  9 10 11
%% position:  0  0  1  2  2  3  3  4  5  5  6  6
%% Shared pairs: (C,C#) (D#,E) (F,F#) (G#,A) (A#,B); D and G unshared.
#(define parity:pc-axis (vector 0 0 1 2 2 3 3 4 5 5 6 6))
#(define parity:octave-stride 7)
#(define parity:anchor -4)

%% THE REAL HOOK: semitone -> LilyPond staff position (half-staff-spaces
%% from the staff center, same unit as cnb:staff-line-positions), octave
%% anchor baked in per the unit contract in cnb/config.ly.
#(set! cnb:get-pitch-staff-position
   (lambda (semitone)
     (let* ((pc  (modulo semitone 12))
            (oct (quotient (- semitone pc) 12)))
       (+ (* oct parity:octave-stride)
          (vector-ref parity:pc-axis pc)
          parity:anchor))))

\layout {
  \context {
    \Staff
    \omit TimeSignature
  }
}

\score {
  \new Staff {
    \time 4/4
    %% m1-m3: full chromatic octave, crotchets (stems + shared positions)
    c'4 cis' d' dis' |
    e' f' fis' g' |
    gis' a' ais' b' |
    %% m4: second octave spot checks (octave stride)
    c''4 d'' e'' g'' |
    %% m5: above-staff ledger exercise
    ais''4 b'' c''' c''' |
    %% m6: below-staff ledger exercise
    b4 a gis g |
    %% m7: shared-position chord, on-line shared chord, normal chord, shared pair
    <c' cis'>4 <gis' a'> <c' g'> <f' fis'> |
    %% m8-m9: duration coverage (repeat-mode minims, semibreve)
    c''2 e'' |
    c''1 |
  }
}
