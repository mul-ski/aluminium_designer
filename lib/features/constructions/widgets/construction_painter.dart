import 'package:flutter/material.dart';

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
  /// Dormant plumbing: nothing produces an [ActiveSnap] yet -- the field
  /// arrives with drag manipulation, which will own its lifecycle (set
  /// during a gesture, cleared on end). When present, a 1 px accent line
  /// is drawn across the full construction extent at the snapped position,
  /// in the same blue as selection highlights.
  final ActiveSnap? activeSnap;

  ConstructionPainter({
    required this.construction,
    required this.selectedSectionId,
    required this.transform,
    this.activeSnap,
  });

  // Palette tuned for ConstructionEditorScreen's DARK SLATE canvas
  // background (Color(0xFF262C33)): mid-tone section fills with light
  // strokes keep aluminium geometry clearly readable, while dimension
  // text uses a muted cool gray. Selection/snap blue is brightened
  // against the dark ground.
  static const _fixedFill = Color(0xFF46525C);
  static const _ouvrantFill = Color(0xFF3E5A4F);
  static const _outerStroke = Color(0xFFB7C4CE);
  static const _sectionStroke = Color(0xFF8FA1AD);
  static const _dimensionColor = Color(0xFFAEB9C2);
  static const _selectionStroke = Color(0xFF64B5F6);

  @override
  void paint(Canvas canvas, Size size) {
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

  /// Draws the accent line for [snap]: perpendicular to the layout axis,
  /// spanning the construction's full extent at the snapped position.
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
      canvas.drawLine(
        Offset(x, transform.toPixelY(0)),
        Offset(x, transform.toPixelY(layout.height)),
        paint,
      );
    } else {
      final y = transform.toPixelY(snap.positionMm);
      canvas.drawLine(
        Offset(transform.toPixelX(0), y),
        Offset(transform.toPixelX(layout.width), y),
        paint,
      );
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
        // The transform lives INSIDE this painter since the live-viewport
        // rewrite, so any pan/zoom/fit must trigger a repaint. Without
        // this comparison the canvas keeps displaying the very first
        // frame -- painted with the pre-fit identity matrix, where
        // millimetre-space rects are enormous and flood the whole view --
        // even though the viewport itself has long been fitted.
        oldDelegate.transform.scale != transform.scale ||
        oldDelegate.transform.offsetX != transform.offsetX ||
        oldDelegate.transform.offsetY != transform.offsetY;
  }
}
