%% ============================================================================
%%
%%  CNB MODULE: test-ids.ly
%%  Comprehensive SVG id + data-attribute injection for integration testing
%%
%%  PURPOSE:
%%    Tags every musically-relevant grob with:
%%      - A unique id (business key) for programmatic lookup
%%      - data-* attributes carrying musical metadata
%%
%%    The SVG harvester (tools/harvest_svg.py) reads these tags to build
%%    a structured JSON representation of the rendered score, which the
%%    test runner compares against expected values.
%%
%%  USAGE:
%%    Include AFTER ChromaticNotationBase.ly in test scores:
%%
%%      \include "ChromaticNotationBase.ly"
%%      \include "cnb/test-ids.ly"
%%
%%    Render with SVG backend:
%%
%%      lilypond -dbackend=svg my-test-score.ly
%%
%%  ID FORMAT:
%%    NoteHead:      nh-{measure}-{beat}-{midi}-{voice}
%%    Stem:          st-{measure}-{beat}-{voice}
%%    Dots:          dt-{measure}-{beat}-{midi}-{voice}
%%    Accidental:    ac-{measure}-{beat}-{midi}-{voice}
%%    Flag:          fl-{measure}-{beat}-{voice}
%%    Beam:          bm-{measure}-{beat}-{voice}  (first note in beam group)
%%    Rest:          rs-{measure}-{beat}-{voice}
%%    LedgerLine:    ll-{measure}-{beat}-{midi}-{voice}
%%    Tie:           ti-{measure}-{beat}-{midi}-{voice}  (starting note)
%%    Slur:          sl-{measure}-{beat}-{midi}-{voice}  (starting note)
%%    BarLine:       bl-{measure}
%%    StaffSymbol:   staff-symbol
%%    Clef:          cl-{measure}
%%    KeySignature:  ks-{measure}
%%    TimeSignature: ts-{measure}
%%
%%  BEAT FORMAT:
%%    Decimal with 3 places: 0.000, 0.250, 0.500, 0.750, 1.000, etc.
%%    Derived from LilyPond's measurePosition (a Moment = fraction).
%%
%%  DATA ATTRIBUTES:
%%    data-type:     grob type (notehead, stem, rest, barline, etc.)
%%    data-measure:  measure number (integer)
%%    data-beat:     beat position in measure (decimal)
%%    data-midi:     MIDI pitch number (for pitched grobs)
%%    data-voice:    voice context id
%%    data-duration: duration-log (0=whole, 1=half, 2=quarter, 3=eighth...)
%%    data-staff-pos: staff position in half-spaces from center
%%    data-pitch-class: pitch class 0-11 (for pitched grobs)
%%
%%  KNOWN LIMITATIONS:
%%    1. (RESOLVED) This module hooks after-line-breaking on Beam/Tie/Slur
%%       grobs. It now registers those hooks via
%%       cnb:chain-after-line-breaking! (cnb/utils.ly), which composes
%%       with any callback another module (e.g., off-key.ly) already
%%       installed instead of overwriting it — so both modules' hooks
%%       fire on the same grob.
%%    2. StaffSymbol is a single grob spanning the system; it gets one id.
%%       Individual staff LINES don't have separate grobs â€” their positions
%%       are encoded in the StaffSymbol's line-positions property. The
%%       harvester must read line positions from the StaffSymbol's geometry.
%%    3. LedgerLineSpanner creates a single grob that draws all ledger
%%       lines for a column. We tag it with the notehead's info.
%%    4. Beam IDs use after-line-breaking (not the acknowledger) so that
%%       the ID reflects the first stem's timing. This means beams depend
%%       on stems already having their output-attributes set. The hook is
%%       registered with cnb:chain-after-line-breaking!, so another
%%       module's beam callback is preserved rather than overwritten.
%%
%% ============================================================================


%% ---------------------------------------------------------------------------
%%  HELPER: Format a LilyPond Moment as a beat decimal string
%% ---------------------------------------------------------------------------

