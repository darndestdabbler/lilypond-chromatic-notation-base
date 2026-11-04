\version "2.24.2"

%% Augmentation dots on and off ledger lines (audit 2026-11-02, H3).
%%
%% cnb:dots-avoid-ledgers (cnb/dots.ly) shifts the dot of a note on a
%% ledger line one staff-position away from the staff. The dot is placed
%% relative to its notehead, so the shift must be the dodge alone; adding
%% the notehead's own position counted it twice and threw the dot several
%% staff spaces away.
%%
%% One dotted half per measure, on the default CNB staff:
%%   on ledger lines below the staff:   bes c' d' e'
%%   between ledger lines below:        a b cis'
%%   inside the staff:                  g' b' (spaces), e'' (top line)
%%   on ledger lines above the staff:   c''' d''' e''' gis'''
%%   between ledger lines above:        f'''

\include "ChromaticNotationBase.ly"
\include "cnb/test-ids.ly"

{
  \time 3/4
  a2. | bes2. | b2. | c'2. | cis'2. | d'2. | e'2. | g'2. | b'2. | e''2. |
  c'''2. | d'''2. | e'''2. | f'''2. | gis'''2. |
}
