%% ============================================================================
%%
%%  CNB MODULE: procedure.ly
%%  Procedure-oriented configuration infrastructure
%%
%%  WHAT THIS FILE DOES:
%%    Provides the configuration model where a single Scheme procedure
%%    (semitone, duration, key) → config drives all notehead rendering.
%%    This module defines:
%%
%%      1. Named definition tables — map symbols to path/attachment data
%%      2. Registration functions — populate the tables
%%      3. A default configuration procedure — overridden by notation configs
%%      4. A config resolver — turns symbolic refs into actual data
%%      5. A config cache — pre-computes resolved configs for fast lookup
%%
%%  DEPENDENCIES: utils.ly (for cnb:make-cache-key, cnb:in?)
%%                colors.ly (for color variables)
%%                config.ly (for default path data)
%%
%%  ALSO PROVIDES:
%%    cnb:step-to-semitone and cnb:get-key-pitch-classes — key pitch class
%%    utilities used by both the config cache (to pass key data to the
%%    procedure) and the off-key engraver. These were originally in
%%    off-key.ly but are needed here for key-change tracking in the
%%    notehead engraver, which loads before off-key.ly.
%%
%%  HOW NOTATION CONFIGS USE THIS:
%%    1. Define paths (using cnb:rotate-path etc. from utils.ly)
%%    2. Register them:  (cnb:register-path! 'my-shape my-path-data)
%%    3. Override cnb:get-notehead-config with a procedure that returns
%%       alists using symbolic references:
%%         '((shape . my-shape) (color . "#FF0000") ...)
%%    4. The engine calls cnb:build-config-cache at engraving start,
%%       which evaluates the procedure and resolves all references.
%%    5. During engraving, cnb:lookup-config fetches pre-resolved configs.
%%
%% ============================================================================


%% =========================================================================
%%  KEY PITCH CLASS UTILITIES
%%
%%  These convert LilyPond's key signature representation to a set of
%%  12-tone pitch classes. Used by the config cache builder to pass
%%  key data to the configuration procedure, and by the off-key engraver
%%  to detect out-of-key notes.
%%
%%  MOVED HERE from off-key.ly because the notehead engraver (which
%%  loads before off-key.ly) needs these for key-change tracking in
%%  procedure model.
%% =========================================================================

%% Map diatonic step number (0-6, C through B) to semitone (0-11).
#(define cnb:step-to-semitone (vector 0 2 4 5 7 9 11))


%% Given LilyPond's keyAlterations context property, compute the set
%% of 7 pitch classes (semitones mod 12) that are "in the key."
%%
%% keyAlterations format: list of (step . alteration) pairs.
%%   step = 0-6 (C D E F G A B)
%%   alteration = fraction (1/2 = sharp, -1/2 = flat, 0 = natural)
%% For C major: '()  (empty — all naturals)
%% For G major: '((3 . 1/2))  (F is sharped)
%%
%% We start with the 7 natural pitch classes, then apply alterations.

#(define (cnb:get-key-pitch-classes key-alts)
   (let* (
           (result (list 0 2 4 5 7 9 11)))  ;; C D E F G A B
     ;; Apply each alteration
     (for-each
       (lambda (entry)
         (let* (
                 ;; Handle both simple (step . alt) and octave-specific
                 ;; ((octave . step) . alt) formats
                 (step (let ((k (car entry)))
                         (if (pair? k) (cdr k) k)))
                 (alt  (cdr entry))
                 (base (vector-ref cnb:step-to-semitone step))
                 (modified (modulo (+ base (inexact->exact (round (* 2 alt)))) 12)))
           (set! result
                 (map (lambda (pc)
                        (if (= pc (vector-ref cnb:step-to-semitone step))
                            modified
                            pc))
                      result))))
       key-alts)
     result))


