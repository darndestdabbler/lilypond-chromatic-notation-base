%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%
%% Kite 4-369 Notation (CLEAN)
%% Compatible with Refactored ChromaticNotationBase (2026)
%%
%% WHAT THIS FILE DOES:
%%   Configures the ChromaticNotationBase engine to produce Kite notation:
%%     - Diamond-shaped noteheads (pointing up or down)
%%     - 3 colors cycling: purple, red, green
%%     - Alternating solid/hollow
%%     - 4 rotation states: inverted, upright, upright, inverted
%%     - 3 semitones per staff space (compact layout)
%%     - Staff lines at +/- 3, 6 & 9 semitones from center
%%     - False-hollow mode (white overlay for sharp diamond corners)
%%
%% HOW TO USE:
%%   In your music file:
%%     \include "Kite-4-369-Notation-Clean.ly"
%%     { c'4 d' e' f' ... }
%%
%% GEOMETRIC STANDARD:
%%   All paths are centered at (0,0), which is the geometric center
%%   of the notehead. Vertical offsets for optical balancing are
%%   handled via cnb:notehead-offset-sequence, NOT baked into the paths.
%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

\version "2.24.2"
\include "ChromaticNotationBase.ly"


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%           CONFIGURATIONS
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% --- Metadata ---
#(set! cnb:file-suffix "-Kite-4-369-Clean")
#(set! cnb:notation-label "Kite 4-369 (Clean)")
#(set! cnb:notation-footnote
  "*4-369 Notation: notehead height = 4 semitones; staff lines at +/- 3, 6 & 9 semitones")

%% --- Staff Geometry ---
%% 3 semitones per staff space gives a compact chromatic layout.
%% Staff lines are placed at 3, 6, and 9 semitones above and below center
%% (in half-staff-space units: -6, -4, -2, 2, 4, 6).
%% Ledger positions are auto-generated from staff line spacing (every 2 units).
#(set! cnb:semitones-per-staff-space 3)
#(set! cnb:staff-line-positions '(-6 -4 -2  2 4 6))

%% --- Multi-note and hollow settings ---
#(set! cnb:multinote-padding -.5)
#(set! cnb:false-hollow #t)

%% --- Offset: paths are perfectly centered, so (0,0) ---
#(define cnb:notehead-offset-sequence (vector '(0 . 0)))


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%         STEM ATTACHMENT
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Diamond noteheads have stems attaching at top/bottom center
%% instead of left/right edges like ovals.
#(set! cnb:stem-attachment-sequence (vector
     `(
        (crotchet-up . (0 . .9))
        (crotchet-down . (0 . -.9))
        (minim-up . (-.365 . .9))
        (minim-down . (.365 . -.9)))))


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%         NOTEHEAD PATHS
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Diamond/kite shape: four straight lines forming a vertical diamond.
%% Top at +0.6667, bottom at -0.6667, center at 0.
#(define cnb:notehead-shape-path '(
    (moveto 0 0.6667)
    (lineto 0.6667 0.3333)
    (lineto 0 -0.6667)
    (lineto -0.6667 0.3333)
    (lineto 0 0.6667)
    (closepath)))

%% Smaller inner diamond used as the hollow cutout.
%% Top at +0.3333, bottom at -0.3333, center at 0.
#(define cnb:notehead-hollow-path '(
    (moveto 0.3333 0.3333)
    (lineto 0 -0.3333)
    (lineto -0.3333 0.3333)
    (lineto 0.3333 0.3333)
    (closepath)))


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%           SEQUENCES
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% COLOR: 3-color cycle starting from C.
%% C=Purple, C#=Red, D=Green, D#=Purple, E=Red, F=Green, ...
#(define cnb:notehead-color-sequence (vector
    cnb:0-purple
    cnb:1-red
    cnb:2-green))

%% SHAPE: Same diamond shape for all pitch classes.
#(define cnb:notehead-shape-sequence (vector
    cnb:notehead-shape-path))

%% HOLLOW: Alternates solid/hollow every pitch.
%% C=solid, C#=hollow, D=solid, D#=hollow, ...
#(define cnb:notehead-hollow-sequence (vector
    #f
    cnb:notehead-hollow-path))

%% ROTATION: 4-step cycle.
%% C=inverted(180°), C#=upright(0°), D=upright(0°), D#=inverted(180°)
%% Then E=inverted, F=upright, F#=upright, G=inverted, etc.
#(define cnb:notehead-rotation-sequence (vector
   180
     0
     0
   180))

%% SCALING: No scaling (full size).
#(define cnb:notehead-scaling-sequence (vector '(1 . 1)))
