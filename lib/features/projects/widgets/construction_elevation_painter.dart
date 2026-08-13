import 'package:flutter/material.dart';

import '../../../core/models/construction.dart';
import '../../../core/models/section.dart';
import 'section_layout_geometry.dart';

/// Paints a read-only elevation view of a [Construction]: the overall
/// frame, dividing lines between sections, a fixed/ouvrant symbol per
/// section, dimension labels, and a highlight around the selected section
/// (if any).
///
/// Takes the same [SectionRect]s produced by [layoutSectionRects] that tap
/// handling uses for hit testing -- see that function's doc comment for
/// why there is only one geometry source.
class ConstructionElevationPainter extends CustomPainter {
  final Construction construction;
  final String? selectedSectionId;

  ConstructionElevationPainter({
    required this.construction,
    required this.selectedSectionId,
  });

  static const double _margin = 48;
  static const double _dimensionLabelGap = 20;

  @override
  void paint(Canvas canvas, Size size) {
    final canvasRect = Rect.fromLTWH(
      _margin,
      _margin,
      size.width - _margin * 2,
      size.height - _margin * 2,
    );

    if (canvasRect.width <= 0 || canvasRect.height <= 0) {
      return;
    }

    final framePaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final dividerPaint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final selectionPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Outer frame.
    canvas.drawRect(canvasRect, framePaint);

    final sectionRects = layoutSectionRects(
      construction: construction,
      canvasRect: canvasRect,
    );

    for (final sr in sectionRects) {
      // Divider between this section and the next (skip the outer frame
      // edge, already drawn above).
      canvas.drawRect(sr.rect, dividerPaint);

      _paintSectionSymbol(canvas, sr.rect, sr.section);

      if (sr.section.id == selectedSectionId) {
        final inset = sr.rect.deflate(2);
        canvas.drawRect(inset, selectionPaint);
      }

      _paintSectionDimensionLabel(canvas, sr.rect, sr.section);
    }

    _paintOverallDimensions(canvas, canvasRect);
  }

  /// Fixed sections are a plain outline (already drawn). Ouvrant sections
  /// additionally get a diagonal "X"-free single-diagonal mark -- the
  /// generic, non-vendor-specific convention for "this panel opens". Real
  /// per-opening-type symbols (casement vs. tilt-turn vs. sliding arrows)
  /// are a placeholder left for a later milestone; this is intentionally
  /// simple and not meant to represent real fabrication/opening data.
  void _paintSectionSymbol(Canvas canvas, Rect rect, Section section) {
    if (section.kind != SectionKind.ouvrant) {
      return;
    }

    final symbolPaint = Paint()
      ..color = Colors.black45
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final inset = rect.deflate(8);
    if (inset.width <= 0 || inset.height <= 0) {
      return;
    }

    canvas.drawLine(inset.topLeft, inset.bottomRight, symbolPaint);
    canvas.drawLine(inset.topRight, inset.bottomLeft, symbolPaint);
  }

  void _paintSectionDimensionLabel(Canvas canvas, Rect rect, Section section) {
    final label = '${section.width.toStringAsFixed(0)} × '
        '${section.height.toStringAsFixed(0)} mm';
    _drawText(canvas, label, rect.center, fontSize: 10, color: Colors.black54);
  }

  void _paintOverallDimensions(Canvas canvas, Rect canvasRect) {
    final linePaint = Paint()
      ..color = Colors.black45
      ..strokeWidth = 1;

    // Width dimension line above the frame.
    final topY = canvasRect.top - _dimensionLabelGap;
    canvas.drawLine(
      Offset(canvasRect.left, topY),
      Offset(canvasRect.right, topY),
      linePaint,
    );
    _drawText(
      canvas,
      '${construction.width.toStringAsFixed(0)} mm',
      Offset(canvasRect.center.dx, topY - 8),
      fontSize: 12,
      color: Colors.black87,
    );

    // Height dimension line left of the frame.
    final leftX = canvasRect.left - _dimensionLabelGap;
    canvas.drawLine(
      Offset(leftX, canvasRect.top),
      Offset(leftX, canvasRect.bottom),
      linePaint,
    );
    _drawText(
      canvas,
      '${construction.height.toStringAsFixed(0)} mm',
      Offset(leftX - 8, canvasRect.center.dy),
      fontSize: 12,
      color: Colors.black87,
      rotated: true,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center, {
    required double fontSize,
    required Color color,
    bool rotated = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (rotated) {
      canvas.rotate(-1.5708); // -90 degrees, for the vertical height label.
    }
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ConstructionElevationPainter oldDelegate) {
    return oldDelegate.construction != construction ||
        oldDelegate.selectedSectionId != selectedSectionId;
  }
}
