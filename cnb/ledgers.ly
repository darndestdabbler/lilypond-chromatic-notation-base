%% ============================================================================
%%
%%  CNB MODULE: ledgers.ly
%%  Proximity-based ledger line visibility system
%%
%%  WHAT THIS FILE DOES:
%%    Determines WHEN ledger lines appear for a given note, using
%%    a simple geometric rule rather than manually enumerated lists.
%%
%%  DEPENDENCIES: config.ly
%%
%%  THE PROXIMITY RULE:
%%    "For any given notehead, show all ledger lines that lie between
%%     the nearest staff line and the notehead."
%%
%%    This single rule handles all cases naturally:
%%
%%    Note WITHIN the staff:
%%      The nearest staff line is very close (0-2 positions away).
%%      No ledger candidates exist in that tiny range. → No ledgers.
%%
%%    Note just OUTSIDE the staff (e.g., first space above):
%%      The nearest staff line is the outermost one, distance 1.
%%      No ledger candidates in that range. → No ledgers. Correct!
%%
%%    Note ON the first ledger line:
%%      The range between the outermost staff line and the note
%%      includes the first ledger position. → One ledger shown.
%%
%%    Note FAR from the staff:
%%      The range grows, and more ledger candidates fall within it.
%%      Ledgers accumulate naturally toward the note. → Many ledgers.
%%
%%    The rule NEVER shows ledgers beyond the note — they must be
%%    between the staff and the notehead.
%%
%%  COMPARISON TO OTHER APPROACHES:
%%
%%    Your previous approach: Manually list every (ledger-position,
%%    notehead-positions-that-trigger-it) mapping. Error-prone,
%%    tightly coupled to staff geometry, tedious to maintain.
%%
%%    Clairnote's recipe system: Cycle-based patterns with further-add/
%%    nearer-drop parameters. Powerful but complex — designed for
%%    Clairnote's specific multi-octave-staff variants. Overkill when
%%    your JS generator already handles the staff geometry.
%%
%%    This approach: The visibility rule derives from geometry.
%%    Change staff lines → ledger behavior updates automatically.
%%    Per-ledger overrides handle edge cases.
%%
%%  HOW THIS MODULE INTEGRATES:
%%    It provides a function compatible with LilyPond's native
%%    StaffSymbol.ledger-positions-function callback. LilyPond calls
%%    this function for every note to determine which ledger lines
%%    to draw. No custom LedgerLineSpanner stencil needed for
%%    basic (simple mode) usage.
%%
%%    For advanced mode (styled ledger lines with custom colors/dashes),
%%    the proximity rule still determines visibility, and the
%%    custom LedgerLineSpanner stencil in staff.ly handles drawing.
%%
%% ============================================================================


%% ---------------------------------------------------------------------------
%%  CONFIGURATION
%% ---------------------------------------------------------------------------

%% Per-notehead overrides for the proximity rule.
%% An alist mapping notehead positions to explicit ledger position lists.
%% When a notehead position has an entry here, the proximity rule is
%% bypassed and these exact positions are used instead.
%%
%% FORMAT: '((notehead-pos . (ledger-pos ...)) ...)
%%
%% EXAMPLE:
%%   '((10 . (6 8))      ;; note at 10: always show ledgers at 6 and 8
%%     (-10 . (-6 -8)))   ;; note at -10: always show ledgers at -6 and -8
%%
%% DEFAULT: Empty (no overrides — use proximity rule for everything)
#(define cnb:ledger-overrides '())


%% ---------------------------------------------------------------------------
%%  AUTOMATIC LEDGER CANDIDATE GENERATION
%%
%%  Given the staff line positions, generate a list of positions where
%%  ledger lines COULD appear. These are the "candidates" that the
%%  proximity rule filters at runtime.
%%
%%  ALGORITHM:
%%    1. Find the minimum spacing between adjacent staff lines
%%    2. Extend that pattern above the top staff line and below
%%       the bottom staff line, up to cnb:ledger-extend-range
%%    3. Exclude any positions that coincide with staff lines
%%
%%  PARAMETERS:
%%    staff-positions — list of staff line positions (e.g., '(-4 -2 0 2 4))
%%    extend-range    — how far to extend, in half-staff-spaces from center
%%
%%  RETURNS:
%%    A sorted list of ledger candidate positions.
%%
%%  EXAMPLE:
%%    Staff lines at (-4 -2 0 2 4), extend-range 24:
%%    → Spacing is 2
%%    → Above: 6, 8, 10, 12, 14, 16, 18, 20, 22, 24
%%    → Below: -6, -8, -10, -12, -14, -16, -18, -20, -22, -24
%%    → These are the same defaults you'd write by hand, but derived.
%%
%%  NOTE FOR YOUR JS GENERATOR:
%%    You can either:
%%    a) Let this function auto-generate candidates (set cnb:ledger-positions to '())
%%    b) Provide explicit candidates in cnb:ledger-positions (this function is skipped)
%% ---------------------------------------------------------------------------

#(define cnb:ledger-extend-range 30)

