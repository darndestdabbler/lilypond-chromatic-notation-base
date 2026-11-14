\version "2.24.2"

%% Integration test for key-signature ledgers from the notation's ledger
%% rules (session 33), under cnb:keysig-style 'chord.
%%
%% The default Configurator 4-8 staff: 4 semitones per staff space, lines
%% at -4 -2 2 4 (no middle line), and the export's cnb:ledgers-by-semitone
%% for semitones 0-24 with its NoteHead.ledger-positions / no-ledgers
%% \layout block, so the notes take their table entries. C major's
%% signature, anchored 'centred, sits on semitones 12-24 (C on the middle
%% position). The signature's heads take the same entries as the notes:
%% C (12) and D (14) their in-gap ledgers, B (23) none. Before session 33
%% the signature used the engine's own rule instead, giving B a ledger
%% above the staff and C and D none.
%%
%% C major's in-gap ledgers lie inside its heads' extent (C 24's ledger
%% already spans both columns), so m2 changes key to G major, on
%% semitones 7-19: there C (12, second column) and D (14, first column)
%% are the only heads with ledgers, and their ledgers widen the signature
%% past its heads, where the engine's rule gives it none.

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

#(set! cnb:keysig-style 'chord)
#(set! cnb:keysig-tonic-octave 'centred)

\include "cnb/test-ids.ly"

{
  \time 4/4
  \key c \major
  c''4 d'' b'' c''' |
  \key g \major
  g'4 a' b' c'' |
}
