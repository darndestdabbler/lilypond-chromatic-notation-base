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
%%    staff-position property so the property agrees with the placed
%%    geometry (arrangement/collision logic read the geometry either
%%    way — see the site comment below). The default (#f) keeps the
%%    literal linear formula and never touches staff-position.
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
%%    - Mutating grobs WHILE positioning-done is being evaluated (a
%%      grob-transformer or plain wrapper around the property) segfaults
%%      LilyPond 2.24.2 on multi-voice scores — property evaluation is
%%      not reentrant against mutation.
%%
%%    - Translating EVERY head of a stem breaks LilyPond's
%%      note-collision meshing: Stem::note_head_positions(filter) drops
%%      heads at nonzero relative X (its way of skipping reversed
%%      heads) and check_meshing_chords indexes the surviving vector
%%      unguarded — an all-heads-moved stem segfaults 2.24.2 on
%%      multi-voice scores.
%%
%%    - What works for every case: AFTER the arrangement has run to
%%      completion, from a plain grob hook, split each stem's offsets
%%      into a COMMON component (the least-displaced head's offset)
%%      applied to the whole NoteColumn plus per-head RESIDUALS. The
%%      engraver captures each note's offset at acknowledge time (when
%%      the key-dependent config cache is current) in the custom grob
%%      property cnb-x-offset; cnb:apply-note-x-offsets — chained onto
%%      Stem.before-line-breaking in cnb/layout.ly — forces
%%      positioning-done, translates the column by the common part
%%      (single note: head, stem, and flag move as one) and each head
%%      by its residual (mixed chord: the stem stays with the unshifted
%%      member). The least-displaced head keeps relative X = 0, so the
%%      meshing invariant holds. This runs before horizontal spacing,
%%      so spacing, ledgers, dots, and multi-voice collisions all see
%%      the moved extents.
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

%% The resolved stem-attachment record of the note's config, captured
%% at acknowledge time for the same reason as cnb-x-offset: stem
%% attachment is evaluated at layout time, after later key changes have
%% rebuilt the config cache (audit 2026-11-02, M1). Read by
%% cnb:stem-attachment (cnb/stems.ly).
#(cnb:define-grob-property 'cnb-attachment list?
   "Stem-attachment record (crotchet-up, crotchet-down, minim-up,
minim-down) of this notehead's config, captured at acknowledge time.")

