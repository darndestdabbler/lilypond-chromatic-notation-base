\version "2.24.2"

%% Stem attachment survives a later key change (audit 2026-11-02, M1).
%%
%% The config procedure receives the key, so a config may choose its
%% attachment by key. The config cache holds only the current key, and
%% stem attachment is evaluated at layout time, after the whole score has
%% been engraved, so reading the cache then gave every note the attachment
%% of the LAST key. The notehead engraver now captures the attachment
%% record on each notehead at acknowledge time, when the cache matches
%% the note's key.
%%
%% The config below attaches stems at the notehead's side (default-side)
%% while F# is out of the key and at its centre (center-stem) once F# is
%% in it. Measure 1 is in C major and measure 2 in G major, with the same
%% notes: measure 1 must keep side-attached stems.

\include "ChromaticNotationBase.ly"

#(cnb:register-attachment! 'center-stem
   '((crotchet-up . (0 . 0)) (crotchet-down . (0 . 0))
     (minim-up . (0 . 0)) (minim-down . (0 . 0))))

#(set! cnb:get-notehead-config
   (lambda (semitone duration key)
     `((shape        . default-oval)
       (color        . ,cnb:black)
       (hollow       . #f)
       (attachment   . ,(if (cnb:in? 6 key) 'center-stem 'default-side))
       (off-key-mark . #f)
       (repeat       . #t))))

\include "cnb/test-ids.ly"

{
  \time 4/4
  \key c \major
  g'4 a' g'2 |
  \key g \major
  g'4 a' g'2 |
}
