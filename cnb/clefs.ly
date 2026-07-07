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
%%    cnb:clef-style          — 'dozenal (default), 'text (render
%%                              cnb:clef-text instead of the computed
%%                              numeral), or 'none (no clef stencil).
%%    cnb:clef-text           — the label for 'text mode; a string
%%                              (rendered bold) or a markup (as-is).
%%    cnb:clef-size-semitones — display height in semitones; #f (default)
%%                              means the legacy 3 staff-spaces.
%%
%%  CACHING:
%%    Clef stencils are cached to avoid re-rendering the same display.
%%    The cache key covers everything the stencil depends on:
%%    (style, middleCPosition, ottava, text label ['text style only],
%%    size setting, cnb:semitones-per-staff-space, font magnification).
%%    The cache uses assoc-ref (equal? comparison) instead of assq-ref
%%    (eq?), because list keys need structural comparison.
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
   (if (memq cnb:clef-style '(dozenal text none))
       cnb:clef-style
       (begin
         (ly:warning
           "cnb:clef-style ~a not recognized (expected dozenal, text, or none); using dozenal"
           cnb:clef-style)
         'dozenal)))

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


%% ---------------------------------------------------------------------------
%%  CLEF STENCIL CONSTRUCTION
%%
%%  'dozenal: Build a clef stencil showing the dozenal number.
%%  The left digit is larger, the right digit is smaller and sits
%%  slightly higher, creating a clear two-digit display.
%%
%%  'text: Build a stencil from the configured cnb:clef-text label,
%%  scaled to the same target height. Plain strings render bold
%%  (matching the numeral's weight) at the glyph's natural aspect
%%  ratio; pass a markup for full styling control.
%% ---------------------------------------------------------------------------

#(define cnb:clef-stencil-cache '())

#(define (cnb:build-dozenal-clef-stencil grob middleCPosition ottava mag)
   (let* (
           (clef-num          (cnb:dozenal-clef middleCPosition ottava))
           (left-digit        (floor (/ clef-num 10)))
           (right-digit       (modulo clef-num 10))
           (left-markup       (markup (#:bold (number->string left-digit))))
           (right-markup      (markup (#:bold (number->string right-digit))))
           (stencil-left      (grob-interpret-markup grob left-markup))
           (stencil-right     (grob-interpret-markup grob right-markup))
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
                             (cons 0 (* -.5 mag)))
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
           (ly:stencil-translate
             (ly:stencil-scale stencil scale-factor scale-factor)
             (cons 0 (* -.5 mag)))))))

#(define (cnb:get-clef-stencil grob context)
   (let* (
           (style           (cnb:clef-resolved-style))
           (middleCPosition (ly:context-property context 'middleCPosition))
           (middleCOffset   (ly:context-property context 'middleCOffset))
           (ottava          (if (equal? middleCOffset '()) 0 middleCOffset))
           (mag             (magstep (ly:grob-property grob 'font-size 0.0)))
           ;; The key covers every input the stencil depends on. The text
           ;; label only participates in 'text style, so dozenal entries
           ;; are not invalidated by label edits.
           (cache-key       (list style middleCPosition ottava
                                  (if (eq? style 'text) cnb:clef-text #f)
                                  cnb:clef-size-semitones
                                  cnb:semitones-per-staff-space
                                  mag))
           (cached          (assoc-ref cnb:clef-stencil-cache cache-key)))

      (if cached
          cached
          (let ((built (if (eq? style 'text)
                           (cnb:build-text-clef-stencil grob mag)
                           (cnb:build-dozenal-clef-stencil
                             grob middleCPosition ottava mag))))
            (set! cnb:clef-stencil-cache
                  (assoc-set! cnb:clef-stencil-cache cache-key built))
            built))))


%% ---------------------------------------------------------------------------
%%  CLEF ENGRAVER
%%
%%  Intercepts Clef grobs and replaces their stencil according to
%%  cnb:clef-style: the dozenal number display ('dozenal), the
%%  configured label ('text), or nothing at all ('none).
%% ---------------------------------------------------------------------------

#(define cnb-clef-engraver
   (lambda (context)
     (make-engraver
       (acknowledgers
         ((clef-interface engraver grob source-engraver)
           (if (eq? (cnb:clef-resolved-style) 'none)
               ;; Suppress the clef entirely — engrave no stencil, so a
               ;; config with its clef disabled matches its preview.
               (ly:grob-set-property! grob 'stencil #f)
               (let* (
                       (stencil (cnb:get-clef-stencil grob context))
                       (mag     (magstep (ly:grob-property grob 'font-size 0.0))))

                 (ly:grob-set-property! grob 'X-offset (+ (* mag -.00001) 1))
                 (ly:grob-set-property! grob 'Y-offset (* mag -1))
                 (ly:grob-set-property! grob 'stencil stencil))))))))
