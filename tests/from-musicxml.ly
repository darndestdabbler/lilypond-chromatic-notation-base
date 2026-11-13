\version "2.24.2"
\include "ChromaticNotationBase.ly"
\include "cnb/test-ids.ly"
% automatically converted by musicxml2ly from 21d-Chords-SchubertStabatMater.xml
\pointAndClickOff

\header {
    texidoc = 
    "Chords in the 
                            second measure, after several ornaments in the first 
                            measure and a p at the beginning of the second 
                            measure."
    }

PartPZeroVoiceOne =  \relative f' {
    \clef "treble" \time 4/4 \key as \major | % 1
    f1 \fermata -> -\markup{ \bold {Largo} } -\fp | % 2
    <f as>4. -\p <f as>8 <g bes>4 <g bes>4 }


% The score definition
\score {
    <<
        
        \new Staff
        <<
            
            \context Staff << 
                \mergeDifferentlyDottedOn\mergeDifferentlyHeadedOn
                \context Voice = "PartPZeroVoiceOne" {  \PartPZeroVoiceOne }
                >>
            >>
        
        >>
    \layout {}
    % To create MIDI output, uncomment the following line:
    %  \midi {\tempo 4 = 100 }
    }

