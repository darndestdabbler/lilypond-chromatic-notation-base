\version "2.24.2"

%% ============================================================================
%% SESSION EVIDENCE — set 008 session 2 (x-offset field, backlog 6.2/E13-2)
%%
%% The 013 spike proved stencil translation moves single noteheads (and
%% their stems, and the spacing) exactly, but measured the offset ABSORBED
%% for chord-internal diatonic-neighbor pairs (013 record §3.4). This score
%% renders the spike's exact compact axis through the REAL engine surface
%% landed this session:
%%
%%   - the (x-offset . N) field of the procedure-model config alist
%%     (staff spaces; the sharper member of each shared pair gets +0.85,
%%     exactly the spike's disambiguation), and
%%   - the 6.2 chord mechanism: cnb:apply-note-x-offsets translates the
%%     NoteColumn by the stem's least-displaced offset plus per-head
%%     residuals AFTER LilyPond's chord arrangement has completed
%%     (Stem.before-line-breaking) — the arrangement re-derives head X
%%     from stencil extents, so neither a stencil translation nor the
%%     X-offset property survives it (both measured; see the change
%%     log and the X-OFFSET SUPPORT block in cnb/noteheads.ly).
%%
%% Acceptance cases (all measured against the byte-identical control
%% render xoffset-cases-ctrl.ly, which differs ONLY in xoff:amount 0.0
%% = field omitted per the v1.3 §6.3 zero-omission rule):
%%   m1-m3  single notes: each offset pc's head AND stem move +0.85
%%          together; spacing accumulates the moved extent
%%   m4     <c' cis'> unison-treated shared pair: separation +0.85
%%          <gis' a'> DIATONIC-SECOND shared pair (the 013 absorbed
%%          case): separation +0.85 — THE 6.2 acceptance case
%%          <c' g'>   spanning chord control (no offset member)
%%          <f' fis'> same-diatonic-step shared pair: +0.85
%%   m5     below-staff ledgers under offset heads (b, a)
%%   m6-m7  repeat-mode minims and semibreve with offset pcs
%%
%% This file is session-record evidence, not a product fixture.
%% ============================================================================

\include "ChromaticNotationBase.ly"
\include "cnb/test-ids.ly"

%% Isolate the placement question: no clef, no key signature (as the spike).
#(set! cnb:clef-style 'none)
#(set! cnb:keysig-style 'none)

%% Compact staff: 3 lines per octave at axis positions {1,3,5}, two octaves.
#(set! cnb:staff-line-positions '(-3 -1 1 4 6 8))

%% --- The compact pitch axis (Twinline-like: 12 pcs on 7 positions) ------
%% pc:        0  1  2  3  4  5  6  7  8  9 10 11
%% position:  0  0  1  2  2  3  3  4  5  5  6  6
%% Shared pairs: (C,C#) (D#,E) (F,F#) (G#,A) (A#,B); D and G unshared.
#(define xoff:pc-axis (vector 0 0 1 2 2 3 3 4 5 5 6 6))
#(define xoff:octave-stride 7)
#(define xoff:anchor -4)

#(set! cnb:get-pitch-staff-position
   (lambda (semitone)
     (let* ((pc  (modulo semitone 12))
            (oct (quotient (- semitone pc) 12)))
       (+ (* oct xoff:octave-stride)
          (vector-ref xoff:pc-axis pc)
          xoff:anchor))))

%% --- The disambiguation offset ------------------------------------------
%% The sharper member of each shared pair carries +0.85 staff spaces
%% (the 013 spike's exact value; v1.3 export spec §6.3 example).
%% The control render sets xoff:amount to 0.0 — the zero guard below
%% then OMITS the field, mirroring the exporter's zero-omission rule.
#(define xoff:amount 0.0)
#(define xoff:offset-pcs '(1 4 6 9 11))

#(set! cnb:get-notehead-config
   (lambda (semitone duration key)
     `((shape      . default-oval)
       (color      . ,cnb:black)
       (hollow     . ,(if (odd? semitone) 'default-oval-cutout #f))
       (attachment . default-side)
       (off-key-mark . #f)
       ,@(if (and (memv semitone xoff:offset-pcs)
                  (not (zero? xoff:amount)))
             `((x-offset . ,xoff:amount))
             '())
       (repeat     . #t))))

\layout {
  \context {
    \Staff
    \omit TimeSignature
  }
}

\score {
  \new Staff {
    \time 4/4
    %% m1-m3: full chromatic octave, crotchets (single-note offsets)
    c'4 cis' d' dis' |
    e' f' fis' g' |
    gis' a' ais' b' |
    %% m4: the chord acceptance cases
    <c' cis'>4 <gis' a'> <c' g'> <f' fis'> |
    %% m5: below-staff ledger exercise under offset heads (b pc11, a pc9)
    b4 a gis g |
    %% m6-m7: repeat-mode durations with offset pcs (1, 6)
    cis'2 fis' |
    cis'1 |
  }
}
