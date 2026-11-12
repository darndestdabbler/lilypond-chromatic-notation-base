%% ============================================================================
%%
%%  CNB MODULE: score-defaults.ly
%%  Staff magnification and room for instrument names, applied to every score
%%
%%  WHAT THIS FILE DOES:
%%    Makes one \include line enough for a plain score (for example
%%    musicxml2ly output), which sets neither a magnification nor an indent:
%%      1. \magnifyStaff #cnb:default-magnify on every Staff, so the custom
%%         noteheads are not engraved at the small default staff size.
%%         cnb:default-magnify is read when each staff starts, not when
%%         this file is included, so a config included after the engine
%%         that set!s it takes effect.
%%      2. A 25 mm indent and a 12 mm short-indent. cnb/layout.ly sets
%%         indent = #cnb:indent (0) and a 5 mm left margin, which leaves no
%%         room for instrumentName / shortInstrumentName: they are clipped
%%         at the page edge. The magnified name "Soprano" fits in 25 mm.
%%
%%    A score's own \paper and \layout are read after this file, so they
%%    still win. \magnifyStaff is idempotent (it records its factor in
%%    magnifyStaffValue): a score that also magnifies its staves by hand
%%    is not magnified twice, and a different factor in a Staff's \with
%%    or its music replaces this one.
%%
%%    Until session 35 the \layout block below held \magnifyStaff
%%    #cnb:default-magnify itself, whose argument is evaluated when this
%%    file is included: a config that set!s the variable afterwards
%%    changed only the staves that magnified themselves with it. Now an
%%    \applyContext builds \magnifyStaff from the variable's value when
%%    each Staff is created and applies it to that Staff.
%%
%%  OPTING OUT:
%%    Define the flag as #f BEFORE including the engine (or a config that
%%    includes it):
%%
%%      #(define cnb:score-defaults #f)
%%      \include "ChromaticNotationBase.ly"
%%
%%  DEPENDENCIES: cnb/config.ly (cnb:default-magnify); loaded after
%%  cnb/layout.ly so that these blocks extend its \layout and \paper.
%%
%% ============================================================================


#(define cnb:score-defaults
   (or (not (defined? 'cnb:score-defaults)) cnb:score-defaults))

$(if cnb:score-defaults
  #{
    \layout {
      \context {
        \Staff
        \applyContext
          #(lambda (staff)
             (ly:context-mod-apply!
               staff
               (context-mod-from-music (magnifyStaff cnb:default-magnify))))
      }
    }
  #})

$(if cnb:score-defaults
  #{
    \paper {
      indent = 25\mm
      short-indent = 12\mm
    }
  #})
