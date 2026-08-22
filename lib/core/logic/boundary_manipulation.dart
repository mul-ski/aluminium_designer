import '../models/construction.dart';
import '../models/layout_direction.dart';
import '../models/section.dart';

/// Smallest section size a boundary drag can produce, in millimetres.
///
/// This is the MODEL GRANULARITY floor (the editor works in whole
/// millimetres), not a fabrication/manufacturing constraint -- real
/// per-system minimum profile lengths belong to future catalog/rule data
/// and will layer on top of this.
const double kMinSectionSizeMm = 1.0;

/// Returns [construction] with the interior boundary after
/// [boundaryIndex] moved so that it sits at [positionMm] along the layout
/// axis, redistributing the sizes of exactly the two ADJACENT sections.
///
/// `boundaryIndex` follows the ordered-section convention of
/// `layoutConstruction`: index i is the line between ordered[i-1] and
/// ordered[i], so valid values are 1..sectionCount-1. Construction edges
/// (0 and the total) are NOT boundaries and return [construction]
/// unchanged -- there is no adjacent pair to redistribute.
///
/// Invariants, by construction:
///   - the sum of the two redistributed sizes is preserved EXACTLY, so the
///     overall construction dimension never changes and the geometry
///     validation sum rule keeps its verdict;
///   - neither neighbor ever goes below [kMinSectionSizeMm]: positions
///     beyond that are clamped to the nearest legal position (direct-
///     manipulation "wall" feel);
///   - every other field of every section (id, order, kind, opening type,
///     vantaux) is carried over untouched.
///
/// Pure function over immutable models: returns a new [Construction],
/// never mutates. Horizontal layouts redistribute widths; vertical
/// layouts mirror onto heights.
Construction withBoundaryMoved(
  Construction construction,
  int boundaryIndex,
  double positionMm,
) {
  final direction = construction.layoutDirection;
  final ordered = [...construction.sections]
    ..sort((a, b) => a.order.compareTo(b.order));

  // Edge indices and out-of-range indices are not interior boundaries.
  if (boundaryIndex < 1 || boundaryIndex >= ordered.length) {
    return construction;
  }

  double axisSize(Section s) =>
      direction == SectionLayoutDirection.horizontal ? s.width : s.height;

  Section withAxisSize(Section s, double size) {
    if (direction == SectionLayoutDirection.horizontal) {
      return Section(
        id: s.id,
        order: s.order,
        kind: s.kind,
        width: size,
        height: s.height,
        openingType: s.openingType,
        vantauxCount: s.vantauxCount,
      );
    }
    return Section(
      id: s.id,
      order: s.order,
      kind: s.kind,
      width: s.width,
      height: size,
      openingType: s.openingType,
      vantauxCount: s.vantauxCount,
    );
  }

  final left = ordered[boundaryIndex - 1];
  final right = ordered[boundaryIndex];

  var offsetBeforeLeft = 0.0;
  for (var i = 0; i < boundaryIndex - 1; i++) {
    offsetBeforeLeft += axisSize(ordered[i]);
  }

  final combined = axisSize(left) + axisSize(right);
  final clampedPosition = positionMm.clamp(
    offsetBeforeLeft + kMinSectionSizeMm,
    offsetBeforeLeft + combined - kMinSectionSizeMm,
  );

  final leftNewSize = clampedPosition - offsetBeforeLeft;
  final rightNewSize = combined - leftNewSize;

  final leftId = left.id;
  final rightId = right.id;
  final newSections = [
    for (final s in construction.sections)
      if (s.id == leftId)
        withAxisSize(s, leftNewSize)
      else if (s.id == rightId)
        withAxisSize(s, rightNewSize)
      else
        s,
  ];

  return construction.copyWith(sections: newSections);
}
