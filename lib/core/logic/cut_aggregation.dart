import '../models/cut.dart';

/// Derived per-profile totals over a calculation run's cuts.
///
/// Pure aggregation of data already present on [ProfileCut] plus the
/// catalogue [Profile] each cut embeds -- nothing here computes a new
/// engineering quantity and nothing is invented: piece counts sum
/// `ProfileCut.quantity` (already `usage.quantity × rule.fixedCount`),
/// lengths sum `length × quantity`, and weight is derived ONLY from the
/// user-entered `weightPerMeter` when it carries a positive value. A
/// missing/zero weight means "unknown", never "estimated".
///
/// This layer is the derivation step a future BOM reuses -- BOM summaries
/// must come from calculation results through pure functions like this,
/// never from hand-maintained UI state.
class ProfileTotals {
  /// Id of the aggregated [Profile] (unique within one run -- cuts are
  /// produced against one system's `profilesById`).
  final String profileId;

  /// Display fields copied from the embedded profile, so consumers (e.g.
  /// the results banner) don't re-resolve the profile to label a line.
  final String profileName;
  final String reference;

  /// Number of distinct cut lines for this profile.
  final int cutCount;

  /// Total physical pieces: Σ `ProfileCut.quantity`.
  final int pieces;

  /// Total linear metres required before any cutting waste: Σ
  /// `length × quantity`, in millimetres.
  final double totalLengthMm;

  /// Estimated stock weight in kilograms:
  /// `(totalLengthMm / 1000) × weightPerMeter`. Null when the profile's
  /// `weightPerMeter` is not a usable positive value.
  final double? weightKg;

  const ProfileTotals({
    required this.profileId,
    required this.profileName,
    required this.reference,
    required this.cutCount,
    required this.pieces,
    required this.totalLengthMm,
    required this.weightKg,
  });
}

/// Construction-wide grand total across [totals].
///
/// [weightKg] is null only when EVERY profile's weight is unknown -- with
/// at least one known weight the sum stays numeric rather than collapsing
/// to null, since the known part of the total is still real information.
class GrandTotals {
  final int pieces;
  final double totalLengthMm;
  final double? weightKg;

  const GrandTotals({
    required this.pieces,
    required this.totalLengthMm,
    required this.weightKg,
  });
}

/// Aggregates [cuts] into per-profile totals, grouped by
/// `ProfileCut.profile.id` in first-encounter order -- the same
/// calculation-order convention as `groupCutsBySectionId`, so banner rows
/// and their totals stay visually aligned without sorting opinions here.
List<ProfileTotals> aggregateProfileTotals(List<ProfileCut> cuts) {
  // Insertion-ordered map: Dart literal maps preserve key insertion order,
  // which IS the grouping convention used by cut_grouping.dart.
  final byProfile = <String, List<ProfileCut>>{};
  for (final cut in cuts) {
    byProfile.putIfAbsent(cut.profile.id, () => []).add(cut);
  }

  final totals = <ProfileTotals>[];
  for (final entry in byProfile.entries) {
    final group = entry.value;
    var pieces = 0;
    var totalLengthMm = 0.0;
    for (final cut in group) {
      pieces += cut.quantity;
      totalLengthMm += cut.length * cut.quantity;
    }
    // Weight derives only from user-entered positive data; zero/negative
    // values read as "unknown" -- never estimated here.
    final profile = group.first.profile;
    final weightKg = profile.weightPerMeter > 0
        ? totalLengthMm / 1000 * profile.weightPerMeter
        : null;
    totals.add(
      ProfileTotals(
        profileId: profile.id,
        profileName: profile.name,
        reference: profile.reference,
        cutCount: group.length,
        pieces: pieces,
        totalLengthMm: totalLengthMm,
        weightKg: weightKg,
      ),
    );
  }
  return totals;
}

/// Sums per-profile [totals] into the construction-wide grand total. See
/// [GrandTotals.weightKg] for the unknown-weight rule.
GrandTotals sumProfileTotals(List<ProfileTotals> totals) {
  var pieces = 0;
  var totalLengthMm = 0.0;
  double? weightKg;
  var anyWeightKnown = false;
  var summedWeight = 0.0;
  for (final t in totals) {
    pieces += t.pieces;
    totalLengthMm += t.totalLengthMm;
    if (t.weightKg != null) {
      anyWeightKnown = true;
      summedWeight += t.weightKg!;
    }
  }
  if (anyWeightKnown) weightKg = summedWeight;
  return GrandTotals(
    pieces: pieces,
    totalLengthMm: totalLengthMm,
    weightKg: weightKg,
  );
}
