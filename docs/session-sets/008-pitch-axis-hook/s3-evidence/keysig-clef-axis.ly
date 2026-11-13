\version "2.24.2"

%% ============================================================================
%% SESSION EVIDENCE — set 008 session 3 (keysig + clef through the hook,
%% backlog 6.3/6.4, E13-3/E13-4)
%%
%% Positive evidence that the two SECONDARY semitone→vertical placement
%% sites follow the pitch axis when cnb:get-pitch-staff-position is set:
%%
%%   - the key-signature notehead-chord marks (cnb/keysig.ly,
%%     cnb:keysig-note-y-offset) land at hook-mapped positions;
%%   - a registered custom clef with a FRACTIONAL anchor (7.5) lands with
%%     its top edge at the position interpolated between the hook values
%%     of its neighboring integer semitones (hook(7), hook(8));
%%   - placement is clef-independent (default treble middleCPosition −6
%%     is in effect; the hook result is used as-is).
%%
%% TWO SCORES, TWO HOOKS (same staff, same key, same clef): score 2 re-sets
%% the hook with the octave anchor shifted +1 (−4 → −3). Every keysig mark,
%% the clef top edge, and the notes must shift by exactly +1 position in
%% score 2 — which simultaneously proves the keysig stencil-cache
%% invalidates on hook change (the hook joined the cache key this session;
%% same keySignature + same staff would otherwise leak score 1's stencil)
%% and that the clef stencil cache correctly does NOT depend on the hook
%% (the cached stencil is reused; the ENGRAVER re-anchors it per score).
%%
%% Axis: the 013 spike's compact map (pc → position [0 0 1 2 2 3 3 4 5 5
%% 6 6], stride 7), staff '(-3 -1 1 4 6 8).
%%
%% Expected (score 1, anchor −4 — middle C → −4):
%%   \key g \major with cnb:keysig-tonic-octave 0 → marks at semitones
%%   {7 9 11 12 14 16 18 19} → positions {0 1 2 3 4 5 6 7};
%%   clef anchor 7.5 → hook(7)=0, hook(8)=1 → top edge at 0.5;
%%   notes c' → −4, g' → 0, c'' → 3.
%% Expected (score 2, anchor −3): all of the above +1
%%   (marks {1..8}, clef top 1.5, c' → −3, g' → 1, c'' → 4).
%%
%% This file is session-record evidence, not a product fixture.
%% ============================================================================

\include "ChromaticNotationBase.ly"
\include "cnb/test-ids.ly"

%% Compact staff (the 013 spike's): 3 lines per octave at axis positions
%% {1,3,5} of the 7-position octave, two octaves shown.
#(set! cnb:staff-line-positions '(-3 -1 1 4 6 8))

%% Anchor the keysig tonic explicitly (set-006 setting) so the displayed
%% octave is deterministic: tonic notehead at LilyPond octave 0 → g' = 7.
#(set! cnb:keysig-tonic-octave 0)

%% Custom clef with a FRACTIONAL top-edge anchor (the set-009 contract):
%% a plain tall rectangle, anchored between G (7) and G♯ (8).
#(cnb:register-clef! 'axis-test-clef
   '((path . ((moveto 0 0) (lineto 1 0) (lineto 1 2) (lineto 0 2)
              (closepath)))
     (anchor-semitones . 7.5)))
#(set! cnb:clef-style 'custom)
#(set! cnb:clef-name 'axis-test-clef)

%% --- The compact pitch axis (Twinline-like: 12 pcs on 7 positions) ------
#(define s3:pc-axis (vector 0 0 1 2 2 3 3 4 5 5 6 6))
#(define s3:octave-stride 7)

#(define (s3:make-axis anchor)
   (lambda (semitone)
     (let* ((pc  (modulo semitone 12))
            (oct (quotient (- semitone pc) 12)))
       (+ (* oct s3:octave-stride)
          (vector-ref s3:pc-axis pc)
          anchor))))

%% TRANSLATION-TIME hook switching: LilyPond collects toplevel scores and
%% translates them together at end-of-file, so a toplevel #(set! ...)
%% between two \score blocks would be parse-time and affect BOTH. Each
%% score instead sets its hook via \applyContext, which executes during
%% that score's translation, before any grob of its first timestep is
%% acknowledged.

%% ============================= SCORE 1 ====================================
%% Anchor −4: middle C at LilyPond position −4 (the 013 spike's anchor).
\score {
  \new Staff {
    \applyContext #(lambda (ctx)
                     (set! cnb:get-pitch-staff-position (s3:make-axis -4)))
    \time 4/4
    \key g \major
    c'4 g' c'' g'
  }
  \layout {
    \context {
      \Staff
      \omit TimeSignature
    }
  }
}

%% ============================= SCORE 2 ====================================
%% Anchor −3: the SAME axis shifted one position up. Same key, same clef,
%% same staff — everything placed through the hook must move +1.
\score {
  \new Staff {
    \applyContext #(lambda (ctx)
                     (set! cnb:get-pitch-staff-position (s3:make-axis -3)))
    \time 4/4
    \key g \major
    c'4 g' c'' g'
  }
  \layout {
    \context {
      \Staff
      \omit TimeSignature
    }
  }
}
