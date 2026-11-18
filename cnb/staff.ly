%% ============================================================================
%%
%%  CNB MODULE: staff.ly
%%  Staff lines, ledger lines, and the staff symbol engraver
%%
%%  WHAT THIS FILE DOES:
%%    1. Manages staff line rendering (including custom colors/dashes)
%%    2. Manages ledger line rendering (including custom styles)
%%    3. Provides the staff-symbol engraver for simple mode
%%    4. Provides custom staff-symbol and ledger-line callbacks for
%%       advanced mode (when cnb:staff-and-ledger-lines is populated)
%%
%%  DEPENDENCIES: config.ly, utils.ly
%%
%%  TWO MODES OF OPERATION:
%%
%%    SIMPLE MODE (default):
%%      cnb:staff-and-ledger-lines is empty ('())
%%      Staff lines use cnb:staff-line-positions (a list of numbers)
%%      Ledger lines use cnb:ledger-positions (a list of numbers)
%%      All lines are black, solid, default thickness.
%%      The staff-symbol engraver sets these LilyPond properties directly.
%%
%%    ADVANCED MODE:
%%      cnb:staff-and-ledger-lines is populated with alist definitions
%%      Each line can have custom color, thickness, dash pattern
%%      The custom-staff-symbol callback draws lines manually
%%      The custom-ledger-line callback draws ledgers manually
%%
%%    The advanced mode is activated by your config file (or JS generator)
%%    setting cnb:staff-and-ledger-lines to a non-empty list.
%%
%%  LEDGER LINE HASH TABLES:
%%    For efficient lookup, ledger line definitions are stored in two
%%    hash tables:
%%      cnb:ledgers-by-notehead-position — given a note position,
%%        returns which ledger offsets to draw
%%      cnb:ledgers-by-offset — given a ledger Y offset,
%%        returns the line's style definition (color, dash, thickness)
%%
%%    These tables are populated by cnb:populate-ledger-hashes, which
%%    should be called after cnb:staff-and-ledger-lines is set.
%%
%% ============================================================================


%% ---------------------------------------------------------------------------
%%  STAFF LINE HELPERS
%% ---------------------------------------------------------------------------

%% Filter the staff-and-ledger-lines list to extract only staff lines.
#(define (is-staff-def? x)
   (eq? (assq-ref x 'type) 'staff-line))

#(define (cnb:staff-lines)
   (filter is-staff-def? cnb:staff-and-ledger-lines))

