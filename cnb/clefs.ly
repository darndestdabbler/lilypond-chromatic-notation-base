%% ============================================================================
%%
%%  CNB MODULE: clefs.ly
%%  Dozenal clef system and clef engraver
%%
%%  WHAT THIS FILE DOES:
%%    Replaces LilyPond's standard clef symbols (treble, bass, alto)
%%    with TWO-DIGIT NUMBERS that indicate the pitch range.
%%    These numbers use a dozenal (base-12) system, where:
%%      - The left (large) digit represents the octave
%%      - The right (small) digit represents the pitch within that octave
%%
%%  DEPENDENCIES: config.ly
%%
%%  THE DOZENAL CLEF SYSTEM:
%%    Traditional clefs are abstract symbols that you memorize.
%%    Dozenal clefs are NUMBERS that tell you exactly what pitch is
%%    at the center of the staff. This makes sight-reading easier
%%    because you can immediately calculate any note's pitch.
%%
%%    Standard mappings:
%%      Treble clef       → 50  (middle of octave 5)
%%      Soprano/Mezzo     → 46  (middle of octave 4, upper half)
%%      Alto clef         → 40  (middle of octave 4)
%%      Tenor/Baritone    → 36  (middle of octave 3, upper half)
%%      Bass clef         → 30  (middle of octave 3)
%%
%%    NOTE: The "right digit" goes 0-9 then wraps. This isn't pure
%%    base-12 — it's a hybrid that stays readable for musicians
%%    who think in base 10.
%%
%%  HOW THE CLEF ENGRAVER WORKS:
%%    1. LilyPond creates a Clef grob with standard properties
%%    2. Our engraver intercepts it and reads middleCPosition + ottava
%%    3. We calculate the dozenal number from those values
%%    4. We render the two digits as text stencils (bold numbers)
%%    5. We replace the clef's stencil with our number display
%%
%%  CONFIGURATION (cnb/config.ly):
%%    cnb:clef-style            — 'dozenal (default), 'text (render
%%                                cnb:clef-text instead of the computed
%%                                numeral), 'none (no clef stencil), or
%%                                'custom (render the registered glyph
%%                                named by cnb:clef-name).
%%    cnb:clef-text             — the label for 'text mode; a string
%%                                (rendered bold) or a markup (as-is).
%%    cnb:clef-size-semitones   — display height in semitones; #f
%%                                (default) means the legacy 3
%%                                staff-spaces ('dozenal/'text) or the
%%                                registered definition's own height
%%                                ('custom). A sized 'dozenal numeral
%%                                is scaled about the staff's middle
%%                                line.
%%    cnb:clef-name            — which registered custom clef to show
%%                                in 'custom style.
%%    cnb:clef-gutter-semitones — extra blank space after the clef, in
%%                                semitones; #f (default) = none.
%%    cnb:clef-gutter-left-semitones — the same before the clef.
%%    cnb:clef-anchor-semitones — 'text style only: the semitone of the
%%                                label's top edge, placed as a 'custom
%%                                clef's anchor is; #f (default) = the
%%                                legacy fixed placement.
%%
%%  CUSTOM CLEF REGISTRATION (set 005, Configurator set-009 contract):
%%    (cnb:register-clef! name def) registers a named clef glyph, where
%%    def is an alist:
%%      (path . <nested path command list>)   — required; same format as
%%                                              cnb:notehead-shape-path
%%      (anchor-semitones . <number>)         — required; the semitone
%%                                              position of the glyph's
%%                                              TOP edge. A FLOAT — see
%%                                              the anchor contract note
%%                                              on cnb:register-clef!.
%%      (height-semitones . <positive number>) — optional design height;
%%                                              when absent the path
%%                                              renders at its native
%%                                              coordinate scale (1 path
%%                                              unit = 1 staff-space).
%%      (color . "#RRGGBB")                   — optional fill color;
%%                                              default black.
%%
%%  CACHING:
%%    Clef stencils are cached to avoid re-rendering the same display.
%%    The cache key covers everything the stencil depends on:
%%    (style, middleCPosition, ottava, text label and anchor setting
%%    ['text style only], custom clef name ['custom style only], size
%%    setting, both gutter
%%    settings, cnb:semitones-per-staff-space, font magnification).
%%    cnb:register-clef! clears the whole cache, because registration
%%    changes what an existing 'custom key would render.
%%    The cache uses assoc-ref (equal? comparison) instead of assq-ref
%%    (eq?), because list keys need structural comparison.
%%    The pitch-axis hook (cnb:get-pitch-staff-position, set 008) is
%%    deliberately NOT in the key: it affects only the grob Y-offset the
%%    ENGRAVER applies per acknowledge ('custom anchor placement), never
%%    the cached stencil itself (built with its top edge at y = 0).
%%
%% ============================================================================


%% ---------------------------------------------------------------------------
%%  DOZENAL CLEF NUMBER CALCULATION
%%
%%  Convert LilyPond's middleCPosition and ottava values into a
%%  two-digit dozenal number.
%%
%%  PARAMETERS:
%%    middle-c-position: LilyPond's internal value indicating where
%%      middle C sits on the staff. Different clefs have different values:
%%        Treble: -6, Alto: 0, Bass: 6  (in standard notation)
%%    ottava: Octave transposition from 8va/8vb markings.
%%      0 = no transposition, positive = up, negative = down.
%%
%%  RETURNS:
%%    A number like 50, 40, 30, etc. representing the dozenal clef.
%% ---------------------------------------------------------------------------

#(define (cnb:dozenal-clef middle-c-position ottava)
   (let* (
           (div-three (floor (/ (+ middle-c-position 1 (* -1 ottava)) 3)))
           (base-ten  (- 40 (* div-three 5)))
           (mod-ten   (modulo base-ten 10))
           (div-ten   (floor (/ base-ten 10))))
     (+ (* div-ten 10) (* mod-ten 6/5))))


%% ---------------------------------------------------------------------------
%%  HELPER: Extract the non-"_change" version of a clef glyph name.
%%
%%  When LilyPond shows a clef change mid-piece, it uses glyph names
%%  like "clefs.G_change" instead of "clefs.G". This function strips
%%  the "_change" suffix when needed.
%%
%%  This helper is not used directly by this module but is provided
%%  for config files that use LilyPond's predefined clef glyphs
%%  alongside the dozenal system.
%% ---------------------------------------------------------------------------

#(define (first-clef-glyph clef-glyph)
   (let* ((is-change? (eq? 7 (string-suffix-length clef-glyph "_change"))))
     (if is-change?
         (xsubstring clef-glyph 0 (- (string-length clef-glyph) 7))
         clef-glyph)))


