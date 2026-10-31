%% ============================================================================
%%
%%  CNB MODULE: beams.ly
%%  Beam thickness and spacing compensation for compressed staves
%%
%%  WHAT THIS FILE DOES:
%%    Adjusts beam thickness and inter-beam spacing to look correct
%%    on chromatic staves that have a compressed staff-space.
%%
%%  DEPENDENCIES: config.ly
%%
%%  WHY THIS IS NEEDED:
%%    LilyPond calculates beam thickness and spacing in staff-space
%%    units. When we compress the staff (staff-space < 1.0), beams
%%    become proportionally thinner and closer together, which looks
%%    wrong. We need to scale them back up by the inverse of staff-space.
%%
%%    Both Clairnote (cn-beam-grob-callback) and Chromatic Lyre
%%    (ln-beams) implement this same compensation. Without it,
%%    beamed eighth/sixteenth notes look visually broken.
%%
%%  HOW IT WORKS:
%%    1. Read the StaffSymbol's staff-space to find the compression ratio
%%    2. Multiply beam-thickness by (1 / staff-space)
%%    3. Multiply length-fraction (inter-beam spacing) by (1 / staff-space)
%%    4. The 1.1 fudge factor on length-fraction is a visual adjustment
%%       (same value used by Clairnote, arrived at by visual estimation)
%%
%%  USAGE:
%%    Applied via \override Beam.before-line-breaking in layout.ly.
%%    The callback runs once per beam group, before final positioning.
%%
%% ============================================================================


#(define (cnb:compensate-beam grob)
   (let* (
           (staff-sym    (ly:grob-object grob 'staff-symbol))
           (ss           (if (ly:grob? staff-sym)
                             (ly:grob-property staff-sym 'staff-space 1.0)
                             1.0))
           (ss-inverse   (/ 1 ss))
           (thick        (ly:grob-property grob 'beam-thickness))
           (len-frac     (ly:grob-property grob 'length-fraction))
           (space        (if (number? len-frac) len-frac 1)))

      ;; Only compensate when staff-space < 1.0 (compressed staff).
      ;; When staff-space >= 1.0 (e.g. from magnifyStaff), beams are
      ;; already correctly sized and compensation would shrink them.
      (if (< ss 1.0)
          (begin
            (ly:grob-set-property! grob 'beam-thickness
                                    (* thick ss-inverse))
            (ly:grob-set-property! grob 'length-fraction
                                    (* space 1.1 ss-inverse))))))
