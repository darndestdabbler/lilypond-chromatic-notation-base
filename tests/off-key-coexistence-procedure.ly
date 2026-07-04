\version "2.24.2"

%% Regression test for callback chaining (Known Issue #1, session set 002)
%% — PROCEDURE MODEL variant.
%%
%% tests/off-key-coexistence.ly covers the vector-model call site in
%% cnb/off-key.ly; this score covers the procedure-model site (the
%% engraver branch that reads off-key-mark from the config cache and
%% chains a closure onto after-line-breaking).
%%
%% The config procedure below extends the engine's default config with a
%% key-aware off-key-mark: any pitch class outside the current key gets
%% 'dot. With test-ids.ly also active, the F# notehead must carry BOTH
%% modules' effects, exactly as in the vector-model test.

\include "ChromaticNotationBase.ly"

#(set! cnb:use-procedure-model #t)

%% Same as the default cnb:get-notehead-config in cnb/procedure.ly,
%% plus an off-key-mark rule: 'dot for notes outside the key.
#(set! cnb:get-notehead-config
   (lambda (semitone duration key)
     `((shape        . default-oval)
       (color        . ,cnb:black)
       (hollow       . ,(if (odd? semitone) 'default-oval-cutout #f))
       (attachment   . default-side)
       (off-key-mark . ,(if (cnb:in? semitone key) #f 'dot))
       (repeat       . #t))))

\include "cnb/test-ids.ly"

\relative c' {
  \key c \major
  \time 4/4
  c4 d fis g |
}
