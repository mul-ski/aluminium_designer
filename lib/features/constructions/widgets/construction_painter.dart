import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/geometry/drafting_grid.dart';
import '../../../core/geometry/section_layout.dart';
import '../../../core/geometry/snap.dart';
import '../../../core/models/construction.dart';
import '../../../core/models/layout_direction.dart';
import '../../../core/models/opening.dart';
import '../../../core/models/section.dart';

/// French label for an [OpeningType], matching the labels already used in
/// `NewConstructionScreen`'s dropdown so the same vocabulary is used
/// everywhere an opening type is shown to the user.
String openingTypeLabel(OpeningType type) {
  switch (type) {
    case OpeningType.fixe:
      return 'Fixe';
    case OpeningType.francaise:
      return 'Française';
    case OpeningType.anglaise:
      return 'Anglaise';
    case OpeningType.oscilloBattant:
      return 'Oscillo-battant';
    case OpeningType.coulissante:
      return 'Coulissante';
  }
}

/// Which OVERALL dimension label a pointer interaction landed on.
enum ConstructionDimensionLabel { overallWidth, overallHeight }

/// One clickable dimension-label region on the canvas, in CANVAS-LOCAL
/// pixel coordinates -- the same space [ConstructionPainter] paints in and
/// gesture handlers read.
class DimensionLabelTarget {
  final ConstructionDimensionLabel label;

  /// Generous grab box around the painted text. Deliberately larger than
  /// the glyphs: a dimension label is a small target for a precise intent
  /// ("edit this number"), so the affordance should forgive.
  final Rect hitBounds;

  const DimensionLabelTarget({required this.label, required this.hitBounds});
}

/// Computes the interactive regions of the OVERALL dimension labels --
/// the exact same anchors `_paintOverallDimensions` draws (width centered
/// above the top edge, height rotated beside the left edge), so what you
/// see is precisely what you can click.
///
/// Only the two OVERALL labels are exposed deliberately: per-section
/// labels sit inside their section rectangles, where a click must keep its
/// existing meaning (section selection); making interior text an edit
/// handle would silently steal that gesture. Dedicated per-section
/// dimension chips OUTSIDE the drawing remain a future task.
///
/// Pure function -- unit-testable against the painter's own constants.
List<DimensionLabelTarget> dimensionLabelTargets({
  required ConstructionLayout layout,
  required FittedTransform transform,
}) {
  final left = transform.toPixelX(0);
  final top = transform.toPixelY(0);
  final right = transform.toPixelX(layout.width);
  final bottom = transform.toPixelY(layout.height);

  return [
    DimensionLabelTarget(
      label: ConstructionDimensionLabel.overallWidth,
      hitBounds: Rect.fromCenter(
        center: Offset((left + right) / 2, top - 18),
        width: 104,
        height: 26,
      ),
    ),
    DimensionLabelTarget(
      label: ConstructionDimensionLabel.overallHeight,
      hitBounds: Rect.fromCenter(
        center: Offset(left - 34, (top + bottom) / 2),
        width: 26,
        height: 104,
      ),
    ),
  ];
}

/// Draws one [Construction]'s outer rectangle and sections in 2D.
///
/// This paints construction/section geometry only -- widths, heights, and
/// fixed-vs-ouvrant distinction -- and deliberately nothing else. No
/// profile cross-sections, no hardware, no mullions/frame thickness: those
/// would be fabrication geometry, which this milestone explicitly excludes
/// (see [layoutConstruction]'s doc for why section geometry and profile
/// geometry are kept separate).
///
/// The model(millimetre)→screen(pixel) mapping comes in via [transform],
/// supplied by the editor's single authoritative `EditorViewport` -- this
/// painter computes NO transform of its own (the previous internal
/// `fitConstructionToCanvas` call was the second of the two stacked
/// transforms and is gone). It owns no geometry state beyond drawing: hit
/// testing lives in `sectionAtPoint` + `EditorViewport.screenToModel`, not
/// here.
class ConstructionPainter extends CustomPainter {
  final Construction construction;

  /// The id of the currently selected [Section], or `null` if the
  /// construction root is selected (no section highlighted). This mirrors
  /// exactly what the editor controller holds -- the painter does not keep
  /// its own idea of "selected", it only visualizes the one shared
  /// selection value passed in, matching the requirement that canvas and
  /// left-panel selection never diverge.
  final String? selectedSectionId;

