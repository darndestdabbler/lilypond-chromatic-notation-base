%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%
%% Chromatic Notation Base Library for LilyPond
%% Dennis Mitchell, 2024-01-01
%% Refactored into modules, 2026
%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%
%% WHAT THIS LIBRARY DOES:
%%   Provides a reusable engine for creating chromatic music notation in
%%   LilyPond. It replaces the standard diatonic staff with a chromatic
%%   staff where every semitone has a unique vertical position, and
%%   noteheads can be customized with different shapes, colors, rotations,
%%   and hollow patterns to visually distinguish pitch classes.
%%
%% HOW TO USE:
%%   1. Place this file and the "cnb/" folder in your project directory
%%   2. Create a notation config file (e.g., MyNotation.ly) that does:
%%        \include "ChromaticNotationBase.ly"
%%        #(set! cnb:some-variable new-value)  % override defaults
%%        ...
%%   3. In your music file, include the config file:
%%        \include "MyNotation.ly"
%%        { c'4 d' e' f' ... }
%%
%%   For colorblind-safe colors (if the notation config supports it),
%%   define the flag BEFORE including the config:
%%        #(define cnb:use-accessible-colors #t)
%%        \include "MyNotation.ly"
%%        { c'4 d' e' f' ... }
%%
%%   See Kite-4-369-Notation-Clean.ly for a complete config example.
%%
%% BASE PROPERTIES (defaults, overridable in config files):
%%   - Dozenal clef notation (numbers instead of clef symbols)
%%   - Notehead key signatures (chord stacks instead of sharps/flats)
%%   - Notehead shape = standard oval (alternating solid/hollow)
%%   - Notehead height = 2 semitones
%%   - Staff space = 2 semitones
%%   - Middle staff line is present
%%   - Default color = black (monochrome)
%%
%% MODULE ARCHITECTURE:
%%   The library is split into focused modules in the cnb/ directory.
%%   Each module handles one aspect of the notation system:
%%
%%   cnb/utils.ly           — Math, list, color, and caching utilities
%%   cnb/colors.ly          — Named color palette (hex strings)
%%   cnb/config.ly          — All configurable variables with defaults
%%   cnb/procedure.ly       - Procedure-oriented configuration infrastructure
%%   cnb/path-geometry.ly   — Path winding detection, reversal, normalization
%%   cnb/stencils.ly        — Notehead stencil construction and caching
%%   cnb/noteheads.ly       — Notehead engraver (positions + renders notes)
%%   cnb/stems.ly           — Stem attachment points and length compensation
%%   cnb/clefs.ly           — Dozenal clef number system and engraver
%%   cnb/ledgers.ly         — Proximity-based ledger line visibility
%%   cnb/staff.ly           — Staff lines, ledger lines, and their engravers
%%   cnb/keysig.ly          — Notehead-based key signatures and engraver
%%   cnb/beams.ly           — Beam thickness/spacing compensation
%%   cnb/articulations.ly   — Articulation Y-offset correction for ledger collisions
%%   cnb/dots.ly            — Augmentation dot avoidance for ledger lines
%%   cnb/off-key.ly         — Off-key note flags (configurable visual indicators)
%%   cnb/layout.ly          — Engraver registration and paper settings
%%
%%   Modules are loaded in dependency order — each module may rely on
%%   modules listed above it, but never on modules listed below it.
%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

\version "2.24.2"


%% ===== LOAD ALL MODULES IN DEPENDENCY ORDER =====

\include "cnb/utils.ly"
\include "cnb/colors.ly"
\include "cnb/config.ly"
\include "cnb/procedure.ly"
\include "cnb/path-geometry.ly"
\include "cnb/stencils.ly"
\include "cnb/noteheads.ly"
\include "cnb/stems.ly"
\include "cnb/clefs.ly"
\include "cnb/ledgers.ly"
\include "cnb/staff.ly"
\include "cnb/keysig.ly"
\include "cnb/beams.ly"
\include "cnb/articulations.ly"
\include "cnb/dots.ly"
\include "cnb/off-key.ly"
\include "cnb/layout.ly"