%% Extract just the position offsets from staff line definitions.
%% Used by the staff-symbol engraver to set LilyPond's line-positions.
#(define (cnb:staff-line-positions-from-line-def grob)
   (let* ((ss (ly:grob-property grob 'staff-space)))
     (map (lambda (x) (assq-ref x 'offset))
          (cnb:staff-lines))))


%% ---------------------------------------------------------------------------
%%  LEDGER LINE HASH TABLE MANAGEMENT
%% ---------------------------------------------------------------------------

%% Two hash tables for fast ledger line lookup during engraving.
%% These are populated once and then read many times.
#(define cnb:ledgers-by-notehead-position (make-hash-table 100))
#(define cnb:ledgers-by-offset (make-hash-table 100))

%% Populate both hash tables from the cnb:staff-and-ledger-lines definitions.
%%
%% HOW IT WORKS:
%%   For each ledger line definition, we store:
%%     1. In cnb:ledgers-by-notehead-position:
%%        key = notehead position, value = list of ledger offsets to draw
%%     2. In cnb:ledgers-by-offset:
%%        key = ledger Y offset, value = the full line definition (alist)
%%
%%   This allows the ledger engraver to:
%%     a) Given a note position, find which ledgers are needed
%%     b) Given a ledger offset, find its color/thickness/dash style
#(define (cnb:populate-ledger-hashes)
   (let* (
           (is-ledger-def? (lambda (x) (eq? (assq-ref x 'type) 'ledger-line)))
           (ledger-line-defs (filter is-ledger-def? cnb:staff-and-ledger-lines)))

      (for-each (lambda (def)
         (let (
               (offset (assq-ref def 'offset))
               (for-notehead-positions (assq-ref def 'for-notehead-positions)))
           (for-each (lambda (pos)
              (let* ((entry (hashq-ref cnb:ledgers-by-notehead-position pos)))
                (if (not entry)
                    (set! entry (list offset))
                    (set! entry (cnb:add-if-not-exists entry offset)))
                (hash-set! cnb:ledgers-by-notehead-position pos entry)))
             for-notehead-positions)
           (hash-set! cnb:ledgers-by-offset (* offset .5) def)))
       ledger-line-defs)))

%% Count how many notehead positions have custom ledger entries.
%% A count of 0 means we're in simple mode (no custom ledgers).
#(define (cnb:custom-ledger-count)
   (hash-count (const #t) cnb:ledgers-by-notehead-position))


%% ---------------------------------------------------------------------------
%%  SHARED LEDGER LINE DRAWING
%%
%%  This factored-out helper draws a single ledger line with the
%%  given style parameters. It's called by both the key-signature
%%  ledger code and the LedgerLineSpanner callback.
%%
%%  Previously, nearly identical drawing code existed in THREE places.
%%  Now there's just this one function.
%%
%%  PARAMETERS:
%%    grob        — a LilyPond grob (needed for grob-interpret-markup)
%%    x-start     — horizontal start position
%%    y-offset    — vertical position
%%    length      — horizontal length of the line
%%    mag         — current magnification factor
%%    line-def    — alist with optional: color, thickness, dash, length-factor
%%
%%  RETURNS:
%%    A stencil of the drawn ledger line.
%% ---------------------------------------------------------------------------

#(define (cnb:draw-single-ledger grob x-start y-offset length mag line-def)
   (let* (
           (color       (or (assq-ref line-def 'color) cnb:default-staff-line-color))
           (dash        (assq-ref line-def 'dash))
           (thickness   (* mag (or (assq-ref line-def 'thickness)
                                   cnb:default-staff-line-thickness)))
           (len-factor  (or (assq-ref line-def 'length-factor) 1.0))
           (adj-len     (* length len-factor))
           (adj-start   (- x-start (/ (- adj-len length) 2))))

      (grob-interpret-markup grob
        (if (not dash)
            (markup
              #:override `((thickness . ,thickness))
              #:translate `(,adj-start . ,y-offset)
              #:with-color color
              #:draw-line `(,adj-len . 0))
            (markup
              #:override `((thickness . ,thickness)
                           (on . ,(assq-ref dash 'on))
                           (off . ,(assq-ref dash 'off)))
              #:translate `(,adj-start . ,y-offset)
              #:with-color color
              #:draw-dashed-line `(,adj-len . 0))))))


%% ---------------------------------------------------------------------------
%%  CUSTOM LEDGER POSITIONS FUNCTION
%%
%%  A lambda stored as quoted code, to be used with LilyPond's
%%  StaffSymbol.ledger-positions-function property.
%%
%%  LilyPond calls this function for each note to determine which
%%  ledger lines should appear. It receives the StaffSymbol grob
%%  and the note's position, and returns a list of ledger positions.
%% ---------------------------------------------------------------------------

#(define (cnb:custom-ledger-positions)
   '(lambda (staff-symbol notehead-pos)
       (let* (
               (ss  (ly:grob-property staff-symbol 'staff-space))
               (mag (if (eq? ss '()) 1 ss))
               (positions (hashq-ref cnb:ledgers-by-notehead-position notehead-pos)))
          (if (not positions) '() positions))))


%% ---------------------------------------------------------------------------
%%  CUSTOM LEDGER LINE STENCIL CALLBACK
%%
%%  Replaces the default LedgerLineSpanner stencil with custom-drawn
%%  ledger lines that respect the style definitions in
%%  cnb:staff-and-ledger-lines.
%%
%%  HOW IT WORKS:
%%    1. LilyPond computes which ledger lines to show (positions)
%%    2. It builds a default stencil from those positions
%%    3. We receive that stencil in 'orig' and parse its structure
%%       to extract Y offsets and X extents
%%    4. We redraw each ledger using our custom styles
%%
%%  WHY WE PARSE THE ORIGINAL STENCIL:
%%    The original stencil contains the correct X positions (adjusted
%%    for note width, accidentals, etc.). Rather than recalculating
%%    those, we extract them and just restyle the lines.
%% ---------------------------------------------------------------------------

#(define (cnb:custom-ledger-line grob orig)
   (if (not (ly:stencil? orig))
       (grob-interpret-markup grob (markup ""))
       (let* (
               (note-heads   (ly:grob-array->list (ly:grob-object grob 'note-heads)))
               (note-head    (first note-heads))
               (expr         (ly:stencil-expr orig))
               (mag          (magstep (ly:grob-property note-head 'font-size 0.0)))
               (third-item   (third expr))
               (stencils     (if (eq? (car third-item) 'translate-stencil)
                                 (list third-item)
                                 (cdr (third expr))))
               (stencil-params
                 (map (lambda (s)
                        `((y-offset . ,(cdr (second s)))
                          (x-start  . ,(second (third s)))
                          (x-end    . ,(third (third s)))))
                   stencils))
               (new-stencil #f))

          (for-each (lambda (x)
             (let* (
                     (y-offset  (assq-ref x 'y-offset))
                     (entry     (hashv-ref cnb:ledgers-by-offset (/ y-offset mag)))
                     (start     (abs (assq-ref x 'x-start)))
                     (end       (assq-ref x 'x-end))
                     (len       (- end start))
                     (adj-start (- start (/ cnb:indent mag)))
                     (stencil   (cnb:draw-single-ledger
                                  grob adj-start y-offset len mag entry)))

               (set! new-stencil
                     (if (not new-stencil)
                         stencil
                         (ly:stencil-add new-stencil stencil)))))
            stencil-params)

          new-stencil)))


%% ---------------------------------------------------------------------------
%%  CUSTOM STAFF SYMBOL STENCIL CALLBACK
%%
%%  Replaces the default StaffSymbol stencil with custom-drawn
%%  staff lines that respect individual color, thickness, and dash
%%  settings from cnb:staff-and-ledger-lines.
%%
%%  HOW IT WORKS:
%%    1. Get the X extent from the original stencil (full system width)
%%    2. For each staff line definition, draw a line at the correct
%%       Y position with the specified style
%%    3. Combine all lines into one stencil
%% ---------------------------------------------------------------------------

#(define (cnb:custom-staff-symbol grob orig)
   (let* (
           (ss                  (ly:grob-property grob 'staff-space))
           (mag                 (if (eq? ss '()) 1 ss))
           (xex                 (ly:stencil-extent orig X))
           (cumulative-stencil  #f)
           (staff-line-defs     (cnb:staff-lines)))

      (for-each (lambda (i)
        (let* (
                (line-def  (list-ref staff-line-defs i))
                (y-offset  (* (assq-ref line-def 'offset) mag .5))
                (dash      (assq-ref line-def 'dash))
                (thickness (assq-ref line-def 'thickness))
                (color     (assq-ref line-def 'color))
                (current-stencil #f))

          (set! thickness
                (* (if (not thickness) cnb:default-staff-line-thickness thickness) mag))
          (set! color
                (if (not color) cnb:default-staff-line-color color))

          (set! current-stencil
                (ly:stencil-in-color
                  (grob-interpret-markup grob
                    (if (not dash)
                        (markup
                          #:override `((thickness . ,thickness))
                          #:translate `(0 . ,y-offset)
                          #:draw-line `(,(cdr xex) . 0))
                        (markup
                          #:override `((thickness . ,thickness)
                                       (on . ,(assq-ref dash 'on))
                                       (off . ,(assq-ref dash 'off)))
                          #:translate `(0 . ,y-offset)
                          #:draw-dashed-line `(,(cdr xex) . 0))))
                  color))

          (set! cumulative-stencil
                (if (not cumulative-stencil)
                    current-stencil
                    (ly:stencil-add cumulative-stencil current-stencil)))))
        (iota (length staff-line-defs) 0))

      cumulative-stencil))


%% ---------------------------------------------------------------------------
%%  STAFF SYMBOL ENGRAVER (SIMPLE MODE)
%%
%%  For simple mode (cnb:staff-and-ledger-lines is empty), this engraver
%%  sets LilyPond's native line-positions and assigns the proximity-based
%%  ledger-positions-function callback.
%%
%%  For advanced mode, the custom callbacks above handle everything
%%  and this engraver does nothing.
%% ---------------------------------------------------------------------------

#(define cnb-staff-symbol-engraver
   (lambda (context)
     (make-engraver
       (acknowledgers
         ((staff-symbol-interface engraver grob source-engraver)
           (if (eq? (length (cnb:staff-lines)) 0)
               (begin
                 (ly:grob-set-property! grob 'line-positions
                       cnb:staff-line-positions)
                 (ly:grob-set-property! grob 'ledger-positions-function
                       cnb:ledger-positions-function)
                 )))))))
