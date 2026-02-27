%% ============================================================================
%%
%%  CNB MODULE: utils.ly
%%  Utility functions used throughout ChromaticNotationBase
%%
%%  WHAT THIS FILE DOES:
%%    Provides small helper functions for math, list manipulation,
%%    color parsing, path data conversion, and path transformations.
%%    These are the building blocks that other modules rely on.
%%
%%  DEPENDENCIES: None (this is the lowest-level module)
%%
%%  KEY CONCEPTS FOR NEWCOMERS:
%%    - LilyPond embeds Guile Scheme inside #( ... ) blocks
%%    - (define name value) creates a variable
%%    - (define (name args) body) creates a function
%%    - (let* ((x 1) (y 2)) body) creates local variables sequentially
%%    - (set! name value) mutates an existing variable
%%    - Vectors are fixed-size arrays: #(a b c), accessed with vector-ref
%%    - Lists are linked lists: '(a b c), accessed with car/cdr/list-ref
%%    - Hash tables are mutable key-value stores
%%    - cons builds a pair: (cons 1 2) => (1 . 2)
%%    - car/cdr extract pair halves: (car '(1 . 2)) => 1
%%
%% ============================================================================


%% ---------------------------------------------------------------------------
%%  MATH HELPERS
%% ---------------------------------------------------------------------------

%% Log base 2. Used to determine note duration category from LilyPond's
%% internal duration representation. LilyPond stores durations as
%% fractions (e.g., 1/4 for a quarter note), and we need the log2
%% to classify them: whole=0, half=1, quarter=2, eighth=3, etc.
#(define (cnb:log2 x)
   (/ (log x) (log 2)))

%% Round a number to n decimal places.
%% Example: (cnb:round2 3.14159 2) => 3.14
#(define (cnb:round2 x n)
   (/ (round (* (expt 10 n) x)) (expt 10 n)))


%% ---------------------------------------------------------------------------
%%  LIST HELPERS
%% ---------------------------------------------------------------------------

