%% ============================================================================
%%
%%  CNB MODULE: stencils.ly
%%  Notehead stencil construction and caching
%%  (Refactored to use make-path-stencil for true pre-computation)
%%
%%  WHAT THIS FILE DOES:
%%    Builds the 12 notehead stencils (one per pitch class C through B)
%%    from the configuration's path, color, rotation, and hollow settings.
%%    Stencils are pre-built at initialization time and cached by
%%    (pitch-class, duration-category) for instant lookup during engraving.
%%
%%  DEPENDENCIES: utils.ly, colors.ly, config.ly, procedure.ly, path-geometry.ly
%%
%%  DUAL MODEL SUPPORT:
%%    This module supports both the vector-cycling model and the
%%    procedure-oriented model, controlled by cnb:use-procedure-model.
%%
%%    VECTOR MODEL (cnb:use-procedure-model = #f):
%%      Builds 12 base stencils at init time from the cycling vectors
%%      (color, shape, hollow, rotation, scaling, offset). Key-independent.
%%
%%    PROCEDURE MODEL (cnb:use-procedure-model = #t):
%%      Builds stencils on demand from the resolved config cache.
%%      Stencils are key-dependent — the cache is invalidated on key change.
%%      No rotation/scaling/offset sequences (rotation baked into paths).
%%
%%  HOW NOTEHEAD RENDERING WORKS (the new pipeline):
%%
%%    OLD APPROACH (markup-based):
%%      1. Build 12 markup objects from config
%%      2. On first encounter of a note, call grob-interpret-markup
%%         (which REQUIRES a grob, preventing true pre-computation)
%%      3. Cache the resulting stencil
%%
%%    NEW APPROACH (make-path-stencil):
%%      1. Flatten the nested path data into the format make-path-stencil wants
%%      2. If hollow: ensure winding directions are opposite, then combine paths
%%      3. Call make-path-stencil to get a stencil DIRECTLY (no grob needed!)
%%      4. Apply color, rotation, scaling, and offset
%%      5. Cache the 12 base stencils as a vector — they're ready to use
%%      6. For each note, look up by pitch class, apply duration handling
%%         (repeating for half/whole notes), and apply magnification
%%
%%    The key insight: make-path-stencil doesn't need a grob.
%%    So we can build all 12 stencils at load time, before any music
%%    is even typeset. The per-note cost drops to a vector lookup,
%%    optional duplication for half/whole notes, and a scale operation.
%%
%%  FILL RULE NOTE:
%%    make-path-stencil uses the "non-zero winding" fill rule.
%%    For hollows to work, the hollow cutout path MUST wind in the
%%    opposite direction from the outer shape. The path-geometry module
%%    handles this automatically via cnb:ensure-opposite-winding.
%%
%%  FALSE-HOLLOW MODE:
%%    When cnb:false-hollow is #t, we DON'T combine the paths.
%%    Instead we build two separate stencils (shape + white overlay)
%%    and stack them. This is used for angular shapes (diamonds/kites)
%%    where the winding-based hollow can produce visual artifacts at
%%    sharp corners.
%%
%% ============================================================================


%% ---------------------------------------------------------------------------
%%  MODULUS HELPERS (VECTOR MODEL ONLY)
%%  These return the length of each sequence vector, used for wrapping
%%  pitch class indices via modulo arithmetic.
%% ---------------------------------------------------------------------------

#(define (cnb:notehead-color-modulus)
   (vector-length cnb:notehead-color-sequence))
#(define (cnb:notehead-shape-modulus)
   (vector-length cnb:notehead-shape-sequence))
#(define (cnb:notehead-hollow-modulus)
   (vector-length cnb:notehead-hollow-sequence))
#(define (cnb:notehead-rotation-modulus)
   (vector-length cnb:notehead-rotation-sequence))
#(define (cnb:notehead-scaling-modulus)
   (vector-length cnb:notehead-scaling-sequence))
#(define (cnb:notehead-offset-modulus)
   (vector-length cnb:notehead-offset-sequence))


%% ---------------------------------------------------------------------------
%%  HELPER: Apply rotation to a stencil
%%
%%  LilyPond's ly:stencil-rotate takes angle, x-center, y-center.
%%  We always rotate around (0, 0) since our paths are centered there.
%% ---------------------------------------------------------------------------

#(define (cnb:rotate-stencil stencil degrees)
   (if (= degrees 0)
       stencil
       (ly:stencil-rotate stencil degrees 0 0)))