%% =========================================================================
%%  NAMED DEFINITION TABLES
%%
%%  These are hash tables mapping symbols to data. Notation configs
%%  populate them with paths, hollow cutouts, stem attachment configs,
%%  and off-key mark definitions. The resolver looks up symbols here.
%%
%%  WHY HASH TABLES (not alists):
%%    O(1) lookup. The resolver is called once per cache entry during
%%    cache build (~48 calls). With alists it would be O(n) per lookup,
%%    but n is small so either would work — hash tables are chosen for
%%    consistency with the config cache.
%%
%%  KEY TYPE:
%%    All keys are Scheme symbols (e.g., 'kite-up, 'center-top).
%%    We use hashq-set!/hashq-ref which compare keys with eq? —
%%    perfect for symbols since identical symbols are always eq?.
%% =========================================================================

#(define cnb:path-defs (make-hash-table))
#(define cnb:hollow-defs (make-hash-table))
#(define cnb:attachment-defs (make-hash-table))
#(define cnb:off-key-mark-defs (make-hash-table))
#(define cnb:color-defs (make-hash-table))


%% ---------------------------------------------------------------------------
%%  REGISTRATION FUNCTIONS
%%
%%  Notation configs call these to populate the definition tables.
%%  Each function takes a symbol name and the actual data.
%%
%%  EXAMPLES:
%%    #(cnb:register-path! 'kite-up kite-up-path-data)
%%    #(cnb:register-hollow! 'kite-up-cutout kite-hollow-path-data)
%%    #(cnb:register-attachment! 'center-top
%%       '((crotchet-up . (0 . 0.9)) (crotchet-down . (0 . -0.9))
%%         (minim-up . (-0.365 . 0.9)) (minim-down . (0.365 . -0.9))))
%%    #(cnb:register-off-key-mark! 'my-dot my-dot-path-data)
%%    #(cnb:register-color! 'kite-primary "#7D3FFF")
%% ---------------------------------------------------------------------------

#(define (cnb:register-path! name path-data)
   (hashq-set! cnb:path-defs name path-data))

#(define (cnb:register-hollow! name hollow-data)
   (hashq-set! cnb:hollow-defs name hollow-data))

#(define (cnb:register-attachment! name attach-data)
   (hashq-set! cnb:attachment-defs name attach-data))

#(define (cnb:register-off-key-mark! name mark-data)
   (hashq-set! cnb:off-key-mark-defs name mark-data))

#(define (cnb:register-color! name hex-string)
   (hashq-set! cnb:color-defs name hex-string))


%% ---------------------------------------------------------------------------
%%  REGISTER DEFAULT DEFINITIONS
%%
%%  These correspond to the defaults in config.ly. If no notation config
%%  overrides the procedure, these defaults are available for resolution.
%% ---------------------------------------------------------------------------

#(cnb:register-path! 'default-oval cnb:notehead-shape-path)
#(cnb:register-hollow! 'default-oval-cutout cnb:notehead-hollow-path)
#(cnb:register-attachment! 'default-side
   (list
     (cons 'crotchet-up   '(1 . 0))
     (cons 'crotchet-down '(-1 . 0))
     (cons 'minim-up      '(1 . 0))
     (cons 'minim-down    '(-1 . 0))))


