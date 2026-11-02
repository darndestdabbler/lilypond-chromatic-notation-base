%% ============================================================================
%%
%%  CNB MODULE: path-geometry.ly
%%  Path winding detection, reversal, and normalization
%%
%%  WHAT THIS FILE DOES:
%%    Provides utilities to analyze and manipulate SVG-like path data so that
%%    make-path-stencil produces correct hollow noteheads. This is needed
%%    because make-path-stencil uses the "non-zero winding" fill rule,
%%    which requires the hollow cutout path to wind in the OPPOSITE direction
%%    from the outer shape path.
%%
%%  DEPENDENCIES: utils.ly (for cnb:flatten-path)
%%
%%  BACKGROUND — THE TWO FILL RULES:
%%
%%    When you draw two closed shapes inside each other (an outer outline
%%    and an inner cutout), the renderer needs to decide which regions
%%    are "inside" and should be filled. There are two common rules:
%%
%%    EVEN-ODD FILL (used by #:path markup with (filled . #t)):
%%      Count how many path boundaries a point is inside.
%%      If the count is odd, fill it. If even, leave it empty.
%%      → Inner region is always empty (it's inside 2 boundaries = even).
%%      → Direction of the paths doesn't matter.
%%
%%    NON-ZERO WINDING (used by make-path-stencil):
%%      Each boundary has a direction (clockwise or counter-clockwise).
%%      Going one direction adds +1, the other adds -1.
%%      If the total is non-zero, fill it. If zero, leave it empty.
%%      → Inner region is empty ONLY if it winds opposite to the outer.
%%      → If both wind the same way, the inner region stays filled (no hole).
%%
%%  WHY THIS MATTERS:
%%    The old code used #:path markup (even-odd), so hollow paths worked
%%    regardless of direction. The new code uses make-path-stencil
%%    (non-zero winding) for performance, so we MUST ensure the hollow
%%    path winds opposite to the shape path.
%%
%%  WHAT YOUR JS CONFIG GENERATOR SHOULD DO:
%%    When outputting path data, the generator should:
%%    1. Ensure the outer shape is wound counter-clockwise (CCW)
%%    2. Ensure the hollow cutout is wound clockwise (CW)
%%    OR use cnb:ensure-opposite-winding at load time (slower but automatic).
%%
%%  ALGORITHM FOR WINDING DETECTION:
%%    We use the "shoelace formula" on the path's control polygon.
%%    For each segment, we compute the cross product contribution:
%%      (x2 - x1) * (y2 + y1)
%%    Sum over all segments. If the sum is positive, the path winds
%%    clockwise. If negative, counter-clockwise.
%%    (This works for the control polygon of Bezier curves too —
%%    it's approximate for curves but correct for the overall direction.)
%%
%% ============================================================================


%% ---------------------------------------------------------------------------
%%  EXTRACT VERTICES FROM A PATH
%%
%%  Walks through the nested path commands and extracts the (x, y)
%%  endpoint of each command. This gives us the "control polygon"
%%  whose signed area tells us the winding direction.
%%
%%  SUPPORTED COMMANDS:
%%    (moveto x y)              → adds (x, y)
%%    (lineto x y)              → adds (x, y)
%%    (curveto x1 y1 x2 y2 x y) → adds the endpoint (x, y) only
%%    (closepath)               → ignored (returns to start)
%%
%%  RETURNS: A list of (x . y) pairs.
%% ---------------------------------------------------------------------------

#(define (cnb:path-vertices nested-path)
   (let loop ((cmds nested-path) (verts '()))
     (if (null? cmds)
         (reverse verts)
         (let* ((cmd (car cmds))
                (op  (car cmd)))
           (cond
             ((eq? op 'moveto)
              (loop (cdr cmds)
                    (cons (cons (second cmd) (third cmd)) verts)))
             ((eq? op 'lineto)
              (loop (cdr cmds)
                    (cons (cons (second cmd) (third cmd)) verts)))
             ((eq? op 'curveto)
              (loop (cdr cmds)
                    (cons (cons (sixth cmd) (seventh cmd)) verts)))
             (else
              (loop (cdr cmds) verts)))))))


%% ---------------------------------------------------------------------------
%%  SIGNED AREA (SHOELACE FORMULA)
%%
%%  Computes the signed area of the polygon formed by the path vertices.
%%    Positive → clockwise winding (in screen coordinates where Y points down)
%%    Negative → counter-clockwise winding
%%
%%  NOTE: In LilyPond's coordinate system, Y points UP (like math),
%%  so the signs are swapped from screen coordinates:
%%    Positive → counter-clockwise (CCW)
%%    Negative → clockwise (CW)
%%
%%  For our purposes, we only care about the SIGN, not the magnitude.
%% ---------------------------------------------------------------------------

#(define (cnb:signed-area vertices)
   (if (< (length vertices) 3)
       0
       (let loop ((verts vertices) (sum 0))
         (if (null? (cdr verts))
             (let ((last (car verts))
                   (first (car vertices)))
               (+ sum (* (- (car first) (car last))
                         (+ (cdr first) (cdr last)))))
             (let ((curr (car verts))
                   (next (cadr verts)))
               (loop (cdr verts)
                     (+ sum (* (- (car next) (car curr))
                               (+ (cdr next) (cdr curr))))))))))


%% ---------------------------------------------------------------------------
%%  WINDING DIRECTION
%%
%%  Returns 'cw for clockwise or 'ccw for counter-clockwise.
%%  Uses the signed area of the path's control polygon.
%% ---------------------------------------------------------------------------

#(define (cnb:winding-direction nested-path)
   (let* ((verts (cnb:path-vertices nested-path))
          (area  (cnb:signed-area verts)))
     (if (> area 0) 'cw 'ccw)))


%% ---------------------------------------------------------------------------
%%  REVERSE A PATH
%%
%%  Takes a nested path and returns a new nested path that traces the
%%  same shape but in the opposite winding direction.
%%
%%  HOW IT WORKS:
%%    1. Strip the closepath command (we'll add it back at the end)
%%    2. Collect all endpoints to know the "previous point" for each segment
%%    3. Walk the commands in reverse order:
%%       - moveto → becomes the new start point (the old last endpoint)
%%       - lineto → becomes a lineto to the previous point
%%       - curveto x1 y1 x2 y2 x y → becomes curveto x2 y2 x1 y1 prev
%%         (control points are swapped and the endpoint becomes the
%%          previous command's endpoint)
%%    4. Append closepath
%%
%%  EXAMPLE:
%%    Original (CW diamond):
%%      (moveto 0 1) (lineto 1 0) (lineto 0 -1) (lineto -1 0) (closepath)
%%    Reversed (CCW diamond):
%%      (moveto 0 1) (lineto -1 0) (lineto 0 -1) (lineto 1 0) (closepath)
%% ---------------------------------------------------------------------------

#(define (cnb:reverse-path nested-path)
   (let* (
           (without-close (filter (lambda (cmd) (not (eq? (car cmd) 'closepath)))
                                  nested-path))
           (endpoints
             (let loop ((cmds without-close) (pts '()))
               (if (null? cmds)
                   (reverse pts)
                   (let* ((cmd (car cmds))
                          (op  (car cmd)))
                     (cond
                       ((eq? op 'moveto)
                        (loop (cdr cmds) (cons (cons (second cmd) (third cmd)) pts)))
                       ((eq? op 'lineto)
                        (loop (cdr cmds) (cons (cons (second cmd) (third cmd)) pts)))
                       ((eq? op 'curveto)
                        (loop (cdr cmds) (cons (cons (sixth cmd) (seventh cmd)) pts)))
                       (else
                        (loop (cdr cmds) pts)))))))
           (n (length endpoints))
           (last-pt (list-ref endpoints (- n 1)))
           (reversed-cmds
             (let loop ((i (- n 1)) (result (list (list 'moveto (car last-pt) (cdr last-pt)))))
               (if (<= i 0)
                   (reverse result)
                   (let* ((prev-pt (list-ref endpoints (- i 1)))
                          (cmd     (list-ref without-close i))
                          (op      (car cmd)))
                     (loop (- i 1)
                           (cons
                             (cond
                               ((eq? op 'lineto)
                                (list 'lineto (car prev-pt) (cdr prev-pt)))
                               ((eq? op 'curveto)
                                (list 'curveto
                                      (fourth cmd) (fifth cmd)
                                      (second cmd) (third cmd)
                                      (car prev-pt) (cdr prev-pt)))
                               (else
                                (list 'lineto (car prev-pt) (cdr prev-pt))))
                             result)))))))
      (append reversed-cmds (list (list 'closepath)))))


%% ---------------------------------------------------------------------------
%%  ENSURE OPPOSITE WINDING
%%
%%  Given an outer shape path and an inner hollow path, ensures they
%%  wind in opposite directions. If they wind the same way, the hollow
%%  path is reversed.
%%
%%  RETURNS: The hollow path (possibly reversed).
%%
%%  This is the main entry point for config files and the stencil builder.
%%  Call it once at config time, not per-note.
%% ---------------------------------------------------------------------------

#(define (cnb:ensure-opposite-winding shape-path hollow-path)
   (let* ((shape-dir  (cnb:winding-direction shape-path))
          (hollow-dir (cnb:winding-direction hollow-path)))
     (if (eq? shape-dir hollow-dir)
         (cnb:reverse-path hollow-path)
         hollow-path)))
