\version "2.24.2"

%% Integration test for cnb:clef-anchor-semitones under the pitch-axis
%% hook (session 24).
%%
%% The Twinline geometry of the Configurator's fixture
%% (cnb/fixtures/twinline-compact-export-baseline.ly there): 12 pitch
%% classes on 7 axis positions per octave, octave stride 7, sps 2, lines
%% at -6 -3 -1 1 4 6, middle G (semitone 7) at position 0.
%%
%% A 'text clef anchored at semitone 16.5, between E (16, hook position
%% 5) and F (17, position 6), which the hook places apart: the anchor
%% interpolates to position 5.5 half-staff-spaces, so the label's TOP
%% edge must land 2.75 staff-spaces above the staff center. (The linear
%% formula would give (16.5 - 12) / 2 = 2.25.)
%%
%% The label is a filled path markup, so its outline harvests (see
%% tests/clef-text-anchor.ly).

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

#(set! cnb:clef-style 'text)
#(set! cnb:clef-text
   (markup #:override '(filled . #t)
           #:path 0.001 '((moveto 0 0) (lineto 1 0) (lineto 1 2)
                          (lineto 0 2) (closepath))))
#(set! cnb:clef-size-semitones 4)
#(set! cnb:clef-anchor-semitones 16.5)

\include "cnb/test-ids.ly"

\relative c' {
  \key c \major
  \time 4/4
  c4 d e f |
}
