\version "2.24.2"

%% ============================================================================
%% SESSION EVIDENCE — set 008 session 2 (collision semantics, backlog 6.5/E13-5)
%%
%% Multi-voice collisions were NOT exercised by the 013 spike. The
%% collision machinery (NoteCollision meshing, Stem parity logic, and
%% the cnb:collision-threshold overrides in cnb/layout.ly) reads the
%% placed GEOMETRY back as rounded staff positions, so under the hook
%% it compares AXIS-space distances. This score exercises cross-voice
%% simultaneities on the compact axis around the default threshold (2):
%%
%%   beat  v1      v2     axis pos     axis dist  diatonic dist  case
%%   m1 b1 cis'    c'     -4 / -4      0          0    shared pair, same step
%%   m1 b2 a'      gis'   +1 / +1      0          1    shared pair, NEIGHBOR
%%                                                     steps (cross-voice
%%                                                     analogue of the 6.2
%%                                                     chord case); a' offset
%%   m1 b3 d'      c'     -3 / -4      1          1    inside threshold
%%   m1 b4 e'      c'     -2 / -4      2          2    at threshold
%%   m2 b1 g'      c'      0 / -4      4          4    beyond threshold
%%   m2 b2 dis'    cis'   -2 / -4      2          1    axis dist (2) !=
%%                                                     diatonic dist (1);
%%                                                     cis' offset
%%   m2 b3 c''     c'     +3 / -4      7          7    octave control
%%   m2 b4 <gis' a'> c'   +1 / -4      chord      -    shared-pair chord
%%                                                     above a second voice
%%
%% Same axis, staff, and offset config as xoffset-cases.ly (the sharper
%% member of each shared pair carries +0.85 staff spaces).
%%
%% This is OBSERVATION evidence (6.5 is verify + document, not redesign):
%% the measured table in measure_collisions_transcript.txt is the record.
%% This file is session-record evidence, not a product fixture.
%% ============================================================================

\include "ChromaticNotationBase.ly"
\include "cnb/test-ids.ly"

#(set! cnb:clef-style 'none)
#(set! cnb:keysig-style 'none)

#(set! cnb:staff-line-positions '(-3 -1 1 4 6 8))

#(define coll:pc-axis (vector 0 0 1 2 2 3 3 4 5 5 6 6))
#(define coll:octave-stride 7)
#(define coll:anchor -4)

#(set! cnb:get-pitch-staff-position
   (lambda (semitone)
     (let* ((pc  (modulo semitone 12))
            (oct (quotient (- semitone pc) 12)))
       (+ (* oct coll:octave-stride)
          (vector-ref coll:pc-axis pc)
          coll:anchor))))

#(define coll:amount 0.85)
#(define coll:offset-pcs '(1 4 6 9 11))

#(set! cnb:get-notehead-config
   (lambda (semitone duration key)
     `((shape      . default-oval)
       (color      . ,cnb:black)
       (hollow     . ,(if (odd? semitone) 'default-oval-cutout #f))
       (attachment . default-side)
       (off-key-mark . #f)
       ,@(if (and (memv semitone coll:offset-pcs)
                  (not (zero? coll:amount)))
             `((x-offset . ,coll:amount))
             '())
       (repeat     . #t))))

\layout {
  \context {
    \Staff
    \omit TimeSignature
  }
}

\score {
  \new Staff <<
    \new Voice { \voiceOne
      cis'4 a' d' e' |
      g' dis' c'' <gis' a'> |
    }
    \new Voice { \voiceTwo
      c'4 gis' c' c' |
      c' cis' c' c' |
    }
  >>
}
