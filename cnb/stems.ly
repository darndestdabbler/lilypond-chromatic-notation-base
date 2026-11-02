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
%%    The attachment data is the resolved config's attachment alist for
%%    the note, which the notehead engraver captures on the grob at
%%    acknowledge time (cnb-attachment, cnb/noteheads.ly).
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
%%  The attachment alist is the one the notehead engraver captured on the
%%  grob (property cnb-attachment, cnb/noteheads.ly) from the note's
%%  resolved config at acknowledge time. It is NOT looked up in the config
%%  cache here: this runs at layout time, when the cache holds the last
%%  key of the score, so a later key change would rewrite earlier stems
%%  (audit 2026-11-02, M1).
%% ---------------------------------------------------------------------------

#(define (cnb:stem-attachment grob)
   (let* (
           (stem      (ly:grob-object grob 'stem))
           (stem-dir  (ly:grob-property stem 'direction UP))
           (logdur    (note-head::calc-duration-log grob))

           ;; The captured attachment record; absent (no config, or an
           ;; unregistered attachment) falls back to a centered side
           ;; attachment.
           (record
             (let ((captured (ly:grob-property grob 'cnb-attachment #f)))
               (if (pair? captured)
                   captured
                   '((crotchet-up . (1 . 0)) (crotchet-down . (-1 . 0))
                     (minim-up . (1 . 0)) (minim-down . (-1 . 0)))))))

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
