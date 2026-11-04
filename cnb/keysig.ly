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
   (if (memq cnb:keysig-style '(chord none))
       cnb:keysig-style
       (begin
         (ly:warning
           "cnb:keysig-style ~a not recognized (expected chord or none); using chord"
           cnb:keysig-style)
         'chord)))

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
%%                          (today's behavior), or an integer to anchor the
%%                          tonic notehead at that LilyPond ly:make-pitch
%%                          octave (0 = the octave starting at middle C).
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
           (current-octave      (if (integer? tonic-octave-override)
                                    tonic-octave-override
                                    (+ tonic-octave octaves-above-mid-c))))
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
%%  at a given Y offset in the key signature display.
%%
%%  Uses the same proximity rule as the main staff ledger system:
%%  show ledger candidates that lie between the outermost staff line
%%  and the notehead position.
%%
%%  The Y offset is in rendered coordinates (scaled by mag), so we
%%  de-magnify to get staff positions, apply the proximity rule, then
%%  convert back to rendered coordinates.
%% ---------------------------------------------------------------------------

#(define (cnb:notehead-ledgers y-offset y-extent mag custom-ledger-cnt)
   (let* (
           (notehead-pos  (inexact->exact (round (/ (* 2 y-offset) mag))))
           (candidates    (cnb:get-ledger-candidates cnb:staff-line-positions))
           (ledgers
             (if (eq? custom-ledger-cnt 0)
                 (cnb:proximity-rule cnb:staff-line-positions notehead-pos candidates)
                 (or (hashv-ref cnb:ledgers-by-notehead-position notehead-pos) '()))))
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
                (ledger-offsets (cnb:notehead-ledgers y-offset y-extent mag custom-ledger-cnt))
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
%%  KEY SIGNATURE CACHE AND ENGRAVER
%%
%%  The cache uses assoc-ref (equal? comparison) instead of assq-ref
%%  (eq? comparison) because the key is a list that needs structural
%%  comparison.
%%
%%  CACHE KEY: covers EVERY input the stencil depends on — the score's
%%  keySignature, the two positioning inputs the engraver reads per grob
%%  (middleCPosition and font magnification), the staff geometry
%%  (cnb:semitones-per-staff-space AND the pitch-axis hook
%%  cnb:get-pitch-staff-position, which replaces the linear placement
%%  formula when set — set 008; procedures compare by identity under
%%  equal?, so re-setting the hook to a new procedure invalidates), and
%%  all of the key-signature display settings (tonic-octave anchor, and
%%  the three separator-bar settings). Before set 006 the key was ONLY
%%  keySignature, which would leak a stale stencil the moment any of
%%  those changed (e.g. a different setting, or the same key on a second
%%  staff with a different clef). 'none never reaches here — the
%%  engraver suppresses that case before caching.
%% ---------------------------------------------------------------------------

#(define cnb:key-signature-stencil-cache '())

#(define (cnb:get-key-signature-stencil grob context)
   (let* (
           (keySignature    (ly:context-property context 'keySignature))
           (mag             (magstep (ly:grob-property grob 'font-size 0.0)))
           (middleCPosition (ly:context-property context 'middleCPosition))
           (cache-key       (list keySignature
                                  middleCPosition
                                  mag
                                  cnb:semitones-per-staff-space
                                  cnb:get-pitch-staff-position
                                  cnb:keysig-tonic-octave
                                  cnb:keysig-bar-color
                                  cnb:keysig-bar-thickness
                                  cnb:keysig-bar-extent-semis))
           (cached          (assoc-ref cnb:key-signature-stencil-cache cache-key)))

      (if cached
          cached
          (let* (
                  (alteration-alist (ly:grob-property grob 'alteration-alist))
                  (tonic-pitch      (ly:context-property context 'tonic))
                  (keysig-pitches   (cnb:keysig-pitches alteration-alist
                                                         tonic-pitch
                                                         middleCPosition
                                                         cnb:keysig-tonic-octave))
                  (stencil          (cnb:keysig-markup-list
                                     keysig-pitches middleCPosition mag grob)))

            (set! cnb:key-signature-stencil-cache
                  (assoc-set! cnb:key-signature-stencil-cache cache-key stencil))
            stencil))))

%% The engraver replaces every KeySignature grob's stencil with the
%% notehead-chord display, or — when cnb:keysig-style is 'none — suppresses
%% it entirely (stencil #f, mirroring the clef engraver's 'none), so a
%% config with keys.keySignature.enabled: false renders no key signature.
#(define cnb-key-signature-engraver
   (lambda (context)
     (make-engraver
       (acknowledgers
         ((key-signature-interface engraver grob source-engraver)
           (if (eq? (cnb:keysig-resolved-style) 'none)
               (ly:grob-set-property! grob 'stencil #f)
               (let* ((stencil (cnb:get-key-signature-stencil grob context)))
                 (ly:grob-set-property! grob 'stencil stencil))))))))
