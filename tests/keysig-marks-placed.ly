\version "2.24.2"

%% Integration test for placed, coloured and layered marks (session 37),
%% under cnb:keysig-style 'marks on the Configurator's default 4-8 staff
%% (4 semitones a staff space, lines on semitones 4 8 16 20).
%%
%% The file registers two one-sided shapes whose origin is not their
%% centre, as an imported symbol's is: test-dot, a square half a staff
%% space wide with its origin at its lower left corner, and test-tail, a
%% thin bar rising from its origin to the right. Each mark's (at dx . dy)
%% is the offset less that reference point, as the Configurator writes it,
%% so (at -0.25 . -0.25) puts the dot's centre on its column and semitone.
%% One system each, no bars:
%%
%%   m1  D major: a default head on B (-1), below the staff, moved 0.1 to
%%       the right of its column with its ledger; a dot on D (14) with a
%%       tail layered on it at the same semitone and column; a hollow
%%       square symbol on F sharp (18), which takes no ledgers; and a red
%%       sharp on C sharp (13) at scale 1, moved by its at.
%%   m2  B flat major: a red flat on B flat (10) at scale 0.6473 and a
%%       blue flat on E flat (15) at scale 1, each moved by its at.

%% Rendered as before the engine's score defaults, like the other specs.
#(define cnb:score-defaults #f)
\include "ChromaticNotationBase.ly"

#(set! cnb:semitones-per-staff-space 4)
#(set! cnb:staff-line-positions '(-4 -2 2 4))

#(cnb:register-color! 'black-000000 "#000000")
#(cnb:register-color! 'red-cc0000 "#cc0000")
#(cnb:register-color! 'blue-0000cc "#0000cc")

#(cnb:register-path! 'test-dot
   '((moveto 0 0) (lineto 0.5 0) (lineto 0.5 0.5) (lineto 0 0.5) (closepath)))
#(cnb:register-hollow! 'test-dot-cutout
   '((moveto 0.1 0.1) (lineto 0.1 0.4) (lineto 0.4 0.4) (lineto 0.4 0.1) (closepath)))
#(cnb:register-path! 'test-tail
   '((moveto 0 0) (lineto 0.6 0.3) (lineto 0.6 0.4) (lineto 0 0.1) (closepath)))

#(set! cnb:keysig-style 'marks)
#(define cnb:keysig-marks
   '((((1 . 0) . (1 2 4 6 7 9 11))                 ; D major
      . ((columns 0.5 1.5 2.5)
         (bars)
         (marks (-1 0 head default-oval #f black-000000 (at 0.1 . 0))
                (14 1 head test-dot #f black-000000 (at -0.25 . -0.25))
                (14 1 symbol test-tail #f black-000000 (at 0.25 . -0.05))
                (18 2 symbol test-dot test-dot-cutout black-000000 (at -0.25 . -0.25))
                (13 2 sharp 1 red-cc0000 (at -0.35 . 0.25)))))
     (((6 . -1/2) . (0 2 3 5 7 9 10))              ; B flat major
      . ((columns 0.5 1.5)
         (bars)
         (marks (10 0 flat 0.6473 red-cc0000 (at -0.3 . 0))
                (15 1 flat 1 blue-0000cc (at -0.46 . 0.25)))))))

\include "cnb/test-ids.ly"

\layout { indent = 0 }

{
  \omit Staff.TimeSignature
  \set Staff.explicitKeySignatureVisibility = #begin-of-line-visible
  \key d \major d''4 fis'' a'' cis''' \break
  \key bes \major bes'4 d'' f'' es''
}
