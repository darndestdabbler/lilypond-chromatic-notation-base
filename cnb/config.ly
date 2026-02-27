%% ============================================================================
%%
%%  CNB MODULE: config.ly
%%  Default configuration values for ChromaticNotationBase
%%
%%  WHAT THIS FILE DOES:
%%    Defines ALL configurable variables with sensible defaults.
%%    Notation-specific config files (like KiteNotation.ly) override
%%    these values using #(set! variable new-value).
%%
%%  DEPENDENCIES: colors.ly (for color name references)
%%
%%  HOW CONFIGURATION WORKS:
%%    1. This file sets defaults with #(define ...)
%%    2. Your notation config file does \include "ChromaticNotationBase.ly"
%%    3. Then it overrides specific values with #(set! cnb:variable value)
%%    4. Stencils are built LAZILY on first use (during engraving),
%%       so config overrides applied after the \include still take effect.
%%
%% ============================================================================


%% ---------------------------------------------------------------------------
%%  METADATA
%%  These identify the notation system in output filenames and labels.
%% ---------------------------------------------------------------------------

%% Appended to output filenames to identify the notation variant.
#(define cnb:file-suffix "-Oval-2-024-Notation")

%% Human-readable name shown in headers/footers.
#(define cnb:notation-label "Oval 2-024 Notation")

%% Footnote text explaining the notation's parameters.
#(define cnb:notation-footnote
  "*2-024 Notation: notehead height = 2 semitones; staff lines at 0 & +/- 2, 4 semitones")


%% ---------------------------------------------------------------------------
%%  STAFF GEOMETRY
%%  These control how the chromatic staff maps semitones to vertical space.
%% ---------------------------------------------------------------------------

%% How many semitones between adjacent staff positions.
%% This is the CORE parameter that defines the staff's vertical density.
%%
%% COMMON VALUES:
%%   1 = every semitone gets its own staff position (very spread out)
%%   2 = two semitones per staff space (default — good balance)
%%   3 = three semitones per staff space (more compact, used by Kite)
%%
%% This value affects:
%%   - Notehead vertical positioning in the notehead engraver
%%   - Key signature layout
%%   - How many ledger lines are needed for extreme notes
#(define cnb:semitones-per-staff-space 2)

%% Staff line positions, in half-staff-spaces from the center.
%% LilyPond's convention: 0 = center, positive = up, negative = down.
%% Each integer step is one half-staff-space.
%%
%% DEFAULT: Five lines at positions -4, -2, 0, 2, 4
%%   This creates a standard 5-line staff where adjacent lines
%%   are 2 half-staff-spaces (= 1 staff-space) apart.
#(define cnb:staff-line-positions '(-4 -2 0 2 4))

%% Ledger line CANDIDATE positions, in half-staff-spaces from center.
%% These are positions where ledger lines CAN appear. A ledger line
%% is only drawn when the proximity rule determines it should be visible
%% (i.e., the note is far enough from the staff).
%%
%% TWO OPTIONS:
%%   Non-empty list: Use these exact positions as candidates.
%%   Empty list '(): Auto-generate candidates by extending the staff
%%     line spacing pattern above and below the staff. The spacing is
%%     detected from cnb:staff-line-positions automatically.
%%
%% The auto-generation extends up to cnb:ledger-extend-range positions
%% (configurable in cnb/ledgers.ly, default 30).
%%
%% MOST CONFIGS SHOULD USE '() and let auto-generation handle it.
%% Only specify explicit positions if your ledger pattern differs
%% from the staff line pattern.
#(define cnb:ledger-positions '())


%% ---------------------------------------------------------------------------
%%  DISPLAY SETTINGS
%% ---------------------------------------------------------------------------

%% Global magnification factor applied to the entire score.
%% Values > 1 make everything larger; < 1 makes it smaller.
%% 7/4 (= 1.75) is a good default for chromatic notation since the
%% noteheads are custom-drawn and benefit from being slightly larger.
#(define cnb:default-magnify 7/4)

%% Left indent for the first system (in staff-spaces).
%% 0 means no indent — the first system starts at the left margin.
%% NOTE: This value affects ledger line positioning calculations,
%%       so if you change it, ledger lines will adjust automatically.
#(define cnb:indent 0)


%% ---------------------------------------------------------------------------
%%  NOTEHEAD PATH DATA
%%  These define the geometric shapes used to draw noteheads.
%%  Paths are lists of SVG-like drawing commands.
%% ---------------------------------------------------------------------------

