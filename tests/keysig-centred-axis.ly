\version "2.24.2"

%% Integration test for cnb:keysig-tonic-octave 'centred under the
%% pitch-axis hook (session 24).
%%
%% The Twinline geometry of the Configurator's fixture
%% (cnb/fixtures/twinline-compact-export-baseline.ly there): 12 pitch
%% classes on 7 axis positions per octave, octave stride 7, sps 2, lines
%% at -6 -3 -1 1 4 6, middle G (semitone 7) at position 0.
%%
%% Twelve key signatures, one per measure, on the tonics C to B. The
%% Configurator's rule centres each tonic's span [t, t+12] on the
%% midpoint 7, ties going up: C..G sit at t = 0..7, and G#, A, A# and B
%% an octave lower, at t = -4..-1 — the four on which the single octave
%% the exporter writes today (cnb:keysig-tonic-octave 0) disagrees.
%%
%% The separator bar is shortened to 0.5 semitones a side, so the
%% harvested key-signature bbox is the marks' own: its vertical centre is
%% the centre of [hook(t), hook(t+12)]. Key cancellations are switched
%% off (KeyCancellation carries key-signature-interface too), and the
%% twelve measures are kept on one system.

%% Rendered as before the engine's score defaults, so the baseline holds.
#(define cnb:score-defaults #f)
\include "ChromaticNotationBase.ly"

#(set! cnb:semitones-per-staff-space 2)
#(set! cnb:staff-line-positions '(-6 -3 -1 1 4 6))
#(set! cnb:get-pitch-staff-position
   (lambda (semitone)
     (let* ((pc (modulo semitone 12))
            (oct (/ (- semitone pc) 12))
            (pos (+ (vector-ref #(0 0 1 2 2 3 3 4 5 5 6 6) pc)
                    (* oct 7))))
       (- pos 4))))

#(set! cnb:keysig-tonic-octave 'centred)
#(set! cnb:keysig-bar-extent-semis 0.5)

\include "cnb/test-ids.ly"

\paper {
  paper-width = 700\mm
}

\layout {
  \context {
    \Staff
    printKeyCancellation = ##f
  }
}

{
  \time 4/4
  \key c \major   g'1 |
  \key cis \major g'1 |
  \key d \major   g'1 |
  \key dis \major g'1 |
  \key e \major   g'1 |
  \key f \major   g'1 |
  \key fis \major g'1 |
  \key g \major   g'1 |
  \key gis \major g'1 |
  \key a \major   g'1 |
  \key ais \major g'1 |
  \key b \major   g'1 |
}
