import 'package:flutter/foundation.dart';

import '../models/construction.dart';
import '../models/layout_direction.dart';
import '../models/section.dart';

/// One section's position and size within a [Construction], in the same
/// millimetre units as [Construction.width]/[Construction.height].
///
/// This is a pure geometry value -- it does not know about pixels, screen
/// size, or Flutter's rendering pipeline. It exists so the layout math
/// (deciding *where* each section sits) can be unit-tested independently
/// of any [CustomPainter] or widget tree, and so the painter has nothing
/// left to decide except how to draw a rectangle it's already been given.
@immutable
class SectionRect {
  /// The [Section] this rectangle represents. Kept as a reference (not
  /// copied out into loose fields) so the painter can read
  /// [Section.kind], [Section.openingType], etc. directly from one place
  /// rather than this class re-exposing every field Section already has.
  final Section section;

  /// Left edge, in millimetres, relative to the construction's own
  /// top-left origin (0, 0) -- not relative to the screen.
  final double x;

  /// Top edge, in millimetres, relative to the construction's own
  /// top-left origin.
  final double y;

  final double width;
  final double height;

  const SectionRect({
    required this.section,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

/// The result of laying out one [Construction]: the overall outer
/// rectangle (always at millimetre origin (0, 0), sized
/// [Construction.width] x [Construction.height]) plus every section's
/// rectangle within it.
@immutable
class ConstructionLayout {
  final double width;
  final double height;
  final List<SectionRect> sections;

  const ConstructionLayout({
    required this.width,
    required this.height,
    required this.sections,
  });
}

/// Computes each [Section]'s position and size within [construction], in
/// millimetres, based on [Construction.layoutDirection].
///
/// This mirrors the same ordering/summing rules [validateSectionGeometry]
/// checks (sections placed left-to-right for `horizontal`, top-to-bottom
/// for `vertical`, ordered by [Section.order]) but produces positions
/// rather than a pass/fail validation result. It does not re-validate;
/// callers that need to guarantee sections actually fit should call
/// `validateSectionGeometry` separately. Sections are laid out from their
/// own width/height as stored on the model, so a construction whose
/// sections don't sum to its overall dimensions will still lay out
/// deterministically (just visibly not filling the outer rectangle) rather
/// than throwing -- this function has no opinion on validity, only
/// position.
ConstructionLayout layoutConstruction(Construction construction) {
  final ordered = [...construction.sections]
    ..sort((a, b) => a.order.compareTo(b.order));

  final rects = <SectionRect>[];
  var cursor = 0.0;

  for (final section in ordered) {
    switch (construction.layoutDirection) {
      case SectionLayoutDirection.horizontal:
        rects.add(
          SectionRect(
            section: section,
            x: cursor,
            y: 0,
            width: section.width,
            height: section.height,
          ),
        );
        cursor += section.width;
        break;

      case SectionLayoutDirection.vertical:
        rects.add(
          SectionRect(
            section: section,
            x: 0,
            y: cursor,
            width: section.width,
            height: section.height,
          ),
        );
        cursor += section.height;
        break;
    }
  }

  return ConstructionLayout(
    width: construction.width,
    height: construction.height,
    sections: rects,
  );
}

/// A uniform millimetre-to-pixel transform plus the pixel-space offset
/// needed to center the scaled construction within the available canvas.
@immutable
class FittedTransform {
  /// Pixels per millimetre. Uniform in both axes so aspect ratio is
  /// preserved -- a construction is never stretched to fill the canvas.
  final double scale;

  /// Pixel offset of the construction's millimetre-origin (0, 0) within
  /// the canvas, after centering.
  final double offsetX;
  final double offsetY;

  const FittedTransform({
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });

  /// Converts a millimetre-space x coordinate to pixel space.
  double toPixelX(double mmX) => offsetX + mmX * scale;

  /// Converts a millimetre-space y coordinate to pixel space.
  double toPixelY(double mmY) => offsetY + mmY * scale;

  /// Converts a millimetre-space length to a pixel-space length. Lengths
  /// (unlike points) don't need the offset -- only the scale applies.
  double toPixelLength(double mmLength) => mmLength * scale;
}

/// Computes the [FittedTransform] that fits a [contentWidth] x
/// [contentHeight] millimetre rectangle inside a [canvasWidth] x
/// [canvasHeight] pixel canvas, preserving aspect ratio and centering the
/// result, with [padding] pixels reserved on every side for dimension
/// labels.
///
/// Returns a degenerate identity-ish transform (scale 0) if the canvas or
/// content has no usable area, so callers can skip drawing rather than
/// dividing by zero.
FittedTransform fitConstructionToCanvas({
  required double contentWidth,
  required double contentHeight,
  required double canvasWidth,
  required double canvasHeight,
  double padding = 32,
}) {
  final availableWidth = canvasWidth - padding * 2;
  final availableHeight = canvasHeight - padding * 2;

  if (contentWidth <= 0 ||
      contentHeight <= 0 ||
      availableWidth <= 0 ||
      availableHeight <= 0) {
    return const FittedTransform(scale: 0, offsetX: 0, offsetY: 0);
  }

  final scaleX = availableWidth / contentWidth;
  final scaleY = availableHeight / contentHeight;
  final scale = scaleX < scaleY ? scaleX : scaleY;

  final scaledWidth = contentWidth * scale;
  final scaledHeight = contentHeight * scale;

  final offsetX = (canvasWidth - scaledWidth) / 2;
  final offsetY = (canvasHeight - scaledHeight) / 2;

  return FittedTransform(scale: scale, offsetX: offsetX, offsetY: offsetY);
}