%% The offset applier, run from Stem.before-line-breaking (cnb/layout.ly).
%%
%% TIMING IS THE POINT: grobs must NOT be mutated while a property is
%% being evaluated — translating a head inside a positioning-done
%% wrapper (grob-transformer or plain) segfaults LilyPond 2.24.2 on
%% multi-voice scores (measured, s2 evidence). before-line-breaking is
%% a plain grob hook, so here we can FORCE the arrangement to run to
%% completion (the property value is cached), then translate on top of
%% it, before horizontal spacing reads any extent.
%%
%% When no head carries an offset (every score with the field unset)
%% this returns after a few plain property reads: positioning-done is
%% NOT forced early, so the default pipeline is byte-identical.
%%
%% The stem's own X may not be materialized yet, so it is forced before
%% the stem translation — translate_axis on an unmaterialized offset
%% would silently DISCARD the stem's X-offset callback (its attachment
%% to the notehead column).
#(define (cnb:apply-note-x-offsets grob)
   (let ((head-array (ly:grob-object grob 'note-heads)))
     (if (ly:grob-array? head-array)
         (let* ((heads (ly:grob-array->list head-array))
                (offs  (map (lambda (h)
                              (let ((o (ly:grob-property h 'cnb-x-offset 0)))
                                (if (number? o) o 0)))
                            heads))
                ;; plain fold — srfi-1 helpers are not visible in every
                ;; module that may end up calling this
                (has-offset (let loop ((l offs))
                              (cond ((null? l) #f)
                                    ((zero? (car l)) (loop (cdr l)))
                                    (else #t)))))
           (if has-offset
               ;; Split every offset into a COMMON component (the
               ;; least-displaced head's offset) applied to the whole
               ;; NoteColumn, plus per-head RESIDUALS:
               ;;
               ;;   single note          -> pure column translate: head,
               ;;                           stem, and flag move together
               ;;   mixed chord {0, N}   -> column stays (stem anchored
               ;;                           to the unshifted member),
               ;;                           offset member moves by N
               ;;   uniform chord {N, N} -> pure column translate
               ;;
               ;; CRASH INVARIANT (do not weaken): the least-displaced
               ;; head's residual is exactly 0, so every stem keeps at
               ;; least one head at relative X = 0. LilyPond's
               ;; note-collision meshing (Stem::note_head_positions with
               ;; filter) DROPS heads at nonzero relative X and then
               ;; indexes the remaining vector unguarded — a stem whose
               ;; every head is moved segfaults 2.24.2 on multi-voice
               ;; scores (measured, s2 evidence).
               (let* ((common (car (sort offs
                                         (lambda (a b)
                                           (< (abs a) (abs b))))))
                      (column (ly:grob-parent grob X)))
                 ;; run LilyPond's chord arrangement to completion FIRST
                 (ly:grob-property grob 'positioning-done)
                 (if (not (zero? common))
                     (begin
                       ;; materialize the column's X first — translating
                       ;; an unmaterialized offset silently discards any
                       ;; pending X-offset callback
                       (ly:grob-relative-coordinate
                         column (ly:grob-parent column X) X)
                       (ly:grob-translate-axis! column common X)))
                 (for-each
                   (lambda (h o)
                     (let ((residual (- o common)))
                       (if (not (zero? residual))
                           (ly:grob-translate-axis! h residual X))))
                   heads offs)))))))


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
               ;; LilyPond's staff-position property, for CONSISTENCY:
               ;; chord arrangement, collision meshing, ledgers, dots,
               ;; and stem geometry all read the placed GEOMETRY back
               ;; (Staff_symbol_referencer), so they operate in axis
               ;; space with or without this write (verified by source
               ;; and by measurement, s2 evidence — the 013 record's
               ;; §3.4 "diatonic-derived arrangement" reading was
               ;; mistaken). The write keeps the property from LYING to
               ;; any direct property reader: without it, the property
               ;; would keep its diatonic value and disagree with the
               ;; placed geometry. It plays NO role in the x-offset
               ;; chord mechanism (that is cnb:apply-note-x-offsets
               ;; above). Y-offset is still set explicitly, so
               ;; staff-position never drives vertical placement. The
               ;; #f path is the literal pre-hook formula and never
               ;; touches staff-position.
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

               ;; X-OFFSET (backlog 6.2 / E13-2) AND STEM ATTACHMENT
               ;; (audit 2026-11-02, M1): capture the config's optional
               ;; x-offset on the grob, scaled to absolute staff-space
               ;; units, for the post-arrangement translation in
               ;; cnb:apply-note-x-offsets (see the X-OFFSET SUPPORT
               ;; block above for why it cannot be applied here or in
               ;; the stencil), and its attachment record for
               ;; cnb:stem-attachment (cnb/stems.ly). Captured NOW
               ;; because the key-dependent config cache is current at
               ;; acknowledge time; both readers run at layout time,
               ;; after any later key changes have rebuilt the cache. A
               ;; zero or missing x-offset never touches the grob.
               (let* ((pc      (modulo note-semis 12))
                      (dur-cat (cnb:duration-category
                                 (ly:event-property note-event 'duration)))
                      (config  (cnb:lookup-config pc dur-cat))
                      (x-off   (let ((x (and config
                                             (cnb:config-field config 'x-offset))))
                                 (if (number? x) x 0))))
                 (let ((att (and config (cnb:config-field config 'attachment))))
                   (if (pair? att)
                       (ly:grob-set-property! grob 'cnb-attachment att)))
                 (if (not (zero? x-off))
                     (ly:grob-set-property! grob 'cnb-x-offset
                                            (* x-off staff-space))))))))))
