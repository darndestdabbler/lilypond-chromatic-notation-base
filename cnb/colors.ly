%% ============================================================================
%%
%%  CNB MODULE: colors.ly
%%  Color palette definitions for ChromaticNotationBase
%%
%%  WHAT THIS FILE DOES:
%%    Defines a library of named colors as hex strings for two purposes:
%%
%%    1. PLATFORM COLORS (black, white, gold, blue) — used internally
%%       by the engine for false-hollow overlays, key signature stems,
%%       and default notehead color. These are always needed.
%%
%%    2. CONVENIENCE PALETTES — pre-defined color collections for
%%       hand-coded notation configs. These are NOT used by
%%       Configurator-generated configs, which use cnb:register-color!
%%       with auto-named symbols and raw hex strings instead.
%%
%%  DEPENDENCIES: None
%%
%%  TWO COLOR SYSTEMS:
%%
%%    Hand-written notation configs can reference these named constants
%%    directly:
%%      #(cnb:register-color! 'my-primary cnb:0-purple)
%%
%%    Configurator-generated configs use the palette-based system:
%%      - Colors are auto-named via nearestColorName (e.g., shamrock-1b9e77)
%%      - Registered via cnb:register-color! with hex string values
%%      - A conditional block in Section A switches between primary and
%%        colorblind-safe palettes based on cnb:use-accessible-colors
%%      - The convenience palettes below are not referenced
%%
%%  ADDING NEW COLORS:
%%    Just add a new #(define cnb:mycolor "#rrggbb") line below.
%%    Then reference it in your config file.
%%
%% ============================================================================


%% ---------------------------------------------------------------------------
%%  FUNDAMENTAL PLATFORM COLORS (required by engine internals)
%%  These are used as default colors for different platform components
%% ---------------------------------------------------------------------------

#(define cnb:black     "#000000") %% default notehead color
#(define cnb:white     "#ffffff") %% default false-hollow color
#(define cnb:gold      "#ffd42a") %% default color for key signature stem
#(define cnb:blue      "#6e8af8") %% utility blue color


%% ---------------------------------------------------------------------------
%%  CONVENIENCE PALETTES (for hand-coded configs — not used by Configurator)
%% ---------------------------------------------------------------------------


%% ---------------------------------------------------------------------------
%%  RICH TRICOLOR PALETTE 
%%  These can be used for modulo-3 semitone colors
%% ---------------------------------------------------------------------------

#(define cnb:0-purple    "#7d3fff") %% Could be used for C, D#, F#, A
#(define cnb:1-red       "#dc4538") %% Could be used for C#, E, G, A#
#(define cnb:2-green     "#0f9e59") %% Could be used for D, F, G#, B


%% ---------------------------------------------------------------------------
%%  COLORBLIND-SAFE TRICOLOR PALETTE 
%%  These can be used for modulo-3 semitone colors
%% ---------------------------------------------------------------------------

#(define cnb:0-skyblue   "#50b4e9") %% Could be used for C, D#, F#, A
#(define cnb:1-rose      "#cc79a7") %% Could be used for C#, E, G, A#
#(define cnb:2-bluegreen "#009e73") %% Could be used for D, F, G#, B
#(define cnb:2-black     "#000000") %% Alternative for D, F, G#, B


%% ---------------------------------------------------------------------------
%% COLORBLIND-SAFE DISCRETE 12-SEMITONE PALETTE
%% Basis: Paul Tol / CARTO
%% Order: Circle of Fifths Jump (C, G, D, A, E, B, F#, C#, G#, D#, A#, F)
%% This ordering ensures adjacent semitones have high visual contrast.
%% ---------------------------------------------------------------------------

#(define cnb:0-tol-lightblue   "#88CCEE")
#(define cnb:1-tol-olive       "#999933")
#(define cnb:2-tol-sand        "#DDCC77")
#(define cnb:3-tol-brown       "#661100")
#(define cnb:4-tol-indigo      "#332288")
#(define cnb:5-tol-gray        "#888888")
#(define cnb:6-tol-teal        "#44AA99")
#(define cnb:7-tol-rose        "#CC6677")
#(define cnb:8-tol-wine        "#882255")
#(define cnb:9-tol-green       "#117733")
#(define cnb:10-tol-slateblue  "#6699CC")
#(define cnb:11-tol-purple     "#AA4499")


%% ---------------------------------------------------------------------------
%% COLORBLIND-SAFE VIVID CHROMATIC 12-SEMITONE PALETTE 
%% Basis: Krzywinski optimized for Deuteranopia
%% Optimized for small noteheads and high saturation displays.
%% Order: Circle of Fifths Jump (C, G, D, A, E, B, F#, C#, G#, D#, A#, F)
%% This ordering ensures adjacent semitones have high visual contrast.
%% ---------------------------------------------------------------------------

#(define cnb:0-krz-magenta     "#9F0162")
#(define cnb:1-krz-lavender    "#FFB2FD")
#(define cnb:2-krz-rose        "#FF5AAF")
#(define cnb:3-krz-crimson     "#E20134")
#(define cnb:4-krz-violet      "#8400CD")
#(define cnb:5-krz-yellow      "#FFC33B")
#(define cnb:6-krz-lightblue   "#00C2F9")
#(define cnb:7-krz-green       "#009F81")
#(define cnb:8-krz-red         "#A40122")
#(define cnb:9-krz-cyan        "#00FCCF")
#(define cnb:10-krz-vermillion "#FF6E3A")
#(define cnb:11-krz-blue       "#008DF9")


%% ---------------------------------------------------------------------------
%% ADDITIONAL STANDARD COLORS
%% These can be overriden
%% ---------------------------------------------------------------------------

#(define cnb:std-gray        "#808080")
#(define cnb:std-silver      "#c0c0c0")
#(define cnb:std-red         "#ff0000")
#(define cnb:std-maroon      "#800000")
#(define cnb:std-orange      "#ffa500")
#(define cnb:std-darkorange  "#ff8c00")
#(define cnb:std-yellow      "#ffff00")
#(define cnb:std-olive       "#808000")
#(define cnb:std-gold        "#ffd700")
#(define cnb:std-lime        "#00ff00")
#(define cnb:std-green       "#008000")
#(define cnb:std-teal        "#008080")
#(define cnb:std-aqua        "#00ffff")
#(define cnb:std-skyblue     "#87ceeb")
#(define cnb:std-blue        "#0000ff")
#(define cnb:std-navy        "#000080")
#(define cnb:std-purple      "#800080")
#(define cnb:std-fuchsia     "#ff00ff")
#(define cnb:std-pink        "#ffc0cb")
#(define cnb:std-crimson     "#dc143c")
#(define cnb:std-brown       "#a52a2a")
#(define cnb:std-slategray   "#708090")