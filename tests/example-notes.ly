\version "2.24.2"

%% Rendered as before the engine's score defaults, so the baseline holds.
#(define cnb:score-defaults #f)
\include "Kite-4-369-Notation-Procedure.ly"
\include "cnb/test-ids.ly"

%% color-blind-friendly scheme (procedure model)
#(cnb:register-color! 'kite-color-primary   cnb:0-skyblue) %% C, D#, F#, A
#(cnb:register-color! 'kite-color-secondary cnb:1-rose)    %% C#, E, G, A#
#(cnb:register-color! 'kite-color-tertiary  cnb:2-black)   %% D, F, G#, B

\book {
  \header {
    title="Joy to the World"
    composer = "Isaac Watts & Lowell Mason"    
  }

  \markup  { #cnb:notation-label \footnote "*" #cnb:notation-footnote }

  \paper {
    indent = #cnb:indent  
    left-margin = #5
    right-margin = #5
    system-system-spacing =
      #'((basic-distance . 12) 
         (minimum-distance . 8)
         (padding . 4)
         (stretchability . 60))
  }

  \new Staff
  \with {
        \magnifyStaff #cnb:default-magnify
      }
  \relative {
     \clef treble
     \key d \major
     \time 4/4
     d''4 d2 r4 | d1 | \break
     a4 a2 r4 | a1 | \break
     g4 g2 r4 | g1 | \break
     e4 e2 r4 | e1 | \fine
   }
}
