%% ============================================================================
%%
%%  CNB MODULE: stems.ly
%%  Stem attachment points
%%
%%  WHAT THIS FILE DOES:
%%    Defines where stems connect to custom noteheads (attachment points).
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
%%    A repeated minim (cnb-repeat captured on the grob) attaches across
%%    its group of heads, or, with cnb:multinote-stem-on-head set, on one
%%    head of it (cnb:stem-on-head below).
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

%% ---------------------------------------------------------------------------
%%  A REPEATED MINIM'S STEM ON ONE OF ITS HEADS
%%
%%  LilyPond reads an attachment point across the whole stencil, which
%%  for a repeated minim is the group of two heads. With
%%  cnb:multinote-stem-on-head set, the point is instead placed on one
%%  head of the group, as a single head's stem is: the last head when the
%%  stem is up, the first when it is down (a centred stem too).
%%
%%  POINT is (x . y) in normalised head coordinates (±1 = the head's
%%  edges), HEAD-WIDTH one head's X width. The second copy starts s after
%%  the first, as cnb:build-duration-stencil (cnb/stencils.ly) places it:
%%  (1 - overlap) head widths, or head-width + cnb:multinote-padding when
%%  the overlap is #f. With k = 1 for the last head and 0 for the first,
%%  the point's x on that head, rewritten relative to the group's X
%%  extent (width s + head-width), is
%%
%%    x' = (2ks + head-width (1 + x)) / (s + head-width) - 1
%%
%%  and y is unchanged.
%% ---------------------------------------------------------------------------

#(define (cnb:stem-on-head point dir head-width)
   (let ((s (if (number? cnb:multinote-overlap)
                (* (- 1 cnb:multinote-overlap) head-width)
                (+ head-width cnb:multinote-padding)))
         (k (if (eqv? dir UP) 1 0)))
     (cons (- (/ (+ (* 2 k s) (* head-width (+ 1 (car point))))
                 (+ s head-width))
              1)
           (cdr point))))

%% One head's X width, recovered from the unscaled X width of a repeated
%% minim's stencil, which is two heads, s + head-width wide:
%% (2 - overlap) head widths, or 2 head widths + cnb:multinote-padding.
#(define (cnb:repeated-minim-head-width group-width)
   (if (number? cnb:multinote-overlap)
       (/ group-width (- 2 cnb:multinote-overlap))
       (/ (- group-width cnb:multinote-padding) 2)))

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
          (let ((point (if (eq? stem-dir UP)
                           (assq-ref record 'minim-up)
                           (assq-ref record 'minim-down))))
            ;; A repeated minim with cnb:multinote-stem-on-head set: on
            ;; one of its heads. Otherwise across the stencil, as before.
            (if (and cnb:multinote-stem-on-head
                     (eq? logdur 1)
                     (ly:grob-property grob 'cnb-repeat #f))
                (let* ((width  (interval-length
                                 (ly:stencil-extent
                                   (ly:grob-property grob 'stencil) X)))
                       ;; The grob's stencil is scaled by the magstep of
                       ;; its font-size; the padding is not, so unscale.
                       (mapped (cnb:stem-on-head
                                 point stem-dir
                                 (cnb:repeated-minim-head-width
                                   (/ width
                                      (magstep (ly:grob-property
                                                 grob 'font-size 0.0)))))))
                  ;; LilyPond moves a stem whose attachment x is not 0 by
                  ;; half its thickness, toward the head (Stem's offset
                  ;; callback), and leaves an x of 0 centred. A centred
                  ;; point is no longer 0 on the group, so undo that move:
                  ;; the stem then stands centred on its head, as the
                  ;; crotchet's does on its one head.
                  (if (and (zero? (car point)) (not (zero? (car mapped))))
                      (cons (+ (car mapped)
                               (/ (* stem-dir
                                     (ly:grob-property stem 'thickness 1.3)
                                     (ly:staff-symbol-line-thickness stem))
                                  width))
                            (cdr mapped))
                      mapped))
                point))))))