%% ---------------------------------------------------------------------------
%%  CLEF STYLE RESOLUTION AND SIZE MATH (pure helpers)
%% ---------------------------------------------------------------------------

%% Validate cnb:clef-style. Unrecognized values warn and fall back to
%% 'dozenal so a typo degrades to today's behavior instead of erroring.
#(define (cnb:clef-resolved-style)
   (if (memq cnb:clef-style '(dozenal text none custom))
       cnb:clef-style
       (begin
         (ly:warning
           "cnb:clef-style ~a not recognized (expected dozenal, text, none, or custom); using dozenal"
           cnb:clef-style)
         'dozenal)))

%% The style the engraver will actually render: like
%% cnb:clef-resolved-style, but 'custom additionally requires a valid
%% registration under cnb:clef-name — otherwise warn and degrade to
%% 'dozenal (a missing registration renders today's display, never an
%% empty slot or a crash).
#(define (cnb:clef-effective-style)
   (let ((style (cnb:clef-resolved-style)))
     (if (and (eq? style 'custom)
              (not (cnb:clef-lookup cnb:clef-name)))
         (begin
           (ly:warning
             "cnb:clef-style is 'custom but cnb:clef-name ~a names no registered clef (see cnb:register-clef!); using dozenal"
             cnb:clef-name)
           'dozenal)
         style)))

%% Target height of the clef display in staff-space units (the unit
%% stencil extents are measured in), for a given font magnification.
%%
%%   cnb:clef-size-semitones = #f — legacy: 3 staff-spaces.
%%   cnb:clef-size-semitones = N  — N semitones, i.e.
%%                                  N / cnb:semitones-per-staff-space
%%                                  staff-spaces.
#(define (cnb:clef-target-height mag)
   (if (number? cnb:clef-size-semitones)
       (* mag (/ cnb:clef-size-semitones cnb:semitones-per-staff-space))
       (* 3 mag)))

%% Scale of the 'dozenal numeral's vertical offsets (the left digit's
%% -.5 translate and the engraver's -1 Y-offset): its target height over
%% the legacy 3 staff-spaces, so a sized numeral is scaled about the
%% staff's middle line. 1 when cnb:clef-size-semitones is #f.
#(define (cnb:dozenal-clef-offset-scale)
   (if (number? cnb:clef-size-semitones)
       (/ cnb:clef-size-semitones cnb:semitones-per-staff-space 3)
       1))

%% Gutter padding after the clef, in staff-space units, for a given
%% font magnification. 0 when cnb:clef-gutter-semitones is #f (legacy).
#(define (cnb:clef-gutter-pad mag)
   (if (number? cnb:clef-gutter-semitones)
       (* mag (/ cnb:clef-gutter-semitones cnb:semitones-per-staff-space))
       0))

%% Gutter padding before the clef, the same way, from
%% cnb:clef-gutter-left-semitones. 0 when it is #f (legacy).
#(define (cnb:clef-gutter-left-pad mag)
   (if (number? cnb:clef-gutter-left-semitones)
       (* mag (/ cnb:clef-gutter-left-semitones cnb:semitones-per-staff-space))
       0))


