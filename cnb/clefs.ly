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
%%  CACHING:
%%    Clef stencils are cached by (middleCPosition, ottava) to avoid
%%    re-rendering the same numbers. BUG FIX: The cache now uses
%%    assoc-ref (equal? comparison) instead of assq-ref (eq?), because
%%    list keys need structural comparison.
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
%%  CLEF STENCIL CONSTRUCTION
%%
%%  Build a clef stencil showing the dozenal number.
%%  The left digit is larger, the right digit is smaller and sits
%%  slightly higher, creating a clear two-digit display.
%% ---------------------------------------------------------------------------

#(define cnb:clef-stencil-cache '())

#(define (cnb:get-clef-stencil grob context)
   (let* (
           (middleCPosition (ly:context-property context 'middleCPosition))
           (middleCOffset   (ly:context-property context 'middleCOffset))
           (ottava          (if (equal? middleCOffset '()) 0 middleCOffset))
           (cache-key       (cons middleCPosition ottava))
           (cached          (assoc-ref cnb:clef-stencil-cache cache-key)))

      (if cached
          cached
          (let* (
                  (clef-num          (cnb:dozenal-clef middleCPosition ottava))
                  (mag               (magstep (ly:grob-property grob 'font-size 0.0)))
                  (left-digit        (floor (/ clef-num 10)))
                  (right-digit       (modulo clef-num 10))
                  (left-markup       (markup (#:bold (number->string left-digit))))
                  (right-markup      (markup (#:bold (number->string right-digit))))
                  (stencil-left      (grob-interpret-markup grob left-markup))
                  (stencil-right     (grob-interpret-markup grob right-markup))
                  (y-extent          (ly:stencil-extent stencil-left 1))
                  (height            (- (cdr y-extent) (car y-extent)))
                  (scale-factor      (/ (* 3 mag) height))
                  (stencil-left-scaled
                    (ly:stencil-scale stencil-left
                                      (* scale-factor 1/2) scale-factor))
                  (stencil-right-scaled
                    (ly:stencil-scale stencil-right
                                      (* scale-factor 1/2) (* scale-factor 2/3)))
                  (combined
                    (ly:stencil-combine-at-edge
                      (ly:stencil-translate stencil-left-scaled
                                            (cons 0 (* -.5 mag)))
                      0 1
                      (ly:stencil-translate stencil-right-scaled (cons 0 0))
                      0)))

            (set! cnb:clef-stencil-cache
                  (assoc-set! cnb:clef-stencil-cache cache-key combined))
            combined))))


%% ---------------------------------------------------------------------------
%%  CLEF ENGRAVER
%%
%%  Intercepts Clef grobs and replaces their stencil with the
%%  dozenal number display.
%% ---------------------------------------------------------------------------

#(define cnb-clef-engraver
   (lambda (context)
     (make-engraver
       (acknowledgers
         ((clef-interface engraver grob source-engraver)
           (let* (
                   (stencil (cnb:get-clef-stencil grob context))
                   (mag     (magstep (ly:grob-property grob 'font-size 0.0))))

             (ly:grob-set-property! grob 'X-offset (+ (* mag -.00001) 1))
             (ly:grob-set-property! grob 'Y-offset (* mag -1))
             (ly:grob-set-property! grob 'stencil stencil)))))))