  /// The current viewport transform. Text labels are drawn at projected
  /// anchor points with UNSCALED font sizes, so labels stay legible at any
  /// zoom level while moving with their geometry.
  final FittedTransform transform;

  /// A currently-highlighted snap to visualize, or null for none.
  ///
  /// Lifecycle is owned by the manipulating widget (set while dragging,
  /// cleared when the gesture ends). Rendered as a 1 px accent line across
  /// the construction extent at the snapped position -- solid for geometry
  /// kinds, dashed for grid snaps (see `_paintActiveSnap`).
  final ActiveSnap? activeSnap;

  /// Whether the real-world measurement grid is drawn UNDER the geometry.
  ///
  /// Pure presentation, driven by the editor's drafting settings; it shares
  /// nothing with snapping (a drawn grid does not snap, a hidden grid can
  /// still snap). The interval adapts to [transform]'s scale via the pure
  /// `drafting_grid` math; lines are enumerated only for the visible
  /// model-space range.
  final bool showGrid;

  ConstructionPainter({
    required this.construction,
    required this.selectedSectionId,
    required this.transform,
    this.activeSnap,
    this.showGrid = false,
  });

  // Palette tuned for the workshop drafting canvas: an off-white ground
  // (ConstructionEditorCanvas background Color(0xFFFAFBFC)) with pale
  // section fills and dark strokes -- a technical drawing, not a dark CAD
  // viewport. Dimension text is muted slate; selection/snap blue reads
  // clearly against both fills and ground.
  static const _fixedFill = Color(0xFFE3E9ED);
  static const _ouvrantFill = Color(0xFFD8EBDF);
  static const _outerStroke = Color(0xFF37424C);
  static const _sectionStroke = Color(0xFF6C7F8C);
  static const _dimensionColor = Color(0xFF4A5763);
  static const _selectionStroke = Color(0xFF1976D2);

  // Measurement grid: deliberately WEAKER than every construction stroke
  // so the grid can never overpower the drawing (unsaturated, near-ground
  // grays). The model origin axes get one step stronger as a subtle anchor.
  static const _gridMinorColor = Color(0xFFE7EAED);
  static const _gridMajorColor = Color(0xFFD8DEE3);
  static const _gridOriginColor = Color(0xFFC9D1D7);

  @override
  void paint(Canvas canvas, Size size) {
    // Grid first: it must sit UNDER everything, and its subtlety is
    // guaranteed by z-order as well as by its near-ground grays.
    if (showGrid) {
      _paintGrid(canvas, size, transform);
    }

    final layout = layoutConstruction(construction);
    if (layout == null) {
      // Construction doesn't have both overall dimensions yet -- nothing
      // to draw. The editor is responsible for telling the user why (see
      // `GeometryStatus.incomplete`); this painter only avoids crashing on
      // a null layout, it doesn't duplicate that messaging.
      return;
    }

    // Degenerate transform (e.g. zero-area canvas) -- nothing usable to
    // draw.
    if (transform.scale <= 0) {
      return;
    }

    for (final rect in layout.sections) {
      _paintSection(canvas, rect, transform);
    }

    _paintOuterOutline(canvas, layout, transform);
    _paintOverallDimensions(canvas, layout, transform);

    final snap = activeSnap;
    if (snap != null) {
      _paintActiveSnap(canvas, layout, snap);
    }
  }

