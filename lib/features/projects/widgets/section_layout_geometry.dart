import 'dart:ui';

import '../../../core/models/construction.dart';
import '../../../core/models/layout_direction.dart';
import '../../../core/models/section.dart';

/// The pixel [Rect] a [Section] occupies within a construction elevation
/// canvas, computed at paint/hit-test time from the domain model -- never
/// stored.
class SectionRect {
  final Section section;
  final Rect rect;

  const SectionRect(this.section, this.rect);
}

/// Derives the on-canvas rectangle for every section of [construction],
/// given the rectangle ([canvasRect]) the whole construction elevation is
/// drawn into.
///
/// This is the single place section pixel geometry is computed. Both the
/// painter (`ConstructionElevationPainter`) and hit testing (tap handling
/// in `ConstructionEditorScreen`) call this same function, so there is
/// exactly one source of truth for "where is section X on screen" -- no
/// separate drawing/geometry model duplicating what's derived here.
///
/// Sections are walked in `order`. For [SectionLayoutDirection.horizontal],
/// each section's width is drawn to scale left-to-right and height fills
/// [canvasRect]'s full height. For [SectionLayoutDirection.vertical], the
/// reverse: height is drawn to scale top-to-bottom, width fills the full
/// canvas width. This matches exactly what `validateSectionGeometry`
/// already assumes about how sections relate to the construction's overall
/// dimensions -- only the axis in play differs.
List<SectionRect> layoutSectionRects({
  required Construction construction,
  required Rect canvasRect,
}) {
  final sections = [...construction.sections]
    ..sort((a, b) => a.order.compareTo(b.order));

  if (sections.isEmpty || construction.width <= 0 || construction.height <= 0) {
    return const [];
  }

  final results = <SectionRect>[];

  switch (construction.layoutDirection) {
    case SectionLayoutDirection.horizontal:
      final scale = canvasRect.width / construction.width;
      var x = canvasRect.left;
      for (final section in sections) {
        final w = section.width * scale;
        results.add(
          SectionRect(
            section,
            Rect.fromLTWH(x, canvasRect.top, w, canvasRect.height),
          ),
        );
        x += w;
      }
      break;

    case SectionLayoutDirection.vertical:
      final scale = canvasRect.height / construction.height;
      var y = canvasRect.top;
      for (final section in sections) {
        final h = section.height * scale;
        results.add(
          SectionRect(
            section,
            Rect.fromLTWH(canvasRect.left, y, canvasRect.width, h),
          ),
        );
        y += h;
      }
      break;
  }

  return results;
}