%% ---------------------------------------------------------------------------
%%  CUSTOM CLEF REGISTRATION (set 005 / Configurator set-009 contract)
%%
%%  Mirrors the notehead registration pattern (cnb:register-path! et al,
%%  cnb/procedure.ly): a hash table of named definitions populated by a
%%  registration function. The tables live here rather than in
%%  procedure.ly because everything else clef-shaped (cache, builders,
%%  engraver) lives in this module.
%%
%%  ANCHOR CONTRACT (Configurator set-009 s1 decision):
%%    anchor-semitones is the semitone position of the glyph's TOP
%%    edge, and it is a FLOAT — surveyed clef designs (Bravura gClef,
%%    Clairnote 2017 clefs, Express Stave F/B/D) register clefs by an
%%    interior musical feature, which puts the bounding-box top at a
%%    fractional grid offset. Any interior-feature registration reduces
%%    to a fractional top anchor: anchor = markedPitchSemi + k.
%%
%%    The semitone coordinate is the one the notehead engraver renders
%%    on (cnb/noteheads.ly): ly:pitch-semitones units, middle C = 0,
%%    combined with the context's middleCPosition. The glyph's top edge
%%    lands at exactly the vertical position where a notehead of that
%%    pitch would have its center, on ANY staff design — the placement
%%    divides through cnb:semitones-per-staff-space just like noteheads,
%%    or, when the pitch-axis hook cnb:get-pitch-staff-position is set
%%    (set 008), maps through the hook just like noteheads (fractional
%%    anchors interpolate — see cnb:clef-anchor-y-offset).
%% ---------------------------------------------------------------------------

#(define cnb:clef-defs (make-hash-table))

#(define cnb:clef-stencil-cache '())

