import '../models/layout_direction.dart';
import 'section_layout.dart';

/// Perceptual snap tolerance, in logical pixels: how close (on screen) a
/// manipulated position must be to a target before it snaps.
///
/// Pure model-space code never sees this constant directly -- consumers
/// convert it into millimetres through the viewport's current scale
/// (`kSnapTolerancePx / viewport.scale`), so the *perceived* grab window
/// stays constant while zooming and the precision keeps improving as you
/// zoom in. At the viewport's minimum scale of 0.2 this yields a ±60 mm
/// window; at maximum scale 6, ±2 mm.
const double kSnapTolerancePx = 12.0;

/// What a [SnapTarget1D] represents in the 1D construction model.
///
/// In a linear layout every interior boundary is simultaneously the shared
/// endpoint of two adjacent sections -- "section endpoints", "section
/// boundaries", and "alignment with existing boundaries" are one and the
/// same set of coordinates. The kinds below are therefore deliberately
/// minimal: outer frame faces vs interior division lines. No grid kind
/// exists yet -- dimensions are free-form millimetres and an arbitrary
/// grid would invent snapping targets with no purpose; the engine is
/// source-agnostic, so a grid source can be added later without touching
/// it.
enum SnapTargetKind { constructionEdge, sectionBoundary }

/// One candidate position, in millimetres, along the active layout axis
/// (X for horizontal layouts, Y for vertical layouts).
///
/// Deliberately 1D: the current construction model has zero degrees of
/// freedom on the cross axis (all sections share the full cross size), so
/// scalar targets capture everything that can meaningfully snap. A future
/// 2D curtain-wall model would introduce its own target generalization.
class SnapTarget1D {
  /// Position along the layout axis, in millimetres.
  final double positionMm;

  final SnapTargetKind kind;

  const SnapTarget1D({required this.positionMm, required this.kind});

  @override
  String toString() => 'SnapTarget1D($positionMm, $kind)';
}

/// The outcome of a successful [snapPosition] call.
class SnapResult1D {
  /// The position to actually use, in millimetres: the target's position,
  /// not the original input.
  final double snappedPositionMm;

  /// The target that won.
  final SnapTarget1D target;

  /// Distance between the original position and the winning target, in
  /// millimetres. Always within the tolerance passed to [snapPosition].
  final double distanceMm;

  const SnapResult1D({
    required this.snappedPositionMm,
    required this.target,
    required this.distanceMm,
  });
}

/// Collects every meaningful snap position from [layout], sorted ascending
/// along [direction]'s axis.
///
/// Horizontal layouts produce X positions (0, each cumulative width
/// boundary, the total width); vertical layouts mirror onto Y/heights.
/// Sections are read in `Section.order` sequence -- the same order
/// `layoutConstruction` uses to place rectangles, so targets always match
/// what is actually drawn. Positions appearing both at an edge (0 or total)
/// and as a section boundary collapse to [SnapTargetKind.constructionEdge];
/// duplicate positions from degenerate sections deduplicate deterministically.
///
/// Returns an unmodifiable list. An empty-sections layout still yields the
/// two construction edges.
List<SnapTarget1D> collectSnapTargets(
  ConstructionLayout layout,
  SectionLayoutDirection direction,
) {
  // Cumulative positions after each section. layoutConstruction already
  // ordered its rects by Section.order, so accumulation mirrors drawing.
  final cumulative = <double>[0.0];
  var cursor = 0.0;
  for (final rect in layout.sections) {
    cursor += direction == SectionLayoutDirection.horizontal
        ? rect.width
        : rect.height;
    cumulative.add(cursor);
  }
  // The outer end face always exists as drawn by the painter, even for
  // invalid-but-displayed geometry whose sections do not sum to it.
  final total = direction == SectionLayoutDirection.horizontal
      ? layout.width
      : layout.height;
  cumulative.add(total);

  // Deduplicate; edges take kind precedence over coinciding boundaries.
  final uniquePositions = cumulative.toSet();
  final targets = [
    for (final position in uniquePositions)
      SnapTarget1D(
        positionMm: position,
        kind: position == 0 || position == total
            ? SnapTargetKind.constructionEdge
            : SnapTargetKind.sectionBoundary,
      ),
  ]..sort((a, b) => a.positionMm.compareTo(b.positionMm));

  return List.unmodifiable(targets);
}

/// Snaps [positionMm] to the nearest target within [toleranceMm], or
/// returns null when nothing qualifies.
///
/// Deterministic selection: smallest distance wins; an exact tie between
/// two distinct targets resolves to the LOWER position (a stable
/// leftward/topward convention independent of list order); duplicate
/// positions cannot occur because collectors dedupe. Boundary semantics
/// are inclusive: distance exactly equal to the tolerance snaps.
///
/// Pure function over values -- no Construction, no viewport, no state.
SnapResult1D? snapPosition({
  required double positionMm,
  required List<SnapTarget1D> targets,
  required double toleranceMm,
}) {
  SnapTarget1D? best;
  var bestDistance = double.infinity;

  for (final target in targets) {
    final distance = (positionMm - target.positionMm).abs();
    if (distance > toleranceMm) continue;
    if (best == null ||
        distance < bestDistance ||
        (distance == bestDistance && target.positionMm < best.positionMm)) {
      best = target;
      bestDistance = distance;
    }
  }

  if (best == null) return null;
  return SnapResult1D(
    snappedPositionMm: best.positionMm,
    target: best,
    distanceMm: bestDistance,
  );
}

/// A currently-highlighted snap, produced by an active manipulation and
/// rendered by the canvas painter as an accent line at [positionMm].
///
/// Presentation-adjacent value type: whoever drives a manipulation owns
/// the lifecycle (set while dragging, cleared when the gesture ends).
/// Nothing produces one today -- the field arrives with drag manipulation;
/// the painter already knows how to render it so the visual path is
/// complete and dormant.
class ActiveSnap {
  final double positionMm;
  final SnapTargetKind kind;

  const ActiveSnap({required this.positionMm, required this.kind});
}
