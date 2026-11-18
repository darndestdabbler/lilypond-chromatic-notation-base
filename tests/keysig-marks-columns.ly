\version "2.24.2"

%% Integration test for the mark-list key signature (session 30): two,
%% three and four columns with their bars, and the space around the
%% signature. One measure per system, each opening with its own key:
%%
%%   m1, m4  C major, two columns of noteheads, one bar
%%   m2, m5  D major, three columns of sharps, two bars
%%   m3, m6  B flat major, four columns of flats, three bars
%%
%% Systems 1-3 show the clef; systems 4-6 hide it, so the signature
%% follows the staff's start. The columns are laid out as the
%% Configurator lays them (CNBKeySignature.marks): each column the widest
%% mark's width wide, its centre at (c + 0.5) x width, a bar on each
%% boundary between columns. The widths are the default notehead's 1.0
%% and Emmentaler's sharp 1.1 and flat 0.92 staff spaces. The time
%% signature is omitted, so each system is clef, signature, first note.

%% Rendered as before the engine's score defaults, so the baseline holds.
#(define cnb:score-defaults #f)
\include "ChromaticNotationBase.ly"

#(cnb:register-color! 'black-000000 "#000000")

#(set! cnb:keysig-style 'marks)
#(define cnb:keysig-marks
   '((((0 . 0) . (0 2 4 5 7 9 11))                 ; C major
      . ((columns 0.5 1.5)
         (bars (1.0 8 16 "#ffd42a" 0.2))
         (marks (8 0 head default-oval #f black-000000)
                (12 0 head default-oval #f black-000000)
                (10 1 head default-oval #f black-000000)
                (14 1 head default-oval #f black-000000))))
     (((1 . 0) . (1 2 4 6 7 9 11))                 ; D major
      . ((columns 0.55 1.65 2.75)
         (bars (1.1 8 16 "#ffd42a" 0.1) (2.2 8 16 "#ffd42a" 0.1))
         (marks (11 0 sharp) (13 1 sharp) (15 2 sharp))))
     (((6 . -1/2) . (0 2 3 5 7 9 10))              ; B flat major
      . ((columns 0.46 1.38 2.3 3.22)
         (bars (0.92 8 16 "#ffd42a" 0.0667)
               (1.84 8 16 "#ffd42a" 0.0667)
               (2.76 8 16 "#ffd42a" 0.0667))
         (marks (10 0 flat) (13 1 flat) (11 2 flat) (15 3 flat))))))

\include "cnb/test-ids.ly"

\layout { indent = 0 }

{
  \omit Staff.TimeSignature
  \set Staff.explicitKeySignatureVisibility = #begin-of-line-visible
  \key c \major c''4 c'' c'' c'' \break
  \key d \major c''4 c'' c'' c'' \break
  \key bes \major c''4 c'' c'' c'' \break
  \once \override Staff.Clef.break-visibility = #all-invisible
  \key c \major c''4 c'' c'' c'' \break
  \once \override Staff.Clef.break-visibility = #all-invisible
  \key d \major c''4 c'' c'' c'' \break
  \once \override Staff.Clef.break-visibility = #all-invisible
  \key bes \major c''4 c'' c'' c''
}
