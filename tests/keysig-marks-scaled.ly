\version "2.24.2"

%% Integration test for sized sharps and flats (session 35), under
%% cnb:keysig-style 'marks on the Configurator's default 4-8 staff.
%%
%% Each sign carries a scale, 0.6473, as the Configurator's session 52
%% writes it: the glyph is scaled about its origin, so the sharp's centre
%% and the flat's bowl stay at their semitones. One system each:
%%
%%   m1  D major, its sharps F (18) and C (13), two columns
%%   m2  B flat major, its flats B (10) and E (15), two columns
%%
%% The columns are laid out for the scaled widths, as the Configurator
%% lays them: each column the scaled sign's width wide (Emmentaler's
%% sharp 1.1 and flat 0.92 staff spaces, times 0.6473: 0.712 and 0.5955),
%% its centre at (c + 0.5) x width. No bars, so the signature's extent is
%% its signs alone.

%% Rendered as before the engine's score defaults, like the other specs.
#(define cnb:score-defaults #f)
\include "ChromaticNotationBase.ly"

#(set! cnb:semitones-per-staff-space 4)
#(set! cnb:staff-line-positions '(-4 -2 2 4))

#(set! cnb:keysig-style 'marks)
#(define cnb:keysig-marks
   '((((1 . 0) . (1 2 4 6 7 9 11))                 ; D major
      . ((columns 0.356 1.068)
         (bars)
         (marks (18 0 sharp 0.6473) (13 1 sharp 0.6473))))
     (((6 . -1/2) . (0 2 3 5 7 9 10))              ; B flat major
      . ((columns 0.29775 0.89325)
         (bars)
         (marks (10 0 flat 0.6473) (15 1 flat 0.6473))))))

\include "cnb/test-ids.ly"

\layout { indent = 0 }

{
  \omit Staff.TimeSignature
  \set Staff.explicitKeySignatureVisibility = #begin-of-line-visible
  \key d \major d''4 fis'' a'' cis''' \break
  \key bes \major bes'4 d'' f'' es''
}
