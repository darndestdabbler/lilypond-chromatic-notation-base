%% ============================================================================
%%
%%  CNB MODULE: articulations.ly
%%  Articulation (Script grob) Y-offset correction for ledger line collisions
%%
%%  WHAT THIS FILE DOES:
%%    Adjusts the vertical position of articulation marks (staccato dots,
%%    accents, fermatas, etc.) so they don't collide with ledger lines
%%    that extend beyond the notehead.
%%
%%  DEPENDENCIES: config.ly, ledgers.ly
%%
%%  THE PROBLEM:
%%    In standard notation, ledger lines are always AT the notehead.
%%    So LilyPond places articulations just beyond the notehead and
%%    everything looks fine.
%%
%%    In chromatic notation with the proximity rule, a note can trigger
%%    ledger lines that are BETWEEN the staff and the note — some of
%%    these ledgers may be further from the note's center than the
%%    notehead's own edge. If an articulation is placed at its default
%%    position (just beyond the notehead), it can sit right on top of
%%    a ledger line.
%%
%%    EXAMPLE (staff lines at -4, -2, 0, 2, 4; note at position 9):
%%
%%      Position 10: ← ledger line is HERE, above the note
%%      Position  9: ← notehead is HERE
%%      Position  8: ← ledger line
%%      Position  6: ← ledger line
%%      Position  4: ← top staff line
%%
%%    Wait — with the proximity rule, ledger 10 would NOT appear
%%    (it's above the note). But ledger lines at 6 and 8 DO appear,
%%    and they're below the note. An articulation placed BELOW the
%%    note (stem-down staccato) at position 8 would collide with
%%    the ledger at 8.
%%
%%    Actually, the more common case: a note at position 9 with
%%    stem UP gets an articulation ABOVE. The articulation at default
%%    position sits just above position 9. No ledger collision above.
%%    But with stem DOWN, the articulation goes below — and could hit
%%    ledger at 8. We need to push it further down.
%%
%%    For notes far from the staff, there can be MANY ledger lines
%%    extending toward the staff, and articulations going in that
%%    direction need to clear all of them.
%%
%%  THE FIX:
%%    This is a grob-transformer callback for Script.Y-offset.
%%    It receives the default Y-offset that LilyPond calculated,
%%    then checks whether any ledger lines extend further than the
%%    notehead in the articulation's direction. If so, it adds
%%    extra offset to push the articulation past those ledgers.
%%
%%  HOW IT'S APPLIED:
%%    In layout.ly:
%%      \override Script.Y-offset =
%%        #(grob-transformer 'Y-offset cnb:script-y-offset-callback)
%%
%%    grob-transformer is a LilyPond utility that wraps a callback.
%%    It calls LilyPond's default calculation first, then passes
%%    the result to our callback as default-value. We return the
%%    adjusted value.
%%
%%  ADAPTED FROM:
%%    Clairnote's cn-script-y-offset-callback (clairnote.ly line 1712).
%%    Simplified to work with our proximity rule instead of Clairnote's
%%    recipe system, and to not require eval of a quoted lambda.
%%
%% ============================================================================


#(define (cnb:script-y-offset-callback grob default-value)
   (let* (
           ;; Which direction is the articulation going?
           ;; +1 = above the note, -1 = below the note
           (direction    (ly:grob-property grob 'direction))

           ;; Get the parent NoteHead grob.
           ;; Script grobs are children of NoteColumn, and the NoteHead
           ;; is accessed via the X-parent chain.
           (note-head    (ly:grob-parent grob X))

           ;; Get the notehead's staff position (in half-staff-spaces).
           ;; This is what the proximity rule uses.
           (nh-pos       (ly:grob-staff-position note-head))

           ;; Get the StaffSymbol grob for staff-space and line-positions.
           (staff-symbol (ly:grob-object grob 'staff-symbol))

           ;; Get the staff line positions (needed by proximity rule).
           (staff-positions
             (if (ly:grob? staff-symbol)
                 (ly:grob-property staff-symbol 'line-positions '())
                 '()))

           ;; Compute ledger positions for this note using the proximity rule.
           (candidates   (cnb:get-ledger-candidates staff-positions))
           (ledger-posns (if (null? staff-positions)
                             '()
                             (cnb:proximity-rule staff-positions nh-pos candidates)))

           ;; Find the furthest ledger in the articulation's direction.
           ;; If direction is +1 (above), we want the maximum ledger position.
           ;; If direction is -1 (below), we want the minimum.
           ;; If there are no ledgers, use the notehead position itself.
           (max-or-min   (if (> direction 0) max min))
           (extreme-ledger
             (if (null? ledger-posns)
                 nh-pos
                 (reduce max-or-min nh-pos ledger-posns)))

           ;; How much further does the extreme ledger extend beyond the note?
           ;; (diff > 0) means there's a ledger beyond the note in the
           ;; articulation's direction, so we need to push the articulation out.
           (diff         (- (abs extreme-ledger) (abs nh-pos)))

           ;; Only adjust if the ledger actually extends beyond the note.
           ;; Subtract 1 because the articulation already has some padding
           ;; from the notehead — we only need to cover the EXTRA distance.
           (adjust       (if (> diff 0)
                             (* direction (- diff 1))
                             0))

           ;; Convert from staff positions to actual coordinates.
           ;; Staff positions are in half-staff-spaces, so multiply by
           ;; half the staff-space to get the pixel offset.
           (staff-space  (if (ly:grob? staff-symbol)
                             (ly:grob-property staff-symbol 'staff-space 1.0)
                             1.0))
           (note-space   (* 0.5 staff-space))
           (final-adjust (* adjust note-space)))

     (+ default-value final-adjust)))
