\version "2.24.2"

%% ============================================================================
%%
%%  CNB TEST SUITE: test-unit.ly
%%  Unit tests for all pure Scheme functions in the CNB framework.
%%
%%  RUN WITH:
%%    lilypond test-unit.ly
%%
%%  No music is rendered. This file only exercises Scheme functions
%%  and reports pass/fail via ly:message. Exit code will be 0 if all
%%  tests pass (LilyPond doesn't support nonzero exit on Scheme errors,
%%  but the FAIL count in the summary tells you).
%%
%%  CONVENTION:
%%    Each test group is a section header followed by assert calls.
%%    assert-equal checks (equal? actual expected).
%%    assert-true checks that a value is not #f.
%%    assert-near checks numeric equality within epsilon.
%%
%% ============================================================================


%% --- Load the framework ---
%% We include only the modules we need for testing.
%% Some modules (layout.ly, noteheads.ly) require a full LilyPond
%% rendering context and can't be unit-tested this way.

\include "cnb/utils.ly"
\include "cnb/colors.ly"
\include "cnb/config.ly"
\include "cnb/procedure.ly"
\include "cnb/path-geometry.ly"
\include "cnb/stencils.ly"
\include "cnb/ledgers.ly"
\include "cnb/off-key.ly"
\include "cnb/clefs.ly"
\include "cnb/staff.ly"
\include "cnb/keysig.ly"


%% =========================================================================
%%  TEST FRAMEWORK
%% =========================================================================

#(define cnb:test-pass-count 0)
#(define cnb:test-fail-count 0)
#(define cnb:test-current-group "")

#(define (cnb:test-group name)
   (set! cnb:test-current-group name)
   (ly:message "\n=== ~a ===" name))

#(define (cnb:assert-equal test-name actual expected)
   (if (equal? actual expected)
       (begin
         (set! cnb:test-pass-count (+ 1 cnb:test-pass-count))
         (ly:message "  PASS: ~a" test-name))
       (begin
         (set! cnb:test-fail-count (+ 1 cnb:test-fail-count))
         (ly:message "  FAIL: ~a" test-name)
         (ly:message "    expected: ~a" expected)
         (ly:message "    actual:   ~a" actual))))

#(define (cnb:assert-true test-name value)
   (if value
       (begin
         (set! cnb:test-pass-count (+ 1 cnb:test-pass-count))
         (ly:message "  PASS: ~a" test-name))
       (begin
         (set! cnb:test-fail-count (+ 1 cnb:test-fail-count))
         (ly:message "  FAIL: ~a (expected truthy, got ~a)" test-name value))))

#(define (cnb:assert-false test-name value)
   (if (not value)
       (begin
         (set! cnb:test-pass-count (+ 1 cnb:test-pass-count))
         (ly:message "  PASS: ~a" test-name))
       (begin
         (set! cnb:test-fail-count (+ 1 cnb:test-fail-count))
         (ly:message "  FAIL: ~a (expected falsy, got ~a)" test-name value))))

#(define (cnb:assert-near test-name actual expected epsilon)
   (if (< (abs (- actual expected)) epsilon)
       (begin
         (set! cnb:test-pass-count (+ 1 cnb:test-pass-count))
         (ly:message "  PASS: ~a" test-name))
       (begin
         (set! cnb:test-fail-count (+ 1 cnb:test-fail-count))
         (ly:message "  FAIL: ~a" test-name)
         (ly:message "    expected: ~a (±~a)" expected epsilon)
         (ly:message "    actual:   ~a" actual))))

#(define (cnb:assert-member test-name value lst)
   (if (member value lst)
       (begin
         (set! cnb:test-pass-count (+ 1 cnb:test-pass-count))
         (ly:message "  PASS: ~a" test-name))
       (begin
         (set! cnb:test-fail-count (+ 1 cnb:test-fail-count))
         (ly:message "  FAIL: ~a" test-name)
         (ly:message "    ~a not found in ~a" value lst))))


%% =========================================================================
%%  TEST: cnb/utils.ly — Math and list utilities
%% =========================================================================

#(cnb:test-group "utils.ly — cnb:round2")
#(cnb:assert-equal "round2(3.14159, 2) = 3.14" (cnb:round2 3.14159 2) 3.14)
%% Guile uses banker's rounding (round-half-to-even): round(2.5) = 2.0
#(cnb:assert-near "round2(2.5, 0) = 2.0 (banker's)" (cnb:round2 2.5 0) 2.0 0.001)
#(cnb:assert-near "round2(3.5, 0) = 4.0 (banker's)" (cnb:round2 3.5 0) 4.0 0.001)

#(cnb:test-group "utils.ly — cnb:add-if-not-exists")
#(cnb:assert-equal "add new element"      (cnb:add-if-not-exists '(1 2 3) 4) '(1 2 3 4))
#(cnb:assert-equal "don't add duplicate"  (cnb:add-if-not-exists '(1 2 3) 2) '(1 2 3))
#(cnb:assert-equal "add to empty list"    (cnb:add-if-not-exists '() 1)       '(1))

#(cnb:test-group "utils.ly — cnb:hex-to-rgb")
#(let ((rgb (cnb:hex-to-rgb "#FF0000")))
   (cnb:assert-near "red channel of #FF0000"   (car rgb)    1.0 0.01)
   (cnb:assert-near "green channel of #FF0000" (cadr rgb)   0.0 0.01)
   (cnb:assert-near "blue channel of #FF0000"  (caddr rgb)  0.0 0.01))
#(let ((rgb (cnb:hex-to-rgb "#00FF00")))
   (cnb:assert-near "green channel of #00FF00" (cadr rgb)   1.0 0.01))
#(let ((rgb (cnb:hex-to-rgb "#808080")))
   (cnb:assert-near "gray #808080 red"         (car rgb)    0.502 0.01))

