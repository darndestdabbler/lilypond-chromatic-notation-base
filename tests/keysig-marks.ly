\version "2.24.2"

%% Integration test for the mark-list key signature (session 30):
%% cnb:keysig-style 'marks draws the cnb:keysig-marks entry for the
%% score's \key, every mark and bar where the entry puts it.
%%
%%   m1  C major: two columns, a double notehead (c'' in both columns),
%%       a hollow head and a gold bar between the columns.
%%   m2  D major, by \transpose c d of a passage written in C major.
%%   m3  C major again: LilyPond would cancel D's sharps with naturals;
%%       under 'marks the new key's marks are drawn and no naturals.
%%   m4  F sharp major (sharps) and m5 G flat major (flats): one set of
%%       pitch classes, two spellings, two entries.
%%   m6  after a \break with the key unchanged: G flat's signature
%%       repeated at the second system's start.
%%   m7  D sharp major, which the table lacks: no signature, and the
%%       engine warns naming it (that warning is expected).

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
                (12 1 head default-oval #f black-000000)
                (16 1 head default-oval default-oval-cutout black-000000))))
     (((1 . 0) . (1 2 4 6 7 9 11))                 ; D major
      . ((columns 0.5 1.5)
         (bars (1.0 8 16 "#ffd42a" 0.2))
         (marks (10 0 head default-oval #f black-000000)
                (14 1 head default-oval #f black-000000))))
     (((3 . 1/2) . (1 3 5 6 8 10 11))              ; F sharp major
      . ((columns 0.55 1.65)
         (bars (1.1 8 16 "#ffd42a" 0.2))
         (marks (10 0 sharp) (13 1 sharp))))
     (((4 . -1/2) . (1 3 5 6 8 10 11))             ; G flat major
      . ((columns 0.46 1.38)
         (bars (0.92 8 16 "#ffd42a" 0.2))
         (marks (11 0 flat) (13 1 flat))))))

\include "cnb/test-ids.ly"

{
  \time 4/4
  \key c \major
  c''4 d'' e'' f'' |
  \transpose c d { \key c \major c''4 d'' e'' f'' | }
  \key c \major
  c''4 d'' e'' f'' |
  \key fis \major
  fis'4 gis' ais' b' |
  \key ges \major
  ges'4 aes' bes' ces'' |
  \break
  ges'4 aes' bes' ces'' |
  \key dis \major
  dis'4 eis' fis' gis' |
}