%% The main notehead outline shape.
%% This is a standard oval, approximated with cubic Bézier curves.
%%
%% PATH FORMAT:
%%   Each sub-list is a drawing command:
%%     (moveto x y)        — move pen to absolute position
%%     (lineto x y)        — draw straight line to position
%%     (curveto x1 y1 x2 y2 x y) — cubic Bézier curve
%%     (closepath)          — close the shape back to moveto point
%%
%% COORDINATE SYSTEM:
%%   (0, 0) is the geometric center of the notehead.
%%   X range is roughly -0.67 to +0.67
%%   Y range is roughly -0.67 to +0.67
%%
%% NOTE FOR YOUR JS CONFIG GENERATOR:
%%   Output SVG paths in this nested-list format.
%%   The stencil builder will:
%%     1. Apply rotation and scaling to these coordinates
%%     2. Flatten them for make-path-stencil
%%   So paths should be defined in their UNROTATED, UNSCALED form.
#(define cnb:notehead-shape-path '(
    (moveto -0.6667 -0.2269)
    (curveto -0.6667 -0.5271 -0.4512 -0.6667 -0.2242 -0.6667)
    (curveto -0.0553 -0.6667 0.1077 -0.6038 0.2475 -0.4991)
    (curveto 0.4396 -0.3595 0.6667 -0.1152 0.6667 0.2269)
    (curveto 0.6667 0.5271 0.4512 0.6667 0.2242 0.6667)
    (curveto 0.0553 0.6667 -0.1077 0.6038 -0.2475 0.4991)
    (curveto -0.4396 0.3595 -0.6667 0.1152 -0.6667 -0.2269)
    (closepath)))

%% The hollow cutout shape for half notes.
%% This is drawn INSIDE the main shape to create the "hole."
%%
%% HOW HOLLOWING WORKS:
%%
%%   When cnb:false-hollow is #f (true-hollow mode):
%%     The stencil builder REVERSES this path's winding direction and
%%     appends it to the shape path. Under the non-zero winding fill
%%     rule (used by make-path-stencil), the inner region's winding
%%     numbers cancel to zero → transparent hole. You don't need to
%%     worry about winding direction in your path definitions — the
%%     reversal is automatic.
%%
%%   When cnb:false-hollow is #t (false-hollow mode):
%%     The shape is drawn filled in color, then this hollow cutout
%%     is drawn on top in white. Two independent stencils stacked.
%%     This gives a "fake" hollow look that works better with angular
%%     shapes (like diamonds, kites) where true-hollow can leave
%%     thin gaps at sharp corners.
%%
%% WINDING DIRECTION NOTE:
%%   Define your hollow path in whatever winding direction feels natural.
%%   The engine handles reversal automatically when needed.
#(define cnb:notehead-hollow-path '(
    (moveto 0.5269 0.3665)
    (curveto 0.5793 0.2548 0.556 0.1152 0.4571 0.0454)
    (lineto -0.2649 -0.4503)
    (curveto -0.3581 -0.5131 -0.4745 -0.4782 -0.5269 -0.3665)
    (curveto -0.5793 -0.2548 -0.5502 -0.1152 -0.4571 -0.0454)
    (lineto 0.2649 0.4503)
    (curveto 0.3697 0.5201 0.4745 0.4782 0.5269 0.3665)
    (closepath)))


%% ---------------------------------------------------------------------------
%%  HOLLOW MODE
%% ---------------------------------------------------------------------------

%% Controls how the "hollow" effect is rendered for half notes.
%%
%% When #f (TRUE-HOLLOW — the default):
%%   The hollow cutout path is winding-reversed and combined with the
%%   outer shape into a single path. make-path-stencil renders the
%%   combined path with non-zero winding fill, producing a true
%%   transparent hole. The staff line underneath is visible.
%%
%% When #t (FALSE-HOLLOW):
%%   The outer shape is drawn filled in the notehead color, then the
%%   hollow cutout is drawn filled in WHITE on top. This "paints over"
%%   the center, hiding anything underneath (including staff lines).
%%
%% WHEN TO USE EACH:
%%   #f (true-hollow) — Best for smooth curves (ovals, circles).
%%     The transparent hole lets staff lines show through naturally.
%%   #t (false-hollow) — Best for angular shapes (diamonds, kites, triangles).
%%     Angular corners can produce rendering artifacts with true-hollow.
%%     The white overlay gives clean, crisp edges.
#(define cnb:false-hollow #f)


