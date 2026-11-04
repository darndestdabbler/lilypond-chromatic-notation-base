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

%% Pitch-axis hook: an arbitrary (possibly many-to-one, non-uniform)
%% semitone -> staff-position map for compact staves (the Twinline
%% family), replacing the linear cnb:semitones-per-staff-space formula
%% for NOTEHEAD vertical placement when set.
%%
%%   #f         — default: the literal linear formula runs unchanged
%%                (today's behavior; zero drift with the hook unset).
%%   procedure  — (proc semitone) is called with the note's ABSOLUTE
%%                semitone (an integer; middle C = 0, LilyPond's
%%                ly:pitch-semitones value) and must return the LilyPond
%%                staff position in HALF-STAFF-SPACES from the staff
%%                center — the same unit as cnb:staff-line-positions.
%%
%% UNIT CONTRACT (shared with the Configurator — do not deviate):
%%   The procedure bakes its OWN octave anchor in (the config's
%%   staff.midpoint lands at position 0), which makes placement
%%   clef-independent: the returned position is used AS-IS and is NOT
%%   further adjusted by middleCPosition. (Precedent for an explicit
%%   anchor overriding middleCPosition: cnb:keysig-tonic-octave below.)
%%   Contrast the #f path, whose anchor is middleCPosition-driven.
%%
%% The hook may be many-to-one (different pitches sharing one vertical
%% position, disambiguated by shape and horizontal offset) and
%% non-uniform (unequal semitone spacing between adjacent positions).
%% Ledger lines, dots, articulations, and stem extents/directions all
%% read the placed geometry back, so the map propagates to them
%% automatically.
%%
%% CONSULTED AT (every semitone→vertical placement site, set 008):
%%   cnb/noteheads.ly — notehead Y-offset (the primary site);
%%   cnb/keysig.ly    — key-signature mark placement
%%                      (cnb:keysig-note-y-offset; joins the keysig
%%                      stencil-cache key);
%%   cnb/clefs.ly     — 'custom clef glyph anchoring
%%                      (cnb:clef-anchor-y-offset; fractional anchors
%%                      interpolate between integer semitones — the
%%                      hook itself is only ever called with integers).
%% Semitone-unit LENGTH settings (cnb:clef-size-semitones,
%% cnb:clef-gutter-semitones, cnb:keysig-bar-extent-semis) are
%% intervals, not pitches — they stay on the linear
%% cnb:semitones-per-staff-space division regardless of the hook.
#(define cnb:get-pitch-staff-position #f)


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
%%  CLEF DISPLAY SETTINGS
%%  Control what the clef engraver renders in the clef slot.
%% ---------------------------------------------------------------------------

%% What to render in the clef slot. A symbol:
%%   'dozenal — the computed two-digit dozenal register numeral
%%              (default — today's behavior).
%%   'text    — render cnb:clef-text instead of the computed numeral
%%              (a configured register label, e.g. an octave numeral
%%              or letter — "glyph-free clef").
%%   'none    — suppress the clef entirely (no stencil is engraved).
%%   'custom  — render the registered clef glyph named by cnb:clef-name
%%              (register glyphs with cnb:register-clef!, cnb/clefs.ly).
%%
%% Any other value warns and falls back to 'dozenal. 'custom with no
%% valid registration under cnb:clef-name also falls back to 'dozenal.
#(define cnb:clef-style 'dozenal)

%% The label rendered when cnb:clef-style is 'text.
%% A string (rendered bold, matching the dozenal numeral's weight) or
%% a markup (used as-is, for full control over styling).
%% Ignored unless cnb:clef-style is 'text.
#(define cnb:clef-text "")

%% Height of the clef display, in SEMITONES (the Configurator's
%% canonical unit), so the clef reads consistently across staff designs
%% with different cnb:semitones-per-staff-space values.
%%
%%   #f       — legacy default: 3 staff-spaces tall, whatever number of
%%              semitones that spans on the current staff (this is
%%              (* 3 cnb:semitones-per-staff-space) semitones, so the
%%              default cannot be a fixed semitone count without
%%              changing behavior on non-default staves).
%%   number N — the display renders N semitones tall regardless of
%%              cnb:semitones-per-staff-space.
%%
%% Applies to the 'dozenal, 'text, and 'custom styles. For 'custom it
%% is an explicit override: it wins over the registered definition's
%% own height-semitones field (see cnb:register-clef!, cnb/clefs.ly).
#(define cnb:clef-size-semitones #f)

%% Which registered custom clef to display when cnb:clef-style is
%% 'custom. A symbol naming a definition previously registered with
%% cnb:register-clef! (cnb/clefs.ly), or #f (default — none selected).
%% Ignored unless cnb:clef-style is 'custom.
#(define cnb:clef-name #f)

%% Extra blank horizontal space after the clef (gutter padding), in
%% SEMITONES — i.e. the same physical distance the clef occupies
%% vertically per semitone, so the gutter scales with the staff design
%% exactly like the size setting does.
%%
%%   #f       — legacy default: no extra space (today's spacing).
%%   number N — widen the clef stencil's right extent by
%%              N / cnb:semitones-per-staff-space staff-spaces.
%%
%% Applies to every rendered style ('dozenal, 'text, 'custom).
#(define cnb:clef-gutter-semitones #f)


%% ---------------------------------------------------------------------------
%%  KEY SIGNATURE DISPLAY SETTINGS
%%  Control the notehead-chord key signature (cnb/keysig.ly): whether it
%%  renders at all, the separator bar's appearance, and where its octave
%%  is anchored. Every setting defaults to today's behavior — with no
%%  overrides the golden baseline renders with zero drift.
%% ---------------------------------------------------------------------------

%% What to render for the key signature. A symbol:
%%   'chord — the notehead-chord display (default — today's behavior:
%%            two interleaved columns of real noteheads plus the
%%            separator bar).
%%   'none  — suppress the key signature entirely (no stencil is
%%            engraved), so a Configurator config with
%%            keys.keySignature.enabled: false becomes emittable.
%%
%% Kept a SYMBOL (not a boolean) so the valueset can grow as new styles
%% are implemented. Any other value warns and falls back to 'chord.
%%
%% NOTE: there is deliberately no 'standard (LilyPond-native sharps/flats)
%% value — the Configurator's set-010 ships the notehead chord as its sole
%% key-signature style (D11) and defers richer custom signatures (D12), so
%% no consumer exists for a native escape hatch. Add one here only when a
%% consumer does.
#(define cnb:keysig-style 'chord)

%% Color of the vertical separator bar drawn through the middle of the two
%% notehead columns. A color value (as produced by colors.ly). Default is
%% cnb:gold (#ffd42a), today's hard-coded bar color.
%% Maps to the Configurator's keySignature.separator.color.
#(define cnb:keysig-bar-color cnb:gold)

%% Thickness of the separator bar, in LilyPond #:draw-line thickness units
%% (multiples of the output's line-thickness; the bar is then scaled by the
%% font magnification like the rest of the display). Default 4 is today's
%% hard-coded value (≈ 0.4 staff-space before magnification).
%% Maps to the Configurator's keySignature.separator.thicknessPct — see the
%% Session-2 handoff record for the exact unit conversion.
#(define cnb:keysig-bar-thickness 4)

%% Vertical half-extent of the separator bar, in SEMITONES: the bar spans
%% from -N to +N semitones around the staff center. Default 12 (= ±1
%% octave) reproduces today's ±(cnb:spaces-per-octave) geometry on ANY
%% staff, because the extent is divided through cnb:semitones-per-staff-space
%% exactly like note positions are.
%% Maps to the Configurator's keySignature.separator.extentSemis.
#(define cnb:keysig-bar-extent-semis 12)

%% Anchor for the key signature's tonic octave.
%%   #f       — derive the octave from middleCPosition (default — today's
%%              behavior in cnb:keysig-pitches: middle-C anchoring).
%%   integer  — anchor the tonic notehead at this LilyPond octave (the
%%              ly:make-pitch octave value, where 0 is the octave starting
%%              at middle C), regardless of middleCPosition. Lets the
%%              Configurator emit keySignature.placement.tonicOctave and
%%              close the documented preview/engine placement divergence
%%              for non-C tonics (see cnb/keysig.ly).
#(define cnb:keysig-tonic-octave #f)


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
%%   Output SVG paths in this nested-list format, already at final size.
%%   In the procedure model the stencil builder applies NO rotation or
%%   scaling — paths are used exactly as defined (rotation is baked into
%%   named shapes, scaling into the coordinates). So define paths in their
%%   final rendered geometry.
%%
%% SIZE: This default oval spans +/- 0.5 in Y (height 1.0 staff-space =
%%   2 semitones at the default cnb:semitones-per-staff-space 2), which is
%%   the "notehead height = 2 semitones" documented in cnb:notation-footnote
%%   and the README. (The retired vector model stored a +/-0.6667 oval and
%%   scaled it 0.75 at build time via cnb:notehead-scaling-sequence; with
%%   the vector model removed in set 007 the scaling is baked in here.)
#(define cnb:notehead-shape-path '(
    (moveto -0.5 -0.1702)
    (curveto -0.5 -0.3953 -0.3384 -0.5 -0.1682 -0.5)
    (curveto -0.0415 -0.5 0.0808 -0.4528 0.1856 -0.3743)
    (curveto 0.3297 -0.2696 0.5 -0.0864 0.5 0.1702)
    (curveto 0.5 0.3953 0.3384 0.5 0.1682 0.5)
    (curveto 0.0415 0.5 -0.0808 0.4528 -0.1856 0.3743)
    (curveto -0.3297 0.2696 -0.5 0.0864 -0.5 -0.1702)
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
    (moveto 0.3952 0.2749)
    (curveto 0.4345 0.1911 0.417 0.0864 0.3428 0.0341)
    (lineto -0.1987 -0.3377)
    (curveto -0.2686 -0.3848 -0.3559 -0.3587 -0.3952 -0.2749)
    (curveto -0.4345 -0.1911 -0.4127 -0.0864 -0.3428 -0.0341)
    (lineto 0.1987 0.3377)
    (curveto 0.2773 0.3901 0.3559 0.3587 0.3952 0.2749)
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
%%  PROCEDURE MODEL FLAG — KEEP FOREVER, DO NOT DELETE
%%
%%  The procedure-oriented configuration model is the ONLY model:
%%    - Stencils are built from the config cache (populated by the
%%      cnb:get-notehead-config procedure)
%%    - Stem attachment is read from the config cache
%%    - Off-key marks are read from the config cache
%%    - The config cache is rebuilt on key changes
%%
%%  WHY THIS VARIABLE STILL EXISTS (set 007 removed the vector-cycling
%%  model it once toggled): every Configurator export unconditionally emits
%%    #(set! cnb:use-procedure-model #t)
%%  as its first engine directive (LY export spec 1.2.1 §5.1). A set! to an
%%  already-defined variable is a harmless no-op, but a set! to an UNDEFINED
%%  variable is an error — so deleting this define would break every existing
%%  export in the wild. It is therefore a permanent, documented no-op: the
%%  engine no longer branches on it. Removing it requires a coordinated
%%  Configurator spec + exporter change (drop the emitted line), which is out
%%  of scope for this repo. Leave it defined.
#(define cnb:use-procedure-model #t)


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
%%  The configuration procedure (cnb:get-notehead-config) may reference
%%  palette entries by integer index; the resolver in procedure.ly reads
%%  from this vector. Named color references (cnb:register-color!) are the
%%  recommended approach — see procedure.ly.
%%
%%  EXAMPLE OVERRIDE IN SCORE FILE:
%%    #(set! cnb:color-palette (vector cnb:blue cnb:rose cnb:black))
%% ---------------------------------------------------------------------------

#(define cnb:color-palette (vector cnb:black))


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
%%
%%  On a chromatic staff, accidentals are never needed to specify pitch
%%  (every pitch has its own position). Flagging out-of-key notes still
%%  helps musicians anticipate which notes belong to the current key.
%%
%%  In the procedure model this is expressed PER NOTE, not by a global
%%  flag: the configuration procedure (cnb:get-notehead-config) returns an
%%  `off-key-mark` field for each (semitone, duration, key) — #f for none,
%%  or a built-in symbol ('dot, 'ring, 'tick), or a registered custom mark
%%  (cnb:register-off-key-mark!), or a procedure. The off-key engraver in
%%  cnb/off-key.ly reads that field and draws the mark; it holds no
%%  detection logic of its own. See cnb/off-key.ly and cnb/procedure.ly.
%%
%%  LilyPond's native accidentals (♯ ♭ ♮) are always suppressed on the
%%  chromatic staff (cnb/layout.ly) — pitch is fully specified by position.
%% ---------------------------------------------------------------------------


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
