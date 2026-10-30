import { useState, useRef, useEffect, useCallback, useMemo } from "react";

const ID_PREFIXES = [
  "nh-", "st-", "dt-", "ac-", "fl-", "bm-",
  "rs-", "bl-", "cl-", "ks-", "ts-", "ll-",
  "staff-symbol", "sl-"
];

const HIGHLIGHT_COLOR = "#ff0080";
const GRID_COLOR = "#ff0080";

const TYPE_LABEL_COLORS = {
  notehead: "#c0392b",
  stem: "#d35400",
  dots: "#8e44ad",
  accidental: "#e67e22",
  flag: "#16a085",
  beam: "#2980b9",
  rest: "#27ae60",
  barline: "#7f8c8d",
  clef: "#f39c12",
  "key-signature": "#c0392b",
  "time-signature": "#e74c3c",
  "ledger-line": "#795548",
  "staff-symbol": "#95a5a6",
  slur: "#2ecc71",
  tie: "#1abc9c",
  grid: GRID_COLOR,
  unknown: "#666",
};

// Types whose bounding box may span multiple grid cells.
// These get all 4 corner attributes; others get only data-grid-tl.
// Extend this set as new spanning types are added.
const SPANNING_TYPES = new Set(["beam", "slur", "tie", "barline"]);

// Types that inherently span the entire system (no single measure).
// Excluded from measure-mismatch diagnostics entirely.
const SYSTEM_WIDE_TYPES = new Set(["staff-symbol"]);

function isTaggedId(id) {
  return id && ID_PREFIXES.some((p) => id.startsWith(p));
}

function findTaggedAncestor(el, boundary) {
  let cur = el;
  while (cur && cur !== boundary) {
    const id = cur.getAttribute?.("id") || "";
    if (isTaggedId(id)) return cur;
    cur = cur.parentElement;
  }
  return null;
}

function getDataAttrs(el) {
  if (!el?.attributes) return {};
  const out = { id: el.getAttribute("id") };
  for (const attr of el.attributes) {
    if (attr.name.startsWith("data-")) out[attr.name] = attr.value;
  }
  return out;
}

const ZOOM_MIN = 0.05;
const ZOOM_MAX = 30;
function zoomToSlider(z) {
  const logMin = Math.log(ZOOM_MIN);
  const logMax = Math.log(ZOOM_MAX);
  return Math.round(((Math.log(z) - logMin) / (logMax - logMin)) * 100);
}
function sliderToZoom(s) {
  const logMin = Math.log(ZOOM_MIN);
  const logMax = Math.log(ZOOM_MAX);
  return Math.exp(logMin + (s / 100) * (logMax - logMin));
}


// =========================================================================
//  GRID COMPUTATION — extract staff geometry & barlines from loaded SVG DOM
// =========================================================================

function parseTranslate(el) {
  // Extract translate(x, y) from the transform attribute
  const tf = el?.getAttribute?.("transform") || "";
  const m = tf.match(/translate\(\s*([-\d.]+)\s*[,\s]\s*([-\d.]+)\s*\)/);
  if (m) return { x: parseFloat(m[1]), y: parseFloat(m[2]) };
  return null;
}