%% =========================================================================
%%  THE CONFIGURATION PROCEDURE
%%
%%  This is the central function that notation configs override.
%%  It takes three parameters and returns an association list describing
%%  how to render a notehead.
%%
%%  PARAMETERS:
%%    semitone  — pitch class 0–11 (C=0, C#=1, ..., B=11)
%%    duration  — duration category:
%%                  0 = breve or longer
%%                  1 = whole note
%%                  2 = half note
%%                  3 = quarter note or shorter
%%    key       — list of pitch classes in the current key,
%%                e.g., '(0 2 4 5 7 9 11) for C major
%%
%%  RETURN VALUE — an association list with these keys:
%%    shape        — symbol referencing cnb:path-defs
%%    color        — symbol referencing cnb:color-defs (recommended),
%%                   e.g., 'kite-primary. Notation configs register colors
%%                   with cnb:register-color!, score files can re-register
%%                   to override for accessibility.
%%                   Also accepts: hex string (e.g., "#7D3FFF") for fixed
%%                   colors that shouldn't be overridable, or integer
%%                   palette index (legacy, indexes cnb:color-palette).
%%    hollow       — #f (solid) or symbol referencing cnb:hollow-defs
%%    attachment   — symbol referencing cnb:attachment-defs
%%    off-key-mark — #f (none), or symbol referencing cnb:off-key-mark-defs,
%%                   or a built-in symbol: 'dot, 'ring, 'tick,
%%                   'sharp-sign, 'flat-sign, 'natural-sign
%%    x-offset     — optional. Horizontal offset in STAFF SPACES applied
%%                   to the notehead stencil (positive = right, negative
%%                   = left). Translating the stencil moves the grob's
%%                   extent, so stems, spacing, and ledgers follow the
%%                   moved head. Missing = 0 = today's behavior. Used by
%%                   pitch-axis configs to disambiguate shared-position
%%                   pitches (LY export spec v1.3 §6.3); the engine
%%                   honors the field whenever present, hook or not.
%%    repeat       — #t (default) or #f. Controls multi-notehead
%%                   repetition for longer durations. When #t, half notes
%%                   are doubled, whole notes quadrupled, etc. When #f,
%%                   a single notehead is rendered regardless of duration.
%%                   Use #f when distinct shapes are provided per duration
%%                   (e.g., separate minim and semibreve paths).
%%                   May be omitted — defaults to #t if absent.
%%
%%  HOW TO OVERRIDE (in your notation config file):
%%    #(set! cnb:get-notehead-config
%%       (lambda (semitone duration key)
%%         (cond
%%           ((cnb:in? semitone '(0 3 6 9))
%%            '((shape . my-shape) (color . "#FF0000") ...))
%%           (else
%%            '((shape . my-shape) (color . "#0000FF") ...)))))
%%
%%  The default implementation returns a monochrome oval for all inputs.
%% =========================================================================

#(define (cnb:get-notehead-config semitone duration key)
   `((shape      . default-oval)
     (color      . ,cnb:black)
     (hollow     . ,(if (odd? semitone) 'default-oval-cutout #f))
     (attachment . default-side)
     (off-key-mark . #f)
     (repeat     . #t)))


%% =========================================================================
%%  CONFIG RESOLVER
%%
%%  Takes a symbolic config alist (as returned by cnb:get-notehead-config)
%%  and resolves all symbol references to actual data by looking them up
%%  in the definition tables.
%%
%%  RESOLUTION RULES:
%%    shape       — looked up in cnb:path-defs
%%    color       — passed through as-is (already a hex string)
%%    hollow      — if #f, passed through. If symbol, looked up in
%%                  cnb:hollow-defs
%%    attachment  — looked up in cnb:attachment-defs
%%    off-key-mark — if #f, passed through. If symbol, looked up in
%%                   cnb:off-key-mark-defs. Built-in symbols ('dot,
%%                   'ring, 'tick, 'sharp-sign, etc.) pass through
%%                   if not found in the table — the engraver knows
%%                   how to handle them directly.
%%    x-offset    — number (staff spaces), passed through as-is.
%%                  Normalized to 0 if absent; a present non-number
%%                  warns and falls back to 0.
%%    repeat      — boolean, passed through as-is.
%%                  Defaults to #t if absent from config.
%%
%%  RETURNS:
%%    A new alist with the same keys but actual data instead of symbols.
%%    If a symbol is not found in its table, the resolved value is #f
%%    (except for off-key-mark built-ins which pass through).
%% =========================================================================

#(define (cnb:resolve-config config)
   (let* ((shape-sym    (assq-ref config 'shape))
          (color-val    (assq-ref config 'color))
          (hollow-sym   (assq-ref config 'hollow))
          (attach-sym   (assq-ref config 'attachment))
          (off-key-sym  (assq-ref config 'off-key-mark))
          ;; repeat: boolean, defaults to #t if absent
          (repeat-val   (let ((r (assq-ref config 'repeat)))
                          (if (eq? r #f)
                              ;; Distinguish "explicitly #f" from "absent".
                              ;; assq-ref returns #f for both, so check if
                              ;; the key actually exists in the alist.
                              (if (assq 'repeat config) #f #t)
                              #t)))

          ;; Resolve color: symbol → color-defs lookup,
          ;;                string → pass through (direct hex),
          ;;                integer → palette lookup (legacy support).
          ;;
          ;; The recommended approach is named color references:
          ;;   (color . kite-primary)
          ;; The notation config registers colors with cnb:register-color!,
          ;; and score files can re-register to override (e.g., for
          ;; accessibility). The resolver runs at cache-build time,
          ;; so it sees score-level overrides.
          ;;
          ;; Direct hex strings also work but aren't overridable:
          ;;   (color . "#7D3FFF")
          ;;
          ;; Integer palette indices are supported for backward compat:
          ;;   (color . 0)  → indexes into cnb:color-palette
          (resolved-color
            (let ((raw-color
                    (cond
                      ;; Symbol → look up in color-defs
                      ((symbol? color-val)
                       (or (hashq-ref cnb:color-defs color-val)
                           (begin
                             (ly:warning "cnb: unregistered color name '~a' — falling back to black. Did you forget to call cnb:register-color!?"
                                         color-val)
                             "#000000")))
                      ;; String → pass through (direct hex)
                      ((string? color-val) color-val)
                      ;; Integer → palette lookup (legacy)
                      ((integer? color-val)
                       (vector-ref cnb:color-palette
                         (modulo color-val (vector-length cnb:color-palette))))
                      ((number? color-val)
                       (vector-ref cnb:color-palette
                         (modulo (inexact->exact (round color-val))
                                 (vector-length cnb:color-palette))))
                      (else "#000000"))))
              ;; Safety: ensure we have a valid hex string
              (if (and (string? raw-color) (> (string-length raw-color) 0)
                       (eqv? (string-ref raw-color 0) #\#))
                  raw-color
                  (begin
                    (ly:warning "cnb: invalid color value '~a' — falling back to black" raw-color)
                    "#000000"))))

          ;; Resolve shape: symbol → path data
          (shape-data (if (symbol? shape-sym)
                         (hashq-ref cnb:path-defs shape-sym)
                         shape-sym))

          ;; Resolve hollow: #f passes through, symbol → path data
          (hollow-data (cond
                         ((not hollow-sym) #f)
                         ((symbol? hollow-sym)
                          (hashq-ref cnb:hollow-defs hollow-sym))
                         (else hollow-sym)))

          ;; Resolve attachment: symbol → alist of attachment points
          (attach-data (if (symbol? attach-sym)
                         (hashq-ref cnb:attachment-defs attach-sym)
                         attach-sym))

          ;; Resolve off-key mark: #f passes through, symbol → data
          ;; Built-in symbols (dot, ring, tick, sharp-sign, etc.)
          ;; pass through as symbols if not found in the table —
          ;; the engraver handles them directly.
          (off-key-data (cond
                          ((not off-key-sym) #f)
                          ((symbol? off-key-sym)
                           (or (hashq-ref cnb:off-key-mark-defs off-key-sym)
                               off-key-sym))
                          (else off-key-sym)))

          ;; x-offset: optional horizontal offset in staff spaces
          ;; (backlog 6.2 / E13-2). Absent = 0 = today's behavior.
          ;; A present non-number warns and falls back to 0 so a
          ;; misconfigured field cannot move a notehead silently.
          (x-offset-val (let ((x (assq-ref config 'x-offset)))
                          (cond
                            ((number? x) x)
                            ((not (assq 'x-offset config)) 0)
                            (else
                             (ly:warning "cnb: x-offset must be a number, got '~a' — using 0" x)
                             0)))))

     `((shape      . ,shape-data)
       (color      . ,resolved-color)
       (hollow     . ,hollow-data)
       (attachment . ,attach-data)
       (off-key-mark . ,off-key-data)
       (x-offset   . ,x-offset-val)
       (repeat     . ,repeat-val))))


%% =========================================================================
%%  CONFIG CACHE
%%
%%  Pre-computes resolved configs for all (semitone, duration) pairs
%%  under a given key. The engraver reads from this cache at render time
%%  instead of calling the procedure and resolver for every note.
%%
%%  CACHING STRATEGY:
%%    Currently uses on-demand mode: the cache is rebuilt each time the
%%    key changes. The cache holds 48 entries (12 semitones × 4 duration
%%    categories). Rebuilding is instant — it just calls the procedure
%%    and resolver <48 times.
%%
%%  ┌─────────────────────────────────────────────────────────────────┐
%%  │  TO SWITCH TO PRE-BUILD-ALL-KEYS MODE:                         │
%%  │                                                                 │
%%  │  The total space across all keys is small (~1,152 entries for   │
%%  │  24 standard keys). To pre-build everything at engraving start: │
%%  │                                                                 │
%%  │  1. Change cnb:config-cache to a nested hash:                   │
%%  │       outer key = sorted key pitch-class list (as a string)     │
%%  │       inner key = (cnb:make-cache-key semitone duration)        │
%%  │                                                                 │
%%  │  2. Add a key-list variable with all standard keys:             │
%%  │       (define cnb:standard-keys                                 │
%%  │         '((0 2 4 5 7 9 11)       ;; C major                    │
%%  │           (0 2 4 6 7 9 11)       ;; G major                    │
%%  │           (1 2 4 6 7 9 11)       ;; D major                    │
%%  │           ... all 12 major + 12 natural minor ...))             │
%%  │                                                                 │
%%  │  3. In cnb:build-config-cache, loop over all keys:              │
%%  │       (for-each (lambda (key-pcs)                               │
%%  │         (let ((key-str (format #f "~a" (sort key-pcs <))))      │
%%  │           (for-each ... build entries ...                        │
%%  │             (hash-set! outer-cache key-str inner-cache))))       │
%%  │         cnb:standard-keys)                                      │
%%  │                                                                 │
%%  │  4. Update cnb:lookup-config to take a key parameter:           │
%%  │       (define (cnb:lookup-config pc dur key-pcs)                │
%%  │         (let* ((key-str (format #f "~a" (sort key-pcs <)))      │
%%  │                (inner (hash-ref outer-cache key-str)))           │
%%  │           (hashv-ref inner (cnb:make-cache-key pc dur))))       │
%%  │                                                                 │
%%  │  See docs/CNB-PROJECT-PLAN.md section 3.5 for full analysis.   │
%%  └─────────────────────────────────────────────────────────────────┘
%%
%%  CACHE KEY ENCODING:
%%    Uses cnb:make-cache-key from utils.ly:
%%      key = pitch-class × 100 + duration-category
%%    Range: 0 to 1104. No collisions (verified in unit tests).
%%
%%  HASH TABLE TYPE:
%%    Uses hashv-set!/hashv-ref (eqv? comparison) for integer keys.
%%    This is safer than hashq- for integers, since eq? on integers
%%    is implementation-dependent for larger values (though our range
%%    is small enough that eq? would work in practice).
%% =========================================================================

#(define cnb:config-cache (make-hash-table))

%% Track the current key so we can detect key changes.
#(define cnb:current-cache-key '())

%% Track whether we've already validated the palette (once per build).
#(define cnb:palette-validated #f)

%% ---------------------------------------------------------------------------
%%  PALETTE VALIDATION
%%
%%  Checks that every entry in cnb:color-palette is a hex color string
%%  (starts with "#", length 7, all hex digits after "#").
%%  Common mistakes this catches:
%%    - Unquoted hex: #009e73 → Scheme reads as integer 0 or error
%%    - Missing "#": "009e73" → not a valid hex color string
%%    - Wrong type: number, symbol, #f, etc.
%%
%%  Called once at first cache build. Warns per bad entry.
%% ---------------------------------------------------------------------------

#(define (cnb:validate-color-palette)
   (if (not cnb:palette-validated)
       (begin
         (set! cnb:palette-validated #t)
         (let ((len (vector-length cnb:color-palette)))
           (if (= len 0)
               (ly:warning "cnb: cnb:color-palette is empty — noteheads will have no color"))
           (let loop ((i 0))
             (if (< i len)
                 (let ((entry (vector-ref cnb:color-palette i)))
                   (cond
                     ((not (string? entry))
                      (ly:warning "cnb: cnb:color-palette[~a] is ~a (type: ~a), expected a hex color string like \"#FF0000\". Did you forget to quote the value?"
                                  i entry (class-of entry)))
                     ((not (eqv? (string-ref entry 0) #\#))
                      (ly:warning "cnb: cnb:color-palette[~a] = \"~a\" — missing '#' prefix. Expected format: \"#RRGGBB\""
                                  i entry))
                     ((not (= (string-length entry) 7))
                      (ly:warning "cnb: cnb:color-palette[~a] = \"~a\" — expected 7 characters (#RRGGBB), got ~a"
                                  i entry (string-length entry))))
                   (loop (+ i 1)))))))))

#(define (cnb:build-config-cache key-pitch-classes)
   ;; Validate palette on first build
   (cnb:validate-color-palette)

   ;; Replace the cache with a fresh table
   (set! cnb:config-cache (make-hash-table))
   (set! cnb:current-cache-key (sort (list-copy key-pitch-classes) <))

   ;; Pre-compute for all 12 pitch classes × 4 duration categories
   (for-each
     (lambda (semitone)
       (for-each
         (lambda (dur-cat)
           (let* ((config   (cnb:get-notehead-config
                              semitone dur-cat key-pitch-classes))
                  (resolved (cnb:resolve-config config))
                  (ckey     (cnb:make-cache-key semitone dur-cat)))
             (hashv-set! cnb:config-cache ckey resolved)))
         '(0 1 2 3)))
     (iota 12)))


#(define (cnb:lookup-config pitch-class duration-category)
   ;; Returns the resolved config alist, or #f if cache miss.
   (hashv-ref cnb:config-cache
              (cnb:make-cache-key pitch-class duration-category)))


%% ---------------------------------------------------------------------------
%%  CACHE REBUILD ON KEY CHANGE
%%
%%  Call this when the key signature changes during engraving.
%%  It only rebuilds if the key has actually changed (compares sorted
%%  pitch-class lists).
%% ---------------------------------------------------------------------------

#(define (cnb:ensure-cache-for-key key-pitch-classes)
   (let ((sorted-key (sort (list-copy key-pitch-classes) <)))
     (if (not (equal? sorted-key cnb:current-cache-key))
         (cnb:build-config-cache key-pitch-classes))))


%% ---------------------------------------------------------------------------
%%  CONVENIENCE: Extract a single field from a resolved config.
%%
%%  EXAMPLES:
%%    (cnb:config-field resolved-config 'color)     → "#7D3FFF"
%%    (cnb:config-field resolved-config 'shape)     → ((moveto 0 0.6667) ...)
%%    (cnb:config-field resolved-config 'hollow)    → #f or path data
%% ---------------------------------------------------------------------------

#(define (cnb:config-field config field-name)
   (assq-ref config field-name))
