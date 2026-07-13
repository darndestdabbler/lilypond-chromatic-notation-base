%% ============================================================================
%%
%%  CNB MODULE: layout.ly
%%  Engraver registration, layout overrides, and paper settings
%%
%%  WHAT THIS FILE DOES:
%%    This is the "wiring" module that connects all the other modules
%%    to LilyPond's typesetting engine. It:
%%      1. Registers our custom engravers in the Staff context
%%      2. Sets grob property overrides (accidentals, stems, noteheads)
%%      3. Configures paper margins and system spacing
%%
%%  DEPENDENCIES: All other CNB modules (this is loaded last)
%%
%%  HOW ENGRAVER REGISTRATION WORKS:
%%    LilyPond processes music through a chain of "engravers" that
%%    create and modify graphical objects ("grobs"). We add our custom
%%    engravers to the Staff context with \consists:
%%
%%      \consists \cnb-clef-engraver
%%        → Replaces clef symbols with dozenal numbers
%%
%%      \consists \cnb-notehead-engraver
%%        → Replaces noteheads with chromatic pitch-colored shapes
%%
%%      \consists \cnb-key-signature-engraver
%%        → Replaces key signatures with notehead chord displays
%%
%%      \consists \cnb-staff-symbol-engraver
%%        → Sets staff line and ledger line positions
%%
%%  HOW GROB OVERRIDES WORK:
%%    \override Grob.property = value
%%    Changes a default property for all instances of that grob type.
%%    These run at Staff creation time, not at parse time.
%%
%% ============================================================================


\layout {
  \context {
    \Staff

    %% --- REGISTER CUSTOM ENGRAVERS ---

    \consists \cnb-clef-engraver
    \consists \cnb-notehead-engraver
    \consists \cnb-key-signature-engraver
    \consists \cnb-staff-symbol-engraver


    %% --- ACCIDENTAL HANDLING ---
    %% LilyPond's built-in accidentals (♯ ♭ ♮) are always suppressed on the
    %% chromatic staff: every pitch has its own staff position, so accidental
    %% symbols are never needed to specify pitch. Out-of-key notes are marked
    %% instead by the off-key engraver, driven per note by the config's
    %% off-key-mark field.
    \override Accidental.stencil = ##f


    %% --- OFF-KEY NOTE FLAGS ---
    %% The off-key engraver reads each note's off-key-mark from the config
    %% cache and attaches a visual flag when it is not #f.
    \consists \cnb-off-key-engraver


    %% --- NOTEHEAD PROPERTIES ---

    %% Use our custom stem attachment function instead of the default.
    %% This ensures stems connect to the right point on custom noteheads.
    \override NoteHead.stem-attachment =
      #(lambda (grob) (cnb:stem-attachment grob))

    %% Draw noteheads ABOVE staff lines and ledger lines.
    %% layer 999 = very high (drawn last = drawn on top).
    \override NoteHead.layer = #999

    %% Draw ledger lines just below noteheads.
    \override LedgerLineSpanner.layer = #998


    %% --- STEM PROPERTIES ---

    %% Prevent stems from extending beyond the staff for short notes.
    %% (In chromatic notation, the "natural" stem extension rules from
    %% standard notation don't apply because the staff geometry is different.)
    \override Stem.no-stem-extend = ##t

    %% Apply per-note pitch-axis x-offsets AFTER LilyPond's chord
    %% arrangement (which would otherwise absorb them — see the
    %% X-OFFSET SUPPORT block in cnb/noteheads.ly). No-op when no
    %% note carries an x-offset.
    \override Stem.positioning-done =
      #(grob-transformer 'positioning-done cnb:apply-note-x-offsets)

    %% Compensate stem lengths for compressed staff spacing.
    %% Without this, stems look too short on compressed staves.
    \override Stem.before-line-breaking = #cnb:compensate-stem-length


    %% --- COLLISION THRESHOLDS ---
    %% How close notes can be before LilyPond shifts them horizontally.
    %% Higher values = more tolerance for close notes.
    \override Stem.note-collision-threshold = #cnb:collision-threshold
    \override NoteCollision.note-collision-threshold = #cnb:collision-threshold


    %% --- BEAM COMPENSATION ---
    %% Adjust beam thickness and spacing for compressed staff.
    \override Beam.before-line-breaking = #cnb:compensate-beam


    %% --- ARTICULATION CORRECTION ---
    %% Adjust articulation marks (staccato, accent, fermata, etc.)
    %% to avoid collision with ledger lines that extend beyond the note.
    %% grob-transformer wraps around LilyPond's default Y-offset
    %% calculation and lets us add extra offset when needed.
    \override Script.Y-offset =
      #(grob-transformer 'Y-offset cnb:script-y-offset-callback)


    %% --- DOT POSITION CORRECTION ---
    %% Prevent augmentation dots from landing on ledger lines.
    %% LilyPond's built-in avoidance handles staff lines, but not
    %% ledger lines. This callback catches the ledger case.
    \override Dots.before-line-breaking = #cnb:dots-avoid-ledgers
  }
}


%% ---------------------------------------------------------------------------
%%  PAPER SETTINGS
%%  Controls page layout, margins, and vertical spacing between systems.
%% ---------------------------------------------------------------------------

\paper {
  indent = #cnb:indent
  left-margin = #5
  right-margin = #5

  %% Vertical spacing between systems (groups of staves).
  %% basic-distance: ideal distance between system reference points
  %% minimum-distance: hard minimum (systems won't be closer than this)
  %% padding: extra space added around systems
  %% stretchability: how much LilyPond can stretch to fill the page
  system-system-spacing =
    #'((basic-distance . 12)
       (minimum-distance . 8)
       (padding . 4)
       (stretchability . 60))
}
