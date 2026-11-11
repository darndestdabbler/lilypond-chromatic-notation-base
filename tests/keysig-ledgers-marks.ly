\version "2.24.2"

%% Integration test for key-signature ledgers from the notation's ledger
%% rules (session 33), under cnb:keysig-style 'marks.
%%
%% The default Configurator 4-8 staff and its cnb:ledgers-by-semitone, as
%% in keysig-ledgers-chord.ly, with a hand-written C major entry: C (12)
%% and B (23) in the first column, D (14) in the second, and no bar, so
%% the signature's extent is its heads and their ledgers alone. Each mark
%% takes its semitone's entry: C and D their in-gap ledgers (C on the
%% middle position, D on the middle position and one above), B none.
%% Before session 33 the marks used the engine's own rule instead, giving
%% B a ledger above the staff and C and D none.

%% Rendered as before the engine's score defaults, like the other specs.
#(define cnb:score-defaults #f)
\include "ChromaticNotationBase.ly"

#(set! cnb:semitones-per-staff-space 4)
#(set! cnb:staff-line-positions '(-4 -2 2 4))

#(define cnb:ledgers-by-semitone
   '((0 . (-6)) (1 . (-6)) (2 . (-6 -5)) (3 . ()) (4 . ()) (5 . ())
     (6 . ()) (7 . ()) (8 . ()) (9 . ()) (10 . (-1)) (11 . ())
     (12 . (0)) (13 . (0)) (14 . (0 1)) (15 . ()) (16 . ()) (17 . ())
     (18 . ()) (19 . ()) (20 . ()) (21 . ()) (22 . (5)) (23 . ())
     (24 . (6))
     ))
#(define (cnb:ledgers-of grob)
   (assv (ly:pitch-semitones (ly:event-property (event-cause grob) 'pitch))
         cnb:ledgers-by-semitone))
\layout {
  \context {
    \Voice
    \override NoteHead.ledger-positions =
      #(lambda (grob) (let ((e (cnb:ledgers-of grob))) (if e (cdr e) '())))
    \override NoteHead.no-ledgers =
      #(lambda (grob) (let ((e (cnb:ledgers-of grob))) (and e (null? (cdr e)))))
  }
}

#(cnb:register-color! 'black-000000 "#000000")

#(set! cnb:keysig-style 'marks)
#(define cnb:keysig-marks
   '((((0 . 0) . (0 2 4 5 7 9 11))                 ; C major
      . ((columns 0.5 1.5)
         (bars)
         (marks (12 0 head default-oval #f black-000000)
                (14 1 head default-oval #f black-000000)
                (23 0 head default-oval #f black-000000))))))

\include "cnb/test-ids.ly"

{
  \time 4/4
  \key c \major
  c''4 d'' b'' c''' |
}