#(define (cnb:auto-generate-ledger-candidates staff-positions)
   (if (< (length staff-positions) 2)
       '()
       (let* (
               (sorted (sort staff-positions <))
               (top    (last sorted))
               (bottom (first sorted))
               (gaps   (let loop ((remaining (cdr sorted))
                                  (prev (car sorted))
                                  (result '()))
                         (if (null? remaining)
                             (reverse result)
                             (loop (cdr remaining)
                                   (car remaining)
                                   (cons (- (car remaining) prev) result)))))
               (spacing (apply min gaps))
               (staff-set sorted)
               (above  (let loop ((pos (+ top spacing)) (result '()))
                         (if (> pos cnb:ledger-extend-range)
                             (reverse result)
                             (loop (+ pos spacing)
                                   (if (member pos staff-set)
                                       result
                                       (cons pos result))))))
               (below  (let loop ((pos (- bottom spacing)) (result '()))
                         (if (< pos (- cnb:ledger-extend-range))
                             (reverse result)
                             (loop (- pos spacing)
                                   (if (member pos staff-set)
                                       result
                                       (cons pos result)))))))
         (append below above))))


%% ---------------------------------------------------------------------------
%%  GET THE EFFECTIVE LEDGER CANDIDATES
%%
%%  If cnb:ledger-positions is non-empty, use it as-is (user-specified).
%%  If empty, auto-generate from staff line positions.
%%
%%  This is resolved once (lazily) and cached.
%% ---------------------------------------------------------------------------

#(define cnb:resolved-ledger-candidates #f)

#(define (cnb:get-ledger-candidates staff-positions)
   (if (not cnb:resolved-ledger-candidates)
       (set! cnb:resolved-ledger-candidates
             (if (and (pair? cnb:ledger-positions)
                      (not (null? cnb:ledger-positions)))
                 cnb:ledger-positions
                 (cnb:auto-generate-ledger-candidates staff-positions))))
   cnb:resolved-ledger-candidates)


%% ---------------------------------------------------------------------------
%%  THE PROXIMITY RULE
%%
%%  Given a notehead position and the staff line positions, return
%%  the list of ledger positions that should be drawn.
%%
%%  ALGORITHM:
%%    1. Check overrides first — if there's an entry for this exact
%%       notehead position, return those ledger positions directly.
%%
%%    2. Find the top and bottom staff line positions.
%%
%%    3. Determine if the note is above, below, or within the staff.
%%
%%    4. For notes outside the staff, filter candidates to those that
%%       lie BETWEEN the outermost staff line (on the note's side)
%%       and the notehead position (inclusive).
%%
%%    5. For notes within the staff, return empty list (no ledgers).
%%
%%  WHY "BETWEEN" WORKS:
%%    Any ledger candidate between the staff and the notehead is
%%    automatically closer to the notehead than the nearest staff line.
%%    This is the user's original rule — just expressed geometrically.
%%    The "between" constraint also prevents showing ledgers beyond
%%    the note, which would look wrong.
%%
%%  PARAMETERS:
%%    staff-positions — list of staff line positions from StaffSymbol
%%    notehead-pos    — the vertical position of the notehead
%%    candidates      — list of ledger candidate positions
%%
%%  RETURNS:
%%    A list of ledger line positions to draw for this note.
%% ---------------------------------------------------------------------------

#(define (cnb:proximity-rule staff-positions notehead-pos candidates)
   (let* (
           (override (assv notehead-pos cnb:ledger-overrides))
           (top-staff    (apply max staff-positions))
           (bottom-staff (apply min staff-positions)))

      (cond
        (override (cdr override))

        ((> notehead-pos top-staff)
         (filter (lambda (lp) (and (> lp top-staff)
                                   (<= lp notehead-pos)))
                 candidates))

        ((< notehead-pos bottom-staff)
         (filter (lambda (lp) (and (< lp bottom-staff)
                                   (>= lp notehead-pos)))
                 candidates))

        (else '()))))


%% ---------------------------------------------------------------------------
%%  LILYPOND CALLBACK: ledger-positions-function
%%
%%  This is the function that LilyPond's StaffSymbol calls for each note
%%  to determine which ledger lines to draw.
%%
%%  IMPORTANT IMPLEMENTATION NOTE:
%%    LilyPond evaluates this function via (eval ... (interaction-environment)).
%%    The function must be QUOTED (stored as code, not as a closure) because
%%    LilyPond stores it as a grob property and evaluates it later.
%%    This is the same pattern Clairnote uses (line 1682).
%%
%%  The function receives:
%%    staff-symbol  — the StaffSymbol grob
%%    pos           — the notehead's staff position (half-staff-spaces)
%%
%%  Returns:
%%    A list of ledger line positions to draw.
%% ---------------------------------------------------------------------------

#(define cnb:ledger-positions-function
   '(lambda (staff-symbol pos)
      (let* (
              (staff-positions (ly:grob-property staff-symbol 'line-positions '()))
              (candidates      (cnb:get-ledger-candidates staff-positions)))
        (cnb:proximity-rule staff-positions pos candidates))))