#(cnb:test-group "utils.ly — cnb:flatten-path")
#(cnb:assert-equal "flatten nested path"
   (cnb:flatten-path '((moveto 0 0) (lineto 1 1) (closepath)))
   '(moveto 0 0 lineto 1 1 closepath))
#(cnb:assert-equal "flatten with curveto"
   (cnb:flatten-path '((moveto 0 0) (curveto 1 2 3 4 5 6) (closepath)))
   '(moveto 0 0 curveto 1 2 3 4 5 6 closepath))

#(cnb:test-group "utils.ly — cnb:make-cache-key")
%% Formula: pitch-class * 100 + duration-category (0 breve, 1 whole,
%% 2 half, 3 quarter or shorter)
#(cnb:assert-equal "cache key for C breve (0, 0)"     (cnb:make-cache-key 0 0)     0)
#(cnb:assert-equal "cache key for C quarter (0, 3)"   (cnb:make-cache-key 0 3)     3)
#(cnb:assert-equal "cache key for F half (5, 2)"      (cnb:make-cache-key 5 2)   502)
#(cnb:assert-equal "cache key for B whole (11, 1)"    (cnb:make-cache-key 11 1) 1101)
#(cnb:assert-equal "cache key for B quarter (11, 3)"  (cnb:make-cache-key 11 3) 1103)
%% Keys must be unique — verify no collisions for all valid combinations
#(cnb:assert-true "all cache keys unique over 12 pitch classes x 4 categories"
   (let* ((keys (map (lambda (p)
                       (map (lambda (d) (cnb:make-cache-key p d))
                            '(0 1 2 3)))
                     (iota 12)))
          (flat (apply append keys))
          (unique (delete-duplicates flat)))
     (= (length flat) (length unique))))
%% The optional semibreve group count keeps the breve, longa and maxima
%% (all category 0) apart, and its default leaves every key unchanged.
#(cnb:assert-equal "cache key with 1 group = key without it" (cnb:make-cache-key 5 1 1) 501)
#(cnb:assert-equal "cache key for C breve, 2 groups"  (cnb:make-cache-key 0 0 2)    10)
#(cnb:assert-equal "cache key for C longa, 4 groups"  (cnb:make-cache-key 0 0 4)    30)
#(cnb:assert-equal "cache key for B maxima, 8 groups" (cnb:make-cache-key 11 0 8) 1170)
#(cnb:assert-true "all cache keys unique over 12 pitch classes x categories and groups"
   (let* ((keys (map (lambda (p)
                       (append (map (lambda (d) (cnb:make-cache-key p d)) '(1 2 3))
                               (map (lambda (g) (cnb:make-cache-key p 0 g)) '(1 2 4 8))))
                     (iota 12)))
          (flat (apply append keys)))
     (= (length flat) (length (delete-duplicates flat)))))
%% A dotted or triplet note keys the same as its plain duration.
#(cnb:assert-equal "cache key of a triplet half = cache key of a half"
   (cnb:make-cache-key 7 (cnb:duration-category (ly:make-duration 1 0 2 3)))
   (cnb:make-cache-key 7 (cnb:duration-category (ly:make-duration 1 0))))

#(cnb:test-group "utils.ly — cnb:duration-category")
%% Scale (cnb/procedure.ly): 0 = breve or longer, 1 = whole, 2 = half,
%% 3 = quarter or shorter. It comes from the duration log alone, so dots
%% and the tuplet factor never change it.
%% Each entry: (log expected-category name).
#(for-each
   (lambda (entry)
     (let ((log (car entry))
           (expected (cadr entry))
           (name (caddr entry)))
       (cnb:assert-equal (format #f "~a (log ~a) -> ~a" name log expected)
         (cnb:duration-category (ly:make-duration log 0)) expected)
       (cnb:assert-equal (format #f "dotted ~a -> ~a" name expected)
         (cnb:duration-category (ly:make-duration log 1)) expected)
       (cnb:assert-equal (format #f "double-dotted ~a -> ~a" name expected)
         (cnb:duration-category (ly:make-duration log 2)) expected)))
   '((-1 0 "breve")
     (0 1 "whole")
     (1 2 "half")
     (2 3 "quarter")
     (3 3 "eighth")
     (4 3 "sixteenth")))
%% Triplets (2/3 factor) keep their written duration's category.
#(cnb:assert-equal "triplet breve -> 0"   (cnb:duration-category (ly:make-duration -1 0 2 3)) 0)
#(cnb:assert-equal "triplet whole -> 1"   (cnb:duration-category (ly:make-duration 0 0 2 3)) 1)
#(cnb:assert-equal "triplet half -> 2"    (cnb:duration-category (ly:make-duration 1 0 2 3)) 2)
#(cnb:assert-equal "triplet quarter -> 3" (cnb:duration-category (ly:make-duration 2 0 2 3)) 3)
#(cnb:assert-equal "dotted triplet half -> 2" (cnb:duration-category (ly:make-duration 1 1 2 3)) 2)

#(cnb:test-group "utils.ly — cnb:semibreve-groups")
%% A breve or longer engraves in repeat mode as 2^(-log) tied semibreve
%% groups; a whole note or shorter as one. Each entry: (log groups name).
#(for-each
   (lambda (entry)
     (cnb:assert-equal (format #f "~a (log ~a) -> ~a group(s)"
                               (caddr entry) (car entry) (cadr entry))
       (cnb:semibreve-groups (car entry)) (cadr entry)))
   '((-3 8 "maxima")
     (-2 4 "longa")
     (-1 2 "breve")
     (0 1 "whole")
     (1 1 "half")
     (2 1 "quarter")))

#(cnb:test-group "stencils.ly — cnb:build-duration-stencil tied semibreves")
%% A 1 x 1 box as the head: the whole-note group is its 4-copy stencil;
%% a breve is 2 groups 1 staff space apart, a longa 4 groups and 3 gaps,
%% and one tie below them all. The composite starts where its first group
%% does, keeps the head's top edge, and the tie takes its bottom below
%% the head's.
#(let* ((box   (make-filled-box-stencil '(-0.5 . 0.5) '(-0.5 . 0.5)))
        (whole (ly:stencil-extent (cnb:build-duration-stencil box 1) X))
        (gw    (interval-length whole)))
   (cnb:assert-equal "1 group = the whole-note stencil's extent"
     (ly:stencil-extent (cnb:build-duration-stencil box 0 1) X) whole)
   (for-each
     (lambda (groups)
       (let* ((st  (cnb:build-duration-stencil box 0 groups))
              (ext (ly:stencil-extent st X))
              (yx  (ly:stencil-extent st Y)))
         (cnb:assert-near (format #f "~a groups: width = ~a group widths + ~a gaps"
                                  groups groups (- groups 1))
           (interval-length ext) (+ (* groups gw) (- groups 1)) 0.001)
         (cnb:assert-near (format #f "~a groups: left edge = the group's" groups)
           (car ext) (car whole) 0.001)
         (cnb:assert-near (format #f "~a groups: top edge = the head's" groups)
           (cdr yx) 0.5 0.001)
         (cnb:assert-true (format #f "~a groups: the tie takes the bottom below the head's" groups)
           (< (car yx) -0.5))))
     '(2 4)))

#(cnb:test-group "utils.ly — cnb:compose-after-line-breaking")
%% The composer is pure: it takes the property's current value and a new
%% callback and returns one procedure. We verify composition and ordering
%% by having each callback append a tag to a shared list; the "grob"
%% argument can be any value since these test callbacks just record it.

%% Unset property ('() is what an unset grob property reads as):
%% the new callback is returned as-is, no wrapper.
#(let ((cb (lambda (g) g)))
   (cnb:assert-true "unset ('()) existing returns new callback unchanged"
     (eq? (cnb:compose-after-line-breaking '() cb) cb)))
#(let ((cb (lambda (g) g)))
   (cnb:assert-true "#f existing returns new callback unchanged"
     (eq? (cnb:compose-after-line-breaking #f cb) cb)))

%% Existing procedure: both callbacks fire, existing first.
#(let* ((calls '())
        (existing (lambda (g) (set! calls (cons 'existing calls))))
        (new-cb   (lambda (g) (set! calls (cons 'new calls))))
        (composed (cnb:compose-after-line-breaking existing new-cb)))
   (composed 'dummy-grob)
   (cnb:assert-equal "existing fires first, then new (registration order)"
     (reverse calls) '(existing new)))

%% Three-deep chain (module A, then B, then C on the same grob property).
#(let* ((calls '())
        (tag (lambda (name) (lambda (g) (set! calls (cons name calls)))))
        (chained (cnb:compose-after-line-breaking
                   (cnb:compose-after-line-breaking
                     (cnb:compose-after-line-breaking '() (tag 'a))
                     (tag 'b))
                   (tag 'c))))
   (chained 'dummy-grob)
   (cnb:assert-equal "three-deep chain fires a, b, c in order"
     (reverse calls) '(a b c)))

%% The grob argument reaches every callback in the chain.
#(let* ((seen '())
        (existing (lambda (g) (set! seen (cons g seen))))
        (new-cb   (lambda (g) (set! seen (cons g seen))))
        (composed (cnb:compose-after-line-breaking existing new-cb)))
   (composed 'the-grob)
   (cnb:assert-equal "grob argument passed to both callbacks"
     seen '(the-grob the-grob)))


%% =========================================================================
%%  TEST: cnb/path-geometry.ly — Winding detection and path manipulation
%% =========================================================================

#(cnb:test-group "path-geometry.ly — cnb:path-vertices")

%% path-vertices returns dotted pairs: (x . y)
%% A simple triangle: (0,0) → (1,0) → (0.5,1) → close
#(let ((verts (cnb:path-vertices
                '((moveto 0 0) (lineto 1 0) (lineto 0.5 1) (closepath)))))
   (cnb:assert-equal "triangle has 3 vertices" (length verts) 3)
   (cnb:assert-equal "first vertex"  (list-ref verts 0) '(0 . 0))
   (cnb:assert-equal "second vertex" (list-ref verts 1) '(1 . 0))
   (cnb:assert-equal "third vertex"  (list-ref verts 2) '(0.5 . 1)))

%% Curveto: only the endpoint (last 2 args) is extracted
#(let ((verts (cnb:path-vertices
                '((moveto 0 0) (curveto 1 2 3 4 5 6) (closepath)))))
   (cnb:assert-equal "curveto endpoint" (list-ref verts 1) '(5 . 6)))


#(cnb:test-group "path-geometry.ly — cnb:signed-area")

%% signed-area takes dotted pairs: ((x . y) ...)
%% Convention in this implementation: positive = CW, negative = CCW
%% (matches winding-direction which maps >0 → 'cw, <0 → 'ccw)

%% CCW triangle (0,0) → (1,0) → (0,1): area should be NEGATIVE
#(cnb:assert-true "CCW triangle has negative signed area"
   (< (cnb:signed-area '((0 . 0) (1 . 0) (0 . 1))) 0))

%% CW triangle (0,0) → (0,1) → (1,0): area should be POSITIVE
#(cnb:assert-true "CW triangle has positive signed area"
   (> (cnb:signed-area '((0 . 0) (0 . 1) (1 . 0))) 0))

%% Degenerate (collinear points): area should be 0
#(cnb:assert-near "collinear points have zero area"
   (cnb:signed-area '((0 . 0) (1 . 1) (2 . 2))) 0.0 0.001)


#(cnb:test-group "path-geometry.ly — cnb:winding-direction")

%% CCW path
#(cnb:assert-equal "CCW triangle → 'ccw"
   (cnb:winding-direction '((moveto 0 0) (lineto 1 0) (lineto 0 1) (closepath)))
   'ccw)

%% CW path
#(cnb:assert-equal "CW triangle → 'cw"
   (cnb:winding-direction '((moveto 0 0) (lineto 0 1) (lineto 1 0) (closepath)))
   'cw)


#(cnb:test-group "path-geometry.ly — cnb:reverse-path")

%% Reversing a CW path should produce a CCW path
#(let* ((cw-path  '((moveto 0 0) (lineto 0 1) (lineto 1 0) (closepath)))
        (reversed (cnb:reverse-path cw-path))
        (orig-dir (cnb:winding-direction cw-path))
        (rev-dir  (cnb:winding-direction reversed)))
   (cnb:assert-equal "original is CW"  orig-dir 'cw)
   (cnb:assert-equal "reversed is CCW" rev-dir  'ccw))

%% Reversing twice should give the same winding direction
#(let* ((path     '((moveto 0 0) (lineto 1 0) (lineto 0 1) (closepath)))
        (rev1     (cnb:reverse-path path))
        (rev2     (cnb:reverse-path rev1))
        (orig-dir (cnb:winding-direction path))
        (rev2-dir (cnb:winding-direction rev2)))
   (cnb:assert-equal "double-reverse preserves winding" rev2-dir orig-dir))


#(cnb:test-group "path-geometry.ly — cnb:ensure-opposite-winding")

%% Two CCW paths: hollow should be reversed to CW
#(let* ((shape  '((moveto 0 0) (lineto 2 0) (lineto 0 2) (closepath)))
        (hollow '((moveto 0.2 0.2) (lineto 1 0.2) (lineto 0.2 1) (closepath)))
        (result (cnb:ensure-opposite-winding shape hollow))
        (shape-dir  (cnb:winding-direction shape))
        (result-dir (cnb:winding-direction result)))
   (cnb:assert-equal "shape is CCW"          shape-dir  'ccw)
   (cnb:assert-equal "result hollow is CW"   result-dir 'cw))

%% Already opposite: hollow should be returned unchanged (same direction)
#(let* ((shape  '((moveto 0 0) (lineto 2 0) (lineto 0 2) (closepath)))    ;; CCW
        (hollow '((moveto 0.2 0.2) (lineto 0.2 1) (lineto 1 0.2) (closepath))) ;; CW
        (result (cnb:ensure-opposite-winding shape hollow))
        (result-dir (cnb:winding-direction result)))
   (cnb:assert-equal "already-opposite stays CW" result-dir 'cw))


%% =========================================================================
%%  TEST: cnb/ledgers.ly — Ledger candidate generation and proximity rule
%% =========================================================================

#(cnb:test-group "ledgers.ly — cnb:auto-generate-ledger-candidates")

%% Standard 5-line staff: lines at -4, -2, 0, 2, 4 (spacing = 2)
#(let ((candidates (cnb:auto-generate-ledger-candidates '(-4 -2 0 2 4))))
   ;; Should generate positions at spacing 2, above 4 and below -4
   (cnb:assert-true "has candidates above staff"
     (member 6 candidates))
   (cnb:assert-true "has candidates below staff"
     (member -6 candidates))
   ;; Should NOT include staff line positions
   (cnb:assert-false "does not include staff line 0"
     (member 0 candidates))
   (cnb:assert-false "does not include staff line 4"
     (member 4 candidates))
   (cnb:assert-false "does not include staff line -2"
     (member -2 candidates))
   ;; Should include several ledger positions
   (cnb:assert-true "includes 8"  (member 8 candidates))
   (cnb:assert-true "includes 10" (member 10 candidates))
   (cnb:assert-true "includes -8" (member -8 candidates)))

%% Kite staff: lines at -6, -4, -2, 2, 4, 6 (spacing = 2)
#(let ((candidates (cnb:auto-generate-ledger-candidates '(-6 -4 -2 2 4 6))))
   (cnb:assert-true "Kite: includes 8"   (member 8 candidates))
   (cnb:assert-true "Kite: includes -8"  (member -8 candidates))
   ;; Center gap: auto-generate only extends ABOVE top and BELOW bottom
   ;; staff lines. Position 0 (inside the gap) is NOT auto-generated.
   ;; If needed, add it via cnb:ledger-positions in the config.
   (cnb:assert-false "Kite: 0 is NOT auto-generated (internal gap)"
     (member 0 candidates)))

%% Edge case: fewer than 2 staff lines
#(cnb:assert-equal "single staff line → no candidates"
   (cnb:auto-generate-ledger-candidates '(0)) '())
#(cnb:assert-equal "empty staff → no candidates"
   (cnb:auto-generate-ledger-candidates '()) '())


#(cnb:test-group "ledgers.ly — cnb:proximity-rule")

%% Reset the resolved cache so our tests use fresh data
#(set! cnb:resolved-ledger-candidates #f)

%% Staff lines at -4, -2, 0, 2, 4
%% Candidates generated: ..., -8, -6, 6, 8, 10, ...
#(let* ((staff  '(-4 -2 0 2 4))
        (cands  (cnb:auto-generate-ledger-candidates staff)))

   ;; Note WITHIN the staff (position 1): no ledgers
   (cnb:assert-equal "note at 1 (within staff) → no ledgers"
     (cnb:proximity-rule staff 1 cands) '())

   ;; Note ON a staff line (position 2): no ledgers
   (cnb:assert-equal "note at 2 (on staff line) → no ledgers"
     (cnb:proximity-rule staff 2 cands) '())

   ;; Note at position 5 (first space above staff): no ledgers
   ;; (no candidates between 4 and 5)
   (cnb:assert-equal "note at 5 (just above staff) → no ledgers"
     (cnb:proximity-rule staff 5 cands) '())

   ;; Note at position 6 (first ledger above): should show ledger at 6
   (cnb:assert-equal "note at 6 → ledger at 6"
     (cnb:proximity-rule staff 6 cands) '(6))

   ;; Note at position 8: should show ledgers at 6 and 8
   (let ((result (cnb:proximity-rule staff 8 cands)))
     (cnb:assert-true  "note at 8: includes 6" (member 6 result))
     (cnb:assert-true  "note at 8: includes 8" (member 8 result))
     (cnb:assert-equal "note at 8: exactly 2 ledgers" (length result) 2))

   ;; Note below staff at -6: should show ledger at -6
   (cnb:assert-equal "note at -6 → ledger at -6"
     (cnb:proximity-rule staff -6 cands) '(-6))

   ;; Note far below at -10: should show ledgers at -6, -8, -10
   (let ((result (cnb:proximity-rule staff -10 cands)))
     (cnb:assert-true  "note at -10: includes -6"  (member -6 result))
     (cnb:assert-true  "note at -10: includes -8"  (member -8 result))
     (cnb:assert-true  "note at -10: includes -10" (member -10 result))
     (cnb:assert-equal "note at -10: exactly 3 ledgers" (length result) 3))
)

#(cnb:test-group "ledgers.ly — cnb:proximity-rule with overrides")

#(set! cnb:ledger-overrides '((10 . (6 8))))
#(let* ((staff '(-4 -2 0 2 4))
        (cands (cnb:auto-generate-ledger-candidates staff)))
   ;; With override: note at 10 should use the override, not the rule
   (cnb:assert-equal "override at position 10"
     (cnb:proximity-rule staff 10 cands) '(6 8))
   ;; Other positions should still use the rule
   (cnb:assert-equal "no override at position 6"
     (cnb:proximity-rule staff 6 cands) '(6)))
#(set! cnb:ledger-overrides '()) %% reset


%% =========================================================================
%%  TEST: cnb/off-key.ly — Key pitch class detection
%% =========================================================================

#(cnb:test-group "procedure.ly — cnb:step-to-semitone")
#(cnb:assert-equal "C (step 0) → semitone 0"  (vector-ref cnb:step-to-semitone 0) 0)
#(cnb:assert-equal "D (step 1) → semitone 2"  (vector-ref cnb:step-to-semitone 1) 2)
#(cnb:assert-equal "E (step 2) → semitone 4"  (vector-ref cnb:step-to-semitone 2) 4)
#(cnb:assert-equal "F (step 3) → semitone 5"  (vector-ref cnb:step-to-semitone 3) 5)
#(cnb:assert-equal "G (step 4) → semitone 7"  (vector-ref cnb:step-to-semitone 4) 7)
#(cnb:assert-equal "A (step 5) → semitone 9"  (vector-ref cnb:step-to-semitone 5) 9)
#(cnb:assert-equal "B (step 6) → semitone 11" (vector-ref cnb:step-to-semitone 6) 11)


#(cnb:test-group "procedure.ly — cnb:get-key-pitch-classes")

%% C major: no alterations → {0, 2, 4, 5, 7, 9, 11}
#(let ((pcs (cnb:get-key-pitch-classes '())))
   (cnb:assert-equal "C major pitch classes"
     (sort pcs <) '(0 2 4 5 7 9 11)))

%% G major: F# → {0, 2, 4, 6, 7, 9, 11}
%% keyAlterations: ((3 . 1/2)) means step 3 (F) is raised by 1/2
#(let ((pcs (cnb:get-key-pitch-classes '((3 . 1/2)))))
   (cnb:assert-true  "G major: F# (6) is in key" (memv 6 pcs))
   (cnb:assert-false "G major: F (5) is NOT in key" (memv 5 pcs))
   (cnb:assert-equal "G major has 7 pitch classes" (length pcs) 7))

%% D major: F#, C# → {0, 2, 4, 6, 7, 9, 1} → sorted: {0, 1, 2, 4, 6, 7, 9}
#(let ((pcs (cnb:get-key-pitch-classes '((3 . 1/2) (0 . 1/2)))))
   (cnb:assert-true  "D major: C# (1) is in key" (memv 1 pcs))
   (cnb:assert-true  "D major: F# (6) is in key" (memv 6 pcs))
   (cnb:assert-false "D major: C (0) is NOT in key" (memv 0 pcs))
   (cnb:assert-false "D major: F (5) is NOT in key" (memv 5 pcs)))

%% F major: Bb → {0, 2, 4, 5, 7, 9, 10}
#(let ((pcs (cnb:get-key-pitch-classes '((6 . -1/2)))))
   (cnb:assert-true  "F major: Bb (10) is in key"  (memv 10 pcs))
   (cnb:assert-false "F major: B (11) is NOT in key" (memv 11 pcs)))

%% Bb major: Bb, Eb → {0, 2, 3, 5, 7, 9, 10}
#(let ((pcs (cnb:get-key-pitch-classes '((6 . -1/2) (2 . -1/2)))))
   (cnb:assert-true  "Bb major: Bb (10) is in key" (memv 10 pcs))
   (cnb:assert-true  "Bb major: Eb (3) is in key"  (memv 3 pcs))
   (cnb:assert-false "Bb major: E (4) is NOT in key" (memv 4 pcs))
   (cnb:assert-false "Bb major: B (11) is NOT in key" (memv 11 pcs)))

%% Each letter takes its pitch class from its own alteration, so the
%% entries' order does not matter and double sharps and flats are read
%% correctly (session 31). Before, D# major gave (2 2 3 7 7 8 10).
#(define cnb:test-dis-major-alts
   '((3 . 1) (0 . 1) (4 . 1/2) (1 . 1/2) (5 . 1/2) (2 . 1/2) (6 . 1/2)))
#(define cnb:test-cis-major-alts
   '((3 . 1/2) (0 . 1/2) (4 . 1/2) (1 . 1/2) (5 . 1/2) (2 . 1/2) (6 . 1/2)))
#(define cnb:test-ces-major-alts
   '((6 . -1/2) (2 . -1/2) (5 . -1/2) (1 . -1/2) (4 . -1/2) (0 . -1/2) (3 . -1/2)))

#(cnb:assert-equal "D# major (F and C double sharp) pitch classes"
   (sort (cnb:get-key-pitch-classes cnb:test-dis-major-alts) <)
   '(0 2 3 5 7 8 10))
#(cnb:assert-equal "D# major pitch classes, entries reversed"
   (sort (cnb:get-key-pitch-classes (reverse cnb:test-dis-major-alts)) <)
   '(0 2 3 5 7 8 10))
#(cnb:assert-equal "Fb major (B double flat) pitch classes"
   (sort (cnb:get-key-pitch-classes
           '((6 . -1) (2 . -1/2) (5 . -1/2) (1 . -1/2) (4 . -1/2) (0 . -1/2) (3 . -1/2)))
         <)
   '(1 3 4 6 8 9 11))
#(cnb:assert-equal "C# major pitch classes"
   (sort (cnb:get-key-pitch-classes cnb:test-cis-major-alts) <)
   '(0 1 3 5 6 8 10))
#(cnb:assert-equal "C# major pitch classes, entries reversed"
   (sort (cnb:get-key-pitch-classes (reverse cnb:test-cis-major-alts)) <)
   '(0 1 3 5 6 8 10))
#(cnb:assert-equal "Cb major pitch classes"
   (sort (cnb:get-key-pitch-classes cnb:test-ces-major-alts) <)
   '(1 3 4 6 8 10 11))
#(cnb:assert-equal "Cb major pitch classes, entries reversed"
   (sort (cnb:get-key-pitch-classes (reverse cnb:test-ces-major-alts)) <)
   '(1 3 4 6 8 10 11))
#(cnb:assert-equal "G major in ((octave . step) . alteration) form"
   (sort (cnb:get-key-pitch-classes '(((0 . 3) . 1/2))) <)
   '(0 2 4 6 7 9 11))


%% =========================================================================
%%  TEST: cnb/utils.ly — Path transformation functions
%% =========================================================================

#(cnb:test-group "utils.ly — cnb:rotate-path")

%% rotate-path takes nested paths: ((moveto x y) (lineto x y) ...)
%% Rotating (1, 0) by 90 degrees should give approximately (0, 1)
#(let* ((path '((moveto 1 0)))
        (rotated (cnb:rotate-path path 90))
        (cmd (car rotated))
        (x (cadr cmd))
        (y (caddr cmd)))
   (cnb:assert-near "rotate (1,0) by 90°: x ≈ 0" x 0.0 0.001)
   (cnb:assert-near "rotate (1,0) by 90°: y ≈ 1" y 1.0 0.001))

%% Rotating by 180 degrees: (1, 0) → (-1, 0)
#(let* ((path '((moveto 1 0)))
        (rotated (cnb:rotate-path path 180))
        (cmd (car rotated))
        (x (cadr cmd))
        (y (caddr cmd)))
   (cnb:assert-near "rotate (1,0) by 180°: x ≈ -1" x -1.0 0.001)
   (cnb:assert-near "rotate (1,0) by 180°: y ≈ 0"  y  0.0 0.001))

#(cnb:test-group "utils.ly — cnb:scale-path")

#(let* ((path '((moveto 2 3) (lineto 4 5)))
        (scaled (cnb:scale-path path 2 3))
        (cmd1 (first scaled))
        (cmd2 (second scaled)))
   (cnb:assert-near "scale (2,3) by (2x,3x) → x=4"
     (cadr cmd1) 4.0 0.001)
   (cnb:assert-near "scale (2,3) by (2x,3x) → y=9"
     (caddr cmd1) 9.0 0.001)
   (cnb:assert-near "scale (4,5) by (2x,3x) → x=8"
     (cadr cmd2) 8.0 0.001)
   (cnb:assert-near "scale (4,5) by (2x,3x) → y=15"
     (caddr cmd2) 15.0 0.001))


%% =========================================================================
%%  TEST: Config defaults — sanity checks
%% =========================================================================

#(cnb:test-group "config.ly — Default values sanity")

#(cnb:assert-true "semitones-per-staff-space > 0"
   (> cnb:semitones-per-staff-space 0))
#(cnb:assert-true "staff-line-positions is a list"
   (list? cnb:staff-line-positions))
#(cnb:assert-true "staff-line-positions has at least 2 entries"
   (>= (length cnb:staff-line-positions) 2))
#(cnb:assert-true "default-magnify > 0"
   (> cnb:default-magnify 0))
#(cnb:assert-equal "false-hollow defaults to #f"
   cnb:false-hollow #f)
#(cnb:assert-equal "ledger-positions defaults to empty"
   cnb:ledger-positions '())
#(cnb:assert-true "cnb:get-pitch-staff-position is defined"
   (defined? 'cnb:get-pitch-staff-position))
#(cnb:assert-equal "cnb:get-pitch-staff-position defaults to #f (linear formula)"
   cnb:get-pitch-staff-position #f)


%% =========================================================================
%%  TEST: cnb/utils.ly — cnb:in? and cnb:all helpers
%% =========================================================================

#(cnb:test-group "utils.ly — cnb:in? (list)")
#(cnb:assert-true  "0 is in '(0 2 4 5 7 9 11)"
   (cnb:in? 0 '(0 2 4 5 7 9 11)))
#(cnb:assert-true  "7 is in '(0 2 4 5 7 9 11)"
   (cnb:in? 7 '(0 2 4 5 7 9 11)))
#(cnb:assert-false "1 is NOT in '(0 2 4 5 7 9 11)"
   (cnb:in? 1 '(0 2 4 5 7 9 11)))
#(cnb:assert-false "6 is NOT in '(0 2 4 5 7 9 11)"
   (cnb:in? 6 '(0 2 4 5 7 9 11)))
#(cnb:assert-true  "element in single-element list"
   (cnb:in? 5 '(5)))
#(cnb:assert-false "element not in empty list"
   (cnb:in? 5 '()))

#(cnb:test-group "utils.ly — cnb:in? (vector)")
#(cnb:assert-true  "0 is in #(0 3 6 9)"
   (cnb:in? 0 #(0 3 6 9)))
#(cnb:assert-true  "9 is in #(0 3 6 9)"
   (cnb:in? 9 #(0 3 6 9)))
#(cnb:assert-false "1 is NOT in #(0 3 6 9)"
   (cnb:in? 1 #(0 3 6 9)))
#(cnb:assert-false "element not in empty vector"
   (cnb:in? 5 #()))

#(cnb:test-group "utils.ly — cnb:all")
#(cnb:assert-true  "all returns #t for 0"     (cnb:all 0))
#(cnb:assert-true  "all returns #t for 11"    (cnb:all 11))
#(cnb:assert-true  "all returns #t for #f"    (cnb:all #f))
#(cnb:assert-true  "all returns #t for list"  (cnb:all '(0 2 4)))
#(cnb:assert-true  "all returns #t for string" (cnb:all "anything"))


%% =========================================================================
%%  TEST: cnb/procedure.ly — Registration and lookup
%% =========================================================================

#(cnb:test-group "procedure.ly — path registration")

%% Register test paths
#(define cnb:test-shape-path '((moveto 0 1) (lineto 1 0) (lineto -1 0) (closepath)))
#(define cnb:test-hollow-path '((moveto 0 0.5) (lineto 0.5 0) (lineto -0.5 0) (closepath)))
#(cnb:register-path! 'test-triangle cnb:test-shape-path)
#(cnb:register-hollow! 'test-triangle-cutout cnb:test-hollow-path)

#(cnb:assert-equal "registered path is retrievable"
   (hashq-ref cnb:path-defs 'test-triangle)
   cnb:test-shape-path)

#(cnb:assert-equal "registered hollow is retrievable"
   (hashq-ref cnb:hollow-defs 'test-triangle-cutout)
   cnb:test-hollow-path)

#(cnb:assert-equal "unregistered path returns #f"
   (hashq-ref cnb:path-defs 'nonexistent)
   #f)

#(cnb:test-group "procedure.ly — attachment registration")

#(define cnb:test-attach
   (list
     (cons 'crotchet-up   '(0 . 1))
     (cons 'crotchet-down '(0 . -1))
     (cons 'minim-up      '(-0.5 . 1))
     (cons 'minim-down    '(0.5 . -1))))
#(cnb:register-attachment! 'test-top cnb:test-attach)

#(cnb:assert-equal "registered attachment is retrievable"
   (hashq-ref cnb:attachment-defs 'test-top)
   cnb:test-attach)

#(cnb:assert-equal "attachment crotchet-up is correct"
   (assq-ref (hashq-ref cnb:attachment-defs 'test-top) 'crotchet-up)
   '(0 . 1))


%% =========================================================================
%%  TEST: cnb/procedure.ly — Config resolver
%% =========================================================================

#(cnb:test-group "procedure.ly — cnb:resolve-config")

%% Resolve a config that uses our registered test definitions
#(let* ((config '((shape . test-triangle)
                  (color . "#FF0000")
                  (hollow . test-triangle-cutout)
                  (attachment . test-top)
                  (off-key-mark . #f)))
        (resolved (cnb:resolve-config config)))

   (cnb:assert-equal "resolved shape is actual path data"
     (assq-ref resolved 'shape)
     cnb:test-shape-path)

   (cnb:assert-equal "resolved color passes through"
     (assq-ref resolved 'color)
     "#FF0000")

   (cnb:assert-equal "resolved hollow is actual path data"
     (assq-ref resolved 'hollow)
     cnb:test-hollow-path)

   (cnb:assert-equal "resolved attachment is actual alist"
     (assq-ref resolved 'attachment)
     cnb:test-attach)

   (cnb:assert-equal "resolved off-key-mark #f passes through"
     (assq-ref resolved 'off-key-mark)
     #f))

%% Resolve a config with solid (no hollow)
#(let* ((config '((shape . test-triangle)
                  (color . "#00FF00")
                  (hollow . #f)
                  (attachment . test-top)
                  (off-key-mark . #f)))
        (resolved (cnb:resolve-config config)))

   (cnb:assert-equal "solid hollow resolves to #f"
     (assq-ref resolved 'hollow)
     #f))

%% Resolve a config with built-in off-key-mark symbol
#(let* ((config '((shape . test-triangle)
                  (color . "#0000FF")
                  (hollow . #f)
                  (attachment . test-top)
                  (off-key-mark . dot)))
        (resolved (cnb:resolve-config config)))

   ;; 'dot is not registered in cnb:off-key-mark-defs, so it passes
   ;; through as a symbol — the engraver handles built-in symbols directly
   (cnb:assert-equal "built-in off-key-mark passes through as symbol"
     (assq-ref resolved 'off-key-mark)
     'dot))

%% x-offset: the optional horizontal-offset field (backlog 6.2, set 008)
#(let* ((config '((shape . test-triangle)
                  (color . "#FF0000")
                  (hollow . #f)
                  (attachment . test-top)
                  (off-key-mark . #f)
                  (x-offset . 0.85)))
        (resolved (cnb:resolve-config config)))
   (cnb:assert-equal "x-offset passes through when present"
     (assq-ref resolved 'x-offset)
     0.85))

#(let* ((config '((shape . test-triangle)
                  (color . "#00FF00")
                  (hollow . #f)
                  (attachment . test-top)
                  (off-key-mark . #f)))
        (resolved (cnb:resolve-config config)))
   (cnb:assert-equal "x-offset defaults to 0 when absent"
     (assq-ref resolved 'x-offset)
     0))

%% A present non-number x-offset warns (expected in the log) and is
%% normalized to 0 so a misconfigured field cannot move a notehead.
#(let* ((config '((shape . test-triangle)
                  (color . "#0000FF")
                  (hollow . #f)
                  (attachment . test-top)
                  (off-key-mark . #f)
                  (x-offset . "0.85")))
        (resolved (cnb:resolve-config config)))
   (cnb:assert-equal "non-number x-offset falls back to 0"
     (assq-ref resolved 'x-offset)
     0))


%% =========================================================================
%%  TEST: cnb/procedure.ly — Default procedure
%% =========================================================================

#(cnb:test-group "procedure.ly — default cnb:get-notehead-config")

%% Save the current procedure (might be overridden by a notation config)
%% and test with the default
#(let* ((config (cnb:get-notehead-config 0 2 '(0 2 4 5 7 9 11))))

   (cnb:assert-true "default config returns an alist"
     (list? config))

   (cnb:assert-true "default config has 'shape key"
     (if (assq 'shape config) #t #f))

   (cnb:assert-true "default config has 'color key"
     (if (assq 'color config) #t #f))

   (cnb:assert-true "default config has 'hollow key"
     (if (assq 'hollow config) #t #f))

   (cnb:assert-true "default config has 'attachment key"
     (if (assq 'attachment config) #t #f))

   (cnb:assert-true "default config has 'off-key-mark key"
     (if (assq 'off-key-mark config) #t #f))

   (cnb:assert-true "default config has 'repeat key"
     (if (assq 'repeat config) #t #f)))


%% =========================================================================
%%  TEST: cnb/procedure.ly — Cache build and lookup
%% =========================================================================

#(cnb:test-group "procedure.ly — cnb:build-config-cache + cnb:lookup-config")

%% Set up a known test procedure
#(define cnb:saved-get-notehead-config cnb:get-notehead-config)

#(set! cnb:get-notehead-config
   (lambda (semitone duration key)
     (cond
       ;; In-key notes: test-triangle, red
       ((cnb:in? semitone key)
        `((shape      . test-triangle)
          (color      . "#FF0000")
          (hollow     . #f)
          (attachment . test-top)
          (off-key-mark . #f)))
       ;; Out-of-key notes: test-triangle, gray, with dot
       (else
        `((shape      . test-triangle)
          (color      . "#999999")
          (hollow     . #f)
          (attachment . test-top)
          (off-key-mark . dot))))))

%% Build cache for C major
#(cnb:build-config-cache '(0 2 4 5 7 9 11))

%% Test in-key lookup (C = pitch class 0, quarter note = dur 3)
#(let ((config (cnb:lookup-config 0 3)))
   (cnb:assert-true "cache hit for C quarter"
     (list? config))
   (cnb:assert-equal "C quarter color is red (in-key)"
     (assq-ref config 'color)
     "#FF0000")
   (cnb:assert-equal "C quarter shape resolved to path data"
     (assq-ref config 'shape)
     cnb:test-shape-path)
   (cnb:assert-equal "C quarter off-key-mark is #f (in-key)"
     (assq-ref config 'off-key-mark)
     #f))

%% Test out-of-key lookup (C# = pitch class 1)
#(let ((config (cnb:lookup-config 1 3)))
   (cnb:assert-equal "C# quarter color is gray (out-of-key)"
     (assq-ref config 'color)
     "#999999")
   (cnb:assert-equal "C# quarter off-key-mark is 'dot"
     (assq-ref config 'off-key-mark)
     'dot))

%% Test all pitch classes are cached (12 × 4 = 48 entries)
#(cnb:assert-true "all 48 cache entries exist"
   (let loop ((semitone 0) (all-found #t))
     (if (>= semitone 12)
         all-found
         (loop (+ semitone 1)
               (and all-found
                    (cnb:lookup-config semitone 0)
                    (cnb:lookup-config semitone 1)
                    (cnb:lookup-config semitone 2)
                    (cnb:lookup-config semitone 3))))))

%% Test cache key tracking
#(cnb:assert-equal "current cache key is C major"
   cnb:current-cache-key
   '(0 2 4 5 7 9 11))

%% Test cnb:ensure-cache-for-key — same key should not rebuild
#(let ((old-cache cnb:config-cache))
   (cnb:ensure-cache-for-key '(0 2 4 5 7 9 11))
   (cnb:assert-true "same key does not rebuild cache"
     (eq? old-cache cnb:config-cache)))

%% Test cnb:ensure-cache-for-key — different key should rebuild
#(cnb:ensure-cache-for-key '(0 2 4 6 7 9 11))  %% G major (F#)
#(cnb:assert-equal "cache key updated to G major"
   cnb:current-cache-key
   '(0 2 4 6 7 9 11))

%% In G major, F# (pc 6) is in-key, F (pc 5) is out-of-key
#(let ((config-f-sharp (cnb:lookup-config 6 2))
       (config-f       (cnb:lookup-config 5 2)))
   (cnb:assert-equal "F# is red in G major (in-key)"
     (assq-ref config-f-sharp 'color)
     "#FF0000")
   (cnb:assert-equal "F is gray in G major (out-of-key)"
     (assq-ref config-f 'color)
     "#999999"))

%% Restore original procedure
#(set! cnb:get-notehead-config cnb:saved-get-notehead-config)


%% =========================================================================
%%  TEST: cnb/procedure.ly — cnb:config-field convenience
%% =========================================================================

#(cnb:test-group "procedure.ly — cnb:config-field")

#(let ((config '((shape . some-data)
                 (color . "#ABCDEF")
                 (hollow . #f)
                 (attachment . some-attach)
                 (off-key-mark . #f))))
   (cnb:assert-equal "config-field extracts color"
     (cnb:config-field config 'color) "#ABCDEF")
   (cnb:assert-equal "config-field extracts shape"
     (cnb:config-field config 'shape) 'some-data)
   (cnb:assert-equal "config-field returns #f for hollow"
     (cnb:config-field config 'hollow) #f)
   (cnb:assert-equal "config-field returns #f for missing key"
     (cnb:config-field config 'nonexistent) #f))


%% =========================================================================
%%  TEST: cnb/procedure.ly — Named color registration and resolution
%% =========================================================================

#(cnb:test-group "procedure.ly — cnb:register-color! and lookup")

#(cnb:register-color! 'test-red "#FF0000")
#(cnb:register-color! 'test-blue "#0000FF")

#(cnb:assert-equal "registered color is retrievable"
   (hashq-ref cnb:color-defs 'test-red)
   "#FF0000")

#(cnb:assert-equal "second registered color is retrievable"
   (hashq-ref cnb:color-defs 'test-blue)
   "#0000FF")

#(cnb:assert-equal "unregistered color returns #f"
   (hashq-ref cnb:color-defs 'nonexistent-color)
   #f)

%% Re-register to test override behavior (score file pattern)
#(cnb:register-color! 'test-red "#00FF00")
#(cnb:assert-equal "re-registered color overwrites previous"
   (hashq-ref cnb:color-defs 'test-red)
   "#00FF00")

%% Restore for subsequent tests
#(cnb:register-color! 'test-red "#FF0000")


#(cnb:test-group "procedure.ly — resolver handles color symbols")

#(let* ((config '((shape . test-triangle)
                  (color . test-red)
                  (hollow . #f)
                  (attachment . test-top)
                  (off-key-mark . #f)))
        (resolved (cnb:resolve-config config)))

   (cnb:assert-equal "color symbol resolved to hex string"
     (assq-ref resolved 'color)
     "#FF0000"))


#(cnb:test-group "procedure.ly — resolver handles direct hex strings")

#(let* ((config '((shape . test-triangle)
                  (color . "#ABCDEF")
                  (hollow . #f)
                  (attachment . test-top)
                  (off-key-mark . #f)))
        (resolved (cnb:resolve-config config)))

   (cnb:assert-equal "direct hex string passes through"
     (assq-ref resolved 'color)
     "#ABCDEF"))


#(cnb:test-group "procedure.ly — resolver handles integer palette indices (legacy)")

%% Ensure palette has known values for this test
#(set! cnb:color-palette (vector "#111111" "#222222" "#333333"))

#(let* ((config `((shape . test-triangle)
                  (color . 0)
                  (hollow . #f)
                  (attachment . test-top)
                  (off-key-mark . #f)))
        (resolved (cnb:resolve-config config)))

   (cnb:assert-equal "integer 0 resolves to first palette entry"
     (assq-ref resolved 'color)
     "#111111"))

#(let* ((config `((shape . test-triangle)
                  (color . 2)
                  (hollow . #f)
                  (attachment . test-top)
                  (off-key-mark . #f)))
        (resolved (cnb:resolve-config config)))

   (cnb:assert-equal "integer 2 resolves to third palette entry"
     (assq-ref resolved 'color)
     "#333333"))

%% Restore default palette
#(set! cnb:color-palette (vector cnb:black))


#(cnb:test-group "procedure.ly — resolver fallback for unregistered color")

%% This will produce a warning — that's expected
#(let* ((config '((shape . test-triangle)
                  (color . totally-unknown-color)
                  (hollow . #f)
                  (attachment . test-top)
                  (off-key-mark . #f)))
        (resolved (cnb:resolve-config config)))

   (cnb:assert-equal "unregistered color symbol falls back to black"
     (assq-ref resolved 'color)
     "#000000"))


%% =========================================================================
%%  TEST: cnb/config.ly — cnb:use-accessible-colors default
%% =========================================================================

#(cnb:test-group "config.ly — cnb:use-accessible-colors")

#(cnb:assert-equal "cnb:use-accessible-colors defaults to #f"
   cnb:use-accessible-colors
   #f)

#(cnb:assert-true "cnb:use-accessible-colors is defined"
   (defined? 'cnb:use-accessible-colors))


%% =========================================================================
%%  TEST: cnb/procedure.ly — Accessible color conditional registration
%%
%%  The Configurator generates an (if ...) block that registers primary
%%  or CB-safe colors based on cnb:use-accessible-colors. Verify that
%%  cnb:register-color! works correctly inside (begin ...) within (if ...).
%% =========================================================================

#(cnb:test-group "procedure.ly — accessible color conditional registration")

%% Test with flag = #f (primary palette)
#(set! cnb:use-accessible-colors #f)

#(if (and (defined? 'cnb:use-accessible-colors) cnb:use-accessible-colors)
   (begin
     (cnb:register-color! 'test-acc-green "#009f81")
     (cnb:register-color! 'test-acc-orange "#ff6e3a"))
   (begin
     (cnb:register-color! 'test-acc-green "#1b9e77")
     (cnb:register-color! 'test-acc-orange "#d95f02")))

#(cnb:assert-equal "primary mode: test-acc-green resolves to primary hex"
   (hashq-ref cnb:color-defs 'test-acc-green)
   "#1b9e77")

#(cnb:assert-equal "primary mode: test-acc-orange resolves to primary hex"
   (hashq-ref cnb:color-defs 'test-acc-orange)
   "#d95f02")


%% Test with flag = #t (accessible palette)
#(set! cnb:use-accessible-colors #t)

#(if (and (defined? 'cnb:use-accessible-colors) cnb:use-accessible-colors)
   (begin
     (cnb:register-color! 'test-acc-green "#009f81")
     (cnb:register-color! 'test-acc-orange "#ff6e3a"))
   (begin
     (cnb:register-color! 'test-acc-green "#1b9e77")
     (cnb:register-color! 'test-acc-orange "#d95f02")))

#(cnb:assert-equal "accessible mode: test-acc-green resolves to CB-safe hex"
   (hashq-ref cnb:color-defs 'test-acc-green)
   "#009f81")

#(cnb:assert-equal "accessible mode: test-acc-orange resolves to CB-safe hex"
   (hashq-ref cnb:color-defs 'test-acc-orange)
   "#ff6e3a")


%% Verify resolver picks up the accessible-mode registration
#(let* ((config '((shape . test-triangle)
                  (color . test-acc-green)
                  (hollow . #f)
                  (attachment . test-top)
                  (off-key-mark . #f)))
        (resolved (cnb:resolve-config config)))

   (cnb:assert-equal "resolver uses accessible color from conditional registration"
     (assq-ref resolved 'color)
     "#009f81"))

%% Reset the flag to default
#(set! cnb:use-accessible-colors #f)


%% =========================================================================
%%  TEST: cnb/procedure.ly — repeat field in default procedure
%% =========================================================================

#(cnb:test-group "procedure.ly — repeat field in default procedure")

#(let* ((config (cnb:get-notehead-config 0 3 '(0 2 4 5 7 9 11))))

   (cnb:assert-true "default config has 'repeat key"
     (if (assq 'repeat config) #t #f))

   (cnb:assert-equal "default config repeat is #t"
     (assq-ref config 'repeat)
     #t))


%% =========================================================================
%%  TEST: cnb/procedure.ly — resolver handles repeat field
%% =========================================================================

#(cnb:test-group "procedure.ly — resolver repeat field handling")

%% Explicit repeat = #t
#(let* ((config '((shape . test-triangle)
                  (color . "#FF0000")
                  (hollow . #f)
                  (attachment . test-top)
                  (off-key-mark . #f)
                  (repeat . #t)))
        (resolved (cnb:resolve-config config)))

   (cnb:assert-equal "explicit repeat #t passes through"
     (assq-ref resolved 'repeat)
     #t))

%% Explicit repeat = #f
#(let* ((config '((shape . test-triangle)
                  (color . "#FF0000")
                  (hollow . #f)
                  (attachment . test-top)
                  (off-key-mark . #f)
                  (repeat . #f)))
        (resolved (cnb:resolve-config config)))

   (cnb:assert-equal "explicit repeat #f passes through"
     (assq-ref resolved 'repeat)
     #f))

%% Absent repeat field — should default to #t
#(let* ((config '((shape . test-triangle)
                  (color . "#FF0000")
                  (hollow . #f)
                  (attachment . test-top)
                  (off-key-mark . #f)))
        (resolved (cnb:resolve-config config)))

   (cnb:assert-equal "absent repeat defaults to #t"
     (assq-ref resolved 'repeat)
     #t))


%% =========================================================================
%%  TEST: cnb/procedure.ly — repeat field in config cache
%% =========================================================================

#(cnb:test-group "procedure.ly — repeat field in config cache")

%% Override procedure to return repeat = #f for half notes
#(define cnb:saved-get-notehead-config cnb:get-notehead-config)

#(set! cnb:get-notehead-config
   (lambda (semitone duration key)
     (if (= duration 2)
         ;; Half note: distinct shape, no repeat
         `((shape      . test-triangle)
           (color      . "#FF0000")
           (hollow     . #f)
           (attachment . test-top)
           (off-key-mark . #f)
           (repeat     . #f))
         ;; Other durations: standard shape, repeat
         `((shape      . test-triangle)
           (color      . "#FF0000")
           (hollow     . #f)
           (attachment . test-top)
           (off-key-mark . #f)
           (repeat     . #t)))))

#(cnb:build-config-cache '(0 2 4 5 7 9 11))

#(let ((quarter-config (cnb:lookup-config 0 3))
       (half-config    (cnb:lookup-config 0 2))
       (whole-config   (cnb:lookup-config 0 1)))

   (cnb:assert-equal "cached quarter note has repeat = #t"
     (assq-ref quarter-config 'repeat)
     #t)

   (cnb:assert-equal "cached half note has repeat = #f"
     (assq-ref half-config 'repeat)
     #f)

   (cnb:assert-equal "cached whole note has repeat = #t"
     (assq-ref whole-config 'repeat)
     #t))

%% Restore the default procedure
#(set! cnb:get-notehead-config cnb:saved-get-notehead-config)


%% =========================================================================
%%  TEST: cnb/clefs.ly — Dozenal clef number calculation
%% =========================================================================

#(cnb:test-group "clefs.ly — cnb:dozenal-clef")

%% Standard clef mappings (middleCPosition, ottava 0) per the module header
#(cnb:assert-equal "treble (mcp -6) → 50"   (cnb:dozenal-clef -6 0) 50)
#(cnb:assert-equal "soprano (mcp -4) → 46"  (cnb:dozenal-clef -4 0) 46)
#(cnb:assert-equal "mezzo (mcp -2) → 46"    (cnb:dozenal-clef -2 0) 46)
#(cnb:assert-equal "alto (mcp 0) → 40"      (cnb:dozenal-clef 0 0)  40)
#(cnb:assert-equal "tenor (mcp 2) → 36"     (cnb:dozenal-clef 2 0)  36)
#(cnb:assert-equal "baritone (mcp 4) → 36"  (cnb:dozenal-clef 4 0)  36)
#(cnb:assert-equal "bass (mcp 6) → 30"      (cnb:dozenal-clef 6 0)  30)

%% Ottava offsets shift the register (pinning current arithmetic)
#(cnb:assert-equal "treble + offset 3 → 56"  (cnb:dozenal-clef -6 3) 56)
#(cnb:assert-equal "treble + offset -3 → 46" (cnb:dozenal-clef -6 -3) 46)
#(cnb:assert-equal "bass + offset -3 → 26"   (cnb:dozenal-clef 6 -3) 26)


%% =========================================================================
%%  TEST: cnb/config.ly — Clef display setting defaults (set 005)
%% =========================================================================

#(cnb:test-group "config.ly — clef setting defaults")

#(cnb:assert-true "cnb:clef-style is defined"
   (defined? 'cnb:clef-style))
#(cnb:assert-equal "cnb:clef-style defaults to 'dozenal"
   cnb:clef-style 'dozenal)
#(cnb:assert-true "cnb:clef-text is defined"
   (defined? 'cnb:clef-text))
#(cnb:assert-equal "cnb:clef-text defaults to empty string"
   cnb:clef-text "")
#(cnb:assert-true "cnb:clef-size-semitones is defined"
   (defined? 'cnb:clef-size-semitones))
#(cnb:assert-equal "cnb:clef-size-semitones defaults to #f"
   cnb:clef-size-semitones #f)


%% =========================================================================
%%  TEST: cnb/clefs.ly — Style resolution
%% =========================================================================

#(cnb:test-group "clefs.ly — cnb:clef-resolved-style")

#(cnb:assert-equal "default resolves to 'dozenal"
   (cnb:clef-resolved-style) 'dozenal)

#(set! cnb:clef-style 'text)
#(cnb:assert-equal "'text resolves to 'text"
   (cnb:clef-resolved-style) 'text)

#(set! cnb:clef-style 'none)
#(cnb:assert-equal "'none resolves to 'none"
   (cnb:clef-resolved-style) 'none)

%% This will produce a warning — that's expected
#(set! cnb:clef-style 'bogus-style)
#(cnb:assert-equal "unrecognized value falls back to 'dozenal"
   (cnb:clef-resolved-style) 'dozenal)

#(set! cnb:clef-style 'dozenal) %% reset


%% =========================================================================
%%  TEST: cnb/clefs.ly — Semitone-denominated size math
%% =========================================================================

#(cnb:test-group "clefs.ly — cnb:clef-target-height (default #f = 3 staff-spaces)")

%% Save config state
#(define cnb:saved-clef-size cnb:clef-size-semitones)
#(define cnb:saved-sps cnb:semitones-per-staff-space)

%% Default (#f): 3 staff-spaces regardless of semitones-per-staff-space
#(set! cnb:clef-size-semitones #f)
#(set! cnb:semitones-per-staff-space 1)
#(cnb:assert-equal "sps-1: default height is 3 staff-spaces"
   (cnb:clef-target-height 1) 3)
#(set! cnb:semitones-per-staff-space 2)
#(cnb:assert-equal "sps-2: default height is 3 staff-spaces"
   (cnb:clef-target-height 1) 3)
#(set! cnb:semitones-per-staff-space 3)
#(cnb:assert-equal "sps-3: default height is 3 staff-spaces"
   (cnb:clef-target-height 1) 3)
#(cnb:assert-equal "default height scales with font magnification"
   (cnb:clef-target-height 2) 6)

#(cnb:test-group "clefs.ly — cnb:clef-target-height (explicit semitone size)")

%% Explicit size N: N semitones = N/sps staff-spaces, so the same N
%% yields different staff-space heights on different staff designs
#(set! cnb:clef-size-semitones 6)
#(set! cnb:semitones-per-staff-space 1)
#(cnb:assert-equal "6 semitones at sps-1 = 6 staff-spaces"
   (cnb:clef-target-height 1) 6)
#(set! cnb:semitones-per-staff-space 2)
#(cnb:assert-equal "6 semitones at sps-2 = 3 staff-spaces"
   (cnb:clef-target-height 1) 3)
#(set! cnb:semitones-per-staff-space 3)
#(cnb:assert-equal "6 semitones at sps-3 = 2 staff-spaces"
   (cnb:clef-target-height 1) 2)

%% On the Kite sps-3 staff, 9 semitones reproduces the legacy height
#(set! cnb:clef-size-semitones 9)
#(cnb:assert-equal "9 semitones at sps-3 = legacy 3 staff-spaces"
   (cnb:clef-target-height 1) 3)

%% Fractional staff-space results and magnification interaction
#(set! cnb:clef-size-semitones 3)
#(set! cnb:semitones-per-staff-space 2)
#(cnb:assert-equal "3 semitones at sps-2 = 3/2 staff-spaces"
   (cnb:clef-target-height 1) 3/2)
#(cnb:assert-equal "explicit size scales with font magnification"
   (cnb:clef-target-height 2) 3)

%% Restore config state
#(set! cnb:clef-size-semitones cnb:saved-clef-size)
#(set! cnb:semitones-per-staff-space cnb:saved-sps)


%% =========================================================================
%%  TEST: cnb/config.ly — Custom clef setting defaults (set 005 s2)
%% =========================================================================

#(cnb:test-group "config.ly — custom clef setting defaults")

#(cnb:assert-true "cnb:clef-name is defined"
   (defined? 'cnb:clef-name))
#(cnb:assert-equal "cnb:clef-name defaults to #f"
   cnb:clef-name #f)
#(cnb:assert-true "cnb:clef-gutter-semitones is defined"
   (defined? 'cnb:clef-gutter-semitones))
#(cnb:assert-equal "cnb:clef-gutter-semitones defaults to #f"
   cnb:clef-gutter-semitones #f)
#(cnb:assert-true "cnb:clef-gutter-left-semitones is defined"
   (defined? 'cnb:clef-gutter-left-semitones))
#(cnb:assert-equal "cnb:clef-gutter-left-semitones defaults to #f"
   cnb:clef-gutter-left-semitones #f)
#(cnb:assert-true "cnb:clef-anchor-semitones is defined"
   (defined? 'cnb:clef-anchor-semitones))
#(cnb:assert-equal "cnb:clef-anchor-semitones defaults to #f (fixed placement)"
   cnb:clef-anchor-semitones #f)


%% =========================================================================
%%  TEST: cnb/clefs.ly — Custom clef registration and lookup
%% =========================================================================

#(cnb:test-group "clefs.ly — cnb:register-clef! / cnb:clef-lookup")

%% A 1-wide × 2-tall rectangle in the notehead path command format.
#(define cnb:test-clef-path
   '((moveto 0 0) (lineto 1 0) (lineto 1 2) (lineto 0 2) (closepath)))

#(cnb:assert-false "lookup of an unregistered name returns #f"
   (cnb:clef-lookup 'never-registered))
#(cnb:assert-false "lookup of a non-symbol (#f) returns #f"
   (cnb:clef-lookup #f))

#(cnb:register-clef! 'ut-clef
   (list (cons 'path cnb:test-clef-path)
         (cons 'anchor-semitones 4)))
#(cnb:assert-true "minimal valid def (path + anchor) registers"
   (cnb:clef-lookup 'ut-clef))
#(cnb:assert-equal "registered anchor is readable from the def"
   (assq-ref (cnb:clef-lookup 'ut-clef) 'anchor-semitones) 4)

%% The 009-pinned contract: anchorSemi is a FLOAT (fractional anchors
%% express interior-feature registration — Bravura/Clairnote designs)
#(cnb:register-clef! 'ut-clef-float
   (list (cons 'path cnb:test-clef-path)
         (cons 'anchor-semitones 22.784)))
#(cnb:assert-near "FLOAT anchor-semitones is accepted and preserved"
   (assq-ref (cnb:clef-lookup 'ut-clef-float) 'anchor-semitones)
   22.784 0.0001)

%% Re-registration under the same name replaces the definition
#(cnb:register-clef! 'ut-clef
   (list (cons 'path cnb:test-clef-path)
         (cons 'anchor-semitones 7)
         (cons 'height-semitones 5.5)))
#(cnb:assert-equal "re-registration replaces the stored anchor"
   (assq-ref (cnb:clef-lookup 'ut-clef) 'anchor-semitones) 7)
#(cnb:assert-equal "fractional height-semitones is accepted"
   (assq-ref (cnb:clef-lookup 'ut-clef) 'height-semitones) 5.5)

%% Invalid definitions warn and are NOT registered
#(cnb:register-clef! 'ut-bad-bare-list (list 'name cnb:test-clef-path))
#(cnb:assert-false "a bare non-alist list is rejected"
   (cnb:clef-lookup 'ut-bad-bare-list))
#(cnb:register-clef! 'ut-bad-no-anchor
   (list (cons 'path cnb:test-clef-path)))
#(cnb:assert-false "a def without anchor-semitones is rejected"
   (cnb:clef-lookup 'ut-bad-no-anchor))
#(cnb:register-clef! 'ut-bad-no-path
   (list (cons 'anchor-semitones 4)))
#(cnb:assert-false "a def without a path is rejected"
   (cnb:clef-lookup 'ut-bad-no-path))
#(cnb:register-clef! 'ut-bad-height
   (list (cons 'path cnb:test-clef-path)
         (cons 'anchor-semitones 4)
         (cons 'height-semitones 0)))
#(cnb:assert-false "a def with a non-positive height is rejected"
   (cnb:clef-lookup 'ut-bad-height))


%% =========================================================================
%%  TEST: cnb/clefs.ly — Style resolution with 'custom
%% =========================================================================

#(cnb:test-group "clefs.ly — cnb:clef-effective-style ('custom)")

#(define cnb:saved-clef-style cnb:clef-style)
#(define cnb:saved-clef-name cnb:clef-name)

#(set! cnb:clef-style 'custom)
#(cnb:assert-equal "'custom is a recognized cnb:clef-style value"
   (cnb:clef-resolved-style) 'custom)

%% Unregistered name → warn and degrade to 'dozenal (never an empty slot)
#(set! cnb:clef-name 'no-such-clef)
#(cnb:assert-equal "'custom with an unregistered name degrades to 'dozenal"
   (cnb:clef-effective-style) 'dozenal)

#(set! cnb:clef-name #f)
#(cnb:assert-equal "'custom with cnb:clef-name #f degrades to 'dozenal"
   (cnb:clef-effective-style) 'dozenal)

#(set! cnb:clef-name 'ut-clef)
#(cnb:assert-equal "'custom with a registered name is effective"
   (cnb:clef-effective-style) 'custom)

#(set! cnb:clef-style 'dozenal)
#(cnb:assert-equal "non-custom styles ignore cnb:clef-name"
   (cnb:clef-effective-style) 'dozenal)

#(set! cnb:clef-style cnb:saved-clef-style)
#(set! cnb:clef-name cnb:saved-clef-name)


%% =========================================================================
%%  TEST: cnb/clefs.ly — Anchor placement math (set-009 contract)
%% =========================================================================

#(cnb:test-group "clefs.ly — cnb:clef-anchor-y-offset (fractional anchors, per-sps)")

%% The formula is the notehead engraver's own position formula
%% (cnb/noteheads.ly): (anchor + 2*middleCPosition) / sps staff-spaces.
#(set! cnb:semitones-per-staff-space 1)
#(cnb:assert-equal "sps-1: anchor 5.5, mcp 0 → 5.5 staff-spaces"
   (cnb:clef-anchor-y-offset 5.5 0) 5.5)
#(set! cnb:semitones-per-staff-space 2)
#(cnb:assert-equal "sps-2: anchor 5.5, mcp 0 → 2.75 staff-spaces"
   (cnb:clef-anchor-y-offset 5.5 0) 2.75)
#(cnb:assert-equal "sps-2: anchor 0 (middle C), treble mcp -6 → -6 staff-spaces"
   (cnb:clef-anchor-y-offset 0 -6) -6)
#(cnb:assert-equal "sps-2: anchor 16 on treble = top staff line (+2 staff-spaces)"
   (cnb:clef-anchor-y-offset 16 -6) 2)
#(set! cnb:semitones-per-staff-space 3)
#(cnb:assert-near "sps-3: fractional anchor 22.784, mcp 0 → 22.784/3"
   (cnb:clef-anchor-y-offset 22.784 0) 7.594667 0.0001)
#(cnb:assert-equal "sps-3: anchor 6, mcp 2 → 10/3 staff-spaces"
   (cnb:clef-anchor-y-offset 6 2) 10/3)
#(set! cnb:semitones-per-staff-space cnb:saved-sps)


%% =========================================================================
%%  TEST: cnb/clefs.ly — Anchor placement through the pitch-axis hook
%%  (set 008, backlog 6.4 / E13-4)
%%
%%  With cnb:get-pitch-staff-position set, the anchor maps through the
%%  hook (half-staff-spaces, × 0.5 = staff-spaces), used as-is — NOT
%%  adjusted by middleCPosition. Fractional anchors interpolate between
%%  the hook positions of their neighboring INTEGER semitones; the hook
%%  itself is never called with a fraction (its input contract).
%% =========================================================================

#(cnb:test-group "clefs.ly — cnb:clef-anchor-y-offset (pitch-axis hook)")

%% The 013 spike's compact axis: pc → position [0 0 1 2 2 3 3 4 5 5 6 6],
%% octave stride 7, anchor baked in (middle C, semitone 0 → position −4).
#(define (cnb:ut-spike-axis semitone)
   (let* ((pc  (modulo semitone 12))
          (oct (/ (- semitone pc) 12))
          (pos (+ (vector-ref #(0 0 1 2 2 3 3 4 5 5 6 6) pc)
                  (* oct 7))))
     (- pos 4)))

#(set! cnb:get-pitch-staff-position cnb:ut-spike-axis)

#(cnb:assert-equal "integer anchor 0 (middle C) → hook position −4 → −2 staff-spaces"
   (cnb:clef-anchor-y-offset 0 0) -2.0)
#(cnb:assert-equal "hook path ignores middleCPosition (anchor 0: mcp −6 = mcp 0)"
   (cnb:clef-anchor-y-offset 0 -6) (cnb:clef-anchor-y-offset 0 0))
#(cnb:assert-equal "fractional anchor 2.5 interpolates distinct neighbors (−3, −2) → −1.25"
   (cnb:clef-anchor-y-offset 2.5 0) -1.25)
#(cnb:assert-equal "fractional anchor 0.5 between collapsed semitones (C, C♯ → −4) stays put"
   (cnb:clef-anchor-y-offset 0.5 0) -2.0)
#(cnb:assert-near "negative fractional anchor −0.25: euclidean neighbors (−5, −4) → −2.125"
   (cnb:clef-anchor-y-offset -0.25 0) -2.125 0.000001)

%% Degeneracy: on a LINEAR hook the interpolation is exact — this is the
%% sps-2 linear value (anchor 5.5, mcp 0 → 2.75) reproduced through the
%% hook path (pos = semi ≡ sps 2, octave anchor at middle C).
#(set! cnb:get-pitch-staff-position (lambda (s) s))
#(cnb:assert-near "linear hook: fractional anchor 5.5 → 2.75 (interpolation exact)"
   (cnb:clef-anchor-y-offset 5.5 0) 2.75 0.000001)

#(set! cnb:get-pitch-staff-position #f)


%% =========================================================================
%%  TEST: cnb/clefs.ly — Custom size precedence and gutter math
%% =========================================================================

#(cnb:test-group "clefs.ly — cnb:clef-custom-target-semitones (precedence)")

#(define cnb:ut-def-with-height
   (list (cons 'path cnb:test-clef-path)
         (cons 'anchor-semitones 4)
         (cons 'height-semitones 4)))
#(define cnb:ut-def-no-height
   (list (cons 'path cnb:test-clef-path)
         (cons 'anchor-semitones 4)))

%% Recorded set-005 decision: explicit cnb:clef-size-semitones wins
%% over the definition's own height-semitones; with neither, #f = the
%% path renders at its native coordinate scale.
#(set! cnb:clef-size-semitones 6)
#(cnb:assert-equal "explicit cnb:clef-size-semitones overrides def height"
   (cnb:clef-custom-target-semitones cnb:ut-def-with-height) 6)
#(cnb:assert-equal "explicit size also applies to a def without height"
   (cnb:clef-custom-target-semitones cnb:ut-def-no-height) 6)
#(set! cnb:clef-size-semitones #f)
#(cnb:assert-equal "size #f defers to the def's height-semitones"
   (cnb:clef-custom-target-semitones cnb:ut-def-with-height) 4)
#(cnb:assert-equal "size #f + no def height → #f (native path scale)"
   (cnb:clef-custom-target-semitones cnb:ut-def-no-height) #f)

#(cnb:test-group "clefs.ly — cnb:clef-gutter-pad")

#(define cnb:saved-gutter cnb:clef-gutter-semitones)

#(cnb:assert-equal "default #f → no gutter padding"
   (cnb:clef-gutter-pad 1) 0)
#(set! cnb:clef-gutter-semitones 3)
#(set! cnb:semitones-per-staff-space 2)
#(cnb:assert-equal "3 semitones at sps-2 = 3/2 staff-spaces"
   (cnb:clef-gutter-pad 1) 3/2)
#(set! cnb:semitones-per-staff-space 3)
#(cnb:assert-equal "3 semitones at sps-3 = 1 staff-space"
   (cnb:clef-gutter-pad 1) 1)
#(set! cnb:semitones-per-staff-space 1)
#(cnb:assert-equal "2 semitones at sps-1 = 2 staff-spaces"
   (begin (set! cnb:clef-gutter-semitones 2) (cnb:clef-gutter-pad 1)) 2)
#(set! cnb:semitones-per-staff-space 2)
#(set! cnb:clef-gutter-semitones 3)
#(cnb:assert-equal "gutter padding scales with font magnification"
   (cnb:clef-gutter-pad 2) 3)
#(set! cnb:clef-gutter-semitones cnb:saved-gutter)
#(set! cnb:semitones-per-staff-space cnb:saved-sps)

#(cnb:test-group "clefs.ly — cnb:clef-gutter-left-pad")

#(cnb:assert-equal "default #f → no padding before the clef"
   (cnb:clef-gutter-left-pad 1) 0)
#(set! cnb:clef-gutter-left-semitones 3)
#(set! cnb:semitones-per-staff-space 2)
#(cnb:assert-equal "3 semitones at sps-2 = 3/2 staff-spaces"
   (cnb:clef-gutter-left-pad 1) 3/2)
#(set! cnb:semitones-per-staff-space 3)
#(cnb:assert-equal "3 semitones at sps-3 = 1 staff-space"
   (cnb:clef-gutter-left-pad 1) 1)
#(cnb:assert-equal "padding before the clef scales with font magnification"
   (cnb:clef-gutter-left-pad 2) 2)
#(cnb:assert-equal "the right-hand gutter is independent of it"
   (cnb:clef-gutter-pad 1) 0)
#(set! cnb:clef-gutter-left-semitones #f)
#(set! cnb:semitones-per-staff-space cnb:saved-sps)


%% =========================================================================
%%  TEST: cnb/clefs.ly — Custom clef stencil geometry
%%  (make-path-stencil needs no grob, so the real builder is testable)
%% =========================================================================

#(cnb:test-group "clefs.ly — cnb:build-custom-clef-stencil (top edge at y=0)")

%% Test path is a 1×2 rectangle (y 0..2), so heights are exact.
#(set! cnb:semitones-per-staff-space 2)
#(set! cnb:clef-size-semitones #f)

%% height-semitones 4 at sps-2 = 2 staff-spaces tall
#(define cnb:ut-stencil-a
   (cnb:build-custom-clef-stencil cnb:ut-def-with-height 1))
#(cnb:assert-near "anchor contract: scaled glyph TOP edge sits at y = 0"
   (cdr (ly:stencil-extent cnb:ut-stencil-a 1)) 0 0.001)
#(cnb:assert-near "def height 4 at sps-2 renders 2 staff-spaces tall"
   (- (cdr (ly:stencil-extent cnb:ut-stencil-a 1))
      (car (ly:stencil-extent cnb:ut-stencil-a 1)))
   2 0.001)
#(cnb:assert-near "uniform scale: 1×2 path at height 2 renders 1 wide"
   (- (cdr (ly:stencil-extent cnb:ut-stencil-a 0))
      (car (ly:stencil-extent cnb:ut-stencil-a 0)))
   1 0.001)

%% Explicit cnb:clef-size-semitones overrides the def height in the
%% actual stencil, not just the pure helper
#(set! cnb:clef-size-semitones 8)
#(define cnb:ut-stencil-b
   (cnb:build-custom-clef-stencil cnb:ut-def-with-height 1))
#(cnb:assert-near "explicit 8 semitones at sps-2 renders 4 staff-spaces tall"
   (- (cdr (ly:stencil-extent cnb:ut-stencil-b 1))
      (car (ly:stencil-extent cnb:ut-stencil-b 1)))
   4 0.001)
#(set! cnb:clef-size-semitones #f)

%% No height anywhere: native path scale (1 path unit = 1 staff-space)
#(define cnb:ut-stencil-c
   (cnb:build-custom-clef-stencil cnb:ut-def-no-height 1))
#(cnb:assert-near "native scale: the 2-unit-tall path renders 2 staff-spaces"
   (- (cdr (ly:stencil-extent cnb:ut-stencil-c 1))
      (car (ly:stencil-extent cnb:ut-stencil-c 1)))
   2 0.001)
#(cnb:assert-near "native scale keeps the top edge at y = 0 too"
   (cdr (ly:stencil-extent cnb:ut-stencil-c 1)) 0 0.001)

%% Magnification scales the stencil like the dozenal/text builders
#(define cnb:ut-stencil-d
   (cnb:build-custom-clef-stencil cnb:ut-def-with-height 2))
#(cnb:assert-near "font magnification 2 doubles the rendered height"
   (- (cdr (ly:stencil-extent cnb:ut-stencil-d 1))
      (car (ly:stencil-extent cnb:ut-stencil-d 1)))
   4 0.001)

#(cnb:test-group "clefs.ly — cnb:clef-text-place ('text label placement)")

%% Placed with the 1×2 rectangle standing in for a scaled label
%% (y 0..2): the legacy translate, or its top edge at y = 0 when
%% cnb:clef-anchor-semitones is set.
#(define cnb:ut-label
   (make-path-stencil (cnb:flatten-path cnb:test-clef-path) 0.0001 1 1 #t))
#(cnb:assert-near "anchor #f: the legacy -.5 × mag translate (top at 2 − 1)"
   (cdr (ly:stencil-extent (cnb:clef-text-place cnb:ut-label 2) 1)) 1 0.001)
#(set! cnb:clef-anchor-semitones 15.5)
#(cnb:assert-near "anchor set: the label's TOP edge sits at y = 0"
   (cdr (ly:stencil-extent (cnb:clef-text-place cnb:ut-label 2) 1)) 0 0.001)
#(cnb:assert-near "anchor set: the label keeps its height"
   (car (ly:stencil-extent (cnb:clef-text-place cnb:ut-label 2) 1)) -2 0.001)
#(set! cnb:clef-anchor-semitones #f)

#(cnb:test-group "clefs.ly — cnb:clef-apply-gutter")

#(set! cnb:clef-gutter-semitones 3)
#(define cnb:ut-stencil-g (cnb:clef-apply-gutter cnb:ut-stencil-a 1))
#(cnb:assert-near "gutter 3 at sps-2 widens the right X-extent by 3/2"
   (cdr (ly:stencil-extent cnb:ut-stencil-g 0))
   (+ (cdr (ly:stencil-extent cnb:ut-stencil-a 0)) 3/2) 0.001)
#(cnb:assert-near "gutter padding leaves the Y-extent alone"
   (cdr (ly:stencil-extent cnb:ut-stencil-g 1))
   (cdr (ly:stencil-extent cnb:ut-stencil-a 1)) 0.001)
#(set! cnb:clef-gutter-semitones #f)
#(cnb:assert-near "gutter #f leaves the X-extent alone"
   (cdr (ly:stencil-extent (cnb:clef-apply-gutter cnb:ut-stencil-a 1) 0))
   (cdr (ly:stencil-extent cnb:ut-stencil-a 0)) 0.001)

%% Padding before the clef: the X-extent keeps its left edge and grows
%% by both pads, and the ink moves right by the left pad.
#(set! cnb:clef-gutter-semitones 3)
#(set! cnb:clef-gutter-left-semitones 2)
#(define cnb:ut-stencil-l (cnb:clef-apply-gutter cnb:ut-stencil-a 1))
#(cnb:assert-near "left gutter keeps the X-extent's left edge"
   (car (ly:stencil-extent cnb:ut-stencil-l 0))
   (car (ly:stencil-extent cnb:ut-stencil-a 0)) 0.001)
#(cnb:assert-near "left 2 + right 3 at sps-2 widen the X-extent by 5/2"
   (cdr (ly:stencil-extent cnb:ut-stencil-l 0))
   (+ (cdr (ly:stencil-extent cnb:ut-stencil-a 0)) 5/2) 0.001)
#(cnb:assert-true "the ink moves right by the left pad (1 staff-space)"
   (equal? (ly:stencil-expr cnb:ut-stencil-l)
           (ly:stencil-expr (ly:stencil-translate-axis cnb:ut-stencil-a 1 X))))
#(set! cnb:clef-gutter-semitones #f)
#(set! cnb:clef-gutter-left-semitones #f)

%% Restore config state
#(set! cnb:clef-gutter-semitones cnb:saved-gutter)
#(set! cnb:clef-size-semitones cnb:saved-clef-size)
#(set! cnb:semitones-per-staff-space cnb:saved-sps)


%% =========================================================================
%%  TEST: cnb/config.ly — Key signature setting defaults (set 006 s1)
%%
%%  Backward-compatibility invariant: every new key-signature setting
%%  defaults to today's behavior, so the golden baseline is byte-stable.
%% =========================================================================

#(cnb:test-group "config.ly — keysig setting defaults")

#(cnb:assert-true "cnb:keysig-style is defined"
   (defined? 'cnb:keysig-style))
#(cnb:assert-equal "cnb:keysig-style defaults to 'chord"
   cnb:keysig-style 'chord)
#(cnb:assert-true "cnb:keysig-bar-color is defined"
   (defined? 'cnb:keysig-bar-color))
#(cnb:assert-equal "cnb:keysig-bar-color defaults to cnb:gold"
   cnb:keysig-bar-color cnb:gold)
#(cnb:assert-true "cnb:keysig-bar-thickness is defined"
   (defined? 'cnb:keysig-bar-thickness))
#(cnb:assert-equal "cnb:keysig-bar-thickness defaults to 4 (today's hard-coded value)"
   cnb:keysig-bar-thickness 4)
#(cnb:assert-true "cnb:keysig-bar-extent-semis is defined"
   (defined? 'cnb:keysig-bar-extent-semis))
#(cnb:assert-equal "cnb:keysig-bar-extent-semis defaults to 12 (±1 octave)"
   cnb:keysig-bar-extent-semis 12)
#(cnb:assert-true "cnb:keysig-tonic-octave is defined"
   (defined? 'cnb:keysig-tonic-octave))
#(cnb:assert-equal "cnb:keysig-tonic-octave defaults to #f (derive from middleCPosition)"
   cnb:keysig-tonic-octave #f)


%% =========================================================================
%%  TEST: cnb/keysig.ly — Style resolution
%% =========================================================================

#(cnb:test-group "keysig.ly — cnb:keysig-resolved-style")

#(define cnb:saved-keysig-style cnb:keysig-style)

#(cnb:assert-equal "default resolves to 'chord"
   (cnb:keysig-resolved-style) 'chord)
#(set! cnb:keysig-style 'none)
#(cnb:assert-equal "'none resolves to 'none"
   (cnb:keysig-resolved-style) 'none)
#(set! cnb:keysig-style 'chord)
#(cnb:assert-equal "'chord resolves to 'chord"
   (cnb:keysig-resolved-style) 'chord)
%% This will produce a warning — that's expected
#(set! cnb:keysig-style 'bogus-style)
#(cnb:assert-equal "unrecognized value falls back to 'chord"
   (cnb:keysig-resolved-style) 'chord)
#(set! cnb:keysig-style 'marks)
#(cnb:assert-equal "'marks resolves to 'marks"
   (cnb:keysig-resolved-style) 'marks)
#(set! cnb:keysig-style cnb:saved-keysig-style)


%% =========================================================================
%%  TEST: cnb/keysig.ly — The mark table's keys (session 30)
%%
%%  cnb:keysig-marks-key files a key under its tonic's spelling and its
%%  sorted pitch classes; cnb:keysig-marks-entry looks it up.
%% =========================================================================

#(cnb:test-group "keysig.ly — cnb:keysig-marks-key and cnb:keysig-marks-entry")

#(cnb:assert-equal "cnb:keysig-marks defaults to '()"
   cnb:keysig-marks '())

#(define cnb:test-fis-alts
   '((3 . 1/2) (0 . 1/2) (4 . 1/2) (1 . 1/2) (5 . 1/2) (2 . 1/2)))
#(define cnb:test-ges-alts
   '((6 . -1/2) (2 . -1/2) (5 . -1/2) (1 . -1/2) (4 . -1/2) (0 . -1/2)))
#(define cnb:test-c-major-key
   (cnb:keysig-marks-key (ly:make-pitch 0 0 0) '()))
#(define cnb:test-a-minor-key
   (cnb:keysig-marks-key (ly:make-pitch 0 5 0) '()))
#(define cnb:test-fis-major-key
   (cnb:keysig-marks-key (ly:make-pitch 0 3 1/2) cnb:test-fis-alts))
#(define cnb:test-ges-major-key
   (cnb:keysig-marks-key (ly:make-pitch 0 4 -1/2) cnb:test-ges-alts))

#(cnb:assert-equal "C major's key is ((0 . 0) 0 2 4 5 7 9 11)"
   cnb:test-c-major-key '((0 . 0) 0 2 4 5 7 9 11))
#(cnb:assert-equal "C major and A minor share their pitch classes"
   (cdr cnb:test-c-major-key) (cdr cnb:test-a-minor-key))
#(cnb:assert-false "C major and A minor have different keys (their tonics)"
   (equal? cnb:test-c-major-key cnb:test-a-minor-key))
#(cnb:assert-equal "F sharp and G flat major share their pitch classes"
   (cdr cnb:test-fis-major-key) (cdr cnb:test-ges-major-key))
#(cnb:assert-equal "F sharp major's pitch classes are sorted"
   (cdr cnb:test-fis-major-key) '(1 3 5 6 8 10 11))
#(cnb:assert-false "F sharp and G flat major have different keys (their spellings)"
   (equal? cnb:test-fis-major-key cnb:test-ges-major-key))
#(cnb:assert-equal "B flat major's key is ((6 . -1/2) 0 2 3 5 7 9 10)"
   (cnb:keysig-marks-key (ly:make-pitch -1 6 -1/2) '((6 . -1/2) (2 . -1/2)))
   '((6 . -1/2) 0 2 3 5 7 9 10))
#(cnb:assert-equal "D sharp major's key is ((1 . 1/2) 0 2 3 5 7 8 10)"
   (cnb:keysig-marks-key (ly:make-pitch 0 1 1/2) cnb:test-dis-major-alts)
   '((1 . 1/2) 0 2 3 5 7 8 10))

#(define cnb:saved-keysig-marks cnb:keysig-marks)
#(set! cnb:keysig-marks
   `((,cnb:test-c-major-key . ((columns 0.5) (bars) (marks (0 0 sharp))))))
#(cnb:assert-equal "an entry is found for a key in the table"
   (cnb:keysig-marks-entry cnb:test-c-major-key)
   '((columns 0.5) (bars) (marks (0 0 sharp))))
#(cnb:assert-false "no entry for a key the table lacks (A minor)"
   (cnb:keysig-marks-entry cnb:test-a-minor-key))
#(set! cnb:keysig-marks cnb:saved-keysig-marks)


%% =========================================================================
%%  TEST: cnb/keysig.ly — cnb:keysig-marks-stencil (session 30)
%%
%%  The stencil needs a grob, for Emmentaler's glyphs and the ledger
%%  lines' markup, so these assertions run inside a one-note score
%%  typeset in a markup, when an engraver acknowledges its KeySignature
%%  (a grob is only alive then). Treble clef (middleCPosition -6), font
%%  magnification 1.
%% =========================================================================

#(cnb:test-group "keysig.ly — cnb:keysig-marks-stencil")

#(cnb:register-color! 'cnb-test-red "#ff0000")

#(define (cnb:test-keysig-marks grob)
   (let* ((st     (lambda (entry) (cnb:keysig-marks-stencil entry -6 1 grob 'test-key)))
          (head   (lambda (semi column)
                    `(,semi ,column head default-oval #f cnb-test-red)))
          (alone  (cnb:build-stencil-from-config
                    `((shape  . ,(hashq-ref cnb:path-defs 'default-oval))
                      (hollow . #f)
                      (color  . "#ff0000"))))
          (w      (interval-length (ly:stencil-extent alone X)))
          (h      (interval-length (ly:stencil-extent alone Y)))
          (y      (lambda (semi) (cnb:keysig-note-y-offset semi -6 1)))
          (sharp  (ly:font-get-glyph (ly:grob-default-font grob) "accidentals.sharp"))
          (two    (st `((columns 1.0 3.0) (bars)
                        (marks ,(head 12 0)
                               (16 1 head default-oval default-oval-cutout cnb-test-red)))))
          (double (st `((columns 0.5 1.5) (bars) (marks ,(head 12 0) ,(head 12 1)))))
          (bar    (st '((columns 0.5) (bars (1.0 0 24 "#ffd42a" 0.2)) (marks))))
          (low    (st `((columns 1.0) (bars) (marks ,(head -24 0)))))
          (low-sh (st '((columns 1.0) (bars) (marks (-24 0 sharp)))))
          (flat   (st '((columns 1.0) (bars) (marks (12 0 flat)))))
          (bogus  (st '((columns 1.0) (bars) (marks (12 0 head no-such-shape #f cnb-test-red))))))
     (cnb:assert-near "two columns: the first head is centred on x 1.0"
       (car (ly:stencil-extent two X)) (- 1.0 (/ w 2)) 0.0001)
     (cnb:assert-near "two columns: the second head is centred on x 3.0"
       (cdr (ly:stencil-extent two X)) (+ 3.0 (/ w 2)) 0.0001)
     (cnb:assert-near "a double notehead is two heads, a column apart"
       (interval-length (ly:stencil-extent double X)) (+ 1.0 w) 0.0001)
     (cnb:assert-near "a double notehead's heads share one height"
       (interval-length (ly:stencil-extent double Y)) h 0.0001)
     (cnb:assert-near "a bar reaches its bottom semitone (less half its thickness)"
       (car (ly:stencil-extent bar Y)) (- (y 0) 0.1) 0.0001)
     (cnb:assert-near "a bar reaches its top semitone (plus half its thickness)"
       (cdr (ly:stencil-extent bar Y)) (+ (y 24) 0.1) 0.0001)
     (cnb:assert-true "a head below the staff gets ledger lines, wider than the head"
       (> (interval-length (ly:stencil-extent low X)) (+ w 0.0001)))
     (cnb:assert-true "the ledger lines run from the head up towards the staff"
       (> (cdr (ly:stencil-extent low Y)) (+ (y -24) (/ h 2) 0.0001)))
     (cnb:assert-near "a sharp at the same place gets no ledger lines (its glyph's width)"
       (interval-length (ly:stencil-extent low-sh X))
       (interval-length (ly:stencil-extent sharp X)) 0.0001)
     (cnb:assert-near "a sharp is centred on its column"
       (car (ly:stencil-extent low-sh X))
       (- 1.0 (/ (interval-length (ly:stencil-extent sharp X)) 2)) 0.0001)
     (cnb:assert-false "a sharp gives a non-empty stencil"
       (ly:stencil-empty? low-sh))
     (cnb:assert-false "a flat gives a non-empty stencil"
       (ly:stencil-empty? flat))
     ;; This will produce a warning — that's expected
     (cnb:assert-true "an unregistered shape is skipped"
       (ly:stencil-empty? bogus))
     (cnb:test-keysig-sign-scale st y grob 'sharp "accidentals.sharp")
     (cnb:test-keysig-sign-scale st y grob 'flat "accidentals.flat")))

%% A sign's optional scale (session 35): absent or 1 as today; 0.5 half as
%% wide and tall, about its origin at the semitone, still centred on its
%% column; a scale that is not a positive number unscaled, with a warning.
#(define (cnb:test-keysig-sign-scale st y grob sign glyph-name)
   (let* ((sign-at (lambda (scale)
                     (st `((columns 1.0) (bars) (marks (12 0 ,sign ,@scale))))))
          (glyph   (ly:font-get-glyph (ly:grob-default-font grob) glyph-name))
          (gx      (ly:stencil-extent glyph X))
          (gy      (ly:stencil-extent glyph Y))
          (plain   (sign-at '()))
          (one     (sign-at '(1)))
          (half    (sign-at '(0.5)))
          (same?   (lambda (a b)
                     (and (< (abs (- (car (ly:stencil-extent a X)) (car (ly:stencil-extent b X)))) 0.0001)
                          (< (abs (- (cdr (ly:stencil-extent a X)) (cdr (ly:stencil-extent b X)))) 0.0001)
                          (< (abs (- (car (ly:stencil-extent a Y)) (car (ly:stencil-extent b Y)))) 0.0001)
                          (< (abs (- (cdr (ly:stencil-extent a Y)) (cdr (ly:stencil-extent b Y)))) 0.0001)))))
     (cnb:assert-true (format #f "a ~a with scale 1 draws as one with none" sign)
       (same? one plain))
     (cnb:assert-near (format #f "a ~a with no scale is its glyph's height, at the semitone" sign)
       (car (ly:stencil-extent plain Y)) (+ (y 12) (car gy)) 0.0001)
     (cnb:assert-near (format #f "a ~a at scale 0.5 is half as wide" sign)
       (interval-length (ly:stencil-extent half X))
       (* 0.5 (interval-length (ly:stencil-extent plain X))) 0.0001)
     (cnb:assert-near (format #f "a ~a at scale 0.5 is half as tall" sign)
       (interval-length (ly:stencil-extent half Y))
       (* 0.5 (interval-length (ly:stencil-extent plain Y))) 0.0001)
     (cnb:assert-near (format #f "a ~a at scale 0.5: its bottom is half the glyph's below the semitone" sign)
       (car (ly:stencil-extent half Y)) (+ (y 12) (* 0.5 (car gy))) 0.0001)
     (cnb:assert-near (format #f "a ~a at scale 0.5: its top is half the glyph's above the semitone" sign)
       (cdr (ly:stencil-extent half Y)) (+ (y 12) (* 0.5 (cdr gy))) 0.0001)
     (cnb:assert-near (format #f "a ~a at scale 0.5 is still centred on its column" sign)
       (/ (+ (car (ly:stencil-extent half X)) (cdr (ly:stencil-extent half X))) 2)
       1.0 0.0001)
     ;; These will produce warnings — that's expected
     (for-each
       (lambda (bad)
         (cnb:assert-true (format #f "a ~a with scale ~a draws unscaled" sign bad)
           (same? (sign-at (list bad)) plain)))
       '(0 -1 big))))

#(define cnb:test-keysig-grob-proc cnb:test-keysig-marks)
#(define (cnb:test-keysig-grob-engraver context)
   (make-engraver
     (acknowledgers
       ((key-signature-interface engraver grob source-engraver)
        (if cnb:test-keysig-grob-proc
            (let ((proc cnb:test-keysig-grob-proc))
              (set! cnb:test-keysig-grob-proc #f)
              (proc grob)))))))

#(interpret-markup $defaultpaper
   (list (ly:output-def-lookup $defaultpaper 'text-font-defaults))
   #{ \markup \score {
        \new Staff { \key d \major c'1 }
        \layout {
          indent = 0 line-width = 100\mm ragged-right = ##t
          \context { \Staff \consists #cnb:test-keysig-grob-engraver }
        }
      } #})
#(cnb:assert-false "the KeySignature grob was acknowledged (the stencil tests ran)"
   cnb:test-keysig-grob-proc)


%% =========================================================================
%%  TEST: cnb/keysig.ly — cnb:notehead-ledgers by semitone (session 33)
%%
%%  A key-signature head whose engine semitone has an entry in
%%  cnb:ledgers-by-semitone takes exactly that entry's ledgers; any other
%%  head, or a score with no table, keeps the engine's rule. On the
%%  default 4-8 staff (4 semitones per staff space, lines -4 -2 2 4),
%%  treble clef (middleCPosition -6), so semitone 12 is on the middle line;
%%  the table is the default Configurator export's (semitones 0-24).
%% =========================================================================

#(cnb:test-group "keysig.ly — cnb:notehead-ledgers by semitone")

#(cnb:assert-equal "cnb:ledgers-by-semitone defaults to '()"
   cnb:ledgers-by-semitone '())

#(define cnb:saved-ledger-sps cnb:semitones-per-staff-space)
#(define cnb:saved-ledger-lines cnb:staff-line-positions)
#(set! cnb:semitones-per-staff-space 4)
#(set! cnb:staff-line-positions '(-4 -2 2 4))
%% The ledger candidates are cached: resolve them for this staff.
#(set! cnb:resolved-ledger-candidates #f)

%% The head's ledger offsets (rendered, mag-scaled) at MAG.
#(define (cnb:test-ks-ledgers semi mag)
   (cnb:notehead-ledgers semi (cnb:keysig-note-y-offset semi -6 mag) '(-0.5 . 0.5) mag 0))

%% Today's rule for the head, with no table.
#(define (cnb:test-ks-rule semi mag)
   (let ((saved cnb:ledgers-by-semitone))
     (set! cnb:ledgers-by-semitone '())
     (let ((r (cnb:test-ks-ledgers semi mag)))
       (set! cnb:ledgers-by-semitone saved)
       r)))

#(cnb:assert-equal "no table: C (12) gets today's rule"
   (cnb:test-ks-ledgers 12 1)
   (map (lambda (p) (* p 1/2))
        (cnb:proximity-rule '(-4 -2 2 4) 0 (cnb:get-ledger-candidates '(-4 -2 2 4)))))
#(cnb:assert-equal "no table: D (14) gets today's rule"
   (cnb:test-ks-ledgers 14 1)
   (map (lambda (p) (* p 1/2))
        (cnb:proximity-rule '(-4 -2 2 4) 1 (cnb:get-ledger-candidates '(-4 -2 2 4)))))
#(cnb:assert-equal "no table: B (23) gets today's rule"
   (cnb:test-ks-ledgers 23 1)
   (map (lambda (p) (* p 1/2))
        (cnb:proximity-rule '(-4 -2 2 4) 6 (cnb:get-ledger-candidates '(-4 -2 2 4)))))

#(set! cnb:ledgers-by-semitone
   '((0 . (-6)) (1 . (-6)) (2 . (-6 -5)) (3 . ()) (4 . ()) (5 . ())
     (6 . ()) (7 . ()) (8 . ()) (9 . ()) (10 . (-1)) (11 . ())
     (12 . (0)) (13 . (0)) (14 . (0 1)) (15 . ()) (16 . ()) (17 . ())
     (18 . ()) (19 . ()) (20 . ()) (21 . ()) (22 . (5)) (23 . ())
     (24 . (6))))

#(cnb:assert-equal "an entry: D (14) gets exactly (0 1), in half staff spaces"
   (cnb:test-ks-ledgers 14 1) '(0 1/2))
#(cnb:assert-equal "an entry: C (12) gets its in-gap ledger on the middle line"
   (cnb:test-ks-ledgers 12 1) '(0))
#(cnb:assert-equal "an entry scales with the magnification (D at mag 2)"
   (cnb:test-ks-ledgers 14 2) '(0 1))
#(cnb:assert-equal "an empty entry: B (23) gets none"
   (cnb:test-ks-ledgers 23 1) '())
#(cnb:assert-true "an empty entry overrides a ledger today's rule gives B (23)"
   (pair? (cnb:test-ks-rule 23 1)))
#(cnb:assert-equal "no entry: semitone 30 keeps today's rule"
   (cnb:test-ks-ledgers 30 1) (cnb:test-ks-rule 30 1))
#(cnb:assert-true "no entry: semitone 30 has ledgers by today's rule"
   (pair? (cnb:test-ks-ledgers 30 1)))

#(set! cnb:ledgers-by-semitone '())
#(set! cnb:semitones-per-staff-space cnb:saved-ledger-sps)
#(set! cnb:staff-line-positions cnb:saved-ledger-lines)
#(set! cnb:resolved-ledger-candidates #f)


%% =========================================================================
%%  TEST: cnb/keysig.ly — Separator-bar half-extent (semitone-denominated)
%%
%%  The bar spans ±cnb:keysig-bar-extent-semis semitones around the staff
%%  center; the default 12 must reproduce (cnb:spaces-per-octave) — today's
%%  ±1-octave geometry — on ANY staff, because it divides through
%%  cnb:semitones-per-staff-space exactly like note positions do.
%% =========================================================================

#(cnb:test-group "keysig.ly — cnb:keysig-bar-half-extent (default = spaces-per-octave)")

#(define cnb:saved-keysig-sps cnb:semitones-per-staff-space)
#(define cnb:saved-keysig-extent cnb:keysig-bar-extent-semis)

#(set! cnb:keysig-bar-extent-semis 12)
#(set! cnb:semitones-per-staff-space 1)
#(cnb:assert-equal "sps-1: default 12 semis = 12 staff-spaces = spaces-per-octave"
   (cnb:keysig-bar-half-extent) (cnb:spaces-per-octave))
#(cnb:assert-equal "sps-1: default half-extent is 12"
   (cnb:keysig-bar-half-extent) 12)
#(set! cnb:semitones-per-staff-space 2)
#(cnb:assert-equal "sps-2: default 12 semis = 6 staff-spaces = spaces-per-octave"
   (cnb:keysig-bar-half-extent) (cnb:spaces-per-octave))
#(cnb:assert-equal "sps-2: default half-extent is 6"
   (cnb:keysig-bar-half-extent) 6)
#(set! cnb:semitones-per-staff-space 3)
#(cnb:assert-equal "sps-3 (Kite): default 12 semis reproduces spaces-per-octave"
   (cnb:keysig-bar-half-extent) (cnb:spaces-per-octave))
#(cnb:assert-equal "sps-3: default half-extent is 4"
   (cnb:keysig-bar-half-extent) 4)

#(cnb:test-group "keysig.ly — cnb:keysig-bar-half-extent (explicit non-default)")

%% A non-default extent detaches from the ±1-octave geometry
#(set! cnb:keysig-bar-extent-semis 6)
#(set! cnb:semitones-per-staff-space 2)
#(cnb:assert-equal "6 semis at sps-2 = 3 staff-spaces (half the default)"
   (cnb:keysig-bar-half-extent) 3)
#(set! cnb:keysig-bar-extent-semis 24)
#(cnb:assert-equal "24 semis at sps-2 = 12 staff-spaces (±2 octaves)"
   (cnb:keysig-bar-half-extent) 12)

#(set! cnb:keysig-bar-extent-semis cnb:saved-keysig-extent)
#(set! cnb:semitones-per-staff-space cnb:saved-keysig-sps)


%% =========================================================================
%%  TEST: cnb/keysig.ly — Mark placement (linear and pitch-axis hook)
%%  (set 008, backlog 6.3 / E13-3)
%%
%%  cnb:keysig-note-y-offset is the notehead engraver's placement formula
%%  with the font magnification standing in for the staff-space:
%%  linear (semi + 2·mcp) / sps × mag when the hook is #f;
%%  (hook semi) × 0.5 × mag — middleCPosition ignored — when set.
%% =========================================================================

#(cnb:test-group "keysig.ly — cnb:keysig-note-y-offset (linear path)")

#(define cnb:saved-keysig-place-sps cnb:semitones-per-staff-space)
#(set! cnb:semitones-per-staff-space 2)
#(cnb:assert-equal "sps-2: semi 4, treble mcp −6, mag 1 → −4 staff-spaces"
   (cnb:keysig-note-y-offset 4 -6 1) -4)
#(cnb:assert-equal "sps-2: mag scales the result (semi 4, mcp −6, mag 7/4 → −7)"
   (cnb:keysig-note-y-offset 4 -6 7/4) -7)
#(set! cnb:semitones-per-staff-space 3)
#(cnb:assert-equal "sps-3: semi 6, mcp 0, mag 1 → 2 staff-spaces"
   (cnb:keysig-note-y-offset 6 0 1) 2)
#(set! cnb:semitones-per-staff-space cnb:saved-keysig-place-sps)

#(cnb:test-group "keysig.ly — cnb:keysig-note-y-offset (pitch-axis hook)")

#(set! cnb:get-pitch-staff-position cnb:ut-spike-axis)
#(cnb:assert-equal "hook: middle C → position −4 → −2 staff-spaces at mag 1"
   (cnb:keysig-note-y-offset 0 0 1) -2.0)
#(cnb:assert-equal "hook path ignores middleCPosition (mcp −6 = mcp 0)"
   (cnb:keysig-note-y-offset 0 -6 1) (cnb:keysig-note-y-offset 0 0 1))
#(cnb:assert-equal "hook: octave stride and mag (semi 12 → position 3 → 1.5 × mag 2)"
   (cnb:keysig-note-y-offset 12 0 2) 3.0)
#(set! cnb:get-pitch-staff-position #f)


%% =========================================================================
%%  TEST: cnb/keysig.ly — Tonic-octave anchor (item 2.4)
%%
%%  cnb:keysig-pitches computes the 8 key-signature noteheads. The first
%%  pitch is the tonic notehead; its octave is derived from middleCPosition
%%  (middle-C anchoring, today's behavior) when the override is #f, or set
%%  explicitly by an integer override. The explicit form is what closes the
%%  preview/engine placement divergence for non-C tonics.
%% =========================================================================

#(cnb:test-group "keysig.ly — cnb:keysig-pitches tonic octave (derived vs explicit)")

%% C-major-style tonic: C natural at ly:make-pitch octave 0. C-major
%% alterations are empty.
#(define cnb:ut-tonic-c (ly:make-pitch 0 0 0))
%% D tonic (non-C), same octave — exercises the placement divergence.
#(define cnb:ut-tonic-d (ly:make-pitch 0 1 0))

%% Every call returns exactly 8 pitches (two stacked 7th chords).
#(cnb:assert-equal "keysig-pitches returns 8 noteheads"
   (length (cnb:keysig-pitches '() cnb:ut-tonic-c 0 #f)) 8)

%% Derived (#f): the tonic notehead octave tracks middleCPosition.
%% octaves-above-mid-c = floor(-mcp/6), added to the tonic's own octave.
#(cnb:assert-equal "C tonic, derived, mcp 0 → tonic notehead octave 0"
   (ly:pitch-octave (car (cnb:keysig-pitches '() cnb:ut-tonic-c 0 #f))) 0)
#(cnb:assert-equal "C tonic, derived, mcp -6 → tonic notehead octave 1 (mcp shifts it)"
   (ly:pitch-octave (car (cnb:keysig-pitches '() cnb:ut-tonic-c -6 #f))) 1)

%% Explicit integer override: the tonic notehead octave is anchored, and
%% middleCPosition no longer affects it.
#(cnb:assert-equal "C tonic, explicit 2, mcp 0 → tonic notehead octave 2"
   (ly:pitch-octave (car (cnb:keysig-pitches '() cnb:ut-tonic-c 0 2))) 2)
#(cnb:assert-equal "C tonic, explicit 2, mcp -6 → octave 2 (override ignores mcp)"
   (ly:pitch-octave (car (cnb:keysig-pitches '() cnb:ut-tonic-c -6 2))) 2)

%% The override shifts absolute pitch by whole octaves only: the tonic
%% notehead's semitone value moves by 12 per octave of override.
#(cnb:assert-equal "C tonic derived mcp 0 → tonic semitones 0"
   (ly:pitch-semitones (car (cnb:keysig-pitches '() cnb:ut-tonic-c 0 #f))) 0)
#(cnb:assert-equal "C tonic explicit 2 → tonic semitones 24 (two octaves up)"
   (ly:pitch-semitones (car (cnb:keysig-pitches '() cnb:ut-tonic-c 0 2))) 24)

%% Non-C tonic: the placement divergence. Derived anchoring puts the D
%% tonic where middle-C anchoring lands it; an explicit octave moves it to
%% exactly where the Configurator's placement.tonicOctave asks.
#(cnb:assert-equal "D tonic, derived, mcp 0 → tonic notehead octave 0"
   (ly:pitch-octave (car (cnb:keysig-pitches '() cnb:ut-tonic-d 0 #f))) 0)
#(cnb:assert-equal "D tonic, explicit 4 → tonic notehead octave 4 (divergence closed)"
   (ly:pitch-octave (car (cnb:keysig-pitches '() cnb:ut-tonic-d 0 4))) 4)
%% The tonic notehead is still D (step 1) either way — the override moves
%% only the octave, never the interval structure.
#(cnb:assert-equal "D tonic notehead stays step 1 (D) under derived anchoring"
   (ly:pitch-notename (car (cnb:keysig-pitches '() cnb:ut-tonic-d 0 #f))) 1)
#(cnb:assert-equal "D tonic notehead stays step 1 (D) under explicit anchoring"
   (ly:pitch-notename (car (cnb:keysig-pitches '() cnb:ut-tonic-d 0 4))) 1)


%% =========================================================================
%%  TEST: cnb/keysig.ly — cnb:keysig-tonic-octave 'centred (session 24)
%%
%%  The Configurator's CNBKeySignature.tonicSemi rule: the tonic
%%  t = pc + 12k centring [t, t+12] on the staff's centre semitone M,
%%  k = round((M − 6 − pc) / 12), ties going up.
%% =========================================================================

#(cnb:test-group "keysig.ly — cnb:keysig-centre-semitone")

#(cnb:assert-equal "linear, treble (mcp -6) → semitone 12, the default midpoint"
   (cnb:keysig-centre-semitone -6) 12)
#(cnb:assert-equal "linear, mcp 0 → semitone 0 (middle C on the middle line)"
   (cnb:keysig-centre-semitone 0) 0)

%% The Twinline hook of the Configurator's fixture: 12 pcs on 7 axis
%% positions, octave stride 7, middle G (semitone 7) at position 0.
#(define (cnb:ut-twinline-axis semitone)
   (let* ((pc  (modulo semitone 12))
          (oct (/ (- semitone pc) 12))
          (pos (+ (vector-ref #(0 0 1 2 2 3 3 4 5 5 6 6) pc)
                  (* oct 7))))
     (- pos 4)))
#(set! cnb:get-pitch-staff-position cnb:ut-twinline-axis)
#(cnb:assert-equal "Twinline hook → semitone 7 (middle G), whatever the clef"
   (cnb:keysig-centre-semitone -6) 7)
%% The same axis shifted down 3 positions sends the shared pair C and C♯
%% of octave 1 (semitones 12 and 13) both to position 0: the lowest wins.
#(set! cnb:get-pitch-staff-position (lambda (s) (- (cnb:ut-twinline-axis s) 3)))
#(cnb:assert-equal "many-to-one: C and C♯ (12, 13) share position 0 → 12, the lowest"
   (cnb:keysig-centre-semitone 0) 12)
#(set! cnb:get-pitch-staff-position #f)

#(cnb:test-group "keysig.ly — cnb:keysig-centred-octave (the Configurator's rule)")

%% All twelve tonics around the Twinline centre 7: [t, t+12] centred on
%% 7 puts t at 0..7 for pc 0..7 (k = 0, the tie at G going up) and
%% G♯..B an octave lower (k = -1) — the four tonics on which one
%% explicit octave cannot match the Configurator.
#(define cnb:ut-sharp-tonics
   (list (ly:make-pitch 0 0 0) (ly:make-pitch 0 0 SHARP)
         (ly:make-pitch 0 1 0) (ly:make-pitch 0 1 SHARP)
         (ly:make-pitch 0 2 0) (ly:make-pitch 0 3 0)
         (ly:make-pitch 0 3 SHARP) (ly:make-pitch 0 4 0)
         (ly:make-pitch 0 4 SHARP) (ly:make-pitch 0 5 0)
         (ly:make-pitch 0 5 SHARP) (ly:make-pitch 0 6 0)))
#(cnb:assert-equal "Twinline centre 7: C..G in octave 0, G♯ A A♯ B in octave −1"
   (map (lambda (p) (cnb:keysig-centred-octave p 7)) cnb:ut-sharp-tonics)
   '(0 0 0 0 0 0 0 0 -1 -1 -1 -1))
#(cnb:assert-equal "Twinline centre 7: tonic semitones match pc + 12 × round((1 − pc) / 12)"
   (map (lambda (p)
          (ly:pitch-semitones
            (ly:make-pitch (cnb:keysig-centred-octave p 7)
                           (ly:pitch-notename p) (ly:pitch-alteration p))))
        cnb:ut-sharp-tonics)
   '(0 1 2 3 4 5 6 7 -4 -3 -2 -1))
#(cnb:assert-equal "linear treble centre 12, tie goes up: C at 12, not 0 (today's middle-C anchor)"
   (cnb:keysig-centred-octave (ly:make-pitch -1 0 0) 12) 1)
#(cnb:assert-equal "linear treble centre 12: G at semitone 7 (today's anchor too)"
   (cnb:keysig-centred-octave (ly:make-pitch -1 4 0) 12) 0)
#(cnb:assert-equal "the tonic's own octave does not matter: C written in octave 3, centre 12 → 1"
   (cnb:keysig-centred-octave (ly:make-pitch 3 0 0) 12) 1)
%% Enharmonic spellings land on the Configurator's semitone: B♯ is pc 0
%% (t = 0 at centre 7) and so sits in octave −1; C♭ is pc 11 (t = −1).
#(cnb:assert-equal "B♯ at centre 7 → octave −1 (semitone 0, as C)"
   (cnb:keysig-centred-octave (ly:make-pitch 0 6 SHARP) 7) -1)
#(cnb:assert-equal "C♭ at centre 7 → octave 0 (semitone −1, as B)"
   (cnb:keysig-centred-octave (ly:make-pitch 0 0 FLAT) 7) 0)

#(cnb:test-group "keysig.ly — cnb:keysig-pitches with 'centred")

#(set! cnb:get-pitch-staff-position cnb:ut-twinline-axis)
#(cnb:assert-equal "'centred under the Twinline hook: A tonic notehead at semitone −3"
   (ly:pitch-semitones
     (car (cnb:keysig-pitches '() (ly:make-pitch -1 5 0) -6 'centred))) -3)
#(cnb:assert-equal "'centred under the Twinline hook: G tonic notehead at semitone 7"
   (ly:pitch-semitones
     (car (cnb:keysig-pitches '() (ly:make-pitch -1 4 0) -6 'centred))) 7)
#(set! cnb:get-pitch-staff-position #f)
#(cnb:assert-equal "'centred on a linear treble staff: C tonic at semitone 12, as #f gives"
   (ly:pitch-semitones
     (car (cnb:keysig-pitches '() (ly:make-pitch 0 0 0) -6 'centred)))
   (ly:pitch-semitones
     (car (cnb:keysig-pitches '() (ly:make-pitch 0 0 0) -6 #f))))


%% =========================================================================
%%  SUMMARY
%% =========================================================================

#(ly:message "\n============================================")
#(ly:message "  TEST RESULTS: ~a passed, ~a failed"
   cnb:test-pass-count cnb:test-fail-count)
#(ly:message "============================================\n")

#(if (> cnb:test-fail-count 0)
     (ly:warning "~a TEST(S) FAILED!" cnb:test-fail-count))


%% No music — just output an empty score to keep LilyPond happy
{ s1 }
