\version "2.24.2"

\include "Kite-4-369-Notation-Clean.ly"
\include "cnb/test-ids.ly"

%% color-blind-friendly scheme
 #(define cnb:notehead-color-sequence (vector     
    cnb:blue  ;; semitone mod 3 = 0 (C, D#, F#, A), skyblue
    cnb:rose  ;; semitone mod 3 = 1 (C#, E, G, A#), red-purple
    cnb:black ;; semitone mod 3 = 2 (D, F, G#, B), black
    ))

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
