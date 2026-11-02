%% ============================================================================
%%
%%  CNB MODULE: dots.ly
%%  Augmentation dot position adjustment for chromatic staves
%%
%%  WHAT THIS FILE DOES:
%%    Prevents augmentation dots from sitting on ledger lines.
%%    LilyPond already avoids staff lines (it checks line-positions),
%%    but it does NOT avoid ledger lines. On chromatic staves where
%%    notes frequently sit on ledger lines, dots become visually
%%    obscured without this correction.
%%
%%  DEPENDENCIES: config.ly, ledgers.ly
%%
%%  THE PROBLEM:
%%    Traditional notation has few ledger lines, and dotted notes
%%    on ledger lines are rare enough that LilyPond doesn't bother
%%    avoiding them. But chromatic staves have dense ledger patterns.
%%    A dotted C5 might sit right on a ledger line, making the dot
%%    invisible against the line.
%%
%%    EXAMPLE (staff lines at -4, -2, 0, 2, 4):
%%
%%      Position 6: ← ledger line
%%      Note at 6:  ← dotted half note, dot lands right on the ledger
%%
%%    LilyPond's built-in avoidance catches staff lines (it would
%%    dodge at positions -4, -2, 0, 2, 4) but misses position 6
%%    because that's a ledger, not a staff line.
%%
%%  THE FIX:
%%    A before-line-breaking callback on Dots grobs that:
%%    1. Gets the parent notehead's staff position
%%    2. Computes the ledger lines for that note (via proximity rule)
%%    3. If the note's position matches a ledger line, shifts the
%%       dot 1 staff-position away from the notehead in the
%%       appropriate direction. The dot is positioned relative to its
%%       notehead (its Y-parent), so the shift is the dodge alone, not
%%       the notehead's position plus the dodge.
%%
%%  DIRECTION LOGIC:
%%    When dodging, the dot moves AWAY from the nearest staff line
%%    (outward from the staff). This follows standard engraving
%%    convention: dots above the staff dodge up, dots below dodge down.
%%    If the note is exactly centered (rare), dodge up.
%%
%%  INTERACTION WITH LILYPOND'S BUILT-IN AVOIDANCE:
%%    LilyPond's native dot avoidance runs separately and handles
%%    staff lines. Our callback handles ledger lines only. There's
%%    no conflict because a position can't be both a staff line and
%%    a ledger line simultaneously.
%%
%%  HOW IT'S APPLIED:
%%    In layout.ly:
%%      \override Dots.before-line-breaking = #cnb:dots-avoid-ledgers
%%
%% ============================================================================


#(define (cnb:dots-avoid-ledgers dots-grob)
   (let* (
           ;; The Dots grob's Y-parent is the NoteHead (or Rest).
           (parent      (ly:grob-parent dots-grob Y))
           (parent-name (assq-ref (ly:grob-property parent 'meta) 'name))

           ;; Only adjust for noteheads, not rests.
           (is-note     (not (eq? parent-name 'Rest))))

     (if is-note
         (let* (
                 ;; Get the notehead's staff position.
                 (nh-pos (ly:grob-staff-position parent))

                 ;; Get the StaffSymbol for line positions.
                 (staff-symbol (ly:grob-object dots-grob 'staff-symbol))

                 (staff-positions
                   (if (ly:grob? staff-symbol)
                       (ly:grob-property staff-symbol 'line-positions '())
                       '()))

                 ;; Compute ledger lines for this note using the proximity rule.
                 (candidates (if (null? staff-positions)
                                 '()
                                 (cnb:get-ledger-candidates staff-positions)))
                 (ledger-posns (if (null? staff-positions)
                                   '()
                                   (cnb:proximity-rule staff-positions nh-pos candidates)))

                 ;; Is the notehead sitting on a ledger line?
                 (on-ledger  (memv nh-pos ledger-posns)))

           (if on-ledger
               (let* (
                       ;; Find the nearest staff line to determine dodge direction.
                       (top-staff    (if (null? staff-positions) 0
                                         (apply max staff-positions)))
                       (bottom-staff (if (null? staff-positions) 0
                                         (apply min staff-positions)))

                       ;; Direction: dodge AWAY from the staff center.
                       ;; Notes above the staff → dodge up (+1)
                       ;; Notes below the staff → dodge down (-1)
                       ;; This matches standard engraving convention.
                       (staff-center (/ (+ top-staff bottom-staff) 2))
                       (dodge-dir    (if (>= nh-pos staff-center) 1 -1)))

                 ;; Shift the dot by 1 staff-position in the dodge
                 ;; direction. The dot's Y-parent is the notehead, which
                 ;; already carries its own Y-offset, so the dot's
                 ;; staff-position is RELATIVE to the notehead: set it to
                 ;; the dodge alone. Setting the notehead's absolute
                 ;; position plus the dodge counted the notehead's offset
                 ;; twice and threw the dot several staff spaces away
                 ;; (audit 2026-11-02, H3).
                 (ly:grob-set-property! dots-grob 'staff-position dodge-dir)))))))
