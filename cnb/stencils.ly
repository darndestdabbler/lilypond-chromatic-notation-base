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
%%  MODEL:
%%    Stencils are built on demand from the resolved config cache produced
%%    by the configuration procedure (cnb:get-notehead-config, see
%%    procedure.ly). Stencils are key-dependent — the cache is invalidated
%%    on key change. There is no rotation/scaling/offset step: rotation
%%    is baked into named shapes and scaling into the path coordinates;
%%    the config's optional x-offset field (staff spaces; pitch-axis
%%    disambiguation, backlog 6.2/E13-2) is applied by the notehead
%%    engraver via the grob's X-offset property, NOT here — see the
%%    note in cnb:get-note-stencil.
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
%%  BUILD A SINGLE STENCIL FROM A RESOLVED CONFIG
%%
%%  Takes a resolved config alist (from the config cache) and builds
%%  a stencil using true-hollow / false-hollow / solid logic.
%%
%%  There is no rotation, scaling, or offset step: rotation is baked into
%%  path data (e.g. kite-up and kite-down are separate named shapes), and
%%  scaling is baked into the path coordinates.
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
%%  DURATION-SPECIFIC STENCIL CACHE
%%
%%  The per-duration variants (single for quarter+, doubled for half,
%%  quadrupled for whole) are cached by (pitch-class, duration-category)
%%  since the combine-at-edge has some cost.
%%
%%  Uses integer keys with hashq-ref (correctly matched by eq?).
%%
%%  This cache is invalidated on key change, because stencils may depend on
%%  key (via the config procedure).
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
%%    1. Extract pitch class and duration category from the grob
%%    2. Check cache for this (pitch-class, duration) combination
%%    3. On miss: look up resolved config from the procedure cache,
%%       build stencil from config, apply duration handling
%%       (unless repeat = #f in the config), cache it
%%    4. Apply magnification (font-size dependent, so done outside cache)
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

          ;; Cache miss — build the stencil from the resolved config
          ;;
          ;; NOTE: the config's x-offset field (backlog 6.2 / E13-2) is
          ;; deliberately NOT applied here as a stencil translation.
          ;; LilyPond's chord arrangement (Stem::calc_positioning_done)
          ;; re-derives head X from stencil EXTENTS — edge-aligning every
          ;; head to the support head and shifting reversed heads by
          ;; their own extent — so a translated stencil survives or is
          ;; absorbed depending on stem direction and which chord member
          ;; got reversed (measured this set, s2-evidence). The engraver
          ;; applies x-offset via the grob's X-offset property instead
          ;; (cnb/noteheads.ly), which LilyPond adds AFTER that
          ;; arrangement arithmetic.
          (let* ((base-and-repeat
                   (let ((config (cnb:lookup-config pitch-class dur-cat)))
                     (if config
                         (cons (cnb:build-stencil-from-config config)
                               (cnb:config-field config 'repeat))
                         ;; Fallback if cache miss (shouldn't happen)
                         (begin
                           (ly:warning "cnb: procedure config cache miss for pc=~a dur=~a"
                                       pitch-class dur-cat)
                           (cons empty-stencil #t)))))

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
%%  For key signatures, we always use the quarter-note (dur-cat 3) variant.
%%
%%  Key signatures use the config cache. The key signature is rendered in
%%  the context of the key it represents, so the config cache should already
%%  be built for that key.
%%
%%  The config's x-offset field is deliberately NOT applied here: whether
%%  the key-signature chord display adopts the pitch-axis horizontal
%%  disambiguation is decided with keysig-through-the-hook (backlog 6.3,
%%  set 008 session 3), not by the notehead field (6.2).
%% ---------------------------------------------------------------------------

#(define (cnb:get-keysig-note-stencil pitch-class grob)
   (let* ((mag (magstep (ly:grob-property grob 'font-size 0.0)))
          (config (cnb:lookup-config pitch-class 3)))
     (if config
         (let ((stencil (cnb:build-stencil-from-config config)))
           (ly:stencil-scale stencil mag mag))
         empty-stencil)))