  /// Draws the adaptive measurement grid across the WHOLE canvas -- not
  /// just the construction extent: a drafting workspace extends beyond the
  /// current drawing while staying pinned to real model coordinates.
  ///
  /// Interval selection and line enumeration are fully delegated to the
  /// pure `drafting_grid` functions; this method only maps model-space
  /// lines through the viewport transform. The visible model range is the
  /// exact inverse of that transform at the canvas edges, so panning/zooming
  /// never draws off-screen lines and never misses on-screen ones.
  void _paintGrid(Canvas canvas, Size size, FittedTransform t) {
    final minorMm = selectMinorGridInterval(scale: t.scale);
    if (minorMm <= 0) return; // Degenerate transform: no grid.

    final minModelX = -t.offsetX / t.scale;
    final maxModelX = (size.width - t.offsetX) / t.scale;
    final minModelY = -t.offsetY / t.scale;
    final maxModelY = (size.height - t.offsetY) / t.scale;

    final verticals =
        gridLinesForRange(minMm: minModelX, maxMm: maxModelX, minorIntervalMm: minorMm);
    final horizontals =
        gridLinesForRange(minMm: minModelY, maxMm: maxModelY, minorIntervalMm: minorMm);

    Paint paintFor(DraftingGridLine line) => Paint()
      ..strokeWidth = 1
      ..color = line.positionMm == 0 // index-0 line is exactly 0.0
          ? _gridOriginColor
          : line.isMajor
              ? _gridMajorColor
              : _gridMinorColor;

    for (final line in verticals) {
      final x = t.toPixelX(line.positionMm);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paintFor(line));
    }
    for (final line in horizontals) {
      final y = t.toPixelY(line.positionMm);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintFor(line));
    }
  }

  /// Draws the accent line for [snap]: perpendicular to the layout axis,
  /// spanning the construction's full extent at the snapped position.
  ///
  /// SOLID for geometry snaps (real construction features) and DASHED for
  /// grid snaps (the regular aid) -- same accent color, unambiguous shape,
  /// so the user can always tell WHAT a position locked onto.
  void _paintActiveSnap(
    Canvas canvas,
    ConstructionLayout layout,
    ActiveSnap snap,
  ) {
    final paint = Paint()
      ..color = _selectionStroke
      ..strokeWidth = 1;

    if (construction.layoutDirection == SectionLayoutDirection.horizontal) {
      final x = transform.toPixelX(snap.positionMm);
      final start = Offset(x, transform.toPixelY(0));
      final end = Offset(x, transform.toPixelY(layout.height));
      if (snap.kind == SnapTargetKind.grid) {
        _drawDashedLine(canvas, start, end, paint);
      } else {
        canvas.drawLine(start, end, paint);
      }
    } else {
      final y = transform.toPixelY(snap.positionMm);
      final start = Offset(transform.toPixelX(0), y);
      final end = Offset(transform.toPixelX(layout.width), y);
      if (snap.kind == SnapTargetKind.grid) {
        _drawDashedLine(canvas, start, end, paint);
      } else {
        canvas.drawLine(start, end, paint);
      }
    }
  }

  /// Draws [start]->[end] as a dashed stroke (screen-perceived fixed dash
  /// length; no model-space meaning). Used only for grid-snap indicators.
  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    double dashLength = 6,
    double gapLength = 4,
  }) {
    final delta = end - start;
    final total = delta.distance;
    if (total <= 0) return;
    final unit = delta / total;

    var traveled = 0.0;
    while (traveled < total) {
      final segmentEnd = math.min(traveled + dashLength, total);
      canvas.drawLine(
        start + unit * traveled,
        start + unit * segmentEnd,
        paint,
      );
      traveled = segmentEnd + gapLength;
    }
  }

  void _paintSection(Canvas canvas, SectionRect rect, FittedTransform t) {
    final pixelRect = Rect.fromLTWH(
      t.toPixelX(rect.x),
      t.toPixelY(rect.y),
      t.toPixelLength(rect.width),
      t.toPixelLength(rect.height),
    );

    final isSelected = rect.section.id == selectedSectionId;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = rect.section.kind == SectionKind.ouvrant
          ? _ouvrantFill
          : _fixedFill;

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = _sectionStroke;

    canvas.drawRect(pixelRect, fillPaint);
    canvas.drawRect(pixelRect, strokePaint);

    // Ouvrant sections get an extra inset outline so "openable" is
    // distinguishable from "fixed" even without color (e.g. printing,
    // color-blind accessibility) -- fixed sections stay a single flat
    // rectangle.
    if (rect.section.kind == SectionKind.ouvrant) {
      final inset = (pixelRect.shortestSide * 0.12).clamp(4.0, 16.0);
      final insetRect = pixelRect.deflate(inset);
      if (insetRect.width > 0 && insetRect.height > 0) {
        final insetPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = _sectionStroke.withValues(alpha: 0.6);
        canvas.drawRect(insetRect, insetPaint);
      }
    }

    // Selected section gets a heavier, colored outline drawn on top --
    // this is the only visual difference selection introduces; fill,
    // ouvrant inset, and label all stay exactly as they'd render
    // unselected, so selection never changes what geometry the drawing
    // communicates, only that it's the current focus.
    if (isSelected) {
      final selectionPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _selectionStroke;
      canvas.drawRect(pixelRect.deflate(1.5), selectionPaint);
    }

    _paintSectionLabel(canvas, pixelRect, rect.section);
  }

  void _paintSectionLabel(Canvas canvas, Rect pixelRect, Section section) {
    final lines = <String>[];

    // Dimensions are only worth drawing per-section if there's visibly
    // more than one section -- a single-section construction already
    // shows its size via the overall dimension labels, and repeating it
    // inside the rectangle would be redundant.
    lines.add(
      '${section.width.toStringAsFixed(0)} × '
      '${section.height.toStringAsFixed(0)} mm',
    );

    if (section.kind == SectionKind.ouvrant && section.openingType != null) {
      lines.add(openingTypeLabel(section.openingType!));
      if (section.vantauxCount > 1) {
        lines.add('${section.vantauxCount} vantaux');
      }
    }

    final text = lines.join('\n');

    // Skip the label entirely when the section is too small on screen to
    // hold it legibly. This check MUST run before layout: once a section
    // renders narrower than its horizontal padding -- possible at high
    // zoom-out now that the paint-time transform is the live viewport zoom
    // rather than the fixed internal fit -- `pixelRect.width - 8` becomes
    // negative and TextPainter rejects the constraint outright, crashing
    // every painted frame. Only ever hand TextPainter usable, finite,
    // positive space.
    final availableWidth = pixelRect.width - 8;
    final availableHeight = pixelRect.height - 4;
    if (!availableWidth.isFinite ||
        !availableHeight.isFinite ||
        availableWidth <= 0 ||
        availableHeight <= 0) {
      return;
    }

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: _dimensionColor,
          fontSize: 12,
          height: 1.3,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: availableWidth);

    // Skip the label entirely if the text does not fit inside the section
    // even though there was room to measure it.
    if (painter.width > availableWidth + 4 ||
        painter.height > availableHeight + 4) {
      return;
    }

    final offset = Offset(
      pixelRect.center.dx - painter.width / 2,
      pixelRect.center.dy - painter.height / 2,
    );
    painter.paint(canvas, offset);
  }

  void _paintOuterOutline(
    Canvas canvas,
    ConstructionLayout layout,
    FittedTransform t,
  ) {
    final pixelRect = Rect.fromLTWH(
      t.toPixelX(0),
      t.toPixelY(0),
      t.toPixelLength(layout.width),
      t.toPixelLength(layout.height),
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = _outerStroke;

    canvas.drawRect(pixelRect, paint);
  }

  void _paintOverallDimensions(
    Canvas canvas,
    ConstructionLayout layout,
    FittedTransform t,
  ) {
    final left = t.toPixelX(0);
    final top = t.toPixelY(0);
    final right = t.toPixelX(layout.width);
    final bottom = t.toPixelY(layout.height);

    _drawDimensionLabel(
      canvas,
      text: '${layout.width.toStringAsFixed(0)} mm',
      center: Offset((left + right) / 2, top - 18),
    );

    _drawDimensionLabel(
      canvas,
      text: '${layout.height.toStringAsFixed(0)} mm',
      center: Offset(left - 34, (top + bottom) / 2),
      rotated: true,
    );
  }

  void _drawDimensionLabel(
    Canvas canvas, {
    required String text,
    required Offset center,
    bool rotated = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: _dimensionColor,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    if (!rotated) {
      painter.paint(
        canvas,
        Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
      );
      return;
    }

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-1.5707963267948966); // -90 degrees, in radians.
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ConstructionPainter oldDelegate) {
    return oldDelegate.construction != construction ||
        oldDelegate.selectedSectionId != selectedSectionId ||
        oldDelegate.activeSnap != activeSnap ||
        oldDelegate.showGrid != showGrid ||
        // The transform lives INSIDE this painter since the live-viewport
        // rewrite, so any pan/zoom/fit must trigger a repaint. Without
        // this comparison the canvas keeps displaying the very first
        // frame -- painted with the pre-fit identity matrix, where
        // millimetre-space rects are enormous and flood the whole view --
        // even though the viewport itself has long been fitted. This also
        // keeps the grid re-enumerated on every pan/zoom step.
        oldDelegate.transform.scale != transform.scale ||
        oldDelegate.transform.offsetX != transform.offsetX ||
        oldDelegate.transform.offsetY != transform.offsetY;
  }
}