%% ---------------------------------------------------------------------------
%%  BUILD THE 12 BASE STENCILS — VECTOR MODEL
%%
%%  Called ONCE at initialization, after all config overrides are applied.
%%  Produces a vector of 12 stencils, one per pitch class.
%%
%%  EACH STENCIL IS BUILT BY:
%%    1. Look up shape path, hollow path, color, rotation, scaling, offset
%%    2. Handle hollows based on cnb:false-hollow mode:
%%
%%       false-hollow = #f (true hollows via winding rule):
%%         a. Ensure hollow winds opposite to shape
%%         b. Flatten and combine: shape + hollow
%%         c. make-path-stencil on combined path -> filled with hole
%%
%%       false-hollow = #t (white overlay):
%%         a. make-path-stencil on shape -> filled solid in color
%%         b. make-path-stencil on hollow -> filled solid in white
%%         c. Stack them (white on top of color)
%%
%%       no hollow:
%%         a. make-path-stencil on shape -> filled solid
%%
%%    3. Apply color, rotation, scaling, offset
%%
%%  RETURNS: A vector of 12 stencils, index 0=C through 11=B.
%% ---------------------------------------------------------------------------

#(define (cnb:build-base-stencils)
   (list->vector
     (map (lambda (i)
       (let* (
               (color-hex (vector-ref cnb:notehead-color-sequence
                                      (modulo i (cnb:notehead-color-modulus))))
               (shape     (vector-ref cnb:notehead-shape-sequence
                                      (modulo i (cnb:notehead-shape-modulus))))
               (hollow    (vector-ref cnb:notehead-hollow-sequence
                                      (modulo i (cnb:notehead-hollow-modulus))))
               (rotation  (vector-ref cnb:notehead-rotation-sequence
                                      (modulo i (cnb:notehead-rotation-modulus))))
               (scaling   (vector-ref cnb:notehead-scaling-sequence
                                      (modulo i (cnb:notehead-scaling-modulus))))
               (offset    (vector-ref cnb:notehead-offset-sequence
                                      (modulo i (cnb:notehead-offset-modulus))))
               (x-scale   (car scaling))
               (y-scale   (cdr scaling))
               (rgb       (cnb:hex-to-rgb color-hex))
               (r (first rgb)) (g (second rgb)) (b (third rgb))

               (stencil
                 (cond

                   ;; TRUE HOLLOW: combine paths with opposite winding
                   ((and hollow (not cnb:false-hollow))
                    (let* (
                            (fixed-hollow (cnb:ensure-opposite-winding shape hollow))
                            (combined     (append (cnb:flatten-path shape)
                                                  (cnb:flatten-path fixed-hollow)))
                            (raw          (make-path-stencil combined 0.0001 1 1 #t)))
                      (ly:stencil-in-color raw r g b)))

                   ;; FALSE HOLLOW: white overlay on top of colored shape
                   ((and hollow cnb:false-hollow)
                    (let* (
                            (shape-flat   (cnb:flatten-path shape))
                            (hollow-flat  (cnb:flatten-path hollow))
                            (shape-raw    (make-path-stencil shape-flat 0.0001 1 1 #t))
                            (hollow-raw   (make-path-stencil hollow-flat 0.0001 1 1 #t))
                            (shape-col    (ly:stencil-in-color shape-raw r g b))
                            (hollow-white (ly:stencil-in-color hollow-raw 1.0 1.0 1.0)))
                      (ly:stencil-add shape-col hollow-white)))

                   ;; SOLID: no hollow at all
                   (else
                    (let* (
                            (shape-flat (cnb:flatten-path shape))
                            (raw        (make-path-stencil shape-flat 0.0001 1 1 #t)))
                      (ly:stencil-in-color raw r g b))))))

          ;; Apply transforms in order: rotate, scale, translate
          (set! stencil (cnb:rotate-stencil stencil rotation))
          (set! stencil (ly:stencil-scale stencil x-scale y-scale))
          (set! stencil (ly:stencil-translate stencil offset))

          stencil))
       (iota 12 0))))


%% ---------------------------------------------------------------------------
%%  BUILD A SINGLE STENCIL FROM A RESOLVED CONFIG — PROCEDURE MODEL
%%
%%  Takes a resolved config alist (from the config cache) and builds
%%  a stencil using the same true-hollow / false-hollow / solid logic
%%  as the vector model.
%%
%%  KEY DIFFERENCE FROM VECTOR MODEL:
%%    No rotation, scaling, or offset steps. In the procedure model,
%%    rotation is baked into path data (kite-up and kite-down are
%%    separate named shapes), and scaling/offset are not used.
%%
%%  PARAMETERS:
%%    config — a resolved config alist with keys:
%%      shape      — actual path data (list of drawing commands)
%%      color      — hex color string
%%      hollow     — #f or actual hollow path data
%%      attachment — actual attachment alist (not used here)
%%      off-key-mark — not used here
%%
%%  RETURNS: A stencil ready for use (before duration handling).
%% ---------------------------------------------------------------------------

#(define (cnb:build-stencil-from-config config)
   (let* ((shape-path  (assq-ref config 'shape))
          (color-hex   (assq-ref config 'color))
          (hollow-path (assq-ref config 'hollow))
          (rgb         (cnb:hex-to-rgb color-hex))
          (r (first rgb)) (g (second rgb)) (b (third rgb)))

     (cond

       ;; TRUE HOLLOW: combine paths with opposite winding
       ((and hollow-path (not cnb:false-hollow))
        (let* ((fixed-hollow (cnb:ensure-opposite-winding shape-path hollow-path))
               (combined     (append (cnb:flatten-path shape-path)
                                     (cnb:flatten-path fixed-hollow)))
               (raw          (make-path-stencil combined 0.0001 1 1 #t)))
          (ly:stencil-in-color raw r g b)))

       ;; FALSE HOLLOW: white overlay on top of colored shape
       ((and hollow-path cnb:false-hollow)
        (let* ((shape-flat   (cnb:flatten-path shape-path))
               (hollow-flat  (cnb:flatten-path hollow-path))
               (shape-raw    (make-path-stencil shape-flat 0.0001 1 1 #t))
               (hollow-raw   (make-path-stencil hollow-flat 0.0001 1 1 #t))
               (shape-col    (ly:stencil-in-color shape-raw r g b))
               (hollow-white (ly:stencil-in-color hollow-raw 1.0 1.0 1.0)))
          (ly:stencil-add shape-col hollow-white)))

       ;; SOLID: no hollow at all
       (else
        (let* ((shape-flat (cnb:flatten-path shape-path))
               (raw        (make-path-stencil shape-flat 0.0001 1 1 #t)))
          (ly:stencil-in-color raw r g b))))))


%% ---------------------------------------------------------------------------
%%  BASE STENCIL VECTOR — VECTOR MODEL (LAZILY INITIALIZED)
%%
%%  The 12 stencils are built on first access. This ensures all config
%%  overrides from the notation spec file have been applied before
%%  the stencils are constructed.
%% ---------------------------------------------------------------------------

#(define cnb:base-stencil-vector #f)

#(define (cnb:get-base-stencils)
   (if (not cnb:base-stencil-vector)
       (set! cnb:base-stencil-vector (cnb:build-base-stencils)))
   cnb:base-stencil-vector)


%% ---------------------------------------------------------------------------
%%  DURATION-SPECIFIC STENCIL CACHE
%%
%%  Base stencils are pre-built, but the per-duration variants
%%  (single for quarter+, doubled for half, quadrupled for whole)
%%  are cached separately since the combine-at-edge has some cost.
%%
%%  Uses integer keys with hashq-ref (correctly matched by eq?).
%%
%%  NOTE: In procedure model, this cache is invalidated on key change
%%  because stencils may depend on key (via the config procedure).
%% ---------------------------------------------------------------------------

#(define cnb:note-stencil-cache (make-hash-table 60))


%% ---------------------------------------------------------------------------
%%  INVALIDATE STENCIL CACHE
%%
%%  Called when the key changes (procedure model only). Clears the
%%  duration-specific stencil cache so stencils are rebuilt from the
%%  new config cache entries.
%% ---------------------------------------------------------------------------

#(define (cnb:invalidate-stencil-cache)
   (set! cnb:note-stencil-cache (make-hash-table 60)))


%% ---------------------------------------------------------------------------
%%  BUILD A DURATION-SPECIFIC STENCIL
%%
%%  Takes a base stencil and creates the appropriate repetition:
%%    category >= 2 -> quarter or shorter: 1 copy (no repetition)
%%    category  = 1 -> half note: 2 copies side by side
%%    category <= 0 -> whole/breve: 4 copies
%%
%%  The copies overlap by cnb:multinote-padding (usually negative = overlap).
%% ---------------------------------------------------------------------------

#(define (cnb:build-duration-stencil base-stencil duration-category)
   (let* ((stencil base-stencil))

      (for-each (lambda (i)
        (let* ((threshold (- 1 i)))
          (if (<= duration-category threshold)
              (set! stencil
                    (ly:stencil-combine-at-edge
                      stencil 0 1 stencil cnb:multinote-padding)))))
        (iota 3 0))

      stencil))


%% ---------------------------------------------------------------------------
%%  GET OR BUILD A NOTE STENCIL (MAIN ENTRY POINT)
%%
%%  Called by the notehead engraver for each note.
%%
%%  VECTOR MODEL:
%%    1. Extract pitch class and duration category from the grob
%%    2. Check cache for this (pitch-class, duration) combination
%%    3. On miss: build the duration variant from the base stencil and cache it
%%    4. Apply magnification (font-size dependent, so done outside cache)
%%
%%  PROCEDURE MODEL:
%%    1. Extract pitch class and duration category from the grob
%%    2. Check cache for this (pitch-class, duration) combination
%%    3. On miss: look up resolved config from procedure cache,
%%       build stencil from config, apply duration handling
%%       (unless repeat = #f in the config), cache it
%%    4. Apply magnification
%%
%%  PERFORMANCE:
%%    - First occurrence of each (pitch, duration): build + cache store
%%    - All subsequent occurrences: hash lookup + scale
%% ---------------------------------------------------------------------------

#(define (cnb:get-note-stencil grob)
   (let* (
           (note-event      (ly:grob-property grob 'cause))
           (note-pitch      (ly:event-property note-event 'pitch))
           (note-semis      (ly:pitch-semitones note-pitch))
           (pitch-class     (modulo note-semis 12))
           (note-dur-prop   (ly:event-property note-event 'duration))
           (dur-cat         (cnb:duration-category note-dur-prop))
           (mag             (magstep (ly:grob-property grob 'font-size 0.0)))
           (cache-key       (cnb:make-cache-key pitch-class dur-cat))
           (cached          (hashq-ref cnb:note-stencil-cache cache-key)))

      (if cached
          (ly:stencil-scale cached mag mag)

          ;; Cache miss — build the stencil
          (let* ((base-and-repeat
                   (if cnb:use-procedure-model

                       ;; PROCEDURE MODEL: build from resolved config
                       (let ((config (cnb:lookup-config pitch-class dur-cat)))
                         (if config
                             (cons (cnb:build-stencil-from-config config)
                                   (cnb:config-field config 'repeat))
                             ;; Fallback if cache miss (shouldn't happen)
                             (begin
                               (ly:warning "cnb: procedure config cache miss for pc=~a dur=~a"
                                           pitch-class dur-cat)
                               (cons empty-stencil #t))))

                       ;; VECTOR MODEL: look up from pre-built base stencils
                       ;; (always repeats — no repeat field in vector model)
                       (let ((base-stencils (cnb:get-base-stencils)))
                         (cons (vector-ref base-stencils pitch-class) #t))))

                 (base   (car base-and-repeat))
                 (repeat (cdr base-and-repeat))
                 (result (if (not (eq? repeat #f))
                             (cnb:build-duration-stencil base dur-cat)
                             base)))

            (hashq-set! cnb:note-stencil-cache cache-key result)
            (ly:stencil-scale result mag mag)))))


%% ---------------------------------------------------------------------------
%%  KEY SIGNATURE STENCIL LOOKUP
%%
%%  For key signatures, we always use the base (quarter-note) variant.
%%  Since stencils are pre-computed, this is just a vector lookup + scale.
%%
%%  NOTE: In procedure model, key signatures still use the config cache.
%%  The key signature is rendered in the context of the key it represents,
%%  so the config cache should already be built for that key.
%% ---------------------------------------------------------------------------

#(define (cnb:get-keysig-note-stencil pitch-class grob)
   (let* ((mag (magstep (ly:grob-property grob 'font-size 0.0))))

     (if cnb:use-procedure-model

         ;; PROCEDURE MODEL: build from config for quarter-note duration
         (let ((config (cnb:lookup-config pitch-class 3)))
           (if config
               (let ((stencil (cnb:build-stencil-from-config config)))
                 (ly:stencil-scale stencil mag mag))
               empty-stencil))

         ;; VECTOR MODEL: look up from pre-built base stencils
         (let* ((base-stencils (cnb:get-base-stencils))
                (base          (vector-ref base-stencils pitch-class)))
           (ly:stencil-scale base mag mag)))))
