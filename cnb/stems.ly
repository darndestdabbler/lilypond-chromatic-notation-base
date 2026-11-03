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