%% ---------------------------------------------------------------------------
%%  PROCEDURE MODEL FLAG
%%
%%  When #t, the engine uses the procedure-oriented configuration model:
%%    - Stencils are built from the config cache (populated by
%%      cnb:get-notehead-config procedure)
%%    - Stem attachment is read from the config cache
%%    - Off-key marks are read from the config cache
%%    - The config cache is rebuilt on key changes
%%
%%  When #f (default), the engine uses the vector-cycling model:
%%    - Stencils are built from the cycling sequence vectors
%%    - Stem attachment cycles through cnb:stem-attachment-sequence
%%    - Off-key detection uses cnb:off-key-indicator
%%
%%  Notation configs that use the procedure model should set this to #t.
%%  The vector sequences are ignored when this is #t.
#(define cnb:use-procedure-model #f)


%% ---------------------------------------------------------------------------
%%  ACCESSIBLE COLORS FLAG
%%
%%  When #t, notation configs that support accessible color switching
%%  will register their colorblind-safe alternative palette instead of
%%  the primary palette. The switching is done by a conditional block
%%  in the generated config file (Section A5 of the export spec).
%%
%%  This flag must be set BEFORE \include-ing the notation config file,
%%  since the conditional executes at include time.
%%
%%  USAGE IN A MUSIC FILE:
%%    #(define cnb:use-accessible-colors #t)
%%    \include "MyNotation.ly"
%%    { c'4 d' e' f' ... }
%%
%%  The generated config uses (defined? 'cnb:use-accessible-colors) as
%%  a guard, so configs work correctly whether or not this flag exists.
%%  Defining it here as #f provides a clean default.
%%
%%  NOTE: This flag has no effect on configs that don't include the
%%  conditional color registration block (backward compatible).
%% ---------------------------------------------------------------------------

#(define cnb:use-accessible-colors #f)


%% ---------------------------------------------------------------------------
%%  COLOR PALETTE (SCORE-LEVEL OVERRIDE)
%%
%%  The notation config sets default colors. Score files can override
%%  this for accessibility (e.g., color-blind-safe palettes) or to
%%  produce monochrome output per Music Notation Project criteria:
%%  notation should be readable without color.
%%
%%  Used by procedure-model configs. Vector-model configs use
%%  cnb:notehead-color-sequence directly (which serves the same role).
%%
%%  EXAMPLE OVERRIDE IN SCORE FILE:
%%    #(set! cnb:color-palette (vector cnb:blue cnb:rose cnb:black))
%% ---------------------------------------------------------------------------

#(define cnb:color-palette (vector cnb:black))


%% ---------------------------------------------------------------------------
%%  NOTEHEAD SEQUENCES
%%  These vectors define how notehead properties cycle through pitch classes.
%%  Index 0 = C natural, index 1 = C#/Db, ..., index 11 = B.
%%  If the vector is shorter than 12, it wraps using modulo arithmetic.
%% ---------------------------------------------------------------------------

%% COLOR SEQUENCE: What color is each pitch class?
%% Default: all black (monochrome). Override in config for color coding.
%%
%% EXAMPLE for 3-color system (wraps every 3 pitches):
%%   (vector cnb:purple cnb:red cnb:green)
%%   => C=purple, C#=red, D=green, D#=purple, E=red, F=green, ...
#(define cnb:notehead-color-sequence (vector cnb:black))

%% SHAPE SEQUENCE: Which outline path does each pitch class use?
%% Default: same oval shape for all pitches.
%% You could alternate between different shapes (oval, diamond, triangle).
#(define cnb:notehead-shape-sequence (vector cnb:notehead-shape-path))

%% HOLLOW SEQUENCE: Which pitches get a hollow cutout?
%% #f means solid (no cutout).
%% A path value means draw the hollow cutout for that pitch class.
%% Default: alternates solid/hollow every pitch.
%%
%% EXAMPLE (default):
%%   C=solid, C#=hollow, D=solid, D#=hollow, ...
#(define cnb:notehead-hollow-sequence (vector
    #f
    cnb:notehead-hollow-path))

%% ROTATION SEQUENCE: Rotation angle (degrees) for each pitch class.
%% 0 = upright. 180 = upside-down.
%% The rotation is applied to the path coordinates BEFORE building
%% the stencil, so the result is a cleanly rotated shape.
%%
%% EXAMPLE for Kite notation (wraps every 4 pitches):
%%   (vector 180 0 0 180)
%%   => C=inverted, C#=upright, D=upright, D#=inverted, ...
#(define cnb:notehead-rotation-sequence (vector 0))

%% SCALING SEQUENCE: (x-scale . y-scale) pairs for each pitch class.
%% (1 . 1) = no scaling. (0.75 . 0.75) = 75% size.
%% The scaling is applied to path coordinates, not the stencil,
%% so it happens before stencil construction.
#(define cnb:notehead-scaling-sequence (vector '(0.75 . 0.75)))

