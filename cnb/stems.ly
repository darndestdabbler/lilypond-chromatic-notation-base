%% ============================================================================
%%
%%  CNB MODULE: stems.ly
%%  Stem attachment points and stem length compensation
%%
%%  WHAT THIS FILE DOES:
%%    1. Defines where stems connect to custom noteheads (attachment points)
%%    2. Adjusts stem lengths to compensate for compressed staff spacing
%%
%%  DEPENDENCIES: config.ly, procedure.ly
%%
%%  WHY STEM ATTACHMENT MATTERS:
%%    Standard LilyPond noteheads have built-in stem attachment points
%%    (left/right edges for up/down stems). Custom noteheads need
%%    custom attachment points, or stems will connect at wrong positions.
%%
%%    VECTOR MODEL: The attachment points cycle through pitch classes
%%    just like notehead shapes, because different shapes may need
%%    different connection points (e.g., a diamond vs. an oval).
%%
%%    PROCEDURE MODEL: The attachment data comes from the resolved
%%    config cache, which already contains the correct attachment
%%    alist for the given (pitch-class, duration) combination.
%%
%%  WHY STEM LENGTH COMPENSATION:
%%    When we compress the staff (staff-space < 1), LilyPond's automatic
%%    stem lengths become too short because they're calculated in staff
%%    spaces. We multiply stem length parameters by the inverse of
%%    staff-space to restore proper visual proportions.
%%
%%    Both Clairnote and Chromatic Lyre do this same compensation.
%%    Without it, stems look stubby on compressed chromatic staves.
%%
%% ============================================================================


%% ---------------------------------------------------------------------------
%%  STEM ATTACHMENT LOOKUP
%%
%%  Given a NoteHead grob, determine where the stem should connect.
%%  The attachment point depends on:
%%    1. The pitch class (for shape-dependent attachment)
%%    2. The stem direction (up or down)
%%    3. The duration (quarter note vs. half note)
%%
%%  Returns an (x . y) pair in notehead-relative coordinates.
%%
%%  DUAL MODEL:
%%    Vector model: indexes into cnb:stem-attachment-sequence by pitch class
%%    Procedure model: reads attachment alist from config cache
%% ---------------------------------------------------------------------------

#(define (cnb:stem-attachment-modulus)
   (vector-length cnb:stem-attachment-sequence))

#(define (cnb:stem-attachment grob)
   (let* (
           (stem      (ly:grob-object grob 'stem))
           (stem-dir  (ly:grob-property stem 'direction UP))
           (event     (ly:grob-property grob 'cause))
           (pitch     (ly:event-property event 'pitch))
           (semi      (ly:pitch-semitones pitch))
           (logdur    (note-head::calc-duration-log grob))
           (pitch-class (modulo semi 12))

           ;; Get the attachment record from the appropriate source
           (record
             (if cnb:use-procedure-model

                 ;; PROCEDURE MODEL: read from config cache
                 (let* ((dur-prop  (ly:event-property event 'duration))
                        (dur-cat   (cnb:duration-category dur-prop))
                        (config    (cnb:lookup-config pitch-class dur-cat)))
                   (if config
                       (assq-ref config 'attachment)
                       ;; Fallback to vector model if cache miss
                       (vector-ref cnb:stem-attachment-sequence
                                   (modulo semi (cnb:stem-attachment-modulus)))))

                 ;; VECTOR MODEL: index into sequence
                 (vector-ref cnb:stem-attachment-sequence
                             (modulo semi (cnb:stem-attachment-modulus))))))

       (cond
         ((eq? logdur 2)
          (if (eq? stem-dir UP)
              (assq-ref record 'crotchet-up)
              (assq-ref record 'crotchet-down)))
         (#t
          (if (eq? stem-dir UP)
              (assq-ref record 'minim-up)
              (assq-ref record 'minim-down))))))


%% ---------------------------------------------------------------------------
%%  STEM LENGTH COMPENSATION
%%
%%  Multiplies all stem-related "details" parameters by the inverse of
%%  the staff-space. This undoes the compression so stems look normal.
%%
%%  HOW IT WORKS:
%%    LilyPond stores stem configuration in the 'details property,
%%    which is an alist of named parameter lists:
%%      ((beamed-lengths 3.5 3.5 4.25)
%%       (beamed-minimum-free-lengths 2.0 2.0 2.0)
%%       (stem-shorten 0.5 0.5)     ← EXCLUDED from scaling
%%       ...)
%%
%%    We multiply every numeric value by (1 / staff-space), EXCEPT
%%    'stem-shorten which should stay as-is (it controls shortening
%%    for notes with flags, which isn't affected by staff compression).
%%
%%    This approach is used by both Clairnote (cn-multiply-details)
%%    and Chromatic Lyre (stem-lengthen).
%% ---------------------------------------------------------------------------

#(define (cnb:multiply-stem-details details multiplier)
   (map
     (lambda (entry)
       (let ((name (car entry))
             (values (cdr entry)))
         (cons name
               (if (eq? name 'stem-shorten)
                   values
                   (map (lambda (v) (* v multiplier)) values)))))
     details))

#(define (cnb:compensate-stem-length grob)
   (let* (
           (staff-sym  (ly:grob-object grob 'staff-symbol))
           (ss         (if (ly:grob? staff-sym)
                           (ly:grob-property staff-sym 'staff-space 1.0)
                           1.0))
           (multiplier (/ 1 ss))
           (details    (ly:grob-property grob 'details)))

      ;; Only compensate when staff-space < 1.0 (compressed staff).
      ;; When staff-space >= 1.0 (e.g. from magnifyStaff), stems are
      ;; already correctly sized and compensation would shrink them.
      (if (and (pair? details) (< ss 1.0))
          (ly:grob-set-property! grob 'details
                                 (cnb:multiply-stem-details details multiplier)))))
