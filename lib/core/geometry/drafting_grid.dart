/// Minimum on-screen spacing, in logical pixels, between two adjacent MINOR
/// grid lines. The adaptive interval selector refuses any real-world
/// interval that would render denser than this, so the grid stays readable
/// at every zoom level instead of degenerating into solid gray.
///
/// Tuning this value changes only VISUAL density -- never geometry, never
/// snapping (the snap increment is a separate, user-facing setting).
const double kMinGridLineSpacingPx = 20.0;

/// A major grid line is drawn every [kGridMajorEvery]-th minor interval.
/// Five works across the whole 1-2-5 x 10^n series (1->5, 2->10, 5->25,
/// 10->50, ...), keeping major positions "round" real-world numbers no
/// matter which interval the selector picks.
const int kGridMajorEvery = 5;

/// Upper bound of the interval search, in millimetres: one metre per step
/// is already far beyond any plausible aluminium construction; the loop is
/// bounded so a nonsensical scale can never spin it forever.
const double _kMaxSearchIntervalMm = 1000.0;

/// Defensive cap on generated lines per axis. Viewport-driven ranges stay
/// far below this (~a hundred lines worst case); the cap exists so a
/// pathological caller cannot allocate millions of entries silently.
const int kMaxGridLinesPerAxis = 4096;

/// One vertical or horizontal grid line to draw, in model millimetres.
class DraftingGridLine {
  /// Absolute position along the axis, in millimetres. Always an exact
  /// multiple of the minor interval -- including negative multiples when
  /// the viewport is panned past the model origin.
  final double positionMm;

  /// Whether this occurrence is a MAJOR line (every [kGridMajorEvery]-th
  /// minor). Majors render slightly stronger; minors stay very light.
  final bool isMajor;

  const DraftingGridLine({required this.positionMm, required this.isMajor});

  @override
  String toString() =>
      'DraftingGridLine(${positionMm}mm${isMajor ? ', major' : ''})';
}

/// Selects the smallest real-world MINOR grid interval, in millimetres,
/// from the 1-2-5 x 10^n series whose on-screen spacing at [scale]
/// (logical px per mm) reaches [minSpacingPx].
///
/// This is the complete adaptive-spacing strategy: the rendered gap between
/// minor lines never falls below the perceptual floor, while the interval
/// itself always denotes a meaningful measurement (1, 2, 5, 10, 20, 50,
/// 100, ... mm) rather than an arbitrary pixel distance. Major lines sit
/// every [kGridMajorEvery] intervals above it.
///
/// Returns 0 when no usable interval exists -- degenerate input such as a
/// non-finite, zero or negative scale. Callers treat 0 as "draw nothing".
///
/// Pure function over values: no Flutter types, no state, fully unit-testable.
double selectMinorGridInterval({
  required double scale,
  double minSpacingPx = kMinGridLineSpacingPx,
}) {
  if (!scale.isFinite || scale <= 0) return 0;
  if (!minSpacingPx.isFinite || minSpacingPx <= 0) return 0;

  const mantissas = [1.0, 2.0, 5.0];
  var magnitude = 0.001; // start at sub-millimetre precision.
  while (magnitude <= _kMaxSearchIntervalMm) {
    for (final mantissa in mantissas) {
      final candidate = mantissa * magnitude;
      // Inclusive comparison mirrors snapPosition's boundary semantics:
      // exactly reaching the floor qualifies.
      if (candidate * scale >= minSpacingPx) return candidate;
    }
    magnitude *= 10;
  }
  return 0; // Unreachable given _kMaxSearchIntervalMm; kept total anyway.
}

/// Enumerates every grid line whose absolute position falls inside the
/// model-space range [[minMm], [maxMm]] (inclusive), spaced [minorIntervalMm]
/// apart and aligned to the model ORIGIN -- not to the visible range --
/// so lines stay pinned to real-world coordinates while panning.
///
/// Positions are produced by integer-index arithmetic (`index * interval`)
/// rather than repeated addition, so no floating-point drift accumulates
/// across long pans. Negative indices occur naturally once the range dips
/// below the origin and yield correct negative multiples.
///
/// Returns an ascending list, capped at [maxLines] entries (see
/// [kMaxGridLinesPerAxis]) as a defensive allocation guard.
///
/// Degenerate inputs ([minorIntervalMm] not finite/positive, inverted or
/// non-finite range) produce an empty list -- never an exception -- so the
/// painter can consume the result unconditionally.
List<DraftingGridLine> gridLinesForRange({
  required double minMm,
  required double maxMm,
  required double minorIntervalMm,
  int majorEvery = kGridMajorEvery,
  int maxLines = kMaxGridLinesPerAxis,
}) {
  if (!minorIntervalMm.isFinite || minorIntervalMm <= 0) return const [];
  if (!minMm.isFinite || !maxMm.isFinite || minMm > maxMm) return const [];
  if (majorEvery < 1) majorEvery = 1;
  if (maxLines < 0) return const [];

  final firstIndex = (minMm / minorIntervalMm).ceil();
  final lastIndex = (maxMm / minorIntervalMm).floor();

  final lines = <DraftingGridLine>[];
  for (var index = firstIndex; index <= lastIndex; index++) {
    if (lines.length >= maxLines) break;
    final position = index * minorIntervalMm;
    // Dart's % is always non-negative for positive divisors, so negative
    // multiples classify correctly (-500 % 2500 == 0 -> major).
    final isMajor = index % majorEvery == 0;
    lines.add(
      DraftingGridLine(positionMm: position, isMajor: isMajor),
    );
  }
  return lines;
}
