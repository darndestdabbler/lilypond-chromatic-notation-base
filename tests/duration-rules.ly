\version "2.24.2"

%% Duration categories reach the config procedure on the documented scale
%% (cnb/procedure.ly): 0 = breve or longer, 1 = whole, 2 = half,
%% 3 = quarter or shorter, computed from the duration log alone so that
%% dots and tuplets never change it (audit 2026-11-02, H2).
%%
%% The config below colours each category differently and keeps repeat
%% on, so the paired JSON spec can read every note's category from its
%% colour and its notehead repetition (4 heads for a whole, 2 for a half,
%% 1 for a quarter or shorter; a breve is two 4-head semibreve groups, 1
%% staff space apart and tied) from its width. Every note is G4, so widths
%% compare directly.

%% Rendered as before the engine's score defaults, so the baseline holds.
#(define cnb:score-defaults #f)
\include "ChromaticNotationBase.ly"

#(set! cnb:get-notehead-config
   (lambda (semitone duration key)
     `((shape        . default-oval)
       (color        . ,(vector-ref
                          (vector "#FF0000"    ; 0 breve
                                  "#00FF00"    ; 1 whole
                                  "#0000FF"    ; 2 half
                                  "#000000")   ; 3 quarter or shorter
                          duration))
       (hollow       . #f)
       (attachment   . default-side)
       (off-key-mark . #f)
       (repeat       . #t))))

\include "cnb/test-ids.ly"

{
  \time 2/1
  g'\breve |
  \time 4/4
  g'1 |
  g'2 g'4 g'8 g'8 |
  g'2. g'4 |
  g'4. g'8 g'4.. g'16 |
  \tuplet 3/2 { g'2 g'2 g'2 } |
  \tuplet 3/2 { g'4 g'4 g'4 } g'2 |
  \time 6/4
  g'1. |
}