%% OFFSET SEQUENCE: (x-offset . y-offset) pairs for optical adjustment.
%% (0 . 0) = no offset. Use small values to nudge noteheads for
%% better visual alignment when shapes aren't perfectly centered.
%% The offset is applied via ly:stencil-translate AFTER construction.
#(define cnb:notehead-offset-sequence (vector '(0 . 0)))


%% ---------------------------------------------------------------------------
%%  STEM ATTACHMENT SEQUENCE
%%  Defines where stems connect to noteheads, per pitch class.
%%
%%  Each entry is an alist with four keys:
%%    crotchet-up    — stem-up attachment for quarter notes and shorter
%%    crotchet-down  — stem-down attachment for quarter notes and shorter
%%    minim-up       — stem-up attachment for half notes and longer
%%    minim-down     — stem-down attachment for half notes and longer
%%
%%  Values are (x . y) pairs in notehead-relative coordinates:
%%    x: -1 = left edge, 0 = center, 1 = right edge
%%    y: -1 = bottom, 0 = center, 1 = top
%% ---------------------------------------------------------------------------

#(define cnb:stem-attachment-sequence (vector
     `(
        (crotchet-up . (1 . 0))
        (crotchet-down . (-1 . 0))
        (minim-up . (1 . 0))
        (minim-down . (-1 . 0)))))


%% ---------------------------------------------------------------------------
%%  MULTI-NOTE AND COLLISION SETTINGS
%% ---------------------------------------------------------------------------

%% Padding between repeated noteheads for half/whole/breve notes.
%% Negative values cause overlap. Default -0.5 gives slight overlap.
#(define cnb:multinote-padding -.5)

%% Threshold for LilyPond's collision detection between note columns.
%% Higher values allow closer notes before LilyPond shifts them apart.
#(define cnb:collision-threshold 2)


%% ---------------------------------------------------------------------------
%%  OFF-KEY NOTE FLAGS
%%  Visual indicators for notes that fall outside the current key signature.
%%
%%  On a chromatic staff, accidentals are never needed to specify pitch
%%  (every pitch has its own position). But flagging out-of-key notes
%%  helps musicians anticipate which notes belong to the current key —
%%  a cognitive advantage that diatonic staves provide automatically.
%%
%%  MODES:
%%    'none      — No flags, no accidentals. Pure chromatic reading.
%%                 This is the default.
%%    'standard  — Show LilyPond's built-in accidental symbols (♯ ♭ ♮).
%%                 Traditional symbols with enharmonic distinction.
%%    'dot       — Small filled dot above the notehead.
%%    'ring      — Thin circle around the notehead.
%%    'tick      — Small tick mark above the notehead.
%%    'custom    — User-provided stencil via cnb:off-key-flag-stencil.
%%
%%  NOTE: 'standard mode does NOT modify the key signature — your
%%  notehead-based key signatures remain unchanged. It only controls
%%  whether individual notes get accidental marks.
%% ---------------------------------------------------------------------------

#(define cnb:off-key-indicator 'none)

%% Custom flag stencil callback for 'custom mode.
%% Receives a NoteHead grob, returns a stencil to overlay on the notehead.
%% Ignored unless cnb:off-key-indicator is 'custom.
#(define cnb:off-key-flag-stencil #f)


%% ---------------------------------------------------------------------------
%%  STAFF LINE DEFINITIONS (ADVANCED)
%%  An alternative to cnb:staff-line-positions that allows per-line
%%  customization of color, thickness, and dash patterns.
%%
%%  When this list is NON-EMPTY, it overrides cnb:staff-line-positions
%%  and cnb:ledger-positions entirely. The staff-symbol engraver will
%%  use the custom drawing routines instead of LilyPond's built-in ones.
%%
%%  FORMAT: A list of association lists (alists), each with:
%%    (type . staff-line) or (type . ledger-line)
%%    (offset . N)           — position in half-staff-spaces from center
%%    (color . "#hex")       — optional, defaults to black
%%    (thickness . N)        — optional, defaults to 2
%%    (dash . ((on . N) (off . N))) — optional, for dashed lines
%%
%%  For ledger lines, also:
%%    (for-notehead-positions . (list ...)) — which note positions trigger this ledger
%%    (length-factor . N)    — multiplier for ledger line length
%%
%%  DEFAULT: Empty list (use simple staff-line-positions instead)
%%
%%  NOTE: Your JS config generator can populate this programmatically
%%  for notation systems that need colored or dashed staff/ledger lines.
%% ---------------------------------------------------------------------------

#(define cnb:staff-and-ledger-lines '())

%% Default thickness for staff lines when using the simple mode.
#(define cnb:default-staff-line-thickness 2)

%% Default color for staff lines when using the simple mode.
#(define cnb:default-staff-line-color "#000000")
