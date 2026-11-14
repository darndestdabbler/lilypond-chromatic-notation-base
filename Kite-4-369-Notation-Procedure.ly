%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%
%% Kite 4-369 Notation — PROCEDURE MODEL
%% Compatible with Refactored ChromaticNotationBase (2026)
%%
%% WHAT THIS FILE DOES:
%%   Configures CNB using the procedure-oriented model to produce
%%   Kite notation:
%%     - Diamond-shaped noteheads (kite-up and kite-down as named shapes)
%%     - 3 colors cycling: purple, red, green
%%     - Alternating solid/hollow
%%     - Rotation baked into paths (not a runtime parameter)
%%     - 3 semitones per staff space (compact layout)
%%     - Staff lines at +/- 3, 6 & 9 semitones from center
%%     - False-hollow mode (white overlay for sharp diamond corners)
%%
%% HOW THIS DIFFERS FROM THE CLEAN (VECTOR) VERSION:
%%   Instead of separate cycling vectors for color, shape, hollow, and
%%   rotation, this file defines a single procedure that returns a
%%   complete notehead config for any (semitone, duration, key) input.
%%   Rotation is eliminated as a parameter — kite-up and kite-down are
%%   separate named shapes with their own stem attachment points.
%%
%%   This version uses cnb:use-procedure-model = #t, so the engine reads
%%   from the procedure config cache. No vector sequences are defined.
%%
%% HOW TO USE:
%%   In your music file:
%%     \include "Kite-4-369-Notation-Procedure.ly"
%%     { c'4 d' e' f' ... }
%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

\version "2.24.2"
\include "ChromaticNotationBase.ly"


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%           METADATA
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#(set! cnb:file-suffix "-Kite-4-369-Procedure")
#(set! cnb:notation-label "Kite 4-369 (Procedure)")
#(set! cnb:notation-footnote
  "*4-369 Notation: notehead height = 4 semitones; staff lines at +/- 3, 6 & 9 semitones")


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%     ENABLE PROCEDURE MODEL
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#(set! cnb:use-procedure-model #t)


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%        STAFF GEOMETRY
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#(set! cnb:semitones-per-staff-space 3)
#(set! cnb:staff-line-positions '(-6 -4 -2  2 4 6))


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%     MULTI-NOTE AND HOLLOW SETTINGS
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#(set! cnb:multinote-padding -.5)
#(set! cnb:false-hollow #t)


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%       COLOR DEFINITIONS
%%
%% Named colors — override in score file for accessibility.
%% Example:
%%   #(cnb:register-color! 'kite-color-primary   cnb:0-skyblue)
%%   #(cnb:register-color! 'kite-color-secondary cnb:1-rose)
%%   #(cnb:register-color! 'kite-color-tertiary  cnb:2-black)
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#(cnb:register-color! 'kite-color-primary   cnb:0-purple)
#(cnb:register-color! 'kite-color-secondary cnb:1-red)
#(cnb:register-color! 'kite-color-tertiary  cnb:2-green)


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%       PATH DEFINITIONS
%%
%% Rotation is baked into paths: kite-up is the base shape (0°),
%% kite-down is rotated 180°. Each has its own hollow cutout.
%% The Baker (Configurator) would generate these automatically
%% via "generate inverted pair".
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% --- Base diamond shape (upright, kite pointing up) ---
#(define cnb:kite-base-shape '(
    (moveto 0 0.6667)
    (lineto 0.6667 0.3333)
    (lineto 0 -0.6667)
    (lineto -0.6667 0.3333)
    (lineto 0 0.6667)
    (closepath)))

%% --- Base hollow cutout (upright) ---
#(define cnb:kite-base-hollow '(
    (moveto 0.3333 0.3333)
    (lineto 0 -0.3333)
    (lineto -0.3333 0.3333)
    (lineto 0.3333 0.3333)
    (closepath)))

%% --- Generate rotated variants ---
#(define cnb:kite-up-path   cnb:kite-base-shape)
#(define cnb:kite-down-path (cnb:rotate-path cnb:kite-base-shape 180))

#(define cnb:kite-up-cutout   cnb:kite-base-hollow)
#(define cnb:kite-down-cutout (cnb:rotate-path cnb:kite-base-hollow 180))


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%     REGISTER NAMED DEFINITIONS
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% --- Shapes ---
#(cnb:register-path! 'kite-up   cnb:kite-up-path)
#(cnb:register-path! 'kite-down cnb:kite-down-path)

%% --- Hollow cutouts ---
#(cnb:register-hollow! 'kite-up-cutout   cnb:kite-up-cutout)
#(cnb:register-hollow! 'kite-down-cutout cnb:kite-down-cutout)

%% --- Stem attachment ---
%% Diamond noteheads: stems attach at top/bottom center.
%% Minim (half note) attachment is offset for double-notehead layout.
#(cnb:register-attachment! 'center-top
   (list
     (cons 'crotchet-up   '(0 . .9))
     (cons 'crotchet-down '(0 . -.9))
     (cons 'minim-up      '(-.365 . .9))
     (cons 'minim-down    '(.365 . -.9))))


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%   THE CONFIGURATION PROCEDURE
%%
%% Maps (semitone, duration, key) → notehead config.
%%
%% Kite 4-369 combines three independent cycles:
%%   Color:  mod 3 — purple, red, green
%%   Shape:  mod 4 — down, up, up, down
%%   Hollow: mod 2 — solid, hollow
%%
%% The procedure computes these directly rather than
%% using 12 separate cond clauses, since the cycles
%% are independent. For notations with key-dependent or
%% duration-dependent rules, use cond-based dispatch.
%%
%% PITCH CLASS → PROPERTY TABLE:
%%   PC  Color                  Shape      Hollow
%%   0   kite-color-primary     kite-down  solid
%%   1   kite-color-secondary   kite-up    kite-up-cutout
%%   2   kite-color-tertiary    kite-up    solid
%%   3   kite-color-primary     kite-down  kite-down-cutout
%%   4   kite-color-secondary   kite-down  solid
%%   5   kite-color-tertiary    kite-up    kite-up-cutout
%%   6   kite-color-primary     kite-up    solid
%%   7   kite-color-secondary   kite-down  kite-down-cutout
%%   8   kite-color-tertiary    kite-down  solid
%%   9   kite-color-primary     kite-up    kite-up-cutout
%%   10  kite-color-secondary   kite-up    solid
%%   11  kite-color-tertiary    kite-down  kite-down-cutout
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#(set! cnb:get-notehead-config
   (lambda (semitone duration key)
     (let* (;; Color: named reference, cycling mod 3.
            ;; The resolver maps these to hex strings via cnb:color-defs.
            ;; Score files can re-register to override for accessibility.
            (color (vector-ref
                     (vector 'kite-color-primary 'kite-color-secondary 'kite-color-tertiary)
                     (modulo semitone 3)))

            ;; Shape: 4-cycle — down(180°), up(0°), up(0°), down(180°)
            ;; mod4=0 or 3 → kite-down, mod4=1 or 2 → kite-up
            (mod4 (modulo semitone 4))
            (is-down (or (= mod4 0) (= mod4 3)))
            (shape (if is-down 'kite-down 'kite-up))

            ;; Hollow: 2-cycle — even=solid, odd=hollow
            ;; Hollow cutout must match the shape variant
            (hollow (if (odd? semitone)
                       (if is-down 'kite-down-cutout 'kite-up-cutout)
                       #f)))

       `((shape      . ,shape)
         (color      . ,color)
         (hollow     . ,hollow)
         (attachment . center-top)
         (off-key-mark . #f)))))