%% Structural validity of a clef definition alist: a required path (a
%% non-empty list of drawing commands), a required numeric anchor, an
%% optional positive numeric height, an optional string color. Checks
%% the alist SHAPE first (every entry a pair) so malformed input — e.g.
%% a bare '(name path) list — is reported instead of crashing assq-ref.
#(define (cnb:clef-def-valid? def)
   (define (all-pairs? lst)
     (or (null? lst)
         (and (pair? (car lst))
              (all-pairs? (cdr lst)))))
   (and (list? def)
        (all-pairs? def)
        (let ((path   (assq-ref def 'path))
              (anchor (assq-ref def 'anchor-semitones))
              (height (assq-ref def 'height-semitones))
              (color  (assq-ref def 'color)))
          (and (pair? path)
               (number? anchor)
               (or (not height) (and (number? height) (> height 0)))
               (or (not color) (string? color))))))

%% Register (or re-register) a named custom clef. Invalid definitions
%% warn and are NOT registered, so cnb:clef-effective-style degrades to
%% 'dozenal instead of failing during engraving. Registration clears
%% the stencil cache: a cached 'custom stencil for this name would
%% otherwise keep rendering the old definition.
#(define (cnb:register-clef! name def)
   (if (and (symbol? name) (cnb:clef-def-valid? def))
       (begin
         (hashq-set! cnb:clef-defs name def)
         (set! cnb:clef-stencil-cache '()))
       (ly:warning
         "cnb:register-clef! ~a: invalid definition — expected an alist with (path . <non-empty list>), (anchor-semitones . <number>), optional (height-semitones . <positive number>) and (color . \"#RRGGBB\"); not registered"
         name)))

%% Look up a registered clef definition. #f when name is not a symbol
%% or nothing is registered under it.
#(define (cnb:clef-lookup name)
   (and (symbol? name) (hashq-ref cnb:clef-defs name)))

%% Vertical offset (in staff-spaces, relative to the staff center) that
%% places a glyph top edge at anchor-semitones — the notehead engraver's
%% position formula (cnb/noteheads.ly) applied to the anchor. The
%% engraver multiplies by the staff's staff-space, exactly as the
%% notehead engraver does.
%%
%% PITCH-AXIS HOOK (backlog 6.4 / E13-4): when
%% cnb:get-pitch-staff-position is a procedure, the anchor maps through
%% the hook instead of the linear formula, used AS-IS (octave anchor
%% baked into the hook, NOT adjusted by middleCPosition — the
%% cnb/config.ly unit contract). The hook's input contract is INTEGER
%% absolute semitones (the Configurator compiles procedures with
%% exact-integer modulo arithmetic), but anchor-semitones is a FLOAT by
%% the set-009 anchor contract (interior-feature registration puts the
%% top edge at a fractional grid offset), so a fractional anchor
%% interpolates linearly between the hook positions of its neighboring
%% integer semitones:
%%
%%   pos = hook(floor(a)) + frac(a) × (hook(floor(a)+1) − hook(floor(a)))
%%
%% On a linear map the interpolation is EXACT (it reduces symbol-for-
%% symbol to the formula the hook replaces, so the degeneracy invariant
%% holds); on a many-to-one axis an anchor between two semitones that
%% collapse onto one position stays at that shared position. Integer
%% anchors call the hook once, directly. The result is half-staff-
%% spaces, hence the × 0.5 to staff-spaces.
#(define (cnb:clef-anchor-y-offset anchor-semitones middle-c-position)
   (if (procedure? cnb:get-pitch-staff-position)
       (let* ((lo   (inexact->exact (floor anchor-semitones)))
              (frac (- anchor-semitones lo))
              (pos  (if (zero? frac)
                        (cnb:get-pitch-staff-position lo)
                        (let ((pos-lo (cnb:get-pitch-staff-position lo))
                              (pos-hi (cnb:get-pitch-staff-position (+ lo 1))))
                          (+ pos-lo (* frac (- pos-hi pos-lo)))))))
         (* pos 0.5))
       (* (+ anchor-semitones (* 2 middle-c-position))
          (/ 1 cnb:semitones-per-staff-space))))

%% Target height in semitones for a registered clef, or #f to render
%% the path at its native coordinate scale (1 path unit = 1 staff-space).
%% PRECEDENCE (recorded set-005 decision): the explicit score-level
%% cnb:clef-size-semitones override wins over the definition's own
%% height-semitones design field.
#(define (cnb:clef-custom-target-semitones def)
   (cond
     ((number? cnb:clef-size-semitones) cnb:clef-size-semitones)
     ((number? (assq-ref def 'height-semitones))
      (assq-ref def 'height-semitones))
     (else #f)))


%% ---------------------------------------------------------------------------
%%  CLEF STENCIL CONSTRUCTION
%%
%%  'dozenal: Build a clef stencil showing the dozenal number.
%%  The left digit is larger, the right digit is smaller and sits
%%  slightly higher, creating a clear two-digit display. With
%%  cnb:clef-size-semitones set, the left digit's -.5 translate is
%%  multiplied by cnb:dozenal-clef-offset-scale, as the engraver's
%%  Y-offset is, so the numeral is scaled about the middle line.
%%  cnb:dozenal-clef-numeral assembles it from the two digit stencils,
%%  so it can be measured without a grob.
%%
%%  'text: Build a stencil from the configured cnb:clef-text label,
%%  scaled to the same target height. Plain strings render bold
%%  (matching the numeral's weight) at the glyph's natural aspect
%%  ratio; pass a markup for full styling control.
%%
%%  'custom: Build a path stencil from a registered clef definition,
%%  scaled uniformly to its target height and translated so its TOP
%%  edge sits at y = 0 — the engraver then Y-offsets the grob to the
%%  anchor semitone (the set-009 anchor contract).
%% ---------------------------------------------------------------------------

#(define (cnb:build-dozenal-clef-stencil grob middleCPosition ottava mag)
   (let* (
           (clef-num          (cnb:dozenal-clef middleCPosition ottava))
           (left-digit        (floor (/ clef-num 10)))
           (right-digit       (modulo clef-num 10))
           (left-markup       (markup (#:bold (number->string left-digit))))
           (right-markup      (markup (#:bold (number->string right-digit)))))
     (cnb:dozenal-clef-numeral
       (grob-interpret-markup grob left-markup)
       (grob-interpret-markup grob right-markup)
       mag)))

%% The numeral from its two unscaled digit stencils: the left digit at
%% the target height (half width), the right at 2/3 of it beside it.
#(define (cnb:dozenal-clef-numeral stencil-left stencil-right mag)
   (let* (
           (y-extent          (ly:stencil-extent stencil-left 1))
           (height            (- (cdr y-extent) (car y-extent)))
           (scale-factor      (/ (cnb:clef-target-height mag) height))
           (stencil-left-scaled
             (ly:stencil-scale stencil-left
                               (* scale-factor 1/2) scale-factor))
           (stencil-right-scaled
             (ly:stencil-scale stencil-right
                               (* scale-factor 1/2) (* scale-factor 2/3))))
     (ly:stencil-combine-at-edge
       (ly:stencil-translate stencil-left-scaled
                             (cons 0 (* -.5 mag
                                        (cnb:dozenal-clef-offset-scale))))
       0 1
       (ly:stencil-translate stencil-right-scaled (cons 0 0))
       0)))

#(define (cnb:build-text-clef-stencil grob mag)
   (let* (
           (label     cnb:clef-text)
           (m         (cond
                        ((string? label) (make-bold-markup label))
                        ((markup? label) label)
                        (else
                          (ly:warning
                            "cnb:clef-text ~a is not a string or markup; rendering nothing"
                            label)
                          "")))
           (stencil   (grob-interpret-markup grob m))
           (y-extent  (ly:stencil-extent stencil 1))
           (height    (- (cdr y-extent) (car y-extent))))
     ;; An empty label produces a zero-height stencil — return it
     ;; unscaled to avoid dividing by zero.
     (if (<= height 0)
         stencil
         (let ((scale-factor (/ (cnb:clef-target-height mag) height)))
           (cnb:clef-text-place
             (ly:stencil-scale stencil scale-factor scale-factor)
             mag)))))

%% Vertical placement of a scaled 'text label: the legacy -.5 × mag
%% translate, or — with cnb:clef-anchor-semitones set — its TOP edge at
%% y = 0, as a 'custom glyph's is, so the engraver can Y-offset it to
%% the anchor semitone.
#(define (cnb:clef-text-place scaled mag)
   (ly:stencil-translate
     scaled
     (cons 0 (if (number? cnb:clef-anchor-semitones)
                 (- (cdr (ly:stencil-extent scaled 1)))
                 (* -.5 mag)))))

#(define (cnb:build-custom-clef-stencil def mag)
   (let* (
           (path         (assq-ref def 'path))
           (color        (assq-ref def 'color))
           (raw          (make-path-stencil
                           (cnb:flatten-path path) 0.0001 1 1 #t))
           (colored      (if (string? color)
                             (let* ((rgb (cnb:hex-to-rgb color)))
                               (ly:stencil-in-color raw
                                 (first rgb) (second rgb) (third rgb)))
                             raw))
           (y-extent     (ly:stencil-extent colored 1))
           (height       (- (cdr y-extent) (car y-extent)))
           (target-semis (cnb:clef-custom-target-semitones def))
           ;; Uniform scale: explicit/design height in semitones, or the
           ;; path's native scale (1 path unit = 1 staff-space) when no
           ;; height is given. A degenerate flat path skips the height
           ;; division to avoid dividing by zero.
           (scale-factor (if (and (number? target-semis) (> height 0))
                             (/ (* mag (/ target-semis
                                          cnb:semitones-per-staff-space))
                                height)
                             mag))
           (scaled       (ly:stencil-scale colored scale-factor scale-factor))
           (scaled-top   (cdr (ly:stencil-extent scaled 1))))
     ;; Anchor contract: put the glyph's TOP edge at y = 0. The engraver
     ;; Y-offsets the grob so y = 0 lands on the anchor semitone.
     (ly:stencil-translate scaled (cons 0 (- scaled-top)))))

%% Add the configured gutter padding to a built clef stencil — blank
%% space, no ink. The right pad widens its right X-extent, so LilyPond's
%% horizontal spacing pushes the following material further from the
%% clef. The left pad moves the ink right while the X-extent keeps its
%% left edge, so the blank space sits before the ink. No-op at the
%% legacy defaults (both gutter settings #f) or on empty stencils.
#(define (cnb:clef-apply-gutter stencil mag)
   (let ((pad      (cnb:clef-gutter-pad mag))
         (left-pad (cnb:clef-gutter-left-pad mag)))
     (if (or (and (= pad 0) (= left-pad 0)) (ly:stencil-empty? stencil X))
         stencil
         (let ((x-extent (ly:stencil-extent stencil 0))
               (y-extent (ly:stencil-extent stencil 1)))
           (ly:make-stencil
             (ly:stencil-expr (if (= left-pad 0)
                                  stencil
                                  (ly:stencil-translate-axis stencil left-pad X)))
             (cons (car x-extent) (+ (cdr x-extent) left-pad pad))
             y-extent)))))

#(define (cnb:get-clef-stencil grob context style)
   (let* (
           (middleCPosition (ly:context-property context 'middleCPosition))
           (middleCOffset   (ly:context-property context 'middleCOffset))
           (ottava          (if (equal? middleCOffset '()) 0 middleCOffset))
           (mag             (magstep (ly:grob-property grob 'font-size 0.0)))
           ;; The key covers every input the stencil depends on. The text
           ;; label participates only in 'text style and the custom clef
           ;; name only in 'custom style, so dozenal entries are not
           ;; invalidated by label edits or name switches.
           (cache-key       (list style middleCPosition ottava
                                  (if (eq? style 'text) cnb:clef-text #f)
                                  (if (eq? style 'text) cnb:clef-anchor-semitones #f)
                                  (if (eq? style 'custom) cnb:clef-name #f)
                                  cnb:clef-size-semitones
                                  cnb:clef-gutter-semitones
                                  cnb:clef-gutter-left-semitones
                                  cnb:semitones-per-staff-space
                                  mag))
           (cached          (assoc-ref cnb:clef-stencil-cache cache-key)))

      (if cached
          cached
          (let* ((built (cond
                          ((eq? style 'text)
                           (cnb:build-text-clef-stencil grob mag))
                          ((eq? style 'custom)
                           (cnb:build-custom-clef-stencil
                             (cnb:clef-lookup cnb:clef-name) mag))
                          (else
                           (cnb:build-dozenal-clef-stencil
                             grob middleCPosition ottava mag))))
                 (padded (cnb:clef-apply-gutter built mag)))
            (set! cnb:clef-stencil-cache
                  (assoc-set! cnb:clef-stencil-cache cache-key padded))
            padded))))


%% ---------------------------------------------------------------------------
%%  CLEF ENGRAVER
%%
%%  Intercepts Clef grobs and replaces their stencil according to
%%  cnb:clef-style: the dozenal number display ('dozenal), the
%%  configured label ('text), a registered glyph ('custom), or nothing
%%  at all ('none).
%%
%%  VERTICAL PLACEMENT:
%%    'dozenal / 'text — the legacy fixed placement around the staff
%%    center (Y-offset -1 staff-space × mag, plus the -.5 translate
%%    baked into the builders). These are register displays centered on
%%    the staff, not pitch-anchored — the pitch-axis hook does not move
%%    them. A 'dozenal numeral sized by cnb:clef-size-semitones has both
%%    offsets multiplied by cnb:dozenal-clef-offset-scale, so it is
%%    scaled about the middle line. Exception: a 'text clef with cnb:clef-anchor-semitones set is
%%    anchored like 'custom, at that semitone.
%%    'custom — the anchor contract: the stencil's top edge (y = 0 by
%%    construction) is offset to the anchor semitone with the notehead
%%    engraver's own formula — linear, or through the pitch-axis hook
%%    when cnb:get-pitch-staff-position is set (backlog 6.4 / E13-4; see
%%    cnb:clef-anchor-y-offset) — scaled by the staff's staff-space
%%    exactly as noteheads are (cnb/noteheads.ly).
%% ---------------------------------------------------------------------------

#(define cnb-clef-engraver
   (lambda (context)
     (make-engraver
       (acknowledgers
         ((clef-interface engraver grob source-engraver)
           (let ((style (cnb:clef-effective-style)))
             (if (eq? style 'none)
                 ;; Suppress the clef entirely — engrave no stencil, so a
                 ;; config with its clef disabled matches its preview.
                 (ly:grob-set-property! grob 'stencil #f)
                 (let* (
                         (stencil (cnb:get-clef-stencil grob context style))
                         (mag     (magstep (ly:grob-property grob 'font-size 0.0))))

                   (ly:grob-set-property! grob 'X-offset (+ (* mag -.00001) 1))
                   (let ((anchor
                           (cond
                             ((eq? style 'custom)
                              (assq-ref (cnb:clef-lookup cnb:clef-name)
                                        'anchor-semitones))
                             ((and (eq? style 'text)
                                   (number? cnb:clef-anchor-semitones))
                              cnb:clef-anchor-semitones)
                             (else #f))))
                     (if anchor
                         (let* (
                                 (middleCPosition
                                   (ly:context-property context 'middleCPosition))
                                 (staff-def
                                   (ly:context-grob-definition context 'StaffSymbol))
                                 (staff-space
                                   (or (assq-ref staff-def 'staff-space) 1.0)))
                           (ly:grob-set-property! grob 'Y-offset
                             (* (cnb:clef-anchor-y-offset anchor middleCPosition)
                                staff-space)))
                         (ly:grob-set-property! grob 'Y-offset
                           (if (eq? style 'dozenal)
                               (* mag -1 (cnb:dozenal-clef-offset-scale))
                               (* mag -1)))))
                   (ly:grob-set-property! grob 'stencil stencil)))))))))
