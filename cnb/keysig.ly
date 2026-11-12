%% ============================================================================
%%
%%  CNB MODULE: keysig.ly
%%  Notehead-based key signatures and key signature engraver
%%
%%  WHAT THIS FILE DOES:
%%    Replaces LilyPond's standard key signature (sharps/flats on lines)
%%    with a display of ACTUAL NOTEHEADS showing the key's characteristic
%%    chord, followed by a gold vertical bar separator.
%%
%%  DEPENDENCIES: config.ly, stencils.ly, staff.ly
%%
%%  HOW THE NOTEHEAD KEY SIGNATURE WORKS:
%%    Instead of showing abstract sharp/flat symbols, this system shows
%%    two stacks of noteheads — specifically, two 7th chords built on
%%    the first and second scale degrees of the key.
%%
%%    The chord types depend on the mode:
%%
%%    FIRST CHORD (root of key):
%%      Aeolian (minor), Dorian, Phrygian → minor 7th
%%      Ionian (major), Lydian            → major 7th
%%      Mixolydian                        → dominant 7th
%%      Locrian                           → half-diminished 7th
%%
%%    SECOND CHORD (2nd degree):
%%      Ionian, Dorian, Mixolydian        → minor 7th
%%      Phrygian, Locrian                 → major 7th
%%      Lydian                            → dominant 7th
%%      Aeolian                           → half-diminished 7th
%%
%%    The noteheads are interleaved in two columns (even-indexed notes
%%    in the left column, odd-indexed notes in the right) for readability.
%%    Ledger lines are drawn for notes that extend beyond the staff.
%%    The whole thing is capped with a vertical gold bar.
%%
%% ============================================================================


%% ---------------------------------------------------------------------------
%%  HELPER: Staff spaces per octave
%%  This depends on cnb:semitones-per-staff-space and determines how
%%  spread out the key signature noteheads are vertically.
%% ---------------------------------------------------------------------------

#(define (cnb:spaces-per-octave)
   (/ 12 cnb:semitones-per-staff-space))


%% ---------------------------------------------------------------------------
%%  KEY SIGNATURE SETTING RESOLVERS (pure helpers)
%% ---------------------------------------------------------------------------

%% Validate cnb:keysig-style. Unrecognized values warn and fall back to
%% 'chord so a typo degrades to today's display instead of erroring.
#(define (cnb:keysig-resolved-style)
   (if (memq cnb:keysig-style '(chord marks none))
       cnb:keysig-style
       (begin
         (ly:warning
           "cnb:keysig-style ~a not recognized (expected chord, marks or none); using chord"
           cnb:keysig-style)
         'chord)))

%% The key cnb:keysig-marks files an entry under (cnb/config.ly): the
%% tonic's note name and alteration, and the key's pitch classes from
%% KEY-ALTERATIONS (the context's keyAlterations), ascending.
#(define (cnb:keysig-marks-key tonic-pitch key-alterations)
   (cons (cons (ly:pitch-notename tonic-pitch)
               (ly:pitch-alteration tonic-pitch))
         (sort (cnb:get-key-pitch-classes key-alterations) <)))

%% The table's entry for KEY, or #f when the table has none.
#(define (cnb:keysig-marks-entry key)
   (assoc-ref cnb:keysig-marks key))

%% Vertical half-extent of the separator bar, in staff-spaces, from
%% cnb:keysig-bar-extent-semis. Divides through cnb:semitones-per-staff-space
%% exactly like note positions, so the default 12 semitones reproduces
%% (cnb:spaces-per-octave) — today's ±1-octave geometry — on any staff.
#(define (cnb:keysig-bar-half-extent)
   (/ cnb:keysig-bar-extent-semis cnb:semitones-per-staff-space))

%% Vertical offset (staff-spaces, scaled by mag) of a key-signature
%% notehead for absolute semitone SEMI — the notehead engraver's
%% placement formula (cnb/noteheads.ly) with the font magnification
%% standing in for the staff's staff-space, because keysig stencils are
%% built in mag-scaled coordinates.
%%
%% PITCH-AXIS HOOK (backlog 6.3 / E13-3): when
%% cnb:get-pitch-staff-position is a procedure, the mark's position is
%% (hook semi) in half-staff-spaces, used AS-IS (octave anchor baked
%% into the hook, NOT adjusted by middleCPosition — the cnb/config.ly
%% unit contract), so the notehead-chord signature lands on the same
%% compact axis as the notes. When #f, the literal linear formula runs
%% unchanged. Pitch SELECTION (which octave the displayed chords sit
%% in) stays with cnb:keysig-pitches either way — the hook only maps
%% the chosen pitches to vertical positions. Note the bar half-extent
%% above stays on the linear division even with the hook set:
%% cnb:keysig-bar-extent-semis is an INTERVAL (a length in semitones),
%% and the hook maps absolute pitches, not intervals.
#(define (cnb:keysig-note-y-offset semi middleCPosition mag)
   (if (procedure? cnb:get-pitch-staff-position)
       (* (cnb:get-pitch-staff-position semi) 0.5 mag)
       (* (+ semi (* 2 middleCPosition))
          (/ 1 cnb:semitones-per-staff-space) mag)))


