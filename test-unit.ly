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
\include "cnb/ledgers.ly"
\include "cnb/off-key.ly"


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

#(cnb:test-group "utils.ly — cnb:log2")
%% log returns inexact (floating point), so use assert-near
#(cnb:assert-near "log2(1) ≈ 0"  (cnb:log2 1)  0.0 0.001)
#(cnb:assert-near "log2(2) ≈ 1"  (cnb:log2 2)  1.0 0.001)
#(cnb:assert-near "log2(4) ≈ 2"  (cnb:log2 4)  2.0 0.001)
#(cnb:assert-near "log2(8) ≈ 3"  (cnb:log2 8)  3.0 0.001)

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
%% Formula: pitch-class * 100 + duration-category
#(cnb:assert-equal "cache key for pitch 0, dur 2"  (cnb:make-cache-key 0 2)    2)
#(cnb:assert-equal "cache key for pitch 5, dur 3"  (cnb:make-cache-key 5 3)  503)
#(cnb:assert-equal "cache key for pitch 11, dur 1" (cnb:make-cache-key 11 1) 1101)
%% Keys must be unique — verify no collisions for all valid combinations
#(cnb:assert-true "all cache keys unique"
   (let* ((keys (map (lambda (p)
                       (map (lambda (d) (cnb:make-cache-key p d))
                            '(0 1 2 3 4)))
                     (iota 12)))
          (flat (apply append keys))
          (unique (delete-duplicates flat)))
     (= (length flat) (length unique))))

#(cnb:test-group "utils.ly — cnb:duration-category")
%% NOTE: cnb:duration-category takes a LilyPond Duration object (from
%% ly:event-property 'duration), not a plain integer. It cannot be unit
%% tested without a rendering context. This is a Tier 2 test candidate.
#(ly:message "  SKIP: duration-category requires LilyPond Duration objects")


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
#(cnb:assert-equal "off-key-indicator defaults to 'none"
   cnb:off-key-indicator 'none)
#(cnb:assert-equal "false-hollow defaults to #f"
   cnb:false-hollow #f)
#(cnb:assert-equal "ledger-positions defaults to empty"
   cnb:ledger-positions '())


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