%% Add an element to a list only if it's not already present.
%% Used when building ledger line position lists to avoid duplicates.
%%
%% HOW IT WORKS:
%%   (memq x lst) checks if x is in lst using eq? (identity comparison).
%%   If x is already there, return lst unchanged.
%%   Otherwise, append x to the end.
%%
%% EXAMPLE:
%%   (cnb:add-if-not-exists '(1 2 3) 4) => '(1 2 3 4)
%%   (cnb:add-if-not-exists '(1 2 3) 2) => '(1 2 3)
#(define (cnb:add-if-not-exists lst x)
   (if (or (null? lst) (not (memq x lst)))
       (append lst (list x))
       lst))


%% ---------------------------------------------------------------------------
%%  MEMBERSHIP AND WILDCARD HELPERS
%%  Used by the procedure-oriented configuration model (cnb/procedure.ly).
%% ---------------------------------------------------------------------------

%% Test whether a value is a member of a collection.
%% Works with both lists and vectors.
%%
%% EXAMPLES:
%%   (cnb:in? 0 '(0 2 4 5 7 9 11))  => #t
%%   (cnb:in? 1 '(0 2 4 5 7 9 11))  => #f
%%   (cnb:in? 3 #(0 3 6 9))          => #t
%%   (cnb:in? 5 #())                  => #f
#(define (cnb:in? value collection)
   (cond
     ((list? collection)
      (if (member value collection) #t #f))
     ((vector? collection)
      (let loop ((i 0))
        (cond
          ((>= i (vector-length collection)) #f)
          ((equal? (vector-ref collection i) value) #t)
          (else (loop (+ i 1))))))
     (else #f)))

%% Wildcard matcher — always returns #t regardless of input.
%% Used in configuration procedure conditions to mean "any value."
%%
%% EXAMPLE (in a cond clause):
%%   ((and (cnb:in? semitone '(0 3 6 9))
%%         (cnb:all duration)          ;; matches any duration
%%         (cnb:all key))              ;; matches any key
%%    '((shape . kite-up) ...))
#(define (cnb:all value) #t)


%% ---------------------------------------------------------------------------
%%  COLOR PARSING
%% ---------------------------------------------------------------------------

%% Convert a hex color string like "#7d3fff" into a list of three
%% floating-point RGB values (0.0 to 1.0) that LilyPond's stencil
%% functions can use.
%%
%% WHY WE NEED THIS:
%%   Config files define colors as hex strings (familiar to web developers).
%%   But LilyPond's low-level stencil API (ly:stencil-in-color) needs
%%   separate R, G, B values between 0.0 and 1.0.
%%
%% EXAMPLE:
%%   (cnb:hex-to-rgb "#ff0000") => (1.0 0.0 0.0)    ; pure red
%%   (cnb:hex-to-rgb "#7d3fff") => (0.49 0.25 1.0)   ; purple
#(define (cnb:hex-to-rgb hex-str)
   (let* ((hex (if (string-prefix? "#" hex-str)
                   (substring hex-str 1)
                   hex-str))
          (r (/ (string->number (substring hex 0 2) 16) 255.0))
          (g (/ (string->number (substring hex 2 4) 16) 255.0))
          (b (/ (string->number (substring hex 4 6) 16) 255.0)))
     (list r g b)))


%% Apply a hex color to a stencil.
%% Convenience wrapper — parses hex string and applies via ly:stencil-in-color.
#(define (cnb:colorize-stencil stencil hex-color)
   (let* ((rgb (cnb:hex-to-rgb hex-color)))
     (ly:stencil-in-color stencil
                          (first rgb)
                          (second rgb)
                          (third rgb))))


%% ---------------------------------------------------------------------------
%%  PATH DATA HELPERS
%% ---------------------------------------------------------------------------

%% Flatten a nested path list into the flat format that make-path-stencil
%% expects.
%%
%% WHY WE NEED THIS:
%%   Config files define notehead paths as nested lists for readability:
%%     '((moveto 0 0.6667) (lineto 0.6667 0.3333) ...)
%%
%%   But LilyPond's make-path-stencil wants a flat list:
%%     '(moveto 0 0.6667 lineto 0.6667 0.3333 ...)
%%
%% EXAMPLE:
%%   (cnb:flatten-path '((moveto 0 1) (lineto 2 3)))
%%   => '(moveto 0 1 lineto 2 3)
#(define (cnb:flatten-path nested-path)
   (apply append nested-path))


%% ============================================================================
%%
%%  PATH TRANSFORM FUNCTIONS
%%
%%  These functions transform notehead path data — rotate, scale, and
%%  reverse winding direction — BEFORE building stencils. This enables:
%%
%%    1. Pre-computing all 12 notehead stencils at init time using
%%       make-path-stencil (grob-independent, fast)
%%    2. Correct hollow rendering under the non-zero winding fill rule
%%       (by reversing the hollow path's winding direction)
%%
%%  PATH FORMAT REMINDER:
%%    Paths are lists of drawing commands, each a sub-list:
%%      (moveto x y)                         — 1 point  (2 coords)
%%      (lineto x y)                         — 1 point  (2 coords)
%%      (curveto cx1 cy1 cx2 cy2 ex ey)     — 3 points (6 coords)
%%      (closepath)                           — 0 points (0 coords)
%%
%%  ALL TRANSFORMS operate on the nested-list format and return the
%%  same format. Call cnb:flatten-path AFTER transforming, not before.
%%
%% ============================================================================


%% ---------------------------------------------------------------------------
%%  GENERIC PATH POINT TRANSFORM
%%
%%  Applies a point-transform function to every coordinate pair in a path.
%%  This is the engine behind rotate-path and scale-path.
%%
%%  ARGUMENTS:
%%    path      — nested path list
%%    point-fn  — function that takes (x, y) and returns (new-x . new-y)
%%                as a cons pair
%%
%%  HOW IT WORKS:
%%    For each command, we identify how many coordinate pairs it contains
%%    and apply point-fn to each one:
%%      moveto    → 1 pair at indices 1,2
%%      lineto    → 1 pair at indices 1,2
%%      curveto   → 3 pairs at indices 1,2 / 3,4 / 5,6
%%      closepath → 0 pairs (passed through unchanged)
%%
%%  RETURNS:
%%    A new nested path list with all coordinates transformed.
%% ---------------------------------------------------------------------------

#(define (cnb:transform-path path point-fn)
   (map (lambda (cmd)
     (let ((type (car cmd)))
       (cond
         ((eq? type 'moveto)
          (let ((p (point-fn (cadr cmd) (caddr cmd))))
            (list 'moveto (car p) (cdr p))))

         ((eq? type 'lineto)
          (let ((p (point-fn (cadr cmd) (caddr cmd))))
            (list 'lineto (car p) (cdr p))))

         ((eq? type 'curveto)
          (let ((p1 (point-fn (list-ref cmd 1) (list-ref cmd 2)))
                (p2 (point-fn (list-ref cmd 3) (list-ref cmd 4)))
                (p3 (point-fn (list-ref cmd 5) (list-ref cmd 6))))
            (list 'curveto
                  (car p1) (cdr p1)
                  (car p2) (cdr p2)
                  (car p3) (cdr p3))))

         ((eq? type 'closepath)
          (list 'closepath))

         (else cmd))))
     path))


%% ---------------------------------------------------------------------------
%%  ROTATE PATH
%%
%%  Rotates all coordinates around the origin by the given angle.
%%
%%  ARGUMENTS:
%%    path    — nested path list
%%    degrees — rotation angle in degrees (counter-clockwise positive)
%%
%%  MATH:
%%    Standard 2D rotation matrix:
%%      x' = x·cos(θ) − y·sin(θ)
%%      y' = x·sin(θ) + y·cos(θ)
%%
%%  EXAMPLE:
%%    Rotating a diamond by 180° flips it upside-down (inverts it).
%%    (cnb:rotate-path diamond-path 180)
%%
%%  OPTIMIZATION:
%%    Returns the input unchanged when degrees is 0 (identity rotation).
%% ---------------------------------------------------------------------------

#(define (cnb:rotate-path path degrees)
   (if (= degrees 0)
       path
       (let* ((rad (* degrees (/ 3.14159265358979 180.0)))
              (cos-r (cos rad))
              (sin-r (sin rad)))
         (cnb:transform-path path
           (lambda (x y)
             (cons (- (* x cos-r) (* y sin-r))
                   (+ (* x sin-r) (* y cos-r))))))))


%% ---------------------------------------------------------------------------
%%  SCALE PATH
%%
%%  Multiplies all coordinates by (sx, sy) scaling factors.
%%
%%  ARGUMENTS:
%%    path — nested path list
%%    sx   — horizontal scale factor (1.0 = no change)
%%    sy   — vertical scale factor (1.0 = no change)
%%
%%  EXAMPLES:
%%    (cnb:scale-path path 0.75 0.75)  → shrink to 75% in both axes
%%    (cnb:scale-path path 1.0 -1.0)   → flip vertically
%%
%%  OPTIMIZATION:
%%    Returns the input unchanged when both factors are 1 (identity).
%% ---------------------------------------------------------------------------

#(define (cnb:scale-path path sx sy)
   (if (and (= sx 1) (= sy 1))
       path
       (cnb:transform-path path
         (lambda (x y)
           (cons (* x sx) (* y sy))))))


%% ---------------------------------------------------------------------------
%%  CACHE KEY HELPERS
%% ---------------------------------------------------------------------------

%% Create a numeric cache key from a pitch class (0-11) and a
%% duration category.
%%
%% ENCODING SCHEME:
%%   key = (pitch-class * 100) + duration-category
%%   This works because pitch-class is 0-11 and duration-category
%%   is a small integer (typically 0-4), so keys never collide.
%%
%% EXAMPLES:
%%   C quarter note:  (cnb:make-cache-key 0 2) => 2
%%   F# half note:    (cnb:make-cache-key 6 1) => 601
%%   B whole note:    (cnb:make-cache-key 11 0) => 1100
#(define (cnb:make-cache-key pitch-class duration-category)
   (+ (* pitch-class 100) duration-category))


%% Compute the duration category for a note event.
%%
%% LilyPond represents durations as fractions:
%%   breve=2, whole=1, half=1/2, quarter=1/4, eighth=1/8, etc.
%%
%% We convert to a "log2 duration" number:
%%   breve=-1, whole=0, half=1, quarter=2, eighth=3, etc.
#(define (cnb:duration-category duration-prop)
   (let* ((dur (duration-length duration-prop))
          (raw (- (cnb:log2 (denominator dur))
                  (floor (/ (numerator dur) 2))))
          (clamped (max 0 (min 3 (inexact->exact (round raw))))))
     clamped))
