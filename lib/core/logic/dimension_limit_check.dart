import '../models/opening.dart';
import '../models/profile_system_metadata.dart';

/// One [DimensionLimit] envelope that a construction's overall dimensions
/// exceed, produced by [checkDimensionLimits].
///
/// Advisory only: this never blocks editing and never feeds
/// `ConstructionCalculator` -- it exists so the editor can tell the user
/// they are leaving the system's documented/certified size range.
class DimensionLimitExceeded {
  final DimensionLimit limit;

  const DimensionLimitExceeded(this.limit);
}

/// Checks construction-level [widthMm]/[heightMm] against a system's
/// verified [DimensionLimit] envelopes (from `ProfileSystemMetadata`).
///
/// Semantics, chosen to stay honest about what the source documents
/// actually state:
///
///   - A limit with `openingType == null` applies to any construction; a
///     limit scoped to an [OpeningType] applies only when at least one of
///     the construction's sections has that opening type (passed in as
///     [sectionOpeningTypes]).
///   - Multiple envelopes are ALTERNATIVES (e.g. the Série 14600's two
///     certified test sizes 1600x1800 and 2500x2500), not a min/max
///     range: a construction that still fits ANY applicable envelope is
///     inside the documented range and produces NO warning. A warning is
///     produced only when the dimensions exceed EVERY applicable
///     envelope -- and then all exceeded envelopes are returned so the
///     UI can show what was left behind.
///   - "Exceeds" an envelope means width > maxWidth OR height >
///     maxHeight. There is no area rule and no interpolation: nothing of
///     the sort exists in any transcribed source (see
///     `docs/VERIFIED_SOURCES.md`).
///   - `null` width/height (construction still being dimensioned) or an
///     empty/wholly-inapplicable limit list produce no warnings -- an
///     unknown limit must never read as "within limit".
List<DimensionLimitExceeded> checkDimensionLimits({
  required double? widthMm,
  required double? heightMm,
  required List<DimensionLimit> limits,
  Set<OpeningType> sectionOpeningTypes = const {},
}) {
  final width = widthMm;
  final height = heightMm;
  if (width == null || height == null) return const [];

  final applicable = limits
      .where(
        (limit) =>
            limit.openingType == null ||
            sectionOpeningTypes.contains(limit.openingType),
      )
      .toList();
  if (applicable.isEmpty) return const [];

  final exceeded = applicable
      .where((limit) => width > limit.maxWidthMm || height > limit.maxHeightMm)
      .toList();

  // Still fitting at least one documented envelope -> inside the
  // documented range, no warning.
  if (exceeded.length < applicable.length) return const [];

  return [
    for (final limit in exceeded) DimensionLimitExceeded(limit),
  ];
}