#(define (cnb:moment-to-beat-string context)
   ;; measurePosition is a Moment representing position within the measure.
   ;; Convert to a decimal string with 3 decimal places.
   ;; Use ly:moment-main-numerator/denominator (safe for LilyPond 2.24)
   ;; rather than ly:moment-main which may not exist in all versions.
   ;; ly:make-moment requires 2 args in 2.24: (ly:make-moment num den)
   (let* ((pos (ly:context-property context 'measurePosition
                 (ly:make-moment 0 1)))
          (num (ly:moment-main-numerator pos))
          (den (ly:moment-main-denominator pos))
          (val (if (= den 0) 0.0 (exact->inexact (/ num den)))))
     (format #f "~,3f" val)))

#(define (cnb:get-measure context)
   (ly:context-property context 'currentBarNumber 1))

#(define (cnb:get-voice-id context)
   ;; Walk up the context tree to find the Voice context
   ;; and return its id. Falls back to "0" if not found.
   (let loop ((ctx context))
     (if (not ctx)
         "0"
         (let ((name (ly:context-name ctx)))
           (if (or (eq? name 'Voice)
                   (eq? name 'CueVoice))
               (let ((id (ly:context-id ctx)))
                 (if (and (string? id) (> (string-length id) 0))
                     id
                     "0"))
               (loop (ly:context-parent ctx)))))))


%% ---------------------------------------------------------------------------
%%  HELPER: Build output-attributes alist from key-value pairs
%%  Always includes the id as the first entry.
%% ---------------------------------------------------------------------------

#(define (cnb:make-output-attrs id . pairs)
   ;; pairs is a flat list: (key1 val1 key2 val2 ...)
   ;; Returns: ((id . "...") (key1 . "val1") (key2 . "val2") ...)
   (let loop ((rest pairs) (acc (list (cons 'id id))))
     (if (or (null? rest) (null? (cdr rest)))
         (reverse acc)
         (loop (cddr rest)
               (cons (cons (car rest) (cadr rest)) acc)))))


%% ---------------------------------------------------------------------------
%%  NOTEHEAD ID
%% ---------------------------------------------------------------------------

#(define (cnb:test-id-notehead context grob)
   (let* ((cause  (ly:grob-property grob 'cause))
          (pitch  (if (ly:stream-event? cause)
                      (ly:event-property cause 'pitch)
                      #f))
          (midi   (if pitch
                      (+ 60 (ly:pitch-semitones pitch))  ;; middle C = 60
                      0))
          (pc     (if pitch
                      (modulo (ly:pitch-semitones pitch) 12)
                      0))
          (dur-ev (if (ly:stream-event? cause)
                      (ly:event-property cause 'duration)
                      #f))
          (dur-log (if (ly:duration? dur-ev)
                       (ly:duration-log dur-ev)
                       2))
          (measure (cnb:get-measure context))
          (beat    (cnb:moment-to-beat-string context))
          (voice   (cnb:get-voice-id context))
          (id-str  (format #f "nh-~a-~a-~a-~a" measure beat midi voice)))
     (ly:grob-set-property! grob 'output-attributes
       (cnb:make-output-attrs id-str
         'data-type "notehead"
         'data-measure (format #f "~a" measure)
         'data-beat beat
         'data-midi (format #f "~a" midi)
         'data-pitch-class (format #f "~a" pc)
         'data-voice voice
         'data-duration (format #f "~a" dur-log)))))


%% ---------------------------------------------------------------------------
%%  STEM ID
%% ---------------------------------------------------------------------------

#(define (cnb:test-id-stem context grob)
   (let* ((measure (cnb:get-measure context))
          (beat    (cnb:moment-to-beat-string context))
          (voice   (cnb:get-voice-id context))
          (id-str  (format #f "st-~a-~a-~a" measure beat voice)))
     (ly:grob-set-property! grob 'output-attributes
       (cnb:make-output-attrs id-str
         'data-type "stem"
         'data-measure (format #f "~a" measure)
         'data-beat beat
         'data-voice voice))))


%% ---------------------------------------------------------------------------
%%  DOTS ID
%% ---------------------------------------------------------------------------

#(define (cnb:test-id-dots context grob)
   (let* ((parent (ly:grob-parent grob Y))
          (cause  (if parent (ly:grob-property parent 'cause) #f))
          (pitch  (if (and cause (ly:stream-event? cause))
                      (ly:event-property cause 'pitch)
                      #f))
          (midi   (if pitch (+ 60 (ly:pitch-semitones pitch)) 0))
          (measure (cnb:get-measure context))
          (beat    (cnb:moment-to-beat-string context))
          (voice   (cnb:get-voice-id context))
          (id-str  (format #f "dt-~a-~a-~a-~a" measure beat midi voice)))
     (ly:grob-set-property! grob 'output-attributes
       (cnb:make-output-attrs id-str
         'data-type "dots"
         'data-measure (format #f "~a" measure)
         'data-beat beat
         'data-midi (format #f "~a" midi)
         'data-voice voice))))


%% ---------------------------------------------------------------------------
%%  ACCIDENTAL ID
%% ---------------------------------------------------------------------------

#(define (cnb:test-id-accidental context grob)
   (let* ((parent (ly:grob-parent grob Y))
          (cause  (if parent (ly:grob-property parent 'cause) #f))
          (pitch  (if (and cause (ly:stream-event? cause))
                      (ly:event-property cause 'pitch)
                      #f))
          (midi   (if pitch (+ 60 (ly:pitch-semitones pitch)) 0))
          (measure (cnb:get-measure context))
          (beat    (cnb:moment-to-beat-string context))
          (voice   (cnb:get-voice-id context))
          (id-str  (format #f "ac-~a-~a-~a-~a" measure beat midi voice)))
     (ly:grob-set-property! grob 'output-attributes
       (cnb:make-output-attrs id-str
         'data-type "accidental"
         'data-measure (format #f "~a" measure)
         'data-beat beat
         'data-midi (format #f "~a" midi)
         'data-voice voice))))


%% ---------------------------------------------------------------------------
%%  FLAG ID
%% ---------------------------------------------------------------------------

#(define (cnb:test-id-flag context grob)
   (let* ((measure (cnb:get-measure context))
          (beat    (cnb:moment-to-beat-string context))
          (voice   (cnb:get-voice-id context))
          (id-str  (format #f "fl-~a-~a-~a" measure beat voice)))
     (ly:grob-set-property! grob 'output-attributes
       (cnb:make-output-attrs id-str
         'data-type "flag"
         'data-measure (format #f "~a" measure)
         'data-beat beat
         'data-voice voice))))


%% ---------------------------------------------------------------------------
%%  BEAM ID
%%
%%  Beams are spanning grobs — LilyPond creates and acknowledges them when
%%  the second beamed note arrives, so the context timing at acknowledgment
%%  reflects that later moment, not the beam's start. We defer ID assignment
%%  to after-line-breaking, when all stems are present, and read the timing
%%  from the first stem's output-attributes (already set by the stem
%%  acknowledger).
%% ---------------------------------------------------------------------------

#(define (cnb:test-id-beam-after-break grob)
   (let* ((stems-array (ly:grob-object grob 'stems))
          (stems (if (ly:grob-array? stems-array)
                     (ly:grob-array->list stems-array)
                     '())))
     (if (pair? stems)
         ;; Find the stem with the earliest (measure, beat) — normally
         ;; car is already first, but sort to be safe with cross-bar beams.
         (let* ((stem-timing
                 (map (lambda (s)
                        (let* ((attrs (ly:grob-property s 'output-attributes '()))
                               (m (or (assoc-ref attrs 'data-measure) "1"))
                               (b (or (assoc-ref attrs 'data-beat) "0.000"))
                               (v (or (assoc-ref attrs 'data-voice) "0")))
                          (list s m b v)))
                      stems))
                ;; Sort by measure (numeric) then beat (numeric)
                (sorted (sort stem-timing
                              (lambda (a b)
                                (let ((ma (string->number (cadr a)))
                                      (mb (string->number (cadr b)))
                                      (ba (string->number (caddr a)))
                                      (bb (string->number (caddr b))))
                                  (or (< ma mb)
                                      (and (= ma mb) (< ba bb)))))))
                (first (car sorted))
                (measure (cadr first))
                (beat (caddr first))
                (voice (cadddr first))
                (id-str (format #f "bm-~a-~a-~a" measure beat voice)))
           (ly:grob-set-property! grob 'output-attributes
             (cnb:make-output-attrs id-str
               'data-type "beam"
               'data-measure measure
               'data-beat beat
               'data-voice voice))))))


%% ---------------------------------------------------------------------------
%%  REST ID
%% ---------------------------------------------------------------------------

#(define (cnb:test-id-rest context grob)
   (let* ((cause   (ly:grob-property grob 'cause))
          (dur-ev  (if (ly:stream-event? cause)
                       (ly:event-property cause 'duration)
                       #f))
          (dur-log (if (ly:duration? dur-ev)
                       (ly:duration-log dur-ev)
                       2))
          (measure (cnb:get-measure context))
          (beat    (cnb:moment-to-beat-string context))
          (voice   (cnb:get-voice-id context))
          (id-str  (format #f "rs-~a-~a-~a" measure beat voice)))
     (ly:grob-set-property! grob 'output-attributes
       (cnb:make-output-attrs id-str
         'data-type "rest"
         'data-measure (format #f "~a" measure)
         'data-beat beat
         'data-voice voice
         'data-duration (format #f "~a" dur-log)))))


%% ---------------------------------------------------------------------------
%%  BARLINE ID
%% ---------------------------------------------------------------------------

#(define (cnb:test-id-barline context grob)
   (let* ((measure (cnb:get-measure context))
          (id-str  (format #f "bl-~a" measure)))
     (ly:grob-set-property! grob 'output-attributes
       (cnb:make-output-attrs id-str
         'data-type "barline"
         'data-measure (format #f "~a" measure)))))


%% ---------------------------------------------------------------------------
%%  CLEF ID
%% ---------------------------------------------------------------------------

#(define (cnb:test-id-clef context grob)
   (let* ((measure (cnb:get-measure context))
          (id-str  (format #f "cl-~a" measure)))
     (ly:grob-set-property! grob 'output-attributes
       (cnb:make-output-attrs id-str
         'data-type "clef"
         'data-measure (format #f "~a" measure)))))


%% ---------------------------------------------------------------------------
%%  KEY SIGNATURE ID
%% ---------------------------------------------------------------------------

#(define (cnb:test-id-keysig context grob)
   (let* ((measure (cnb:get-measure context))
          (id-str  (format #f "ks-~a" measure)))
     (ly:grob-set-property! grob 'output-attributes
       (cnb:make-output-attrs id-str
         'data-type "key-signature"
         'data-measure (format #f "~a" measure)))))


%% ---------------------------------------------------------------------------
%%  TIME SIGNATURE ID
%% ---------------------------------------------------------------------------

#(define (cnb:test-id-timesig context grob)
   (let* ((measure (cnb:get-measure context))
          (id-str  (format #f "ts-~a" measure)))
     (ly:grob-set-property! grob 'output-attributes
       (cnb:make-output-attrs id-str
         'data-type "time-signature"
         'data-measure (format #f "~a" measure)))))


%% ---------------------------------------------------------------------------
%%  STAFF SYMBOL ID
%% ---------------------------------------------------------------------------

#(define (cnb:test-id-staff-symbol context grob)
   (ly:grob-set-property! grob 'output-attributes
     (cnb:make-output-attrs "staff-symbol"
       'data-type "staff-symbol")))


%% ---------------------------------------------------------------------------
%%  LEDGER LINE SPANNER ID
%% ---------------------------------------------------------------------------

#(define (cnb:test-id-ledger context grob)
   (let* ((measure (cnb:get-measure context))
          (beat    (cnb:moment-to-beat-string context))
          (voice   (cnb:get-voice-id context))
          (id-str  (format #f "ll-~a-~a-~a" measure beat voice)))
     (ly:grob-set-property! grob 'output-attributes
       (cnb:make-output-attrs id-str
         'data-type "ledger-line"
         'data-measure (format #f "~a" measure)
         'data-beat beat
         'data-voice voice))))


%% ---------------------------------------------------------------------------
%%  HELPER: Extract timing from a spanner's left-bound NoteHead.
%%
%%  Ties and slurs are spanners. Like beams, they're acknowledged at a
%%  moment that doesn't match their visual start. We defer to
%%  after-line-breaking, then read the left-bound NoteColumn's NoteHead
%%  to get measure/beat/midi for the starting note.
%% ---------------------------------------------------------------------------

#(define (cnb:spanner-left-note-attrs grob)
   ;; Returns (measure beat midi voice) from the left-bound notehead,
   ;; or ("?" "0.000" "0" "0") if unavailable.
   (let* ((left-bound (ly:spanner-bound grob LEFT))
          (note-heads (if (ly:grob? left-bound)
                          (ly:grob-object left-bound 'note-heads)
                          #f))
          (nh-list (if (ly:grob-array? note-heads)
                       (ly:grob-array->list note-heads)
                       '())))
     (if (pair? nh-list)
         (let* ((nh (car nh-list))
                (attrs (ly:grob-property nh 'output-attributes '()))
                (m (or (assoc-ref attrs 'data-measure) "?"))
                (b (or (assoc-ref attrs 'data-beat) "0.000"))
                (midi (or (assoc-ref attrs 'data-midi) "0"))
                (v (or (assoc-ref attrs 'data-voice) "0")))
           (list m b midi v))
         (list "?" "0.000" "0" "0"))))


%% ---------------------------------------------------------------------------
%%  TIE ID
%% ---------------------------------------------------------------------------

#(define (cnb:test-id-tie-after-break grob)
   (let* ((info (cnb:spanner-left-note-attrs grob))
          (measure (list-ref info 0))
          (beat    (list-ref info 1))
          (midi    (list-ref info 2))
          (voice   (list-ref info 3))
          (id-str  (format #f "ti-~a-~a-~a-~a" measure beat midi voice)))
     (ly:grob-set-property! grob 'output-attributes
       (cnb:make-output-attrs id-str
         'data-type "tie"
         'data-measure measure
         'data-beat beat
         'data-midi midi
         'data-voice voice))))


%% ---------------------------------------------------------------------------
%%  SLUR ID
%% ---------------------------------------------------------------------------

#(define (cnb:test-id-slur-after-break grob)
   (let* ((info (cnb:spanner-left-note-attrs grob))
          (measure (list-ref info 0))
          (beat    (list-ref info 1))
          (midi    (list-ref info 2))
          (voice   (list-ref info 3))
          (id-str  (format #f "sl-~a-~a-~a-~a" measure beat midi voice)))
     (ly:grob-set-property! grob 'output-attributes
       (cnb:make-output-attrs id-str
         'data-type "slur"
         'data-measure measure
         'data-beat beat
         'data-midi midi
         'data-voice voice))))


%% ---------------------------------------------------------------------------
%%  THE TEST-ID ENGRAVER
%%
%%  Uses acknowledgers to tag grobs as they are created.
%%  The engraver has access to the context (for measure/beat/voice)
%%  and the grob (for pitch and other properties from the cause event).
%% ---------------------------------------------------------------------------

#(define cnb-test-id-engraver
   (lambda (context)
     (make-engraver
       (acknowledgers
         ((note-head-interface engraver grob source-engraver)
          (cnb:test-id-notehead context grob))

         ((stem-interface engraver grob source-engraver)
          (cnb:test-id-stem context grob))

         ((dots-interface engraver grob source-engraver)
          (cnb:test-id-dots context grob))

         ((accidental-interface engraver grob source-engraver)
          (cnb:test-id-accidental context grob))

         ((flag-interface engraver grob source-engraver)
          (cnb:test-id-flag context grob))

         ((beam-interface engraver grob source-engraver)
          (cnb:chain-after-line-breaking! grob
            cnb:test-id-beam-after-break))

         ((rest-interface engraver grob source-engraver)
          (cnb:test-id-rest context grob))

         ((bar-line-interface engraver grob source-engraver)
          (cnb:test-id-barline context grob))

         ((clef-interface engraver grob source-engraver)
          (cnb:test-id-clef context grob))

         ((key-signature-interface engraver grob source-engraver)
          (cnb:test-id-keysig context grob))

         ((time-signature-interface engraver grob source-engraver)
          (cnb:test-id-timesig context grob))

         ((staff-symbol-interface engraver grob source-engraver)
          (cnb:test-id-staff-symbol context grob))

         ((ledger-line-spanner-interface engraver grob source-engraver)
          (cnb:test-id-ledger context grob))

         ((tie-interface engraver grob source-engraver)
          (cnb:chain-after-line-breaking! grob
            cnb:test-id-tie-after-break))

         ((slur-interface engraver grob source-engraver)
          (cnb:chain-after-line-breaking! grob
            cnb:test-id-slur-after-break))
       ))))


%% ---------------------------------------------------------------------------
%%  REGISTER THE ENGRAVER
%% ---------------------------------------------------------------------------

\layout {
  \context {
    \Staff
    \consists \cnb-test-id-engraver
  }
}