%% The semitone the staff centres on, for cnb:keysig-tonic-octave
%% 'centred: with the pitch-axis hook, the lowest semitone it sends
%% nearest staff position 0 (searched over -120..120; a many-to-one map
%% sends several there, and the lowest is the Configurator's midpoint
%% for its pitch-class maps); on a linear staff, the middle line's
%% semitone, -2 × middleCPosition (12 under the treble clef — the
%% Configurator's default staff.midpoint).
#(define (cnb:keysig-centre-semitone middle-c-position)
   (if (procedure? cnb:get-pitch-staff-position)
       (let loop ((s -120) (best #f) (best-dist #f))
         (if (> s 120)
             best
             (let ((d (abs (cnb:get-pitch-staff-position s))))
               (if (or (not best-dist) (< d best-dist))
                   (loop (+ s 1) s d)
                   (loop (+ s 1) best best-dist)))))
       (* -2 middle-c-position)))

%% The ly:make-pitch octave for TONIC-PITCH under 'centred: the
%% Configurator's CNBKeySignature.tonicSemi rule — the tonic t = pc + 12k
%% whose span [t, t+12] is centred on CENTRE, k = round((CENTRE − 6 −
%% pc) / 12) with ties going up — converted to the octave of the tonic's
%% own spelling, so B♯ or C♭ lands on the Configurator's semitone too.
#(define (cnb:keysig-centred-octave tonic-pitch centre)
   (let* ((s0 (ly:pitch-semitones
                (ly:make-pitch 0 (ly:pitch-notename tonic-pitch)
                                 (ly:pitch-alteration tonic-pitch))))
          (o0 (floor (/ s0 12)))
          (pc (- s0 (* 12 o0)))
          (k  (floor (+ (/ (- centre 6 pc) 12) 1/2))))
     ;; t = pc + 12k = s0 + 12(k − o0): the octave is k − o0.
     (inexact->exact (- k o0))))


%% ---------------------------------------------------------------------------
%%  CALCULATE KEY SIGNATURE PITCHES
%%
%%  Given the alteration list (sharps/flats) and the tonic pitch,
%%  compute the 8 pitches (two 7th chords = 8 notes) to display.
%%
%%  PARAMETERS:
%%    alteration-alist   — LilyPond's key signature alterations
%%                          list of (scale-degree . alteration) pairs
%%    tonic-pitch        — the tonic as a LilyPond pitch object
%%    middle-c-position  — clef-dependent offset for positioning
%%    tonic-octave-override — #f to derive the octave from middle-c-position
%%                          (today's behavior), an integer to anchor the
%%                          tonic notehead at that LilyPond ly:make-pitch
%%                          octave (0 = the octave starting at middle C),
%%                          or 'centred for the Configurator's per-tonic
%%                          rule (cnb:keysig-centred-octave).
%%                          This is cnb:keysig-tonic-octave; an explicit
%%                          value closes the preview/engine placement
%%                          divergence for non-C tonics.
%%
%%  RETURNS:
%%    A list of 8 LilyPond pitch objects representing the key signature
%%    noteheads, starting from near middle C.
%% ---------------------------------------------------------------------------

#(define (cnb:keysig-pitches alteration-alist tonic-pitch middle-c-position
                             tonic-octave-override)
   (let* (
           (semi                (ly:pitch-semitones tonic-pitch))
           (tonic-steps         (floor (ly:pitch-steps tonic-pitch)))
           (tonic-octave        (ly:pitch-octave tonic-pitch))
           (tonic-alteration    (ly:pitch-alteration tonic-pitch))
           (tonic-tones-asc     (+ tonic-steps 7))
           (octaves-above-mid-c (floor (/ (* -1 middle-c-position) 6)))
           (current-octave      (cond
                                  ((integer? tonic-octave-override)
                                   tonic-octave-override)
                                  ((eq? tonic-octave-override 'centred)
                                   (cnb:keysig-centred-octave
                                     tonic-pitch
                                     (cnb:keysig-centre-semitone middle-c-position)))
                                  (else
                                   (+ tonic-octave octaves-above-mid-c)))))
      (map (lambda (t)
             (let* (
                     (tonic-idx-tmp    (+ t tonic-tones-asc))
                     (from-tonic-idx   (- tonic-idx-tmp
                                          (if (> tonic-idx-tmp 6) 7 0)))
                     (current-alt      (assq from-tonic-idx alteration-alist)))
                (set! current-octave
                      (+ current-octave
                         (if (and (> t 0) (eq? 0 from-tonic-idx)) 1 0)))
                (ly:make-pitch
                  current-octave
                  from-tonic-idx
                  (if current-alt (cdr current-alt) 0))))
        '(0 1 2 3 4 5 6 7))))


%% ---------------------------------------------------------------------------
%%  LEDGER LINES FOR KEY SIGNATURE NOTEHEADS
%%
%%  Determine which ledger line positions are needed for a notehead
%%  of engine semitone SEMI at a given Y offset in the key signature
%%  display.
%%
%%  A semitone with an entry in cnb:ledgers-by-semitone (cnb/config.ly)
%%  takes exactly that entry's ledgers, none for an empty one, as the
%%  score's notes do. Any other semitone, or a score with no table, uses
%%  the same proximity rule as the main staff ledger system: show ledger
%%  candidates that lie between the outermost staff line and the
%%  notehead position.
%%
%%  The Y offset is in rendered coordinates (scaled by mag), so we
%%  de-magnify to get staff positions, apply the proximity rule, then
%%  convert back to rendered coordinates.
%% ---------------------------------------------------------------------------

#(define (cnb:notehead-ledgers semi y-offset y-extent mag custom-ledger-cnt)
   (let* (
           (entry         (assv semi cnb:ledgers-by-semitone))
           (notehead-pos  (inexact->exact (round (/ (* 2 y-offset) mag))))
           (ledgers
             (cond
               (entry (cdr entry))
               ((eq? custom-ledger-cnt 0)
                (cnb:proximity-rule cnb:staff-line-positions notehead-pos
                                    (cnb:get-ledger-candidates cnb:staff-line-positions)))
               (else
                (or (hashv-ref cnb:ledgers-by-notehead-position notehead-pos) '())))))
      (map (lambda (y) (* y mag 1/2)) ledgers)))


%% ---------------------------------------------------------------------------
%%  ADD LEDGER LINES TO A KEY SIGNATURE NOTEHEAD
%%
%%  Draw ledger lines around a key signature notehead stencil.
%%  Uses the shared cnb:draw-single-ledger for advanced-mode lines,
%%  or draws simple black lines for simple mode.
%% ---------------------------------------------------------------------------

#(define (cnb:add-keysig-ledgers notehead-stencil ledger-offsets x-offset grob mag custom-ledger-cnt)
   (let* (
           (stencil   notehead-stencil)
           (x-extent  (ly:stencil-extent stencil 0))
           (width     (- (cdr x-extent) (car x-extent)))
           (ledger-length (* width 4/3))
           (start     (- (car x-extent) (* width 1/6))))

      (for-each (lambda (x)
        (let* (
                (current-stencil
                  (if (eq? custom-ledger-cnt 0)
                      (grob-interpret-markup grob
                        (markup
                          #:override `((thickness . ,(* 2 mag)))
                          #:translate `(,start . ,x)
                          #:draw-line `(,ledger-length . 0)))
                      (let* (
                              (entry (hashv-ref cnb:ledgers-by-offset (/ x mag))))
                        (cnb:draw-single-ledger
                          grob start x ledger-length mag
                          (or entry '()))))))
          (set! stencil (ly:stencil-add current-stencil stencil))))
        ledger-offsets)

      stencil))


%% ---------------------------------------------------------------------------
%%  BUILD THE FULL KEY SIGNATURE STENCIL
%%
%%  Combines all key signature noteheads (with ledger lines) and
%%  the gold vertical bar into one final stencil.
%%
%%  LAYOUT:
%%    - Notes are arranged in two columns (even/odd index)
%%    - Each column has notes stacked vertically by semitone position
%%    - Ledger lines are drawn first (lower layer)
%%    - Then noteheads are drawn again on top (higher layer) so they
%%      appear above the ledger lines
%%    - A gold vertical bar is drawn at the right edge spanning ±1 octave
%% ---------------------------------------------------------------------------

#(define (cnb:keysig-markup-list keysig-pitches middleCPosition mag grob)
   (let* (
           (base-x-offset         (* mag 1))
           (cumulative-stencil    #f)
           (bar-stencil           #f)
           (bar-y-max             (cnb:keysig-bar-half-extent))
           (bar-y-min             (* -1 (cnb:keysig-bar-half-extent)))
           (custom-ledger-cnt     (cnb:custom-ledger-count))
           (x-offset              #f)
           (max-notehead-width    0)
           (max-notehead-x-offset 0))

      ;; PASS 1: Draw noteheads with ledger lines (ledgers are the base layer)
      (for-each (lambda (i)
        (let* (
                (semi           (ly:pitch-semitones (list-ref keysig-pitches i)))
                (nh-stencil    (cnb:get-keysig-note-stencil (modulo semi 12) grob))
                (x-extent      (ly:stencil-extent nh-stencil 0))
                (y-extent      (ly:stencil-extent nh-stencil 1))
                (width         (- (cdr x-extent) (car x-extent)))
                (x-offset      (+ base-x-offset (if (even? i) 0 width)))
                (y-offset      (cnb:keysig-note-y-offset semi middleCPosition mag))
                (ledger-offsets (cnb:notehead-ledgers semi y-offset y-extent mag custom-ledger-cnt))
                (stencil       (ly:stencil-translate nh-stencil `(,x-offset . ,y-offset)))
                (with-ledgers  (cnb:add-keysig-ledgers
                                 stencil ledger-offsets x-offset grob mag custom-ledger-cnt)))

          (if (> x-offset max-notehead-x-offset) (set! max-notehead-x-offset x-offset))
          (if (> width max-notehead-width) (set! max-notehead-width width))

          (set! cumulative-stencil
                (if (not cumulative-stencil)
                    with-ledgers
                    (ly:stencil-add cumulative-stencil with-ledgers)))))
        (iota (length keysig-pitches) 0))

      ;; PASS 2: Re-draw noteheads on top so they appear above ledger lines
      (for-each (lambda (i)
        (let* (
                (semi        (ly:pitch-semitones (list-ref keysig-pitches i)))
                (nh-stencil (cnb:get-keysig-note-stencil (modulo semi 12) grob))
                (x-extent   (ly:stencil-extent nh-stencil 0))
                (width      (- (cdr x-extent) (car x-extent)))
                (x-offset   (+ base-x-offset (if (even? i) 0 width)))
                (y-offset   (cnb:keysig-note-y-offset semi middleCPosition mag))
                (stencil    (ly:stencil-translate nh-stencil `(,x-offset . ,y-offset))))

          (set! cumulative-stencil
                (if (not cumulative-stencil)
                    stencil
                    (ly:stencil-add cumulative-stencil stencil)))))
        (iota (length keysig-pitches) 0))

      ;; DRAW GOLD BAR at the right edge
      (set! x-offset (- max-notehead-x-offset (/ max-notehead-width 2)))
      (set! bar-stencil
            (ly:stencil-translate
              (ly:stencil-scale
                (grob-interpret-markup grob
                  (markup
                    #:with-color cnb:keysig-bar-color
                    #:override `((thickness . ,cnb:keysig-bar-thickness))
                    #:translate `(0 . ,bar-y-min)
                    #:draw-line `(0 . ,(* 2 bar-y-max))))
                mag mag)
              (cons x-offset 0)))

      (set! cumulative-stencil (ly:stencil-add bar-stencil cumulative-stencil))

      cumulative-stencil))


%% ---------------------------------------------------------------------------
%%  THE MARK-LIST KEY SIGNATURE ('marks, session 30)
%%
%%  Draws one entry of cnb:keysig-marks (format: cnb/config.ly) where the
%%  entry puts everything; the engine computes no layout. x is staff
%%  spaces from the signature's start, a semitone's height is
%%  cnb:keysig-note-y-offset's (so the pitch-axis hook applies as for
%%  'chord), and both scale with the font magnification MAG.
%%
%%  Layers, bottom up (cnb:keysig-marks-layers): the bars; every head's
%%  ledger lines; then each mark once, in the table's order, so marks
%%  layered at one semitone and column draw as written and no ledger
%%  covers a mark. The sharps and flats, Emmentaler's, take no ledgers.
%%
%%  A symbol mark (session 37) is drawn as a head is, solid or hollow by
%%  its cutout, but takes no ledgers: it serves a head's added symbols (a
%%  dot's tail) and any symbol drawn without ledger lines.
%%
%%  A mark's optional last element (at dx . dy), in staff spaces (session
%%  37), places it by its origin: the stencil's origin goes to the
%%  column's x plus dx and the semitone's height plus dy, and its box is
%%  not centred. Without it the mark's X extent is centred on its column
%%  and its origin is at the semitone's height, as before. A head's
%%  ledgers stay at the staff positions its semitone takes and span the
%%  placed head's X extent, so they follow it along the staff: dx and dy
%%  are the Configurator's offset less the symbol's reference point, not
%%  a change of pitch.
%%
%%  A sign's optional scale (session 35) scales its glyph about its
%%  origin, so the sharp's centre or the flat's bowl stays at the
%%  semitone, before it is centred on its column. A scale that is not a
%%  positive number warns naming KEY, and the sign draws unscaled.
%%
%%  A sign's optional colour (session 37), after its scale, is a
%%  registered colour name or a hex string, resolved as a head's is (an
%%  unregistered name warns and draws black). A sign without one draws
%%  black, as Emmentaler's glyph is.
%% ---------------------------------------------------------------------------

%% A colour name registered with cnb:register-color!, or a hex string.
#(define (cnb:keysig-marks-color color)
   (if (symbol? color)
       (or (hashq-ref cnb:color-defs color)
           (begin
             (ly:warning "cnb:keysig-marks: unregistered color name '~a' — using black"
                         color)
             "#000000"))
       color))

%% The (dx . dy) of MARK's optional last element (at dx . dy), or #f.
#(define (cnb:keysig-mark-at mark)
   (let ((end (last mark)))
     (and (pair? end) (eq? (car end) 'at) (cdr end))))

%% MARK without its (at dx . dy), so its other fields keep their indexes.
#(define (cnb:keysig-mark-fields mark)
   (if (cnb:keysig-mark-at mark) (drop-right mark 1) mark))

#(define (cnb:keysig-marks-layers entry middleCPosition mag grob key)
   (let* ((columns   (or (assq-ref entry 'columns) '()))
          (custom-ledger-cnt (cnb:custom-ledger-count))
          (y-of      (lambda (semi)
                       (cnb:keysig-note-y-offset semi middleCPosition mag)))
          ;; STENCIL with its origin at AT from COLUMN and SEMI, or, with
          ;; no AT, its X extent centred on COLUMN and its origin at SEMI.
          (place     (lambda (stencil column semi at)
                       (ly:stencil-translate
                         stencil
                         (if at
                             (cons (* mag (+ (list-ref columns column) (car at)))
                                   (+ (y-of semi) (* mag (cdr at))))
                             (let ((ext (ly:stencil-extent stencil X)))
                               (cons (- (* mag (list-ref columns column))
                                        (/ (+ (car ext) (cdr ext)) 2))
                                     (y-of semi)))))))
          (bars
            (map (lambda (bar)
                   (let ((x (* mag (list-ref bar 0))))
                     (cnb:colorize-stencil
                       (make-line-stencil (* mag (list-ref bar 4))
                                          x (y-of (list-ref bar 1))
                                          x (y-of (list-ref bar 2)))
                       (cnb:keysig-marks-color (list-ref bar 3)))))
                 (or (assq-ref entry 'bars) '())))
          ;; A head's or symbol's stencil, or #f (with a warning) when its
          ;; shape is not registered.
          (head-stencil
            (lambda (mark)
              (let* ((shape  (list-ref mark 3))
                     (hollow (list-ref mark 4))
                     (path   (hashq-ref cnb:path-defs shape)))
                (if (not path)
                    (begin
                      (ly:warning "cnb:keysig-marks: unregistered shape '~a' — mark skipped"
                                  shape)
                      #f)
                    (ly:stencil-scale
                      (cnb:build-stencil-from-config
                        `((shape  . ,path)
                          (hollow . ,(and hollow
                                          (hashq-ref cnb:hollow-defs hollow)))
                          (color  . ,(cnb:keysig-marks-color (list-ref mark 5)))))
                      mag mag)))))
          ;; A sharp's or flat's glyph at its scale, in its colour if it
          ;; has one (none: black, the glyph as Emmentaler draws it).
          (sign-stencil
            (lambda (mark)
              (let* ((glyph  (ly:font-get-glyph
                               (ly:grob-default-font grob)
                               (if (eq? (list-ref mark 2) 'sharp)
                                   "accidentals.sharp"
                                   "accidentals.flat")))
                     (scale  (if (> (length mark) 3) (list-ref mark 3) 1))
                     (color  (and (> (length mark) 4) (list-ref mark 4)))
                     (scaled (cond
                               ((and (number? scale) (positive? scale))
                                (if (= scale 1)
                                    glyph
                                    (ly:stencil-scale glyph scale scale)))
                               (else
                                (ly:warning "cnb:keysig-marks: the key of ~a has mark ~a whose scale ~a is not a positive number — drawn unscaled"
                                            key mark scale)
                                glyph))))
                (if color
                    (cnb:colorize-stencil scaled (cnb:keysig-marks-color color))
                    scaled))))
          ;; (fields . placed stencil) for each mark drawn, in table order.
          (drawn
            (filter-map
              (lambda (mark)
                (let* ((fields  (cnb:keysig-mark-fields mark))
                       (stencil (case (list-ref fields 2)
                                  ((head symbol) (head-stencil fields))
                                  ((sharp flat) (sign-stencil fields))
                                  (else #f))))
                  (and stencil
                       (cons fields
                             (place stencil (cadr fields) (car fields)
                                    (cnb:keysig-mark-at mark))))))
              (or (assq-ref entry 'marks) '())))
          ;; Each head's ledgers alone, drawn on a blank stencil with the
          ;; placed head's X extent (which sets their span) and no Y
          ;; extent: at its semitone's staff positions, across the head.
          (ledgers
            (filter-map
              (lambda (d)
                (and (eq? (list-ref (car d) 2) 'head)
                     (let* ((semi    (car (car d)))
                            (x-ext   (ly:stencil-extent (cdr d) X))
                            (y-ext   (ly:stencil-extent (cdr d) Y)))
                       (cnb:add-keysig-ledgers
                         (ly:make-stencil "" x-ext empty-interval)
                         (cnb:notehead-ledgers semi (y-of semi) y-ext
                                               mag custom-ledger-cnt)
                         0 grob mag custom-ledger-cnt))))
              drawn)))
     (append bars ledgers (map cdr drawn))))

%% The 'marks key signature for ENTRY: its layers, added together.
#(define (cnb:keysig-marks-stencil entry middleCPosition mag grob key)
   (apply ly:stencil-add
          (cnb:keysig-marks-layers entry middleCPosition mag grob key)))


%% ---------------------------------------------------------------------------
%%  KEY SIGNATURE CACHE AND ENGRAVER
%%
%%  The cache uses assoc-ref (equal? comparison) instead of assq-ref
%%  (eq? comparison) because the key is a list that needs structural
%%  comparison.
%%
%%  CACHE KEY: covers EVERY input the stencil depends on — the key itself
%%  (the grob's alteration-alist and the context's tonic, the two inputs
%%  cnb:keysig-pitches reads), the two positioning inputs the engraver
%%  reads per grob (middleCPosition and font magnification), the staff
%%  geometry
%%  (cnb:semitones-per-staff-space AND the pitch-axis hook
%%  cnb:get-pitch-staff-position, which replaces the linear placement
%%  formula when set — set 008; procedures compare by identity under
%%  equal?, so re-setting the hook to a new procedure invalidates), and
%%  all of the key-signature display settings (tonic-octave anchor, and
%%  the three separator-bar settings), and the notation's ledgers by
%%  pitch, cnb:ledgers-by-semitone (session 33). Before set 006 the key was ONLY
%%  keySignature, which would leak a stale stencil the moment any of
%%  those changed (e.g. a different setting, or the same key on a second
%%  staff with a different clef). Until session 24 the key's part was
%%  the context property keySignature, which LilyPond 2.24 and 2.26 never
%%  set (the key is in keyAlterations), so every key signature after the
%%  first in a file drew the first one's marks. 'none never reaches
%%  here — the engraver suppresses that case before caching.
%% ---------------------------------------------------------------------------

#(define cnb:key-signature-stencil-cache '())

#(define (cnb:get-key-signature-stencil grob context)
   (let* (
           (alteration-alist (ly:grob-property grob 'alteration-alist))
           (tonic-pitch     (ly:context-property context 'tonic))
           (mag             (magstep (ly:grob-property grob 'font-size 0.0)))
           (middleCPosition (ly:context-property context 'middleCPosition))
           (cache-key       (list alteration-alist
                                  tonic-pitch
                                  middleCPosition
                                  mag
                                  cnb:semitones-per-staff-space
                                  cnb:get-pitch-staff-position
                                  cnb:keysig-tonic-octave
                                  cnb:keysig-bar-color
                                  cnb:keysig-bar-thickness
                                  cnb:keysig-bar-extent-semis
                                  cnb:ledgers-by-semitone))
           (cached          (assoc-ref cnb:key-signature-stencil-cache cache-key)))

      (if cached
          cached
          (let* (
                  (keysig-pitches   (cnb:keysig-pitches alteration-alist
                                                         tonic-pitch
                                                         middleCPosition
                                                         cnb:keysig-tonic-octave))
                  (stencil          (cnb:keysig-markup-list
                                     keysig-pitches middleCPosition mag grob)))

            (set! cnb:key-signature-stencil-cache
                  (assoc-set! cnb:key-signature-stencil-cache cache-key stencil))
            stencil))))

%% 'marks: the stencil of the table's entry for the context's key, or #f
%% when the table has none (warned once per key, with no fallback to the
%% scale stack). Cached on every input cnb:keysig-marks-stencil reads,
%% cnb:ledgers-by-semitone among them.
#(define cnb:keysig-marks-stencil-cache '())
#(define cnb:keysig-marks-warned '())

#(define (cnb:get-keysig-marks-stencil grob context)
   (let* ((tonic (ly:context-property context 'tonic))
          (key   (cnb:keysig-marks-key
                   tonic (ly:context-property context 'keyAlterations '())))
          (entry (cnb:keysig-marks-entry key)))
     (if (not entry)
         (begin
           (if (not (member key cnb:keysig-marks-warned))
               (begin
                 (set! cnb:keysig-marks-warned (cons key cnb:keysig-marks-warned))
                 (ly:warning "cnb:keysig-marks has no entry for the key of ~a, ~a (tonic, pitch classes); no key signature drawn"
                             tonic key)))
           #f)
         (let* ((mag             (magstep (ly:grob-property grob 'font-size 0.0)))
                (middleCPosition (ly:context-property context 'middleCPosition))
                (cache-key       (list entry middleCPosition mag
                                       cnb:semitones-per-staff-space
                                       cnb:get-pitch-staff-position
                                       cnb:false-hollow
                                       cnb:ledgers-by-semitone))
                (cached          (assoc-ref cnb:keysig-marks-stencil-cache cache-key)))
           (or cached
               (let ((stencil (cnb:keysig-marks-stencil
                                entry middleCPosition mag grob key)))
                 (set! cnb:keysig-marks-stencil-cache
                       (assoc-set! cnb:keysig-marks-stencil-cache cache-key stencil))
                 stencil))))))

%% The engraver replaces every KeySignature grob's stencil with the
%% notehead-chord display, or — when cnb:keysig-style is 'none — suppresses
%% it entirely (stencil #f, mirroring the clef engraver's 'none), so a
%% config with keys.keySignature.enabled: false renders no key signature.
%% Under 'marks it draws the cnb:keysig-marks entry for the key instead,
%% and a KeyCancellation (the naturals a key change cancels) draws nothing.
%%
%% The display's noteheads come from the procedure config cache, which
%% otherwise only the notehead engraver fills, on its first note. A key
%% signature engraved before any note (a top staff opening on a rest or a
%% spacer, a staff with no notes) found it empty: every notehead was
%% empty-stencil, its -inf width became an "Improbable offset for stencil"
%% translate, and the display was drawn as its bar alone. So the cache is
%% brought up to the current key here first.
#(define cnb-key-signature-engraver
   (lambda (context)
     (make-engraver
       (acknowledgers
         ((key-signature-interface engraver grob source-engraver)
           (let ((style (cnb:keysig-resolved-style)))
             (cond
               ((eq? style 'none)
                (ly:grob-set-property! grob 'stencil #f))
               ;; 'marks: a key change draws the new key's marks and no
               ;; cancelling naturals.
               ((eq? style 'marks)
                (ly:grob-set-property!
                  grob 'stencil
                  (and (not (grob::has-interface grob 'key-cancellation-interface))
                       (cnb:get-keysig-marks-stencil grob context))))
               (else
                (cnb:handle-key-change context)
                (ly:grob-set-property!
                  grob 'stencil
                  (cnb:get-key-signature-stencil grob context))))))))))
