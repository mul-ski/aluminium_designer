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
/// minimal: outer frame faces vs interior division lines vs regular grid
/// positions.
enum SnapTargetKind {
  /// A construction's outer face (the model-space origin or total extent).
  constructionEdge,

  /// An interior division between two ordered sections.
  sectionBoundary,

  /// A regular multiple of the user's snap increment -- an interaction aid,
  /// NOT a meaningful feature of the construction itself. Grid candidates
  /// are synthesized on demand by [snapToGrid]; they never come from
  /// [collectSnapTargets], whose output stays purely geometry-derived.
  grid,
}

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

/// User-facing snapping configuration for one editor session.
///
/// Two orthogonal knobs, deliberately kept apart:
/// - [enabled] gates ALL automatic snapping. When false, manipulations use
///   raw model-space positions and no candidate of any source qualifies.
/// - [gridIncrementMm] is the model-space spacing between synthesized grid
///   candidates, in millimetres. It is an EDITING AID only: it implies no
///   fabrication rule, tolerance or manufacturer convention. `null` (or a
///   non-positive value) means "no grid source" -- geometry targets alone,
///   which is exactly the pre-grid behavior.
///
/// Pure value type; ownership/lifecycle lives with the editor's other
/// presentation state, not in this file.
class SnapConfig {
  /// Master switch for automatic snapping during manipulations.
  final bool enabled;

  /// Grid candidate spacing in millimetres, or null for no grid source.
  ///
  /// NOTE: grid VISIBILITY (whether lines are drawn) is an independent
  /// presentation concern and intentionally does NOT live here.
  final double? gridIncrementMm;

  const SnapConfig({this.enabled = true, this.gridIncrementMm});

  /// Snapping fully off: every resolver call returns null.
  const SnapConfig.disabled()
    : enabled = false,
      gridIncrementMm = null;
}

/// Snaps [positionMm] to the nearest multiple of [incrementMm], provided
/// that multiple lies within [toleranceMm].
///
/// The tolerance check keeps ONE uniform semantic across all snap sources:
/// a candidate only ever wins if the user's position is perceptually close
/// to it. For the grid this matters at high zoom, where the model-space
/// tolerance shrinks below half an increment and far-away grid lines stop
/// grabbing the pointer.
///
/// Returns null when [incrementMm] is not finite/positive (no grid source),
/// when [toleranceMm] is negative/non-finite, or when no multiple qualifies.
/// The returned target carries [SnapTargetKind.grid].
SnapResult1D? snapToGrid({
  required double positionMm,
  required double incrementMm,
  required double toleranceMm,
}) {
  if (!incrementMm.isFinite || incrementMm <= 0) return null;
  if (!toleranceMm.isFinite || toleranceMm < 0) return null;

  // Round-to-nearest multiple via integer index arithmetic: exact halves
  // round away from zero symmetrically (Dart .round on .5 goes toward
  // positive infinity, which is fine -- either neighbor is equidistant and
  // both are valid multiples).
  final index = (positionMm / incrementMm).roundToDouble();
  final snapped = index * incrementMm;
  final distance = (positionMm - snapped).abs();
  // Inclusive boundary, matching snapPosition's semantics.
  if (distance > toleranceMm) return null;

  return SnapResult1D(
    snappedPositionMm: snapped,
    target: SnapTarget1D(positionMm: snapped, kind: SnapTargetKind.grid),
    distanceMm: distance,
  );
}

/// Resolves ONE winning snap from ALL enabled sources for [positionMm]:
/// the geometry [targets] (if any) plus, when configured, the regular grid.
///
/// Deterministic strategy, independent of iteration order:
/// 1. Only candidates within [toleranceMm] qualify (inclusive), per source.
/// 2. Smallest model-space distance wins across sources.
/// 3. EXACT tie between grid and geometry -> GEOMETRY wins: real
///    construction features outrank the aid whenever they are equally
///    close ("not strictly closer" also covers floating-point near-ties,
///    so the outcome can never flip on representation noise).
/// 4. Ties between two geometry targets -> lower position, as established
///    by [snapPosition].
/// 5. A disabled [config] short-circuits to null before any source runs:
///    OFF means OFF -- raw positions, no candidates, no exceptions.
///
/// Pure function over values.
SnapResult1D? resolveSnapPosition({
  required double positionMm,
  required List<SnapTarget1D> targets,
  required SnapConfig config,
  required double toleranceMm,
}) {
  if (!config.enabled) return null;

  final geometry = snapPosition(
    positionMm: positionMm,
    targets: targets,
    toleranceMm: toleranceMm,
  );

  final increment = config.gridIncrementMm;
  if (increment == null) return geometry;

  final grid = snapToGrid(
    positionMm: positionMm,
    incrementMm: increment,
    toleranceMm: toleranceMm,
  );

  if (geometry == null) return grid;
  if (grid == null) return geometry;
  // Geometry wins unless the grid is STRICTLY closer (rule 3 above).
  return grid.distanceMm < geometry.distanceMm ? grid : geometry;
}
