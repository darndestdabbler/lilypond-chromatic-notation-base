%% ============================================================================
%%
%%  CNB MODULE: noteheads.ly
%%  Notehead engraver — positions and renders chromatic noteheads
%%
%%  WHAT THIS FILE DOES:
%%    Defines a LilyPond engraver that intercepts every NoteHead grob
%%    and replaces its stencil with a custom chromatic notehead, while
%%    also repositioning it vertically based on semitone value.
%%
%%  DEPENDENCIES: config.ly, procedure.ly, stencils.ly
%%
%%  HOW LILYPOND ENGRAVERS WORK (for non-experts):
%%    An "engraver" is a plugin that LilyPond runs during typesetting.
%%    It can intercept "grobs" (graphical objects) and modify them.
%%
%%    This engraver uses an "acknowledger" — it runs when LilyPond
%%    creates a NoteHead grob, giving us a chance to replace the
%%    default notehead with our custom one.
%%
%%    The engraver is registered in layout.ly via:
%%      \consists \cnb-notehead-engraver
%%
%%  VERTICAL POSITIONING:
%%    In standard notation, notes are placed on a 7-step diatonic scale.
%%    In chromatic notation, notes are placed by SEMITONE value.
%%
%%    The formula for vertical position is:
%%      Y = (semitones + 2 × middleCPosition)
%%          × (1 / semitones-per-staff-space)
%%          × staff-space
%%
%%    Where:
%%      semitones = the note's semitone number (C4=0, C#4=1, D4=2, etc.)
%%      middleCPosition = LilyPond's clef-dependent offset for middle C
%%      semitones-per-staff-space = how compressed the staff is
%%      staff-space = the actual pixel size of one staff space
%%
%%    PITCH-AXIS HOOK: when cnb:get-pitch-staff-position (cnb/config.ly)
%%    is set to a procedure, the linear formula above is replaced by
%%      Y = (hook semitones) × 0.5 × staff-space
%%    where the hook returns a staff position in half-staff-spaces from
%%    the staff center (octave anchor baked in; clef-independent). The
%%    default (#f) keeps the literal linear formula.
%%
%%  KEY-CHANGE TRACKING:
%%    The engraver monitors the keyAlterations context property. On change,
%%    it rebuilds both the procedure config cache and the stencil cache,
%%    since stencil appearance may depend on the current key (e.g., off-key
%%    notes rendered in different colors).
%%
%%  PERFORMANCE NOTE:
%%    The stencil returned by cnb:get-note-stencil is built on demand from
%%    the config cache and cached by pitch+duration. This engraver's
%%    per-note cost is: one equal? comparison on keyAlterations, one hash
%%    lookup, and one Y-offset assignment. No markup interpretation happens
%%    here.
%%
%% ============================================================================


%% ---------------------------------------------------------------------------
%%  KEY-CHANGE TRACKING
%%
%%  Tracks the last-seen keyAlterations value. When it changes:
%%    1. Computes the new key's pitch classes
%%    2. Rebuilds the procedure config cache
%%    3. Invalidates the stencil cache
%%
%%  Called from the engraver on every note. The equal? comparison is
%%  cheap; rebuilding only happens on actual key changes.
%% ---------------------------------------------------------------------------

#(define cnb:last-key-alterations 'uninitialized)

#(define (cnb:handle-key-change context)
   (let ((key-alts (ly:context-property context 'keyAlterations '())))
     (if (not (equal? key-alts cnb:last-key-alterations))
         (begin
           (set! cnb:last-key-alterations key-alts)
           (let ((key-pcs (cnb:get-key-pitch-classes key-alts)))
             (cnb:build-config-cache key-pcs)
             (cnb:invalidate-stencil-cache))))))


%% ---------------------------------------------------------------------------
%%  THE NOTEHEAD ENGRAVER
%% ---------------------------------------------------------------------------

#(define cnb-notehead-engraver
   (lambda (context)
     (make-engraver
       (acknowledgers
         ((note-head-interface engraver grob source-engraver)

           ;; Ensure the config cache is current for the active key
           (cnb:handle-key-change context)

           (let* (
                   (note-stencil   (cnb:get-note-stencil grob))
                   (note-event     (ly:grob-property grob 'cause))
                   (note-pitch     (ly:event-property note-event 'pitch))
                   (note-semis     (ly:pitch-semitones note-pitch))
                   (staff-def      (ly:context-grob-definition context 'StaffSymbol))
                   (staff-space    (or (assq-ref staff-def 'staff-space) 1.0))
                   (middleCPosition (ly:context-property context 'middleCPosition)))

               ;; Set the vertical position based on semitone value.
               ;;
               ;; PITCH-AXIS HOOK: when cnb:get-pitch-staff-position is a
               ;; procedure, it maps the absolute semitone to a staff
               ;; position in HALF-staff-spaces from the staff center
               ;; (the cnb:staff-line-positions unit; octave anchor baked
               ;; in — used as-is, NOT adjusted by middleCPosition; see
               ;; cnb/config.ly for the full unit contract). One staff
               ;; position is half a staff space, hence the * 0.5.
               ;;
               ;; The hook path sets ONLY Y-offset and leaves LilyPond's
               ;; diatonic staff-position property untouched, exactly like
               ;; the linear path below. Writing the mapped value into
               ;; staff-position is one of the two candidate mechanisms
               ;; for chord-internal horizontal arrangement (backlog 6.2)
               ;; and is decided there, not here.
               (ly:grob-set-property! grob 'Y-offset
                     (if (procedure? cnb:get-pitch-staff-position)
                         (* (cnb:get-pitch-staff-position note-semis)
                            0.5
                            staff-space)
                         (* (+ note-semis (* 2 middleCPosition))
                            (/ 1 cnb:semitones-per-staff-space)
                            staff-space)))

               ;; Replace the default notehead stencil with our custom one.
               (ly:grob-set-property! grob 'stencil
                     note-stencil)))))))
