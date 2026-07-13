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
%%    hook path additionally writes the mapped value into the grob's
%%    staff-position property so chord arrangement and collision logic
%%    operate in axis space (the backlog-6.2 mechanism decision — see
%%    the site comment below). The default (#f) keeps the literal
%%    linear formula and never touches staff-position.
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
%%  X-OFFSET SUPPORT (backlog 6.2 / E13-2)
%%
%%  The config alist's optional x-offset field moves a notehead
%%  horizontally by N staff spaces (of the containing staff — the unit
%%  scales with \magnifyStaff), so pitch-axis configs can disambiguate
%%  shared-position pitches. Mechanism, decided by measurement (see the
%%  set-008 session-2 evidence):
%%
%%    - A STENCIL translation is re-derived away by LilyPond's chord
%%      arrangement (Stem::calc_positioning_done edge-aligns every head
%%      to the support head from stencil EXTENTS, then shifts reversed
%%      heads by their own extent), so a chord member's offset survives
%%      or is absorbed depending on stem direction and reversal order.
%%    - The X-offset PROPERTY is silently discarded for chord members
%%      (the arrangement's translate_axis materializes the offset cache
%%      before the property is ever evaluated), and single-note stems
%%      do not follow the head.
%%
%%    - What works for every case: translate the grobs immediately AFTER
%%      the arrangement. The engraver captures each note's offset at
%%      acknowledge time (when the key-dependent config cache is
%%      current) in the custom grob property cnb-x-offset, and a wrapper
%%      around Stem.positioning-done (installed in cnb/layout.ly)
%%      applies it: each head is translated by its own offset, the stem
%%      by the offset of its LEAST-DISPLACED head — a single note's
%%      head and stem move together, a mixed chord's stem stays with the
%%      unshifted member. Everything that reads head positions (spacing,
%%      ledgers, dots, multi-voice collisions) forces positioning-done
%%      first, so the moved extents propagate everywhere downstream.
%% ---------------------------------------------------------------------------

%% Register the custom grob property (the standard LilyPond extension
%% idiom): per-note x-offset, already scaled to absolute staff-space
%% units at capture time.
#(define (cnb:define-grob-property symbol type? description)
   (set-object-property! symbol 'backend-type? type?)
   (set-object-property! symbol 'backend-doc description)
   symbol)

#(cnb:define-grob-property 'cnb-x-offset number?
   "Pitch-axis horizontal offset for this notehead, in absolute
staff-space units (already scaled by the staff's staff-space).")

%% The Stem.positioning-done wrapper. Runs with LilyPond's own
%% arrangement already applied (grob-transformer evaluates the default
%% first); `done` is that default's value and is returned unchanged.
%%
%% The stem's own X may not be materialized yet, so it is forced before
%% the stem translation — translate_axis on an unmaterialized offset
%% would silently DISCARD the stem's X-offset callback (its attachment
%% to the notehead column).
#(define (cnb:apply-note-x-offsets grob done)
   (let ((head-array (ly:grob-object grob 'note-heads)))
     (if (ly:grob-array? head-array)
         (let* ((heads (ly:grob-array->list head-array))
                (offs  (map (lambda (h)
                              (let ((o (ly:grob-property h 'cnb-x-offset 0)))
                                (if (number? o) o 0)))
                            heads)))
           (if (any (lambda (o) (not (zero? o))) offs)
               (begin
                 (for-each
                   (lambda (h o)
                     (if (not (zero? o))
                         (ly:grob-translate-axis! h o X)))
                   heads offs)
                 ;; Stem anchor: the least-displaced head's offset.
                 ;; Single note / uniformly offset chord: the stem moves
                 ;; with the head(s). Chord with any unshifted member:
                 ;; the stem stays put.
                 (let ((stem-off (car (sort offs
                                            (lambda (a b)
                                              (< (abs a) (abs b)))))))
                   (if (not (zero? stem-off))
                       (begin
                         (ly:grob-relative-coordinate
                           grob (ly:grob-parent grob X) X)
                         (ly:grob-translate-axis! grob stem-off X)))))))))
   done)


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
               ;; The hook path ALSO writes the mapped value into
               ;; LilyPond's staff-position property — the backlog-6.2
               ;; chord-mechanism decision. Chord-internal horizontal
               ;; arrangement and note-column collision logic read the
               ;; staff-position PROPERTY (diatonic unless overwritten),
               ;; not the placed geometry, so writing it makes both run
               ;; in axis space: shared-position chord members arrange as
               ;; unisons and honor the config's x-offset (otherwise the
               ;; offset is ABSORBED for diatonic-neighbor pairs — 013
               ;; record §3.4), and cnb:collision-threshold compares
               ;; axis-space distances (backlog 6.5). Y-offset is still
               ;; set explicitly, so staff-position never drives vertical
               ;; placement. The #f path is the literal pre-hook formula
               ;; and never touches staff-position.
               (if (procedure? cnb:get-pitch-staff-position)
                   (let ((mapped-pos (cnb:get-pitch-staff-position note-semis)))
                     (ly:grob-set-property! grob 'staff-position mapped-pos)
                     (ly:grob-set-property! grob 'Y-offset
                           (* mapped-pos 0.5 staff-space)))
                   (ly:grob-set-property! grob 'Y-offset
                         (* (+ note-semis (* 2 middleCPosition))
                            (/ 1 cnb:semitones-per-staff-space)
                            staff-space)))

               ;; Replace the default notehead stencil with our custom one.
               (ly:grob-set-property! grob 'stencil
                     note-stencil)

               ;; X-OFFSET (backlog 6.2 / E13-2): capture the config's
               ;; optional x-offset on the grob, scaled to absolute
               ;; staff-space units, for the post-arrangement translation
               ;; in cnb:apply-note-x-offsets (see the X-OFFSET SUPPORT
               ;; block above for why it cannot be applied here or in
               ;; the stencil). Captured NOW because the key-dependent
               ;; config cache is current at acknowledge time; the
               ;; wrapper runs at layout time, after any later key
               ;; changes have rebuilt the cache. A zero or missing
               ;; field never touches the grob — byte-identical to
               ;; today's behavior.
               (let* ((pc      (modulo note-semis 12))
                      (dur-cat (cnb:duration-category
                                 (ly:event-property note-event 'duration)))
                      (config  (cnb:lookup-config pc dur-cat))
                      (x-off   (let ((x (and config
                                             (cnb:config-field config 'x-offset))))
                                 (if (number? x) x 0))))
                 (if (not (zero? x-off))
                     (ly:grob-set-property! grob 'cnb-x-offset
                                            (* x-off staff-space))))))))))