function computeGridData(svgWrapEl) {
  // Find all staff-symbol elements → each one is a system
  const staffSymbols = svgWrapEl.querySelectorAll('[data-type="staff-symbol"]');
  if (!staffSymbols.length) return null;

  const systems = [];
  let staffLeftX = Infinity;
  let staffRightX = -Infinity;

  staffSymbols.forEach((ss) => {
    const lineYs = [];
    // Staff lines are <line> elements inside <g transform="translate(x, y)">
    ss.querySelectorAll("g > line").forEach((line) => {
      const parentG = line.parentElement;
      const t = parseTranslate(parentG);
      if (!t) return;

      const x1 = parseFloat(line.getAttribute("x1") || "0");
      const x2 = parseFloat(line.getAttribute("x2") || "0");
      const y1 = parseFloat(line.getAttribute("y1") || "0");
      const y2 = parseFloat(line.getAttribute("y2") || "0");

      // Only horizontal lines (staff lines)
      if (Math.abs(y1 - y2) < 0.5) {
        lineYs.push(t.y + y1);
        const lx = t.x + x1;
        const rx = t.x + x2;
        if (lx < staffLeftX) staffLeftX = lx;
        if (rx > staffRightX) staffRightX = rx;
      }
    });

    if (lineYs.length > 0) {
      lineYs.sort((a, b) => a - b);
      systems.push({
        lineYs,
        topY: lineYs[0],
        bottomY: lineYs[lineYs.length - 1],
        centerY: (lineYs[0] + lineYs[lineYs.length - 1]) / 2,
      });
    }
  });

  if (systems.length === 0) return null;

  // Sort systems by vertical position (top to bottom)
  systems.sort((a, b) => a.topY - b.topY);

  // Compute system row boundaries (midpoints between adjacent systems)
  const rowBoundaries = [];
  for (let i = 0; i < systems.length - 1; i++) {
    const midY = (systems[i].bottomY + systems[i + 1].topY) / 2;
    rowBoundaries.push(midY);
  }

  // Collect barlines and assign to systems
  const barlineEls = svgWrapEl.querySelectorAll('[data-type="barline"]');
  const barlines = [];

  barlineEls.forEach((bl) => {
    const measure = bl.getAttribute("data-measure") || "?";
    // Barline position: the <rect> is inside a <g transform="translate(x, y)">
    const innerG = bl.querySelector("g[transform]");
    if (!innerG) return;
    const t = parseTranslate(innerG);
    if (!t) return;

    // The rect inside gives the x offset and width within the translate
    const rect = innerG.querySelector("rect");
    const rectX = rect ? parseFloat(rect.getAttribute("x") || "0") : 0;
    const rectW = rect ? parseFloat(rect.getAttribute("width") || "0") : 0;

    // Use the center of the barline rect as the grid boundary
    const blX = t.x + rectX + rectW / 2;
    const blY = t.y;

    // Find which system this barline belongs to
    let sysIdx = 0;
    for (let i = 0; i < rowBoundaries.length; i++) {
      if (blY > rowBoundaries[i]) sysIdx = i + 1;
    }

    barlines.push({ x: blX, y: blY, measure, systemIndex: sysIdx });
  });

  // Group barlines by system
  const barlinesBySystem = systems.map(() => []);
  barlines.forEach((bl) => {
    if (bl.systemIndex < barlinesBySystem.length) {
      barlinesBySystem[bl.systemIndex].push(bl);
    }
  });
  // Sort each system's barlines by x
  barlinesBySystem.forEach((bls) => bls.sort((a, b) => a.x - b.x));

  // Find preamble right edge per system (from key-sig, time-sig, clef)
  const preambleTypes = ["key-signature", "time-signature", "clef"];
  const preambleRightBySystem = systems.map(() => null);

  preambleTypes.forEach((ptype) => {
    svgWrapEl.querySelectorAll(`[data-type="${ptype}"]`).forEach((el) => {
      // Get bounding position — use getBoundingClientRect relative approach
      // or just parse transforms. For simplicity, get the element's
      // rough x extent from its contained drawing primitives.
      // We'll use a simpler approach: find max x from all translate values
      let maxX = -Infinity;
      el.querySelectorAll("g[transform]").forEach((g) => {
        const tf = g.getAttribute("transform") || "";
        // Handle translate
        const tm = tf.match(/translate\(\s*([-\d.]+)/);
        if (tm) {
          const x = parseFloat(tm[1]);
          if (x > maxX) maxX = x;
        }
        // Handle scale — need to account for scaled coordinates
        const sm = tf.match(/scale\(\s*([-\d.]+)/);
        if (sm) {
          const scale = parseFloat(sm[1]);
          // Find translates inside this scaled group
          g.querySelectorAll("g[transform]").forEach((inner) => {
            const itm = (inner.getAttribute("transform") || "").match(/translate\(\s*([-\d.]+)/);
            if (itm) {
              const sx = parseFloat(itm[1]) * scale;
              if (sx > maxX) maxX = sx;
            }
          });
        }
      });

      if (maxX > -Infinity) {
        // Determine which system this preamble element belongs to
        // Use data-measure to help, and match to system by position
        const measure = el.getAttribute("data-measure") || "1";

        // For each system, check if this is likely the first measure preamble
        // by checking if any of the element's y values fall within the system's range
        for (let si = 0; si < systems.length; si++) {
          const sys = systems[si];
          // If the preamble element's rightmost x is within reasonable range of staff left
          // and its y is near this system, assign it
          if (maxX < staffLeftX + 30) {
            // Check y proximity — look for any translate y within system range
            let matchesSystem = false;
            el.querySelectorAll("g[transform]").forEach((g) => {
              const tm = (g.getAttribute("transform") || "").match(/translate\(\s*[-\d.]+\s*[,\s]\s*([-\d.]+)/);
              if (tm) {
                const y = parseFloat(tm[1]);
                if (y >= sys.topY - 5 && y <= sys.bottomY + 5) matchesSystem = true;
              }
              // Also check scaled translates
              const sm = (g.getAttribute("transform") || "").match(/scale\(\s*([-\d.]+)/);
              if (sm) {
                const scale = parseFloat(sm[1]);
                g.querySelectorAll("g[transform]").forEach((inner) => {
                  const itm = (inner.getAttribute("transform") || "").match(/translate\(\s*[-\d.]+\s*[,\s]\s*([-\d.]+)/);
                  if (itm) {
                    const sy = parseFloat(itm[1]) * scale;
                    if (sy >= sys.topY - 5 && sy <= sys.bottomY + 5) matchesSystem = true;
                  }
                });
              }
            });

            if (matchesSystem) {
              // Add ~1.5 units padding to the right of the rightmost preamble element
              const rightEdge = maxX + 1.5;
              if (preambleRightBySystem[si] === null || rightEdge > preambleRightBySystem[si]) {
                preambleRightBySystem[si] = rightEdge;
              }
            }
          }
        }
      }
    });
  });

  return {
    systems,
    rowBoundaries,
    barlinesBySystem,
    staffLeftX: staffLeftX === Infinity ? 0 : staffLeftX,
    staffRightX: staffRightX === -Infinity ? 100 : staffRightX,
    preambleRightBySystem,
  };
}


// =========================================================================
//  GRID-LOCATION ENRICHMENT
//  Maps each tagged element's bounding box corners to grid cells (S{n}-M{m}).
//  Non-spanning types get only data-grid-tl.
//  Spanning types (beams, slurs, ties, barlines) get all 4 corners.
//  Returns enrichment stats + diagnostic mismatch records.
// =========================================================================

function buildPointToGridCell(gridData) {
  /**
   * Returns a function: (x, y) => "S{n}-M{m}"
   *
   * Vertical: system determined by row boundaries (midpoints between systems).
   * Horizontal: measure determined by barline x-positions within that system.
   *
   * Convention (from test-ids.ly / harvest_svg.py):
   *   bl-N marks the LEFT edge of measure N.
   *   Area before first barline on a system = the measure preceding bl-N
   *     (i.e., if first barline is bl-2, area before it is measure 1).
   *   Area from bl-N.x to bl-(N+1).x = measure N.
   *   Area past the last barline = that barline's measure.
   */
  const { systems, rowBoundaries, barlinesBySystem, staffRightX } = gridData;

  return function pointToGridCell(x, y) {
    // --- Vertical: find system ---
    let sysIdx = 0;
    for (let i = 0; i < rowBoundaries.length; i++) {
      if (y > rowBoundaries[i]) sysIdx = i + 1;
    }
    if (sysIdx >= systems.length) sysIdx = systems.length - 1;

    // --- Horizontal: find measure within system ---
    const bls = barlinesBySystem[sysIdx] || [];
    let measureLabel;

    if (bls.length === 0) {
      // No barlines on this system — everything is measure 1
      measureLabel = "1";
    } else if (x < bls[0].x) {
      // Before the first barline: measure = firstBarlineMeasure - 1
      // (the preamble and first measure's content live here)
      const firstBlMeasure = parseInt(bls[0].measure, 10);
      measureLabel = isNaN(firstBlMeasure) ? "1" : String(firstBlMeasure - 1);
    } else {
      // Walk through barline segments: bl[i].x to bl[i+1].x = measure bl[i].measure
      measureLabel = bls[bls.length - 1].measure; // fallback: past last barline
      for (let i = 0; i < bls.length; i++) {
        const nextX = i + 1 < bls.length ? bls[i + 1].x : Infinity;
        if (x >= bls[i].x && x < nextX) {
          measureLabel = bls[i].measure;
          break;
        }
      }
    }

    return `S${sysIdx + 1}-M${measureLabel}`;
  };
}

function extractMeasureFromCell(cell) {
  /** Extract the measure number string from a grid cell label like "S1-M3". */
  if (!cell) return null;
  const m = cell.match(/M(\w+)$/);
  return m ? m[1] : null;
}

function assignGridLocations(svgWrapEl, gridData) {
  /**
   * Enriches every tagged SVG element with data-grid-* attributes:
   *   data-grid-tl  — always set (top-left corner's grid cell)
   *   data-grid-tr  — only for SPANNING_TYPES (top-right)
   *   data-grid-bl  — only for SPANNING_TYPES (bottom-left)
   *   data-grid-br  — only for SPANNING_TYPES (bottom-right)
   *
   * Runs measure-mismatch diagnostics:
   *   For non-spanning types: data-measure must match tl cell's measure.
   *   For spanning types: data-measure must appear in at least one corner.
   *   System-wide types (staff-symbol): skipped entirely.
   *
   * Returns: { enriched, skipped, diagnostics[] }
   *
   * NOTE: Requires that the SVG is attached to the DOM and laid out
   * (so getBBox works). Call inside requestAnimationFrame after injection.
   */
  if (!gridData) return { enriched: 0, skipped: 0, diagnostics: [] };

  const ptToCell = buildPointToGridCell(gridData);
  let enriched = 0;
  let skipped = 0;
  const diagnostics = [];

  svgWrapEl.querySelectorAll("[id]").forEach((el) => {
    const id = el.getAttribute("id");
    if (!isTaggedId(id)) return;

    const dataType = el.getAttribute("data-type") || "unknown";
    const dataMeasure = el.getAttribute("data-measure"); // may be null

    // --- Get bounding box ---
    // Tagged elements are top-level <g> with no transform on themselves,
    // so getBBox() returns coordinates in the SVG viewBox space.
    let bbox;
    try {
      bbox = el.getBBox();
    } catch (_) {
      skipped++;
      return;
    }
    if (bbox.width === 0 && bbox.height === 0) {
      skipped++;
      return;
    }

    // --- Map corners to grid cells ---
    const tl = ptToCell(bbox.x, bbox.y);
    el.setAttribute("data-grid-tl", tl);

    const isSpanning = SPANNING_TYPES.has(dataType);
    let tr = null, bl = null, br = null;
    if (isSpanning) {
      tr = ptToCell(bbox.x + bbox.width, bbox.y);
      bl = ptToCell(bbox.x, bbox.y + bbox.height);
      br = ptToCell(bbox.x + bbox.width, bbox.y + bbox.height);
      el.setAttribute("data-grid-tr", tr);
      el.setAttribute("data-grid-bl", bl);
      el.setAttribute("data-grid-br", br);
    }

    enriched++;

    // --- Measure-mismatch diagnostic ---
    if (!dataMeasure || SYSTEM_WIDE_TYPES.has(dataType)) return;

    if (isSpanning) {
      // For spanning types: data-measure should appear in at least one corner
      const cornerMeasures = new Set(
        [tl, tr, bl, br].filter(Boolean).map(extractMeasureFromCell).filter(Boolean)
      );
      if (!cornerMeasures.has(dataMeasure)) {
        diagnostics.push({
          id,
          type: dataType,
          severity: "warning",
          dataMeasure,
          gridCells: { tl, tr, bl, br },
          cornerMeasures: [...cornerMeasures],
          message: `data-measure=${dataMeasure} not in any corner [${[...cornerMeasures].join(", ")}]`,
        });
      }
    } else {
      // For non-spanning types: data-measure should match the tl corner's measure
      const gridMeasure = extractMeasureFromCell(tl);
      if (gridMeasure && gridMeasure !== dataMeasure) {
        diagnostics.push({
          id,
          type: dataType,
          severity: "error",
          dataMeasure,
          gridMeasure,
          gridCell: tl,
          message: `data-measure=${dataMeasure} but grid says M${gridMeasure}`,
        });
      }
    }
  });

  return { enriched, skipped, diagnostics };
}


// =========================================================================
//  DIAGNOSTIC PANEL COMPONENT
// =========================================================================

function DiagnosticPanel({ diagnostics, enriched, skipped, onHighlight }) {
  const [expanded, setExpanded] = useState(false);

  const errors = diagnostics.filter((d) => d.severity === "error");
  const warnings = diagnostics.filter((d) => d.severity === "warning");

  // Group by type for summary
  const byType = {};
  diagnostics.forEach((d) => {
    byType[d.type] = (byType[d.type] || 0) + 1;
  });

  const hasIssues = diagnostics.length > 0;

  return (
    <div>
      {/* Indicator bar — always visible once enrichment has run */}
      <div
        onClick={() => setExpanded((v) => !v)}
        style={{
          padding: "3px 12px",
          background: hasIssues ? "#fef3f2" : "#f0fdf4",
          borderTop: `1px solid ${hasIssues ? "#fecaca" : "#bbf7d0"}`,
          fontSize: 10,
          cursor: "pointer",
          display: "flex",
          alignItems: "center",
          gap: 8,
          userSelect: "none",
        }}
      >
        <span style={{ color: hasIssues ? "#e74c3c" : "#27ae60", fontWeight: 700 }}>
          {hasIssues ? "⚠" : "✓"} GRID DIAGNOSTICS
        </span>
        <span style={{ color: "#888" }}>
          {enriched} enriched · {skipped} skipped
          {errors.length > 0 && ` · ${errors.length} error${errors.length !== 1 ? "s" : ""}`}
          {warnings.length > 0 && ` · ${warnings.length} warning${warnings.length !== 1 ? "s" : ""}`}
          {!hasIssues && " · all clear"}
        </span>
        <span style={{ color: "#bbb", marginLeft: "auto" }}>
          {expanded ? "▼" : "▶"}
          {hasIssues ? ` ${diagnostics.length} issue${diagnostics.length !== 1 ? "s" : ""}` : ""}
        </span>
      </div>

      {/* Expanded detail panel */}
      {expanded && (
        <div style={{
          maxHeight: 220,
          overflowY: "auto",
          background: "#fff",
          borderTop: "1px solid #eee",
          fontSize: 10,
          lineHeight: 1.6,
        }}>
          {diagnostics.length === 0 && (
            <div style={{ padding: "8px 12px", color: "#27ae60" }}>
              All {enriched} tagged elements have consistent measure attributes and grid locations.
            </div>
          )}

          {/* Summary by type */}
          {diagnostics.length > 0 && (
            <div style={{ padding: "6px 12px", borderBottom: "1px solid #f5f5f5", color: "#888" }}>
              By type: {Object.entries(byType)
                .sort((a, b) => b[1] - a[1])
                .map(([t, c]) => `${t}(${c})`)
                .join(", ")}
            </div>
          )}

          {/* Individual issues — errors first, then warnings */}
          {[...errors, ...warnings].map((d, i) => (
            <div
              key={i}
              onClick={() => onHighlight?.(d.id)}
              style={{
                padding: "3px 12px",
                borderBottom: "1px solid #f9f9f9",
                cursor: "pointer",
                display: "flex",
                gap: 8,
                alignItems: "baseline",
              }}
              title={`Click to highlight ${d.id}`}
            >
              <span style={{
                color: d.severity === "error" ? "#e74c3c" : "#f39c12",
                fontWeight: 700,
                minWidth: 14,
              }}>
                {d.severity === "error" ? "✗" : "⚠"}
              </span>
              <span style={{
                color: TYPE_LABEL_COLORS[d.type] || "#666",
                minWidth: 85,
              }}>
                {d.type}
              </span>
              <span style={{
                color: HIGHLIGHT_COLOR,
                fontWeight: 600,
                minWidth: 150,
                fontFamily: "inherit",
              }}>
                {d.id}
              </span>
              <span style={{ color: "#666", flex: 1 }}>
                {d.message}
              </span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}


// =========================================================================
//  NORMALIZATION LAYER — builds clean, semantically structured SVG elements
//  from the raw LilyPond output. Starts with staff lines; designed to
//  extend incrementally to noteheads, stems, barlines, etc.
//
//  Architecture:
//    buildNormalizedData()  → { defs[], uses[], warnings[], stats }
//    NormalizationOverlay() → renders <svg> with <defs> + flat/grouped elements
//
//  Generic bottom-up normalization:
//    1. Find all data-type elements in the SVG
//    2. For each, find leaf descendants (path, line, rect, text)
//    3. Walk ancestor chain from each leaf to its data-type boundary
//       → extract shape fingerprint, accumulated transform, color
//    4. Deduplicate leaf shapes → Level 1 defs (atomic shapes)
//    5. Group leaves within each data-type element by position
//       → Leaves at same position form a "sub-group" (e.g., outer + cutout)
//    6. Deduplicate sub-group patterns → Level 2 defs (compound groups)
//    7. Emit per-instance <use> elements with fill + transform
//
//  The algorithm is config-agnostic: it works with any notation style
//  and handles all element types (noteheads, stems, barlines, etc.)
//  with zero type-specific code.
// =========================================================================

const NORM_COLOR = "#0066cc";  // Blue accent for norm layer UI elements
const LEAF_TAGS = new Set(["path", "line", "rect", "circle", "ellipse", "text"]);

function stripNs(tag) {
  const i = tag.indexOf("}");
  return i >= 0 ? tag.slice(i + 1) : tag;
}

/**
 * Compute a shape-identity fingerprint for a leaf element.
 * Position is excluded — only intrinsic geometry matters.
 */
function leafFingerprint(el) {
  const tag = stripNs(el.tagName);
  if (tag === "path") {
    const d = el.getAttribute("d") || "";
    const dRounded = d.replace(
      /[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?/g,
      (m) => String(round4(parseFloat(m)))
    );
    return { type: "path", key: `path:${dRounded}`, attrs: { d: dRounded } };
  }
  if (tag === "line") {
    const x1 = parseFloat(el.getAttribute("x1") || 0);
    const y1 = parseFloat(el.getAttribute("y1") || 0);
    const x2 = parseFloat(el.getAttribute("x2") || 0);
    const y2 = parseFloat(el.getAttribute("y2") || 0);
    const dx = round4(x2 - x1), dy = round4(y2 - y1);
    const sw = el.getAttribute("stroke-width") || "";
    const lc = el.getAttribute("stroke-linecap") || "";
    const lj = el.getAttribute("stroke-linejoin") || "";
    return {
      type: "line",
      key: `line:${dx},${dy},sw=${sw},lc=${lc},lj=${lj}`,
      attrs: { x1: 0, y1: 0, x2: dx, y2: dy,
        ...(sw ? { strokeWidth: sw } : {}),
        ...(lc ? { strokeLinecap: lc } : {}),
        ...(lj ? { strokeLinejoin: lj } : {}),
      },
      // Local offset: where the line starts in its parent's coordinate space
      localOffset: [round4(x1), round4(y1)],
    };
  }
  if (tag === "rect") {
    const x = round4(parseFloat(el.getAttribute("x") || 0));
    const y = round4(parseFloat(el.getAttribute("y") || 0));
    const w = round4(parseFloat(el.getAttribute("width") || 0));
    const h = round4(parseFloat(el.getAttribute("height") || 0));
    return {
      type: "rect", key: `rect:${w},${h}`,
      attrs: { width: w, height: h },
      localOffset: [x, y],
    };
  }
  if (tag === "text") {
    const text = el.textContent || "";
    const font = el.getAttribute("font-family") || "";
    const size = el.getAttribute("font-size") || "";
    const weight = el.getAttribute("font-weight") || "";
    const anchor = el.getAttribute("text-anchor") || "";
    return {
      type: "text", key: `text:${font}:${weight}:${size}:${anchor}:${text}`,
      attrs: { fontFamily: font, fontWeight: weight, fontSize: size, textAnchor: anchor },
      text,
    };
  }
  return { type: tag, key: `${tag}:unknown`, attrs: {} };
}

/**
 * Walk from a leaf element up to (but not including) the boundary element,
 * extracting transform components and color from each ancestor.
 *
 * Returns: { rawTransforms[], color, colorIsWhite, stroke, strokeWidth, leafFill }
 *
 * rawTransforms is in nesting order (outermost first), which is the correct
 * order for concatenation into a single SVG transform attribute.
 * The leaf's own transform (if any) is appended last.
 */
function walkAncestorChain(leafEl, boundaryEl) {
  const ancestors = [];
  let cur = leafEl.parentElement;
  while (cur && cur !== boundaryEl) {
    ancestors.push(cur);
    cur = cur.parentElement;
  }
  ancestors.reverse(); // outermost first (boundary's child → leaf's parent)

  const rawTransforms = [];
  let color = null;
  let stroke = null;
  let strokeWidth = null;

  for (const anc of ancestors) {
    const tf = anc.getAttribute("transform");
    if (tf) rawTransforms.push(tf);

    // Color (closest to leaf wins, since we walk top-down and overwrite)
    const c = anc.getAttribute("color");
    if (c && c !== "currentColor") color = c;

    // Stroke (for staff lines, barlines)
    const s = anc.getAttribute("stroke");
    if (s && s !== "currentColor") stroke = s;

    const sw = anc.getAttribute("stroke-width");
    if (sw) strokeWidth = parseFloat(sw);
  }

  // Include the leaf element's own transform (e.g., time-sig path has scale on it)
  const leafTf = leafEl.getAttribute("transform");
  if (leafTf) rawTransforms.push(leafTf);

  // Check the leaf itself for fill, stroke
  const leafFill = leafEl.getAttribute("fill");
  const leafStroke = leafEl.getAttribute("stroke");
  const leafSW = leafEl.getAttribute("stroke-width");
  if (leafStroke && leafStroke !== "currentColor") stroke = leafStroke;
  if (leafSW) strokeWidth = parseFloat(leafSW);

  // Determine if color is white
  let colorIsWhite = false;
  if (color) {
    if (/100\.0+%.*100\.0+%.*100\.0+%/.test(color)) colorIsWhite = true;
    if (color.toLowerCase() === "#ffffff" || color.toLowerCase() === "#fff" || color.toLowerCase() === "white") colorIsWhite = true;
  }

  return {
    rawTransforms,
    color,
    colorIsWhite,
    stroke,
    strokeWidth,
    leafFill,
  };
}

/**
 * Build a compound sub-group signature for deduplication.
 * Captures shape identities and color roles, NOT position/rotation/scale.
 */
function compoundSignature(subgroup, shapeIndex) {
  return subgroup.map((li) => {
    const shapeId = shapeIndex[li.fp.key];
    const role = li.chain.colorIsWhite ? "fixed:white" : "inherit";
    return `${shapeId}:${role}`;
  }).join("|");
}

/**
 * Extract the last translate (x, y) from a raw transforms array.
 * Used for grouping leaves by position within a data-type element.
 */
function extractTranslate(rawTransforms) {
  let tx = 0, ty = 0;
  for (const tf of rawTransforms) {
    const tm = tf.match(/translate\(\s*([-\d.]+)\s*[,\s]\s*([-\d.]+)\s*\)/);
    if (tm) {
      tx = round4(parseFloat(tm[1]));
      ty = round4(parseFloat(tm[2]));
    }
  }
  return [tx, ty];
}


function buildNormalizedData(svgWrapEl, gridData) {
  /**
   * Generic bottom-up normalization.
   * Processes ALL data-type elements in the SVG uniformly.
   */
  if (!gridData) return null;

  const warnings = [];

  // ─── Find all data-type elements ───
  const dtElements = svgWrapEl.querySelectorAll("[data-type]");
  if (!dtElements.length) {
    warnings.push("No data-type elements found in SVG");
    return { defs: [], uses: [], warnings, stats: {} };
  }

  // ─── Analyze each element: find leaves, fingerprint, walk chains ───
  const analyses = [];

  dtElements.forEach((dtEl) => {
    const dtId = dtEl.getAttribute("id") || "?";
    const dtType = dtEl.getAttribute("data-type") || "unknown";

    // Collect all data-* attributes for passthrough
    const dataAttrs = {};
    for (const attr of dtEl.attributes) {
      if (attr.name.startsWith("data-")) {
        dataAttrs[attr.name] = attr.value;
      }
    }

    // Find all leaf descendants
    const leaves = [];
    const walk = (el) => {
      for (const child of el.children) {
        const tag = stripNs(child.tagName);
        if (LEAF_TAGS.has(tag)) {
          leaves.push(child);
        }
        // Always recurse (leaves might be nested inside <g>, <a>, etc.)
        walk(child);
      }
    };
    walk(dtEl);

    const leafInfos = leaves.map((leaf) => {
      const fp = leafFingerprint(leaf);
      const chain = walkAncestorChain(leaf, dtEl);
      return { fp, chain };
    });

    analyses.push({ dtId, dtType, dataAttrs, leafInfos });
  });

  // ─── Level 1: Deduplicate atomic shapes ───
  const shapeIndex = {};  // fp.key → def id
  let shapeCounter = 0;
  const shapeDefs = [];   // { id, tag, attrs, text? }

  for (const a of analyses) {
    for (const li of a.leafInfos) {
      const key = li.fp.key;
      if (!(key in shapeIndex)) {
        shapeCounter++;
        const id = `leaf-${shapeCounter}`;
        shapeIndex[key] = id;
        shapeDefs.push({ id, tag: li.fp.type, attrs: li.fp.attrs, text: li.fp.text || null });
      }
    }
  }

  // ─── Group leaves into sub-groups by position within each element ───
  // Leaves at the same translate form a sub-group (e.g., outer diamond + white cutout)
  function groupByPosition(leafInfos) {
    const byPos = {};
    for (const li of leafInfos) {
      const [tx, ty] = extractTranslate(li.chain.rawTransforms);
      const key = `${tx},${ty}`;
      if (!byPos[key]) byPos[key] = [];
      byPos[key].push(li);
    }
    // Sort groups by x-position descending (matches LilyPond's ordering)
    return Object.entries(byPos)
      .sort((a, b) => {
        const [ax] = a[0].split(",").map(Number);
        const [bx] = b[0].split(",").map(Number);
        return bx - ax;
      })
      .map(([, group]) => group);
  }

  // ─── Level 2: Deduplicate compound groups ───
  const compoundIndex = {};   // signature → def id
  let compoundCounter = 0;
  const compoundDefs = [];    // { id, children: [{ href, fill? }] }

  // Also build the uses array
  const uses = [];

  for (const a of analyses) {
    if (a.leafInfos.length === 0) continue;

    const subgroups = groupByPosition(a.leafInfos);
    const subUses = [];

    for (const sg of subgroups) {
      const sig = compoundSignature(sg, shapeIndex);

      // Register compound if new
      if (!(sig in compoundIndex)) {
        compoundCounter++;
        const cid = `compound-${compoundCounter}`;
        compoundIndex[sig] = cid;

        const children = sg.map((li) => {
          const child = { href: `#${shapeIndex[li.fp.key]}` };
          if (li.chain.colorIsWhite) child.fill = "white";
          return child;
        });
        compoundDefs.push({ id: cid, children });
      }

      const compoundId = compoundIndex[sig];
      const compoundDef = compoundDefs.find((d) => d.id === compoundId);

      // Determine what href to use:
      // If compound is a single shape with inheriting color, use the shape directly
      const isSingleAlias = compoundDef.children.length === 1 && !compoundDef.children[0].fill;
      const href = isSingleAlias ? compoundDef.children[0].href : `#${compoundId}`;

      // Per-instance color: first non-white leaf's color
      let fillColor = null;
      let instanceStroke = null;
      let instanceStrokeWidth = null;
      let leafType = sg[0].fp.type; // "path", "line", "rect", "text"

      for (const li of sg) {
        if (!li.chain.colorIsWhite && li.chain.color) {
          fillColor = li.chain.color;
          break;
        }
      }
      // For elements without ancestor color (staff lines, barlines), default to black
      // Lines use stroke, paths/rects use fill
      if (leafType === "line") {
        instanceStroke = fillColor || "#000000";
        fillColor = null; // lines don't use fill
      }
      // Check if leaf has explicit strokeWidth
      for (const li of sg) {
        if (li.chain.strokeWidth != null) { instanceStrokeWidth = li.chain.strokeWidth; break; }
      }

      // Build transform string by concatenating raw transforms in chain order.
      // This preserves the correct nesting semantics (scale/translate order matters).
      const rep = sg[0].chain; // representative (all in subgroup share same transforms)
      const localOff = sg[0].fp.localOffset;
      let transform = rep.rawTransforms.join(" ");

      // If the leaf has a local offset (e.g., line with non-zero x1), append a translate
      if (localOff && (localOff[0] !== 0 || localOff[1] !== 0)) {
        transform += ` translate(${localOff[0]},${localOff[1]})`;
      }

      subUses.push({
        href,
        fill: fillColor || null,
        stroke: instanceStroke || null,
        strokeWidth: instanceStrokeWidth,
        transform,
      });
    }

    // Emit as single use or group
    if (subUses.length === 1) {
      uses.push({
        type: "use",
        ...subUses[0],
        sourceId: a.dtId,
        sourceType: a.dtType,
        normType: a.dtType,
        dataAttrs: a.dataAttrs,
      });
    } else {
      uses.push({
        type: "group",
        sourceId: a.dtId,
        sourceType: a.dtType,
        normType: a.dtType,
        dataAttrs: a.dataAttrs,
        children: subUses,
      });
    }
  }

  // ─── Untagged elements: leaves NOT inside any data-type element ───
  // These include titles, lyrics, footnotes, and other non-musical content.
  // We emit them directly (no dedup/defs) with their full transform chains.
  {
    // Build a set of all data-type elements for fast descendant checking
    const dtSet = new Set();
    dtElements.forEach((dt) => {
      const markDescendants = (el) => {
        dtSet.add(el);
        for (const child of el.children) markDescendants(child);
      };
      markDescendants(dt);
    });

    // Walk the SVG tree looking for leaf elements outside data-type boundaries
    const untaggedLeaves = [];
    const walkForUntagged = (el) => {
      if (dtSet.has(el)) return; // skip entire data-type subtrees
      const tag = stripNs(el.tagName);
      if (LEAF_TAGS.has(tag)) {
        untaggedLeaves.push(el);
      }
      for (const child of el.children) {
        walkForUntagged(child);
      }
    };
    // Start walk from the SVG root (the wrapper element's first SVG child)
    const svgRoot = svgWrapEl.querySelector("svg") || svgWrapEl;
    for (const child of svgRoot.children) {
      walkForUntagged(child);
    }

    // For each untagged leaf, collect transform chain up to svgRoot
    for (const leaf of untaggedLeaves) {
      const tag = stripNs(leaf.tagName);
      const rawTransforms = [];
      let color = null;
      let stroke = null;
      let strokeWidth = null;

      // Walk ancestors up to svgRoot
      let cur = leaf.parentElement;
      const ancestors = [];
      while (cur && cur !== svgRoot && cur !== svgWrapEl) {
        ancestors.push(cur);
        cur = cur.parentElement;
      }
      ancestors.reverse(); // outermost first

      for (const anc of ancestors) {
        const tf = anc.getAttribute("transform");
        if (tf) rawTransforms.push(tf);
        const c = anc.getAttribute("color");
        if (c && c !== "currentColor") color = c;
        const s = anc.getAttribute("stroke");
        if (s && s !== "currentColor") stroke = s;
        const sw = anc.getAttribute("stroke-width");
        if (sw) strokeWidth = parseFloat(sw);
      }

      // Include leaf's own transform
      const leafTf = leaf.getAttribute("transform");
      if (leafTf) rawTransforms.push(leafTf);

      // Check leaf for stroke/fill
      const leafStroke = leaf.getAttribute("stroke");
      const leafSW = leaf.getAttribute("stroke-width");
      if (leafStroke && leafStroke !== "currentColor") stroke = leafStroke;
      if (leafSW) strokeWidth = parseFloat(leafSW);

      const transform = rawTransforms.join(" ");

      if (tag === "text") {
        // Text elements: emit inline (not via defs/use)
        const text = leaf.textContent || "";
        const fontFamily = leaf.getAttribute("font-family") || "";
        const fontSize = leaf.getAttribute("font-size") || "";
        const fontWeight = leaf.getAttribute("font-weight") || "";
        const textAnchor = leaf.getAttribute("text-anchor") || "";
        const fill = leaf.getAttribute("fill") || color || "#000000";
        const textDecor = leaf.getAttribute("text-decoration") || "";

        uses.push({
          type: "raw-text",
          transform,
          fill,
          fontFamily,
          fontSize,
          fontWeight,
          textAnchor,
          textDecoration: textDecor,
          text,
          sourceId: leaf.getAttribute("id") || null,
          sourceType: "untagged",
          normType: "untagged",
        });
      } else if (tag === "path") {
        const d = leaf.getAttribute("d") || "";
        const fill = leaf.getAttribute("fill") || color || "#000000";
        uses.push({
          type: "raw-path",
          transform,
          d,
          fill,
          stroke: stroke || null,
          strokeWidth,
          sourceId: leaf.getAttribute("id") || null,
          sourceType: "untagged",
          normType: "untagged",
        });
      } else if (tag === "line") {
        const x1 = leaf.getAttribute("x1") || "0";
        const y1 = leaf.getAttribute("y1") || "0";
        const x2 = leaf.getAttribute("x2") || "0";
        const y2 = leaf.getAttribute("y2") || "0";
        const lc = leaf.getAttribute("stroke-linecap") || "";
        const lj = leaf.getAttribute("stroke-linejoin") || "";
        uses.push({
          type: "raw-line",
          transform,
          x1, y1, x2, y2,
          stroke: stroke || color || "#000000",
          strokeWidth,
          strokeLinecap: lc,
          strokeLinejoin: lj,
          sourceId: leaf.getAttribute("id") || null,
          sourceType: "untagged",
          normType: "untagged",
        });
      } else if (tag === "rect") {
        const x = leaf.getAttribute("x") || "0";
        const y = leaf.getAttribute("y") || "0";
        const w = leaf.getAttribute("width") || "0";
        const h = leaf.getAttribute("height") || "0";
        const fill = leaf.getAttribute("fill") || color || "#000000";
        uses.push({
          type: "raw-rect",
          transform,
          x, y, width: w, height: h,
          fill,
          stroke: stroke || null,
          strokeWidth,
          sourceId: leaf.getAttribute("id") || null,
          sourceType: "untagged",
          normType: "untagged",
        });
      }
    }
  }

  // ─── Build final defs array ───
  // Combine Level 1 (atoms) + Level 2 (compounds, excluding single-aliases)
  const defs = [...shapeDefs];
  for (const cd of compoundDefs) {
    // Only emit compound as a <g> def if it has >1 child or has a fixed fill
    const isSingleAlias = cd.children.length === 1 && !cd.children[0].fill;
    if (!isSingleAlias) {
      defs.push({ id: cd.id, tag: "g", children: cd.children });
    }
  }

  // ─── Stats ───
  const typeCounts = {};
  for (const u of uses) {
    const t = u.sourceType;
    if (!typeCounts[t]) typeCounts[t] = { elements: 0, uses: 0 };
    typeCounts[t].elements++;
    typeCounts[t].uses += u.type === "group" ? u.children.length : 1;
  }

  const totalUseCount = uses.reduce((n, u) => n + (u.type === "group" ? u.children.length : 1), 0);

  return {
    defs,
    uses,
    warnings,
    stats: {
      atomicShapes: shapeDefs.length,
      compoundGroups: compoundDefs.filter((d) => d.children.length > 1 || d.children.some((c) => c.fill)).length,
      totalDefs: defs.length,
      totalElements: analyses.length,
      totalUses: totalUseCount,
      typeCounts,
    },
  };
}

function round3(n) {
  return Math.round(n * 1000) / 1000;
}

function round4(n) {
  return Math.round(n * 10000) / 10000;
}


// =========================================================================
//  NOTEHEAD DIAGNOSTIC — temporary analysis tool
//  Walks notehead DOM elements, extracts transform chains, path data,
//  colors, and structural info for understanding the SVG patterns.
// =========================================================================

function diagnoseNoteheads(svgWrapEl) {
  const noteheads = svgWrapEl.querySelectorAll('[data-type="notehead"]');
  if (!noteheads.length) return null;

  const details = [];  // detailed per-notehead info (first N)
  const summary = {
    total: noteheads.length,
    pathCounts: {},      // "1 path": N, "2 paths": N
    uniqueDs: new Set(),
    dFrequency: {},      // d-string → count
    transformPatterns: {},
    colorsFound: new Set(),
    multiNoteCount: 0,
  };

  const MAX_DETAIL = 6;

  noteheads.forEach((nh, idx) => {
    const id = nh.getAttribute("id") || "?";
    const midi = nh.getAttribute("data-midi") || "?";
    const pc = nh.getAttribute("data-pitch-class") || "?";

    // Find all <path> elements and their ancestry chains
    const paths = nh.querySelectorAll("path");
    const pathKey = `${paths.length} path${paths.length !== 1 ? "s" : ""}`;
    summary.pathCounts[pathKey] = (summary.pathCounts[pathKey] || 0) + 1;

    const pathInfos = [];

    paths.forEach((path, pi) => {
      const d = path.getAttribute("d") || "";
      const fill = path.getAttribute("fill") || null;

      // Round the d string for comparison
      const dRounded = d.replace(
        /[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?/g,
        (m) => round4(parseFloat(m)).toString()
      );

      summary.uniqueDs.add(dRounded);
      summary.dFrequency[dRounded] = (summary.dFrequency[dRounded] || 0) + 1;

      // Compute bounding box of path coordinates to check centering
      const coords = [];
      const tokens = d.match(/[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?/g) || [];
      // Simple: just grab pairs of numbers as approximate coords
      for (let i = 0; i + 1 < tokens.length; i += 2) {
        coords.push({ x: parseFloat(tokens[i]), y: parseFloat(tokens[i + 1]) });
      }
      let pathCenter = null;
      if (coords.length > 0) {
        const xs = coords.map((c) => c.x);
        const ys = coords.map((c) => c.y);
        const minX = Math.min(...xs), maxX = Math.max(...xs);
        const minY = Math.min(...ys), maxY = Math.max(...ys);
        pathCenter = {
          x: round4((minX + maxX) / 2),
          y: round4((minY + maxY) / 2),
          bbox: { minX: round4(minX), maxX: round4(maxX), minY: round4(minY), maxY: round4(maxY) },
        };
      }

      // Walk ancestor chain from path up to the notehead <g>,
      // collecting transforms and color attributes
      const chain = [];
      let cur = path;
      while (cur && cur !== nh) {
        const tag = cur.tagName?.toLowerCase() || "?";
        const tf = cur.getAttribute("transform") || null;
        const color = cur.getAttribute("color") || null;
        const elFill = cur !== path ? null : fill; // only record fill on the path itself
        if (tf || color || elFill) {
          chain.push({
            tag,
            id: cur.getAttribute("id") || null,
            transform: tf,
            color,
            fill: elFill,
          });
        }
        cur = cur.parentElement;
      }
      chain.reverse(); // now top-down: notehead → path

      // Compute accumulated transform (including rotation)
      let accSx = 1, accSy = 1, accTx = 0, accTy = 0;
      let accRotation = 0;
      const rawTransforms = []; // collect all raw transform strings
      // Walk from nh's first child down to path's parent
      const allAncestors = [];
      cur = path.parentElement;
      while (cur && cur !== nh) {
        allAncestors.unshift(cur);
        cur = cur.parentElement;
      }
      for (const anc of allAncestors) {
        const tf = anc.getAttribute("transform") || "";
        if (tf) rawTransforms.push(tf);

        // Parse translate
        const tm = tf.match(/translate\(\s*([-\d.]+)\s*[,\s]\s*([-\d.]+)\s*\)/);
        if (tm) {
          accTx += accSx * parseFloat(tm[1]);
          accTy += accSy * parseFloat(tm[2]);
        }
        // Parse scale
        const sm = tf.match(/scale\(\s*([-\d.]+)\s*(?:[,\s]\s*([-\d.]+))?\s*\)/);
        if (sm) {
          const sx = parseFloat(sm[1]);
          const sy = sm[2] !== undefined ? parseFloat(sm[2]) : sx;
          accSx *= sx;
          accSy *= sy;
        }
        // Parse rotate
        const rm = tf.match(/rotate\(\s*([-\d.]+)\s*(?:[,\s]\s*([-\d.]+)\s*[,\s]\s*([-\d.]+))?\s*\)/);
        if (rm) {
          accRotation += parseFloat(rm[1]);
        }
        // Detect matrix transforms (flag for manual inspection)
        if (tf.includes("matrix")) {
          rawTransforms.push("⚠ MATRIX detected");
        }
      }

      // Build transform signature — now includes rotation
      const tfSig = `scale(${round4(accSx)},${round4(accSy)})` +
        (accRotation !== 0 ? ` rotate(${round4(accRotation)})` : "");
      summary.transformPatterns[tfSig] = (summary.transformPatterns[tfSig] || 0) + 1;

      // Collect colors from the ancestor chain
      chain.forEach((c) => { if (c.color) summary.colorsFound.add(c.color); });

      pathInfos.push({
        pathIndex: pi,
        d: d.length > 120 ? d.slice(0, 120) + "…" : d,
        dRounded: dRounded.length > 120 ? dRounded.slice(0, 120) + "…" : dRounded,
        dFull: dRounded,
        fill,
        pathCenter,
        chain,
        rawTransforms,
        accumulated: {
          sx: round4(accSx), sy: round4(accSy),
          tx: round4(accTx), ty: round4(accTy),
          rotation: round4(accRotation),
        },
        tfSig,
      });
    });

    // Detect multi-note: if pathCount > 2 for a false-hollow or > 1 for solid
    const isMultiNote = paths.length > 2 || (paths.length > 1 &&
      ![...paths].some((p) => (p.getAttribute("fill") || "").toLowerCase() === "white" ||
                               (p.getAttribute("fill") || "").toLowerCase() === "#ffffff"));

    if (isMultiNote) summary.multiNoteCount++;

    const entry = { id, midi, pc, pathCount: paths.length, paths: pathInfos, isMultiNote };

    if (idx < MAX_DETAIL) {
      details.push(entry);
    } else if (isMultiNote && !details.some((d) => d.isMultiNote)) {
      // Always include at least one multi-note example
      details.push(entry);
    }
  });

  // Sort d-strings by frequency
  const dsByFreq = Object.entries(summary.dFrequency)
    .sort((a, b) => b[1] - a[1])
    .map(([d, count]) => ({
      d: d.length > 100 ? d.slice(0, 100) + "…" : d,
      dFull: d,
      count,
    }));

  return {
    details,
    summary: {
      total: summary.total,
      pathCounts: summary.pathCounts,
      uniquePathShapes: summary.uniqueDs.size,
      dsByFrequency: dsByFreq,
      transformPatterns: summary.transformPatterns,
      colorsFound: [...summary.colorsFound],
      multiNoteCount: summary.multiNoteCount,
    },
  };
}


// =========================================================================
//  NOTEHEAD DIAGNOSTIC PANEL COMPONENT
// =========================================================================

function NoteheadDiagnosticPanel({ diagData }) {
  const [expanded, setExpanded] = useState(false);
  const [showDetail, setShowDetail] = useState(null); // index of expanded detail

  if (!diagData) return null;

  const { details, summary } = diagData;

  return (
    <div>
      <div
        onClick={() => setExpanded((v) => !v)}
        style={{
          padding: "3px 12px",
          background: "#f5f0ff",
          borderTop: "1px solid #e0d4f5",
          fontSize: 10,
          cursor: "pointer",
          display: "flex",
          alignItems: "center",
          gap: 8,
          userSelect: "none",
        }}
      >
        <span style={{ color: "#7c3aed", fontWeight: 700 }}>
          🔬 NOTEHEAD DIAGNOSTIC
        </span>
        <span style={{ color: "#888" }}>
          {summary.total} noteheads · {summary.uniquePathShapes} unique path shape{summary.uniquePathShapes !== 1 ? "s" : ""}
          {" · "}{Object.entries(summary.pathCounts).map(([k, v]) => `${k}: ${v}`).join(", ")}
          {" · "}{summary.colorsFound.length} color{summary.colorsFound.length !== 1 ? "s" : ""}
          {" · "}{Object.keys(summary.transformPatterns).length} tf pattern{Object.keys(summary.transformPatterns).length !== 1 ? "s" : ""}
          {summary.multiNoteCount > 0 && (
            <span style={{ color: "#e67e22", fontWeight: 600 }}>
              {" "}· {summary.multiNoteCount} multi-note
            </span>
          )}
        </span>
        <span style={{ color: "#bbb", marginLeft: "auto" }}>
          {expanded ? "▼" : "▶"}
        </span>
      </div>

      {expanded && (
        <div style={{
          maxHeight: 400,
          overflowY: "auto",
          background: "#fff",
          borderTop: "1px solid #eee",
          fontSize: 10,
          lineHeight: 1.6,
          padding: "8px 12px",
        }}>
          {/* Summary section */}
          <div style={{ marginBottom: 8 }}>
            <div style={{ fontWeight: 700, color: "#7c3aed", marginBottom: 4 }}>SUMMARY</div>

            <div><span style={{ color: "#999" }}>Colors: </span>
              {summary.colorsFound.map((c, i) => (
                <span key={i} style={{ marginRight: 8 }}>
                  <span style={{
                    display: "inline-block", width: 10, height: 10,
                    background: c, border: "1px solid #ccc", borderRadius: 2,
                    verticalAlign: "middle", marginRight: 2,
                  }} />
                  {c}
                </span>
              ))}
            </div>

            <div style={{ marginTop: 4 }}>
              <span style={{ color: "#999" }}>Transform patterns: </span>
              {Object.entries(summary.transformPatterns).map(([pat, count], i) => (
                <span key={i} style={{
                  background: "#f0f0ff", border: "1px solid #ddd",
                  borderRadius: 3, padding: "1px 5px", marginRight: 4,
                  fontFamily: "monospace",
                }}>
                  {pat}: ×{count}
                </span>
              ))}
            </div>

            <div style={{ marginTop: 4 }}>
              <span style={{ color: "#999" }}>Unique path shapes ({summary.uniquePathShapes}): </span>
            </div>
            {summary.dsByFrequency.map((entry, i) => (
              <div key={i} style={{
                marginLeft: 12, fontFamily: "monospace", fontSize: 9,
                padding: "2px 0", borderBottom: "1px solid #f5f5f5",
                display: "flex", gap: 8,
              }}>
                <span style={{ color: "#7c3aed", fontWeight: 700, minWidth: 30 }}>×{entry.count}</span>
                <span style={{ color: "#555", wordBreak: "break-all" }}>{entry.d}</span>
              </div>
            ))}
          </div>

          {/* Detail section */}
          <div style={{ fontWeight: 700, color: "#7c3aed", marginBottom: 4, marginTop: 12 }}>
            FIRST {details.length} NOTEHEADS
          </div>

          {details.map((nh, ni) => (
            <div key={ni} style={{
              marginBottom: 6, padding: "4px 8px",
              background: ni % 2 === 0 ? "#faf8ff" : "#fff",
              border: "1px solid #eee", borderRadius: 4,
            }}>
              <div
                onClick={() => setShowDetail(showDetail === ni ? null : ni)}
                style={{ cursor: "pointer", display: "flex", gap: 8, alignItems: "baseline" }}
              >
                <span style={{ color: "#7c3aed", fontWeight: 700 }}>{nh.id}</span>
                <span style={{ color: "#999" }}>midi={nh.midi} pc={nh.pc}</span>
                <span style={{ color: "#666" }}>{nh.pathCount} path{nh.pathCount !== 1 ? "s" : ""}</span>
                {nh.isMultiNote && (
                  <span style={{ color: "#e67e22", fontWeight: 700, fontSize: 9, background: "#fef3c7", padding: "0 4px", borderRadius: 2 }}>
                    MULTI-NOTE
                  </span>
                )}
                <span style={{ color: "#bbb", marginLeft: "auto" }}>
                  {showDetail === ni ? "▼" : "▶"}
                </span>
              </div>

              {showDetail === ni && nh.paths.map((p, pi) => (
                <div key={pi} style={{
                  marginTop: 4, marginLeft: 12, padding: "4px 6px",
                  background: "#f8f8ff", border: "1px solid #e8e8f0", borderRadius: 3,
                }}>
                  <div style={{ fontWeight: 600, color: "#555" }}>
                    path[{pi}]
                    {p.fill && <span style={{ color: "#c0392b" }}> fill="{p.fill}"</span>}
                  </div>

                  <div style={{ fontFamily: "monospace", fontSize: 9, marginTop: 2, color: "#333" }}>
                    <span style={{ color: "#999" }}>d (rounded): </span>
                    <span style={{ wordBreak: "break-all" }}>{p.dRounded}</span>
                  </div>

                  {p.pathCenter && (
                    <div style={{ marginTop: 2 }}>
                      <span style={{ color: "#999" }}>bbox center: </span>
                      <span style={{
                        color: Math.abs(p.pathCenter.x) < 0.1 && Math.abs(p.pathCenter.y) < 0.1
                          ? "#27ae60" : "#e74c3c",
                        fontWeight: 600,
                      }}>
                        ({p.pathCenter.x}, {p.pathCenter.y})
                      </span>
                      <span style={{ color: "#999", marginLeft: 8 }}>
                        bbox: [{p.pathCenter.bbox.minX}, {p.pathCenter.bbox.minY}] → [{p.pathCenter.bbox.maxX}, {p.pathCenter.bbox.maxY}]
                      </span>
                    </div>
                  )}

                  <div style={{ marginTop: 2 }}>
                    <span style={{ color: "#999" }}>accumulated: </span>
                    <span style={{ fontFamily: "monospace" }}>
                      scale({p.accumulated.sx}, {p.accumulated.sy})
                      translate({p.accumulated.tx}, {p.accumulated.ty})
                      {p.accumulated.rotation !== 0 && (
                        <span style={{ color: "#e74c3c", fontWeight: 600 }}>
                          {" "}rotate({p.accumulated.rotation}°)
                        </span>
                      )}
                    </span>
                  </div>

                  {p.rawTransforms && p.rawTransforms.length > 0 && (
                    <div style={{ marginTop: 2 }}>
                      <span style={{ color: "#999" }}>raw transforms: </span>
                      <span style={{ fontFamily: "monospace", fontSize: 9, color: "#666" }}>
                        {p.rawTransforms.join("  →  ")}
                      </span>
                    </div>
                  )}

                  <div style={{ marginTop: 2, color: "#888" }}>
                    <span style={{ color: "#999" }}>chain: </span>
                    {p.chain.map((c, ci) => (
                      <span key={ci} style={{ marginRight: 4 }}>
                        {c.transform && <span style={{ color: "#2980b9" }}>{c.transform} </span>}
                        {c.color && <span style={{ color: c.color, fontWeight: 600 }}>color="{c.color}" </span>}
                        {c.fill && <span style={{ color: "#c0392b" }}>fill="{c.fill}" </span>}
                        {ci < p.chain.length - 1 && <span style={{ color: "#ddd" }}>→ </span>}
                      </span>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}


// =========================================================================
//  NORMALIZED SVG SERIALIZATION
//  Builds a standalone SVG string from normData for download/export.
// =========================================================================

function serializeNormSvg(normData, viewBox) {
  if (!normData || !viewBox) return "";

  const lines = [];
  lines.push(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="${viewBox}">`);

  // ── Defs ──
  lines.push("  <defs>");
  for (const def of normData.defs) {
    if (def.tag === "path") {
      lines.push(`    <path id="${def.id}" d="${def.attrs.d}"/>`);
    } else if (def.tag === "line") {
      const a = def.attrs;
      const extras = [
        a.strokeWidth ? `stroke-width="${a.strokeWidth}"` : "",
        a.strokeLinecap ? `stroke-linecap="${a.strokeLinecap}"` : "",
        a.strokeLinejoin ? `stroke-linejoin="${a.strokeLinejoin}"` : "",
      ].filter(Boolean).join(" ");
      lines.push(`    <line id="${def.id}" x1="${a.x1}" y1="${a.y1}" x2="${a.x2}" y2="${a.y2}"${extras ? " " + extras : ""}/>`);
    } else if (def.tag === "rect") {
      lines.push(`    <rect id="${def.id}" width="${def.attrs.width}" height="${def.attrs.height}"/>`);
    } else if (def.tag === "text") {
      const a = def.attrs;
      const extras = [
        a.fontFamily ? `font-family="${a.fontFamily}"` : "",
        a.fontWeight ? `font-weight="${a.fontWeight}"` : "",
        a.fontSize ? `font-size="${a.fontSize}"` : "",
        a.textAnchor ? `text-anchor="${a.textAnchor}"` : "",
      ].filter(Boolean).join(" ");
      lines.push(`    <text id="${def.id}"${extras ? " " + extras : ""}>${escXml(def.text || "")}</text>`);
    } else if (def.tag === "g" && def.children) {
      lines.push(`    <g id="${def.id}">`);
      for (const child of def.children) {
        const fill = child.fill ? ` fill="${child.fill}"` : "";
        lines.push(`      <use href="${child.href}"${fill}/>`);
      }
      lines.push("    </g>");
    }
  }
  lines.push("  </defs>");
  lines.push("");

  // ── Uses ──
  const sorted = [...normData.uses].sort(normRenderSort);

  /** Build id + data-* attribute string for an element */
  const idAndData = (u) => {
    const parts = [];
    if (u.sourceId) parts.push(`id="${escXml(u.sourceId)}"`);
    if (u.dataAttrs) {
      for (const [k, v] of Object.entries(u.dataAttrs)) {
        parts.push(`${k}="${escXml(v)}"`);
      }
    }
    return parts.join(" ");
  };

  for (const u of sorted) {
    const idStr = idAndData(u);

    if (u.type === "group") {
      lines.push(`  <g ${idStr}>`);
      for (const c of u.children) {
        const parts = [
          `href="${c.href}"`,
          c.transform ? `transform="${c.transform}"` : "",
          c.fill ? `fill="${c.fill}"` : "",
          c.stroke ? `stroke="${c.stroke}"` : "",
          c.strokeWidth != null ? `stroke-width="${c.strokeWidth}"` : "",
        ].filter(Boolean).join(" ");
        lines.push(`    <use ${parts}/>`);
      }
      lines.push("  </g>");
    } else if (u.type === "use") {
      const parts = [
        idStr,
        `href="${u.href}"`,
        u.transform ? `transform="${u.transform}"` : "",
        u.fill ? `fill="${u.fill}"` : "",
        u.stroke ? `stroke="${u.stroke}"` : "",
        u.strokeWidth != null ? `stroke-width="${u.strokeWidth}"` : "",
      ].filter(Boolean).join(" ");
      lines.push(`  <use ${parts}/>`);
    } else if (u.type === "raw-text") {
      const parts = [
        idStr,
        u.transform ? `transform="${u.transform}"` : "",
        u.fill ? `fill="${u.fill}"` : "",
        u.fontFamily ? `font-family="${u.fontFamily}"` : "",
        u.fontSize ? `font-size="${u.fontSize}"` : "",
        u.fontWeight ? `font-weight="${u.fontWeight}"` : "",
        u.textAnchor ? `text-anchor="${u.textAnchor}"` : "",
        u.textDecoration ? `text-decoration="${u.textDecoration}"` : "",
      ].filter(Boolean).join(" ");
      lines.push(`  <text ${parts}>${escXml(u.text || "")}</text>`);
    } else if (u.type === "raw-path") {
      const parts = [
        idStr,
        u.transform ? `transform="${u.transform}"` : "",
        `d="${u.d}"`,
        u.fill ? `fill="${u.fill}"` : "",
        u.stroke ? `stroke="${u.stroke}"` : "",
        u.strokeWidth != null ? `stroke-width="${u.strokeWidth}"` : "",
      ].filter(Boolean).join(" ");
      lines.push(`  <path ${parts}/>`);
    } else if (u.type === "raw-line") {
      const parts = [
        idStr,
        u.transform ? `transform="${u.transform}"` : "",
        `x1="${u.x1}" y1="${u.y1}" x2="${u.x2}" y2="${u.y2}"`,
        u.stroke ? `stroke="${u.stroke}"` : "",
        u.strokeWidth != null ? `stroke-width="${u.strokeWidth}"` : "",
        u.strokeLinecap ? `stroke-linecap="${u.strokeLinecap}"` : "",
        u.strokeLinejoin ? `stroke-linejoin="${u.strokeLinejoin}"` : "",
      ].filter(Boolean).join(" ");
      lines.push(`  <line ${parts}/>`);
    } else if (u.type === "raw-rect") {
      const parts = [
        idStr,
        u.transform ? `transform="${u.transform}"` : "",
        `x="${u.x}" y="${u.y}" width="${u.width}" height="${u.height}"`,
        u.fill ? `fill="${u.fill}"` : "",
        u.stroke ? `stroke="${u.stroke}"` : "",
        u.strokeWidth != null ? `stroke-width="${u.strokeWidth}"` : "",
      ].filter(Boolean).join(" ");
      lines.push(`  <rect ${parts}/>`);
    }
  }

  lines.push("</svg>");
  return lines.join("\n");
}

function escXml(s) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}


// =========================================================================
//  NORMALIZATION OVERLAY COMPONENT
// =========================================================================

// SVG paints in document order: earlier elements are behind later ones.
// This map controls z-order within the norm layer.
const NORM_RENDER_ORDER = {
  "untagged": -1,        // background — titles, lyrics, decorations
  "staff-symbol": 0,     // behind everything musical
  "barline": 1,
  "key-signature": 2,
  "time-signature": 3,
  "clef": 4,
  "ledger-line": 5,
  "notehead": 10,
  "stem": 11,
  "dots": 12,
  "flag": 13,
  "beam": 14,
  "rest": 15,
  "accidental": 16,
};

function normRenderSort(a, b) {
  const oa = NORM_RENDER_ORDER[a.normType] ?? 50;
  const ob = NORM_RENDER_ORDER[b.normType] ?? 50;
  return oa - ob;
}

function NormalizationOverlay({ normData, viewBox, zoom, baseDims, opacity }) {
  if (!normData || !viewBox || !baseDims) return null;

  const { defs, uses } = normData;

  // Sort uses so staffs render first (behind), noteheads/stems on top
  const sortedUses = useMemo(() => [...uses].sort(normRenderSort), [uses]);

  /**
   * Render a single def element inside <defs>.
   * Handles: path, line, rect, text (atomic), and g (compound).
   */
  const renderDef = (def) => {
    if (def.tag === "path") {
      return <path key={def.id} id={def.id} d={def.attrs.d} />;
    }
    if (def.tag === "line") {
      return (
        <line key={def.id} id={def.id}
          x1={def.attrs.x1} y1={def.attrs.y1}
          x2={def.attrs.x2} y2={def.attrs.y2}
          {...(def.attrs.strokeWidth ? { strokeWidth: def.attrs.strokeWidth } : {})}
          {...(def.attrs.strokeLinecap ? { strokeLinecap: def.attrs.strokeLinecap } : {})}
          {...(def.attrs.strokeLinejoin ? { strokeLinejoin: def.attrs.strokeLinejoin } : {})}
        />
      );
    }
    if (def.tag === "rect") {
      return (
        <rect key={def.id} id={def.id}
          width={def.attrs.width} height={def.attrs.height} />
      );
    }
    if (def.tag === "text") {
      return (
        <text key={def.id} id={def.id}
          fontFamily={def.attrs.fontFamily}
          fontWeight={def.attrs.fontWeight}
          fontSize={def.attrs.fontSize}
          textAnchor={def.attrs.textAnchor}>
          {def.text}
        </text>
      );
    }
    if (def.tag === "g" && def.children) {
      // Compound group: contains <use> children
      return (
        <g key={def.id} id={def.id}>
          {def.children.map((child, ci) => (
            <use key={ci} href={child.href}
              {...(child.fill ? { fill: child.fill } : {})} />
          ))}
        </g>
      );
    }
    return null;
  };

  /**
   * Render a single use instance (may be a <use> or a <g> containing multiple <use>).
   */
  const renderUse = (u, i) => {
    const defaultFill = "#000000";

    if (u.type === "group") {
      return (
        <g key={`use-${i}`}
          data-norm-type={u.normType}
          data-source-type={u.sourceType}
          data-source-id={u.sourceId}>
          {u.children.map((child, ci) => {
            const hasFill = child.fill != null;
            const hasStroke = child.stroke != null;
            const color = child.fill || child.stroke || defaultFill;
            return (
              <use key={ci}
                href={child.href}
                transform={child.transform}
                {...(hasFill ? { fill: child.fill } : hasStroke ? {} : { fill: defaultFill })}
                {...(hasStroke ? { stroke: child.stroke } : {})}
                {...(child.strokeWidth != null ? { strokeWidth: child.strokeWidth } : {})}
              />
            );
          })}
        </g>
      );
    }

    // ── Raw (untagged) elements — rendered directly, no defs ──
    if (u.type === "raw-text") {
      return (
        <text key={`use-${i}`}
          transform={u.transform}
          fill={u.fill || defaultFill}
          fontFamily={u.fontFamily}
          fontSize={u.fontSize}
          fontWeight={u.fontWeight}
          textAnchor={u.textAnchor}
          {...(u.textDecoration ? { textDecoration: u.textDecoration } : {})}
        >
          {u.text}
        </text>
      );
    }
    if (u.type === "raw-path") {
      return (
        <path key={`use-${i}`}
          transform={u.transform}
          d={u.d}
          fill={u.fill || defaultFill}
          {...(u.stroke ? { stroke: u.stroke } : {})}
          {...(u.strokeWidth != null ? { strokeWidth: u.strokeWidth } : {})}
        />
      );
    }
    if (u.type === "raw-line") {
      return (
        <line key={`use-${i}`}
          transform={u.transform}
          x1={u.x1} y1={u.y1} x2={u.x2} y2={u.y2}
          stroke={u.stroke || defaultFill}
          {...(u.strokeWidth != null ? { strokeWidth: u.strokeWidth } : {})}
          {...(u.strokeLinecap ? { strokeLinecap: u.strokeLinecap } : {})}
          {...(u.strokeLinejoin ? { strokeLinejoin: u.strokeLinejoin } : {})}
        />
      );
    }
    if (u.type === "raw-rect") {
      return (
        <rect key={`use-${i}`}
          transform={u.transform}
          x={u.x} y={u.y} width={u.width} height={u.height}
          fill={u.fill || defaultFill}
          {...(u.stroke ? { stroke: u.stroke } : {})}
          {...(u.strokeWidth != null ? { strokeWidth: u.strokeWidth } : {})}
        />
      );
    }

    // Single use (data-type element referencing a def)
    const hasFill = u.fill != null;
    const hasStroke = u.stroke != null;
    return (
      <use key={`use-${i}`}
        href={u.href}
        transform={u.transform}
        {...(hasFill ? { fill: u.fill } : hasStroke ? {} : { fill: defaultFill })}
        {...(hasStroke ? { stroke: u.stroke } : {})}
        {...(u.strokeWidth != null ? { strokeWidth: u.strokeWidth } : {})}
        data-norm-type={u.normType}
        data-source-type={u.sourceType}
        data-source-id={u.sourceId}
      />
    );
  };

  return (
    <svg
      viewBox={viewBox}
      style={{
        position: "absolute",
        top: 0,
        left: 0,
        width: `${baseDims.w * zoom}px`,
        height: `${baseDims.h * zoom}px`,
        pointerEvents: "none",
        opacity,
      }}
      xmlns="http://www.w3.org/2000/svg"
    >
      <defs>
        {defs.map(renderDef)}
      </defs>
      {sortedUses.map(renderUse)}
    </svg>
  );
}


// =========================================================================
//  GRID OVERLAY COMPONENT
// =========================================================================

function GridOverlay({ gridData, viewBox, zoom, baseDims, opacity }) {
  if (!gridData || !viewBox || !baseDims) return null;

  const { systems, rowBoundaries, barlinesBySystem, staffLeftX, staffRightX } = gridData;
  const strokeWidth = 0.15;
  const thinStroke = 0.08;
  const labelSize = 1.5;

  // Compute top/bottom page boundaries for grid
  const pageTopY = systems.length > 0 ? systems[0].topY - 4 : 0;
  const pageBotY = systems.length > 0 ? systems[systems.length - 1].bottomY + 4 : 100;

  return (
    <svg
      viewBox={viewBox}
      style={{
        position: "absolute",
        top: 0,
        left: 0,
        width: `${baseDims.w * zoom}px`,
        height: `${baseDims.h * zoom}px`,
        pointerEvents: "none",
        opacity: opacity,
      }}
      xmlns="http://www.w3.org/2000/svg"
    >
      {/* System row boundary lines (horizontal, between systems) */}
      {rowBoundaries.map((y, i) => (
        <line
          key={`row-${i}`}
          x1={staffLeftX - 1}
          y1={y}
          x2={staffRightX + 1}
          y2={y}
          stroke={GRID_COLOR}
          strokeWidth={strokeWidth}
          strokeDasharray="0.8 0.4"
          opacity={0.6}
        />
      ))}

      {/* Per-system grid */}
      {systems.map((sys, si) => {
        const bls = barlinesBySystem[si] || [];
        // Top/bottom for this system's grid cell area
        const sysTop = si === 0 ? pageTopY : rowBoundaries[si - 1];
        const sysBot = si === systems.length - 1 ? pageBotY : rowBoundaries[si];

        return (
          <g key={`sys-${si}`}>
            {/* System top/bottom boundary lines */}
            <line
              x1={staffLeftX - 1} y1={sysTop}
              x2={staffRightX + 1} y2={sysTop}
              stroke={GRID_COLOR} strokeWidth={thinStroke}
              opacity={0.3}
            />
            <line
              x1={staffLeftX - 1} y1={sysBot}
              x2={staffRightX + 1} y2={sysBot}
              stroke={GRID_COLOR} strokeWidth={thinStroke}
              opacity={0.3}
            />

            {/* Staff center line (gap between upper and lower staff groups) */}
            <line
              x1={staffLeftX} y1={sys.centerY}
              x2={staffRightX} y2={sys.centerY}
              stroke={GRID_COLOR} strokeWidth={thinStroke}
              strokeDasharray="0.3 0.6"
              opacity={0.25}
            />

            {/* Barline verticals */}
            {bls.map((bl, bi) => (
              <g key={`bl-${si}-${bi}`}>
                <line
                  x1={bl.x} y1={sysTop}
                  x2={bl.x} y2={sysBot}
                  stroke={GRID_COLOR}
                  strokeWidth={strokeWidth}
                  opacity={0.5}
                />
                {/* Measure number label above the barline */}
                <text
                  x={bl.x + 0.5}
                  y={sysTop + 1.2}
                  fill={GRID_COLOR}
                  fontSize={labelSize}
                  fontFamily="sans-serif"
                  fontWeight="bold"
                  opacity={0.7}
                >
                  {bl.measure}
                </text>
              </g>
            ))}

            {/* System label on the left */}
            <text
              x={staffLeftX - 2.5}
              y={sys.centerY + 0.5}
              fill={GRID_COLOR}
              fontSize={labelSize * 0.9}
              fontFamily="sans-serif"
              fontWeight="bold"
              textAnchor="end"
              opacity={0.5}
            >
              S{si + 1}
            </text>
          </g>
        );
      })}
    </svg>
  );
}


// =========================================================================
//  NORM-LAYER TOOLTIP ENRICHMENT
//  Looks up the normalized element corresponding to a raw SVG element.
//  Returns the matching norm use entry, or null.
// =========================================================================

function findMatchingNormUse(rawAttrs, normData) {
  /**
   * Given the data attributes of a hovered/pinned raw SVG element,
   * find the corresponding use entry in the normalization layer.
   *
   * Generic match: sourceId === raw element id.
   * Staff-symbol special case: multiple systems share id "staff-symbol",
   * so we disambiguate via grid system number from data-grid-tl.
   */
  if (!normData || !rawAttrs) return null;

  const rawType = rawAttrs["data-type"];
  const rawId = rawAttrs.id;

  // Find all uses matching this source id
  const matches = normData.uses.filter((u) => u.sourceId === rawId);

  if (matches.length === 0) return null;
  if (matches.length === 1) return matches[0];

  // Multiple matches (e.g., staff-symbol appears once per system).
  // Try to disambiguate by system number from grid data.
  if (rawType === "staff-symbol") {
    const gridTl = rawAttrs["data-grid-tl"];
    if (gridTl) {
      const m = gridTl.match(/^S(\d+)/);
      if (m) {
        const sysIdx = parseInt(m[1], 10) - 1; // 0-based
        if (sysIdx >= 0 && sysIdx < matches.length) return matches[sysIdx];
      }
    }
  }

  // Fallback: return first match
  return matches[0];
}


// =========================================================================
//  MAIN INSPECTOR COMPONENT
// =========================================================================

export default function SVGInspector() {
  const [svgText, setSvgText] = useState(null);
  const [fileName, setFileName] = useState("");
  const [zoom, setZoom] = useState(1);
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const [dimLevel, setDimLevel] = useState(1.0);
  const [dimTarget, setDimTarget] = useState("others");
  const [tooltip, setTooltip] = useState(null);
  const [pinned, setPinned] = useState(null);
  const [hoveredId, setHoveredId] = useState(null);
  const [stats, setStats] = useState(null);
  const [selectedTypes, setSelectedTypes] = useState(new Set(["entire-score"]));
  const [baseDims, setBaseDims] = useState(null);
  const [gridData, setGridData] = useState(null);
  const [viewBox, setViewBox] = useState(null);
  const [enrichmentResult, setEnrichmentResult] = useState(null);
  const [normData, setNormData] = useState(null);
  const [normDimLevel, setNormDimLevel] = useState(1.0);
  const [noteheadDiag, setNoteheadDiag] = useState(null);

  const viewportRef = useRef(null);
  const svgWrapRef = useRef(null);
  const isPanning = useRef(false);
  const panOrigin = useRef({ mx: 0, my: 0, px: 0, py: 0 });
  const zoomRef = useRef(1);
  const panRef = useRef({ x: 0, y: 0 });

  useEffect(() => { zoomRef.current = zoom; }, [zoom]);
  useEffect(() => { panRef.current = pan; }, [pan]);

  const isEntireScore = selectedTypes.has("entire-score");
  const isGridActive = selectedTypes.has("grid");
  const isNormActive = selectedTypes.has("norm");
  const activeElementTypes = new Set([...selectedTypes].filter((t) => t !== "entire-score" && t !== "grid" && t !== "norm"));
  const hasTypeSelection = activeElementTypes.size > 0;

  // Grid visibility: shown when "grid" is toggled on
  const gridVisible = isGridActive;

  // Norm visibility: shown when "norm" is toggled on
  const normVisible = isNormActive;

  // Grid opacity: follows dim logic
  const gridOpacity = useMemo(() => {
    if (!gridVisible) return 0;
    if (isEntireScore) return dimLevel;
    if (dimTarget === "selected" && isGridActive && !isEntireScore) return dimLevel;
    if (dimTarget === "others" && !isGridActive) return dimLevel;
    return 1.0;
  }, [gridVisible, isEntireScore, dimLevel, dimTarget, isGridActive]);

  // Norm opacity: independent of source SVG dim — controlled by its own slider
  const normOpacity = useMemo(() => {
    if (!normVisible) return 0;
    return normDimLevel;
  }, [normVisible, normDimLevel]);

  const toggleType = useCallback((type) => {
    setSelectedTypes((prev) => {
      const next = new Set(prev);
      if (type === "entire-score") {
        if (next.has("entire-score")) {
          next.delete("entire-score");
        } else {
          // Keep grid and norm state when switching to entire-score
          const hadGrid = next.has("grid");
          const hadNorm = next.has("norm");
          next.clear();
          next.add("entire-score");
          if (hadGrid) next.add("grid");
          if (hadNorm) next.add("norm");
        }
      } else if (type === "grid" || type === "norm") {
        // Grid and norm toggle independently
        if (next.has(type)) next.delete(type);
        else next.add(type);
      } else {
        if (next.has(type)) {
          next.delete(type);
        } else {
          next.add(type);
          next.delete("entire-score");
        }
        // If no element types left, switch to entire-score
        const remaining = [...next].filter((t) => t !== "entire-score" && t !== "grid" && t !== "norm");
        if (remaining.length === 0 && !next.has("entire-score")) {
          next.add("entire-score");
        }
      }
      return next;
    });
  }, []);

  const selectAllTypes = useCallback(() => {
    if (!stats) return;
    const next = new Set(Object.keys(stats.types));
    // Preserve grid and norm state
    if (selectedTypes.has("grid")) next.add("grid");
    if (selectedTypes.has("norm")) next.add("norm");
    setSelectedTypes(next);
  }, [stats, selectedTypes]);

  const selectNone = useCallback(() => {
    const next = new Set(["entire-score"]);
    // Preserve grid and norm state
    if (selectedTypes.has("grid")) next.add("grid");
    if (selectedTypes.has("norm")) next.add("norm");
    setSelectedTypes(next);
  }, [selectedTypes]);

  // --- SVG INJECTION & STATS ---
  useEffect(() => {
    const wrap = svgWrapRef.current;
    if (!svgText || !wrap) return;
    wrap.innerHTML = svgText;

    // Strip textedit links
    wrap.querySelectorAll("a").forEach((a) => {
      const href = a.getAttribute("href") || a.getAttributeNS("http://www.w3.org/1999/xlink", "href") || "";
      if (href.startsWith("textedit://")) {
        while (a.firstChild) a.parentNode.insertBefore(a.firstChild, a);
        a.remove();
      }
    });

    const svgEl = wrap.querySelector("svg");
    if (svgEl) {
      svgEl.style.display = "block";

      // Ensure a viewBox exists
      if (!svgEl.getAttribute("viewBox")) {
        const rawW = parseFloat(svgEl.getAttribute("width")) || 800;
        const rawH = parseFloat(svgEl.getAttribute("height")) || 600;
        svgEl.setAttribute("viewBox", `0 0 ${rawW} ${rawH}`);
      }
      setViewBox(svgEl.getAttribute("viewBox"));

      // Compute grid data from the DOM (doesn't need layout)
      const computedGrid = computeGridData(wrap);
      setGridData(computedGrid);

      // Measure dimensions + run grid-location enrichment (needs layout → rAF)
      requestAnimationFrame(() => {
        const rect = svgEl.getBoundingClientRect();
        const w = rect.width;
        const h = rect.height;
        if (w > 0 && h > 0) {
          setBaseDims({ w, h });
        } else {
          const fw = parseFloat(svgEl.getAttribute("width")) || 800;
          const fh = parseFloat(svgEl.getAttribute("height")) || 600;
          setBaseDims({ w: fw, h: fh });
        }

        // Assign data-grid-* attributes + collect diagnostics
        if (computedGrid) {
          const result = assignGridLocations(wrap, computedGrid);
          setEnrichmentResult(result);

          // Build normalization data
          setNormData(buildNormalizedData(wrap, computedGrid));

          // Run notehead diagnostic
          setNoteheadDiag(diagnoseNoteheads(wrap));
        } else {
          setEnrichmentResult(null);
          setNormData(null);
          setNoteheadDiag(null);
        }
      });
    }

    // Stats
    const types = {};
    let total = 0;
    wrap.querySelectorAll("[id]").forEach((el) => {
      const id = el.getAttribute("id");
      if (isTaggedId(id)) {
        total++;
        const t = el.getAttribute("data-type") || "unknown";
        types[t] = (types[t] || 0) + 1;
      }
    });
    setStats({ total, types });
  }, [svgText]);

  // --- CRISP ZOOM ---
  useEffect(() => {
    const wrap = svgWrapRef.current;
    if (!wrap || !baseDims) return;
    const svgEl = wrap.querySelector("svg");
    if (!svgEl) return;
    svgEl.style.width = `${baseDims.w * zoom}px`;
    svgEl.style.height = `${baseDims.h * zoom}px`;
  }, [zoom, baseDims]);

  // --- DIM/HIGHLIGHT ---
  useEffect(() => {
    const wrap = svgWrapRef.current;
    if (!wrap) return;
    const svgEl = wrap.querySelector("svg");

    wrap.querySelectorAll("[data-type]").forEach((el) => {
      el.style.opacity = "";
      el.style.pointerEvents = "";
    });
    if (svgEl) svgEl.style.opacity = "";

    if (isEntireScore) {
      if (svgEl) svgEl.style.opacity = dimLevel;
      return;
    }

    if (!hasTypeSelection) return;

    wrap.querySelectorAll("[data-type]").forEach((el) => {
      const type = el.getAttribute("data-type");
      const isSelected = activeElementTypes.has(type);

      if (dimTarget === "others" && !isSelected) {
        el.style.opacity = dimLevel;
        el.style.pointerEvents = "none";
      } else if (dimTarget === "selected" && isSelected) {
        el.style.opacity = dimLevel;
        el.style.pointerEvents = "none";
      }
    });
  }, [selectedTypes, dimLevel, dimTarget, svgText, isEntireScore, hasTypeSelection, activeElementTypes]);

  // --- FILE HANDLING ---
  const loadFile = useCallback((file) => {
    if (!file || !file.name.endsWith(".svg")) return;
    setFileName(file.name);
    setPinned(null);
    setTooltip(null);
    setSelectedTypes(new Set(["entire-score"]));
    setDimLevel(1.0);
    setNormDimLevel(1.0);
    setBaseDims(null);
    setGridData(null);
    setViewBox(null);
    setEnrichmentResult(null);
    setNormData(null);
    setNoteheadDiag(null);
    const reader = new FileReader();
    reader.onload = (e) => {
      setSvgText(e.target.result);
      setZoom(1);
      setPan({ x: 0, y: 0 });
    };
    reader.readAsText(file);
  }, []);

  // --- ZOOM (scroll toward cursor) ---
  useEffect(() => {
    const vp = viewportRef.current;
    if (!vp) return;
    const onWheel = (e) => {
      e.preventDefault();
      const rect = vp.getBoundingClientRect();
      const mx = e.clientX - rect.left;
      const my = e.clientY - rect.top;
      const dir = e.deltaY < 0 ? 1.12 : 1 / 1.12;
      const oldZ = zoomRef.current;
      const newZ = Math.min(ZOOM_MAX, Math.max(ZOOM_MIN, oldZ * dir));
      const ratio = newZ / oldZ;
      const oldP = panRef.current;
      const newP = {
        x: mx - ratio * (mx - oldP.x),
        y: my - ratio * (my - oldP.y),
      };
      setZoom(newZ);
      setPan(newP);
    };
    vp.addEventListener("wheel", onWheel, { passive: false });
    return () => vp.removeEventListener("wheel", onWheel);
  }, []);

  // --- PAN ---
  const onPointerDown = useCallback((e) => {
    if (e.button !== 0) return;
    isPanning.current = true;
    panOrigin.current = { mx: e.clientX, my: e.clientY, px: panRef.current.x, py: panRef.current.y };
    e.currentTarget.setPointerCapture(e.pointerId);
  }, []);

  const isTypeHoverable = useCallback((dataType) => {
    if (isEntireScore) return true;
    return activeElementTypes.has(dataType);
  }, [isEntireScore, activeElementTypes]);

  const onPointerMove = useCallback((e) => {
    if (isPanning.current) {
      const dx = e.clientX - panOrigin.current.mx;
      const dy = e.clientY - panOrigin.current.my;
      setPan({ x: panOrigin.current.px + dx, y: panOrigin.current.py + dy });
      return;
    }
    const wrap = svgWrapRef.current;
    if (!wrap) return;
    const tagged = findTaggedAncestor(e.target, wrap);
    if (tagged) {
      const dataType = tagged.getAttribute("data-type") || "";
      if (isTypeHoverable(dataType)) {
        setHoveredId(tagged.getAttribute("id"));
        if (!pinned) {
          setTooltip({ x: e.clientX, y: e.clientY, attrs: getDataAttrs(tagged) });
        }
      } else {
        setHoveredId(null);
        if (!pinned) setTooltip(null);
      }
    } else {
      setHoveredId(null);
      if (!pinned) setTooltip(null);
    }
  }, [pinned, isTypeHoverable]);

  const onPointerUp = useCallback((e) => {
    const wasPanning = isPanning.current;
    isPanning.current = false;
    if (wasPanning) return;
    const wrap = svgWrapRef.current;
    if (!wrap) return;
    const tagged = findTaggedAncestor(e.target, wrap);
    if (tagged) {
      const dataType = tagged.getAttribute("data-type") || "";
      if (!isTypeHoverable(dataType)) {
        setPinned(null);
        return;
      }
      const attrs = getDataAttrs(tagged);
      if (pinned && pinned.attrs.id === attrs.id) {
        setPinned(null);
      } else {
        setPinned({ x: e.clientX, y: e.clientY, attrs });
        setTooltip(null);
      }
    } else {
      setPinned(null);
    }
  }, [pinned, isTypeHoverable]);

  // --- HOVER OUTLINE ---
  useEffect(() => {
    const wrap = svgWrapRef.current;
    if (!wrap) return;
    wrap.querySelectorAll(".cnb-hover-hl").forEach((el) => {
      el.style.outline = "";
      el.style.outlineOffset = "";
      el.classList.remove("cnb-hover-hl");
    });
    const activeId = pinned?.attrs?.id || hoveredId;
    if (activeId) {
      const escaped = CSS?.escape ? CSS.escape(activeId) : activeId.replace(/([.:])/g, "\\$1");
      const el = wrap.querySelector(`#${escaped}`);
      if (el) {
        el.style.outline = `2px solid ${HIGHLIGHT_COLOR}`;
        el.style.outlineOffset = "2px";
        el.classList.add("cnb-hover-hl");
      }
    }
  }, [hoveredId, pinned, svgText]);

  const activeTooltip = pinned || tooltip;

  // Look up matching norm element for the active tooltip
  const normMatch = useMemo(() => {
    if (!activeTooltip?.attrs || !normData) return null;
    return findMatchingNormUse(activeTooltip.attrs, normData);
  }, [activeTooltip, normData]);

  // --- Highlight from diagnostic panel ---
  const highlightElement = useCallback((id) => {
    const wrap = svgWrapRef.current;
    if (!wrap) return;
    const escaped = CSS?.escape ? CSS.escape(id) : id.replace(/([.:])/g, "\\$1");
    const el = wrap.querySelector(`#${escaped}`);
    if (el) {
      setPinned({ x: 200, y: 200, attrs: getDataAttrs(el) });
    }
  }, []);

  const dimPct = Math.round(dimLevel * 100);
  const zoomPct = Math.round(zoom * 100);
  const zoomSliderVal = zoomToSlider(zoom);

  // Count grid "elements" for the toggle button label
  const gridCount = gridData
    ? gridData.systems.length + gridData.barlinesBySystem.reduce((s, b) => s + b.length, 0)
    : 0;

  return (
    <div style={{
      display: "flex", flexDirection: "column", height: "100vh",
      background: "#f5f5f5", color: "#333",
      fontFamily: "'JetBrains Mono', 'Fira Code', 'SF Mono', 'Consolas', monospace",
      fontSize: 12,
    }}>
      {/* ── TOOLBAR ── */}
      <div style={{
        padding: "6px 12px", background: "#fff",
        borderBottom: "1px solid #ddd",
        display: "flex", alignItems: "center", gap: 10, flexShrink: 0,
        flexWrap: "wrap",
      }}>
        <span style={{ fontWeight: 800, fontSize: 13, color: HIGHLIGHT_COLOR, letterSpacing: 1 }}>
          CNB INSPECTOR
        </span>

        <label style={{
          cursor: "pointer", background: "#f0f0f0", padding: "3px 10px",
          borderRadius: 4, border: "1px solid #ccc", fontSize: 11,
          display: "flex", alignItems: "center", gap: 4, color: "#444",
        }}>
          📂 Open SVG
          <input type="file" accept=".svg" style={{ display: "none" }}
            onChange={(e) => loadFile(e.target.files?.[0])} />
        </label>

        {fileName && (
          <span style={{ color: "#888", fontSize: 11 }}>{fileName}</span>
        )}

        <div style={{ flex: 1 }} />

        {/* Zoom controls */}
        <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
          <span style={{ color: "#999", fontSize: 10 }}>ZOOM</span>
          <input type="range" min="0" max="100" value={zoomSliderVal}
            onChange={(e) => {
              const newZ = sliderToZoom(parseInt(e.target.value));
              const vp = viewportRef.current;
              if (vp) {
                const rect = vp.getBoundingClientRect();
                const mx = rect.width / 2;
                const my = rect.height / 2;
                const ratio = newZ / zoom;
                setPan({
                  x: mx - ratio * (mx - pan.x),
                  y: my - ratio * (my - pan.y),
                });
              }
              setZoom(newZ);
            }}
            style={{ width: 80, accentColor: HIGHLIGHT_COLOR }} />
          <span style={{ color: "#888", fontSize: 10, minWidth: 40, textAlign: "right" }}>
            {zoomPct}%
          </span>
          <button onClick={() => { setZoom(1); setPan({ x: 0, y: 0 }); }} style={{
            background: "#f0f0f0", border: "1px solid #ccc", color: "#444",
            padding: "2px 6px", borderRadius: 3, cursor: "pointer", fontSize: 9,
          }}>100%</button>
        </div>
      </div>

      {/* ── SOURCE SVG BAR ── */}
      {stats && (
        <div style={{
          padding: "3px 12px", background: "#fafafa",
          borderBottom: "1px solid #e8e8e8",
          display: "flex", gap: 4, flexWrap: "wrap", alignItems: "center",
        }}>
          <span style={{ color: "#999", marginRight: 2, fontSize: 9, fontWeight: 700, letterSpacing: 0.5 }}>
            SVG
          </span>
          <span style={{ color: "#ccc", marginRight: 2, fontSize: 10 }}>
            {stats.total}
          </span>

          <button
            onClick={() => toggleType("entire-score")}
            style={{
              background: isEntireScore ? HIGHLIGHT_COLOR + "18" : "#fff",
              border: `1px solid ${isEntireScore ? HIGHLIGHT_COLOR : "#ddd"}`,
              color: isEntireScore ? HIGHLIGHT_COLOR : "#555",
              borderRadius: 3, padding: "1px 6px",
              cursor: "pointer", fontSize: 10, fontFamily: "inherit",
              fontWeight: isEntireScore ? 700 : 400,
            }}>
            entire score
          </button>

          {/* Grid toggle */}
          {gridData && (
            <button
              onClick={() => toggleType("grid")}
              style={{
                background: isGridActive ? GRID_COLOR + "18" : "#fff",
                border: `1px solid ${isGridActive ? GRID_COLOR : "#ddd"}`,
                color: isGridActive ? GRID_COLOR : TYPE_LABEL_COLORS.grid,
                borderRadius: 3, padding: "1px 6px",
                cursor: "pointer", fontSize: 10, fontFamily: "inherit",
                fontWeight: isGridActive ? 700 : 400,
              }}>
              ▦ grid
            </button>
          )}

          <span style={{ color: "#ddd" }}>|</span>

          <button onClick={selectAllTypes} style={{
            background: "#fff", border: "1px solid #ddd", color: "#999",
            borderRadius: 3, padding: "1px 5px", cursor: "pointer",
            fontSize: 9, fontFamily: "inherit",
          }}>all</button>
          <button onClick={selectNone} style={{
            background: "#fff", border: "1px solid #ddd", color: "#999",
            borderRadius: 3, padding: "1px 5px", cursor: "pointer",
            fontSize: 9, fontFamily: "inherit",
          }}>none</button>

          <span style={{ color: "#ddd" }}>|</span>

          {Object.entries(stats.types)
            .sort((a, b) => b[1] - a[1])
            .map(([type, count]) => {
              const labelColor = TYPE_LABEL_COLORS[type] || "#666";
              const active = activeElementTypes.has(type);
              return (
                <button key={type} onClick={() => toggleType(type)}
                  style={{
                    background: active ? HIGHLIGHT_COLOR + "18" : "#fff",
                    border: `1px solid ${active ? HIGHLIGHT_COLOR : "#ddd"}`,
                    color: active ? HIGHLIGHT_COLOR : labelColor,
                    borderRadius: 3, padding: "1px 6px",
                    cursor: "pointer", fontSize: 10, fontFamily: "inherit",
                    fontWeight: active ? 700 : 400,
                  }}>
                  {type}:{count}
                </button>
              );
            })}

          {/* DIM controls — right-aligned within source SVG bar */}
          <div style={{ flex: 1 }} />
          <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
            {hasTypeSelection && (
              <button
                onClick={() => setDimTarget(dimTarget === "others" ? "selected" : "others")}
                style={{
                  background: "#f0f0f0", border: "1px solid #ccc", color: "#555",
                  padding: "2px 7px", borderRadius: 3, cursor: "pointer",
                  fontSize: 9, fontFamily: "inherit", whiteSpace: "nowrap",
                }}
                title="Toggle whether dimming applies to the selected types or everything else"
              >
                dim {dimTarget === "others" ? "others" : "selected"}
              </button>
            )}
            <span style={{ color: "#999", fontSize: 10 }}>DIM</span>
            <input type="range" min="0" max="100" value={dimPct}
              onChange={(e) => setDimLevel(e.target.value / 100)}
              style={{ width: 60, accentColor: HIGHLIGHT_COLOR }} />
            <span style={{ color: "#999", fontSize: 10, minWidth: 28 }}>{dimPct}%</span>
          </div>
        </div>
      )}

      {/* ── NORM BAR ── */}
      {normData && (
        <div style={{
          padding: "3px 12px", background: "#f5f8ff",
          borderBottom: "1px solid #d8e4f0",
          display: "flex", gap: 4, flexWrap: "wrap", alignItems: "center",
        }}>
          <span style={{ color: NORM_COLOR, marginRight: 2, fontSize: 9, fontWeight: 700, letterSpacing: 0.5 }}>
            NORM
          </span>

          <button
            onClick={() => toggleType("norm")}
            style={{
              background: isNormActive ? NORM_COLOR + "18" : "#fff",
              border: `1px solid ${isNormActive ? NORM_COLOR : "#ddd"}`,
              color: isNormActive ? NORM_COLOR : NORM_COLOR,
              borderRadius: 3, padding: "1px 6px",
              cursor: "pointer", fontSize: 10, fontFamily: "inherit",
              fontWeight: isNormActive ? 700 : 400,
            }}>
            ▧ {isNormActive ? "on" : "off"}
          </button>

          <button
            onClick={() => {
              const svgStr = serializeNormSvg(normData, viewBox);
              if (!svgStr) return;
              const blob = new Blob([svgStr], { type: "image/svg+xml" });
              const url = URL.createObjectURL(blob);
              const a = document.createElement("a");
              const base = fileName ? fileName.replace(/\.svg$/i, "") : "score";
              a.href = url;
              a.download = `${base}-normalized.svg`;
              a.click();
              URL.revokeObjectURL(url);
            }}
            style={{
              background: "#fff",
              border: `1px solid ${NORM_COLOR}60`,
              color: NORM_COLOR,
              borderRadius: 3, padding: "1px 6px",
              cursor: "pointer", fontSize: 10, fontFamily: "inherit",
            }}
            title="Download normalized SVG"
          >
            ⬇ save
          </button>

          <span style={{ color: "#ddd" }}>|</span>

          {/* Norm type badges — one per source type present */}
          {normData.stats.typeCounts && Object.entries(normData.stats.typeCounts)
            .sort(([,a], [,b]) => (NORM_RENDER_ORDER[a] ?? 50) - (NORM_RENDER_ORDER[b] ?? 50))
            .map(([type, counts]) => (
            <span key={type} style={{
              background: NORM_COLOR + "10",
              border: `1px solid ${NORM_COLOR}40`,
              color: NORM_COLOR,
              borderRadius: 3, padding: "1px 6px",
              fontSize: 10, fontFamily: "inherit",
            }}>
              {type}:{counts.uses}
            </span>
          ))}

          <div style={{ flex: 1 }} />

          {/* Norm DIM controls */}
          <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
            <span style={{ color: NORM_COLOR, fontSize: 10, opacity: 0.6 }}>DIM</span>
            <input type="range" min="0" max="100" value={Math.round(normDimLevel * 100)}
              onChange={(e) => setNormDimLevel(e.target.value / 100)}
              style={{ width: 60, accentColor: NORM_COLOR }} />
            <span style={{ color: NORM_COLOR, fontSize: 10, minWidth: 28, opacity: 0.6 }}>{Math.round(normDimLevel * 100)}%</span>
          </div>

          <span style={{ color: "#d8e4f0" }}>|</span>

          {/* Summary */}
          <span style={{ color: NORM_COLOR, fontSize: 9, opacity: 0.7 }}>
            {normData.stats.totalDefs} def{normData.stats.totalDefs !== 1 ? "s" : ""}
            {" "}({normData.stats.atomicShapes} leaf{normData.stats.atomicShapes !== 1 ? "s" : ""}
            {normData.stats.compoundGroups > 0 && ` + ${normData.stats.compoundGroups} compound`})
            {" "}· {normData.stats.totalUses} use{normData.stats.totalUses !== 1 ? "s" : ""}
            {normData.warnings.length > 0 && (
              <span style={{ color: "#f39c12" }}>
                {" "}· {normData.warnings.length} ⚠
              </span>
            )}
          </span>
        </div>
      )}

      {/* ── VIEWPORT ── */}
      <div
        ref={viewportRef}
        style={{
          flex: 1, overflow: "hidden", position: "relative",
          cursor: isPanning.current ? "grabbing" : "grab",
          background: "#ffffff",
        }}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerLeave={() => { isPanning.current = false; }}
        onDrop={(e) => { e.preventDefault(); loadFile(e.dataTransfer?.files?.[0]); }}
        onDragOver={(e) => e.preventDefault()}
      >
        {!svgText && (
          <div style={{
            position: "absolute", inset: 0,
            display: "flex", alignItems: "center", justifyContent: "center",
            flexDirection: "column", gap: 8, pointerEvents: "none",
          }}>
            <div style={{ fontSize: 56, opacity: 0.2 }}>🎼</div>
            <div style={{ fontSize: 13, opacity: 0.35, letterSpacing: 1, color: "#666" }}>
              DROP SVG OR CLICK OPEN
            </div>
            <div style={{ fontSize: 10, opacity: 0.25, marginTop: 4, color: "#888" }}>
              drag to pan · scroll to zoom · click element to pin info
            </div>
          </div>
        )}

        {/* Pan wrapper — translate only, zoom handled by SVG width/height */}
        <div style={{
          transformOrigin: "0 0",
          transform: `translate(${pan.x}px, ${pan.y}px)`,
          position: "relative",
        }}>
          {/* Score SVG */}
          <div ref={svgWrapRef} />

          {/* Normalization overlay — clean, restructured elements */}
          {normVisible && normData && (
            <NormalizationOverlay
              normData={normData}
              viewBox={viewBox}
              zoom={zoom}
              baseDims={baseDims}
              opacity={normOpacity}
            />
          )}

          {/* Grid overlay — positioned on top, same zoom via matching width/height */}
          {gridVisible && gridData && (
            <GridOverlay
              gridData={gridData}
              viewBox={viewBox}
              zoom={zoom}
              baseDims={baseDims}
              opacity={gridOpacity}
            />
          )}
        </div>
      </div>

      {/* ── TOOLTIP ── */}
      {activeTooltip && (
        <div style={{
          position: "fixed",
          left: Math.min(activeTooltip.x + 14, window.innerWidth - 300),
          top: Math.min(activeTooltip.y + 14, window.innerHeight - 200),
          background: "#fff",
          border: `1px solid ${pinned ? HIGHLIGHT_COLOR : "#ccc"}`,
          borderRadius: 6, padding: "8px 12px",
          fontSize: 11, lineHeight: 1.7,
          zIndex: 1000, minWidth: 180, maxWidth: 320,
          pointerEvents: "none",
          boxShadow: pinned
            ? `0 0 12px ${HIGHLIGHT_COLOR}33, 0 4px 16px rgba(0,0,0,0.12)`
            : "0 2px 12px rgba(0,0,0,0.1)",
        }}>
          {pinned && (
            <div style={{ fontSize: 9, color: HIGHLIGHT_COLOR, marginBottom: 2, letterSpacing: 1 }}>
              PINNED — click elsewhere to dismiss
            </div>
          )}
          <div style={{
            fontWeight: 700, color: HIGHLIGHT_COLOR,
            marginBottom: 2, fontSize: 12,
          }}>
            {activeTooltip.attrs?.id}
          </div>
          {Object.entries(activeTooltip.attrs || {})
            .filter(([k]) => k !== "id")
            .map(([k, v]) => (
              <div key={k}>
                <span style={{ color: "#999" }}>{k.replace("data-", "")}: </span>
                <span style={{ color: "#333" }}>{v}</span>
              </div>
            ))}
          {/* NORM section — shows matching normalization layer attributes */}
          {normMatch && (
            <>
              <div style={{
                borderTop: `1px solid ${NORM_COLOR}40`,
                marginTop: 4,
                paddingTop: 3,
                fontSize: 9,
                color: NORM_COLOR,
                fontWeight: 700,
                letterSpacing: 0.5,
              }}>
                NORM
              </div>
              <div>
                <span style={{ color: NORM_COLOR, opacity: 0.6 }}>type: </span>
                <span style={{ color: NORM_COLOR }}>{normMatch.normType}</span>
                {normMatch.type === "group" && (
                  <span style={{ color: NORM_COLOR, opacity: 0.6 }}> (group ×{normMatch.children.length})</span>
                )}
              </div>
              {normMatch.type !== "group" ? (
                <>
                  <div>
                    <span style={{ color: NORM_COLOR, opacity: 0.6 }}>href: </span>
                    <span style={{ color: NORM_COLOR }}>{normMatch.href}</span>
                  </div>
                  <div>
                    <span style={{ color: NORM_COLOR, opacity: 0.6 }}>transform: </span>
                    <span style={{ color: NORM_COLOR }}>{normMatch.transform}</span>
                  </div>
                  {normMatch.fill && (
                    <div>
                      <span style={{ color: NORM_COLOR, opacity: 0.6 }}>fill: </span>
                      <span style={{ color: NORM_COLOR }}>{normMatch.fill}</span>
                    </div>
                  )}
                </>
              ) : (
                <>
                  {normMatch.children.slice(0, 3).map((c, ci) => (
                    <div key={ci} style={{ marginLeft: 6 }}>
                      <span style={{ color: NORM_COLOR, opacity: 0.4 }}>[{ci}] </span>
                      <span style={{ color: NORM_COLOR }}>{c.href}</span>
                      <span style={{ color: NORM_COLOR, opacity: 0.5 }}> {c.transform?.split(" ").pop()}</span>
                    </div>
                  ))}
                  {normMatch.children.length > 3 && (
                    <div style={{ color: NORM_COLOR, opacity: 0.5, marginLeft: 6 }}>
                      ...+{normMatch.children.length - 3} more
                    </div>
                  )}
                </>
              )}
            </>
          )}
        </div>
      )}

      {/* ── DIAGNOSTIC PANEL ── */}
      {enrichmentResult && (
        <DiagnosticPanel
          diagnostics={enrichmentResult.diagnostics}
          enriched={enrichmentResult.enriched}
          skipped={enrichmentResult.skipped}
          onHighlight={highlightElement}
        />
      )}

      {/* ── NOTEHEAD DIAGNOSTIC PANEL ── */}
      {noteheadDiag && (
        <NoteheadDiagnosticPanel diagData={noteheadDiag} />
      )}

      {/* ── FOOTER ── */}
      <div style={{
        padding: "3px 12px", background: "#fff",
        borderTop: "1px solid #ddd",
        fontSize: 10, color: "#aaa",
        display: "flex", justifyContent: "space-between",
      }}>
        <span>drag to pan · scroll to zoom · click to pin</span>
        <span style={{ display: "flex", gap: 12 }}>
          {normData && (
            <span style={{ color: NORM_COLOR }}>
              norm: {normData.stats.totalDefs} defs · {normData.stats.totalUses} uses · {normData.stats.totalElements} elements
              {normData.warnings.length > 0 && ` · ${normData.warnings.length} warning${normData.warnings.length !== 1 ? "s" : ""}`}
            </span>
          )}
          {gridData && (
            <span>
              {gridData.systems.length} systems · {gridData.barlinesBySystem.reduce((s, b) => s + b.length, 0)} barlines
            </span>
          )}
          {baseDims && (
            <span>canvas: {Math.round(baseDims.w)} × {Math.round(baseDims.h)} px</span>
          )}
        </span>
      </div>
    </div>
  );
}
