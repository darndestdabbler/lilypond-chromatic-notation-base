%% ============================================================================
%%
%%  CNB MODULE: off-key.ly
%%  Off-key note flag system — visual indicators for notes outside the key
%%
%%  WHAT THIS FILE DOES:
%%    Detects notes whose pitch class is not in the current key signature
%%    and attaches a configurable visual flag to their noteheads.
%%
%%  DEPENDENCIES: config.ly, procedure.ly (for cnb:get-key-pitch-classes,
%%                cnb:step-to-semitone, and config cache functions)
%%
%%  NOTE: cnb:step-to-semitone and cnb:get-key-pitch-classes were
%%  originally defined in this file. They have been moved to
%%  procedure.ly because the notehead engraver (which loads before
%%  this module) needs them for key-change tracking in procedure model.
%%  They are still available here since procedure.ly loads first.
%%
%%  WHY THIS EXISTS:
%%    On a chromatic staff, every pitch has its own staff position —
%%    accidental symbols are never needed to specify WHICH note to play.
%%    But they can still serve a useful cognitive function: flagging
%%    notes that depart from the current key.
%%
%%    As Paul Morris (Clairnote) argues: on a diatonic staff, your
%%    fingers anticipate only 7 notes per octave. On a chromatic staff,
%%    all 12 positions are equally plausible. A visual flag for "this
%%    note is outside the key" restores some of that cognitive advantage,
%%    especially for diatonic music.
%%
%%  MODES (set via cnb:off-key-indicator in config):
%%
%%    'none       — Default. No flags, no accidentals. Pure chromatic
%%                  reading. Good for atonal music or experienced
%%                  chromatic-staff readers.
%%
%%    'standard   — LilyPond's built-in accidental symbols (♯ ♭ ♮).
%%                  Traditional symbols, traditional behavior.
%%                  Preserves enharmonic distinction.
%%
%%    'dot        — Small filled dot above/below the notehead.
%%                  Minimal, unobtrusive. Binary signal only:
%%                  in-key or out-of-key. No enharmonic distinction.
%%
%%    'ring       — Thin circle drawn around the notehead.
%%                  More visible than dot, but busier.
%%
%%    'tick       — Small tick mark above/below the notehead.
%%                  Similar to TwinNote's "matchstick" concept.
%%
%%    'custom     — User-provided flag via cnb:off-key-flag-stencil.
%%                  The function receives the NoteHead grob and
%%                  returns a stencil to combine with the notehead.
%%
%%  DUAL MODEL SUPPORT:
%%
%%    VECTOR MODEL (cnb:use-procedure-model = #f):
%%      The engraver detects off-key notes itself using the current
%%      keyAlterations and cnb:off-key-indicator setting.
%%
%%    PROCEDURE MODEL (cnb:use-procedure-model = #t):
%%      The engraver reads the off-key-mark field from the config cache
%%      for each note. The configuration procedure has already decided
%%      whether and how to mark each note — the engraver just executes.
%%      This is the "dumb engraver" philosophy: no detection logic,
%%      just follow the config's instructions.
%%
%%  HOW IT WORKS:
%%    1. An engraver collects NoteHead grobs during each timestep.
%%    2. At the end of the timestep:
%%       - Vector model: reads the current key from LilyPond's
%%         keyAlterations, converts to pitch classes, checks membership.
%%       - Procedure model: looks up each note's config cache entry
%%         and reads the off-key-mark field.
%%    3. For flagged notes: chains a callback onto after-line-breaking
%%       (via cnb:chain-after-line-breaking!, preserving any callback
%%       another module installed) that adds the flag stencil to the
%%       (now-resolved) notehead stencil.
%%
%%  WHY after-line-breaking?
%%    At acknowledger time, our custom notehead stencil may not yet
%%    be fully resolved (it could still be a callback). By deferring
%%    to after-line-breaking, we guarantee the stencil is a concrete
%%    stencil object that we can combine with the flag.
%%
%%  INTERACTION WITH ACCIDENTAL SUPPRESSION:
%%    In 'none, 'dot, 'ring, 'tick, and 'custom modes:
%%      LilyPond's built-in Accidental.stencil is suppressed (= ##f).
%%    In 'standard mode:
%%      LilyPond's built-in accidentals are shown normally.
%%    This is handled in layout.ly.
%%
%% ============================================================================


%% ---------------------------------------------------------------------------
%%  FLAG STENCIL GENERATORS
%%
%%  Each generator takes a NoteHead grob (with fully resolved stencil)
%%  and returns a flag stencil positioned relative to the notehead center.
%% ---------------------------------------------------------------------------

%% DOT: A small filled circle above or below the notehead.
%% Direction: opposite to stem (above for stem-down, below for stem-up),
%% or above by default if no stem info available.
#(define (cnb:off-key-dot grob)
   (let* (
           (stencil     (ly:grob-property grob 'stencil))
           (y-ext       (if (ly:stencil? stencil)
                            (ly:stencil-extent stencil Y)
                            '(-0.5 . 0.5)))
           ;; Place dot above the notehead with a small gap
           (dot-y       (+ (cdr y-ext) 0.35))
           (dot-radius  0.12)
           (dot         (make-circle-stencil dot-radius 0 #t)))
     (ly:stencil-translate dot (cons 0 dot-y))))


%% RING: A thin circle drawn around the notehead.
%% Radius adapts to the notehead's bounding box.
#(define (cnb:off-key-ring grob)
   (let* (
           (stencil     (ly:grob-property grob 'stencil))
           (x-ext       (if (ly:stencil? stencil)
                            (ly:stencil-extent stencil X)
                            '(-0.5 . 0.5)))
           (y-ext       (if (ly:stencil? stencil)
                            (ly:stencil-extent stencil Y)
                            '(-0.5 . 0.5)))
           (half-w      (* 0.5 (- (cdr x-ext) (car x-ext))))
           (half-h      (* 0.5 (- (cdr y-ext) (car y-ext))))
           (radius      (+ (max half-w half-h) 0.15))
           (center-x    (* 0.5 (+ (car x-ext) (cdr x-ext))))
           (center-y    (* 0.5 (+ (car y-ext) (cdr y-ext))))
           (ring        (make-circle-stencil radius 0.1 #f)))
     (ly:stencil-translate ring (cons center-x center-y))))


%% TICK: A small vertical line mark above the notehead.
%% Like a simplified accent mark, but shorter and thinner.
#(define (cnb:off-key-tick grob)
   (let* (
           (stencil     (ly:grob-property grob 'stencil))
           (y-ext       (if (ly:stencil? stencil)
                            (ly:stencil-extent stencil Y)
                            '(-0.5 . 0.5)))
           ;; Place tick above the notehead
           (tick-bottom (+ (cdr y-ext) 0.2))
           (tick-top    (+ tick-bottom 0.35))
           (tick        (make-line-stencil 0.12 0 tick-bottom 0 tick-top)))
     tick))


%% ---------------------------------------------------------------------------
%%  FLAG APPLICATION CALLBACKS
%%
%%  VECTOR MODEL: cnb:apply-off-key-flag
%%    Set as after-line-breaking on off-key noteheads.
%%    Reads the flag type from cnb:off-key-indicator.
%%
%%  PROCEDURE MODEL: cnb:apply-off-key-mark
%%    Set as after-line-breaking on notes whose config has off-key-mark.
%%    Takes the mark type as a parameter (captured in a closure by the
%%    engraver), so it doesn't depend on a global variable.
%%
%%  By the after-line-breaking point the stencil is fully resolved,
%%  so we can safely read it and combine it with the flag.
%% ---------------------------------------------------------------------------

%% VECTOR MODEL callback
#(define (cnb:apply-off-key-flag grob)
   (let* (
           (stencil (ly:grob-property grob 'stencil))
           (flag-stencil
             (cond
               ((eq? cnb:off-key-indicator 'dot)    (cnb:off-key-dot grob))
               ((eq? cnb:off-key-indicator 'ring)   (cnb:off-key-ring grob))
               ((eq? cnb:off-key-indicator 'tick)   (cnb:off-key-tick grob))
               ((eq? cnb:off-key-indicator 'custom)
                (if (procedure? cnb:off-key-flag-stencil)
                    (cnb:off-key-flag-stencil grob)
                    empty-stencil))
               (else empty-stencil))))
     (if (and (ly:stencil? stencil)
              (ly:stencil? flag-stencil)
              (not (ly:stencil-empty? flag-stencil)))
         (ly:grob-set-property! grob 'stencil
               (ly:stencil-add stencil flag-stencil)))))

%% PROCEDURE MODEL callback
%% Takes the mark type (a symbol) as a parameter.
%% Built-in symbols: 'dot, 'ring, 'tick
%% If the mark is a procedure, it's called as a custom generator.
#(define (cnb:apply-off-key-mark grob mark)
   (let* (
           (stencil (ly:grob-property grob 'stencil))
           (flag-stencil
             (cond
               ((eq? mark 'dot)    (cnb:off-key-dot grob))
               ((eq? mark 'ring)   (cnb:off-key-ring grob))
               ((eq? mark 'tick)   (cnb:off-key-tick grob))
               ((procedure? mark)  (mark grob))
               (else empty-stencil))))
     (if (and (ly:stencil? stencil)
              (ly:stencil? flag-stencil)
              (not (ly:stencil-empty? flag-stencil)))
         (ly:grob-set-property! grob 'stencil
               (ly:stencil-add stencil flag-stencil)))))


%% ---------------------------------------------------------------------------
%%  THE OFF-KEY ENGRAVER
%%
%%  Runs in the Staff context. Collects noteheads during each timestep,
%%  then at stop-translation-timestep checks each against the current key.
%%  Off-key noteheads get tagged with an after-line-breaking callback.
%%
%%  VECTOR MODEL:
%%    The engraver is a no-op when cnb:off-key-indicator is 'none or
%%    'standard (in 'standard mode, LilyPond's built-in accidentals
%%    handle everything).
%%
%%  PROCEDURE MODEL:
%%    The engraver always collects noteheads and checks the config cache.
%%    If the off-key-mark field is not #f, it applies the corresponding
%%    flag. The engraver has no opinion about WHY the mark is there —
%%    the configuration procedure decided.
%% ---------------------------------------------------------------------------

#(define cnb-off-key-engraver
   (lambda (context)
     (let ((note-heads '()))
       (make-engraver

         (acknowledgers
           ((note-head-interface engraver grob source-engraver)
            (cond
              ;; PROCEDURE MODEL: always collect noteheads
              (cnb:use-procedure-model
               (set! note-heads (cons grob note-heads)))
              ;; VECTOR MODEL: only collect in flag modes
              ((memq cnb:off-key-indicator '(dot ring tick custom))
               (set! note-heads (cons grob note-heads))))))

         ((stop-translation-timestep engraver)
          (if (not (null? note-heads))
              (begin

                (if cnb:use-procedure-model

                    ;; === PROCEDURE MODEL ===
                    ;; Read off-key-mark from config cache for each note.
                    ;; The config procedure has already decided what to mark.
                    (for-each
                      (lambda (grob)
                        (let* (
                                (cause    (ly:grob-property grob 'cause))
                                (pitch    (if (ly:stream-event? cause)
                                             (ly:event-property cause 'pitch)
                                             #f))
                                (semi     (if pitch
                                             (modulo (ly:pitch-semitones pitch) 12)
                                             #f))
                                (dur-prop (if (and (ly:stream-event? cause) pitch)
                                             (ly:event-property cause 'duration)
                                             #f))
                                (dur-cat  (if dur-prop
                                             (cnb:duration-category dur-prop)
                                             3))
                                (config   (if semi
                                             (cnb:lookup-config semi dur-cat)
                                             #f))
                                (off-key-mark
                                          (if config
                                             (assq-ref config 'off-key-mark)
                                             #f)))

                          ;; If config says to mark this note, apply the flag
                          (if off-key-mark
                              (let ((mark off-key-mark))
                                (cnb:chain-after-line-breaking! grob
                                  (lambda (g)
                                    (cnb:apply-off-key-mark g mark)))))))
                      note-heads)

                    ;; === VECTOR MODEL ===
                    ;; Detect off-key notes using keyAlterations
                    (let* (
                            (key-alts   (ly:context-property context 'keyAlterations '()))
                            (in-key-pcs (cnb:get-key-pitch-classes key-alts)))

                      (for-each
                        (lambda (grob)
                          (let* (
                                  (cause (ly:grob-property grob 'cause))
                                  (pitch (if (ly:stream-event? cause)
                                             (ly:event-property cause 'pitch)
                                             #f))
                                  (semi  (if pitch
                                             (modulo (ly:pitch-semitones pitch) 12)
                                             #f)))

                            ;; If this pitch class is NOT in the current key, flag it
                            (if (and semi (not (memv semi in-key-pcs)))
                                (cnb:chain-after-line-breaking! grob
                                                                cnb:apply-off-key-flag))))
                        note-heads)))

                (set! note-heads '()))))))))
