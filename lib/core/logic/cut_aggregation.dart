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

/// One workshop-facing cut-list line: every cut sharing the same
/// profile, exact length, and both angles merged into a single row with
/// its physical piece count -- what a fabricator actually cuts.
class CutListLine {
  final String profileId;

  /// Display fields copied from the embedded profile (same convention as
  /// [ProfileTotals]) so consumers never re-resolve profiles to label a
  /// line.
  final String profileName;
  final String reference;

  /// The grouped cut length in mm. Grouping uses EXACT double equality,
  /// which is deterministic here: identical rule expressions over
  /// identical construction dimensions produce bit-identical results, so
  /// equal lengths always merge and unequal expressions stay apart. Any
  /// float randomness inside the calculation engine would be an engine
  /// bug, not an aggregation concern.
  final double lengthMm;

  final double angleStart;
  final double angleEnd;

  /// Physical pieces on this line: Σ `ProfileCut.quantity` of every
  /// merged cut (each already `usage.quantity × rule.fixedCount`).
  final int quantity;

  /// Σ `length × quantity` in mm.
  final double totalLengthMm;

  /// Line weight in kg when the profile's `weightPerMeter` carries a
  /// usable positive value; null = unknown, never estimated.
  final double? weightKg;

  /// Distinct producing-rule descriptions across the merged cuts, in
  /// first-encounter order -- provenance survives grouping: identical
  /// cuts produced by two different rules share the line while naming
  /// both rules.
  final List<String> ruleDescriptions;

  /// Every `ProfileCut.profileUsageId` merged into this line, in
  /// first-encounter order -- the traceability chain back through
  /// usages survives aggregation.
  final List<String> contributingUsageIds;

  /// Distinct `ProfileCut.sectionId`s merged into this line,
  /// first-encounter order; consumers resolve display labels themselves.
  final List<String> contributingSectionIds;

  const CutListLine({
    required this.profileId,
    required this.profileName,
    required this.reference,
    required this.lengthMm,
    required this.angleStart,
    required this.angleEnd,
    required this.quantity,
    required this.totalLengthMm,
    required this.weightKg,
    required this.ruleDescriptions,
    required this.contributingUsageIds,
    required this.contributingSectionIds,
  });
}

/// Groups [cuts] into workshop cut-list lines keyed by
/// (`profile.id`, exact length, angleStart, angleEnd), first-encounter
/// order -- the same calculation-order convention as
/// [aggregateProfileTotals] and `groupCutsBySectionId`.
///
/// Pure derivation over data already on each [ProfileCut]: quantities
/// sum, weights derive only from positive user-entered
/// `weightPerMeter`, and nothing is invented. This is the derivation
/// step the workshop "Liste de découpe" view consumes directly --
/// grouped display NEVER replaces the per-cut records it derives from.
List<CutListLine> buildCutListLines(List<ProfileCut> cuts) {
  // Insertion-ordered map: Dart literal maps preserve key insertion
  // order, so returning its values at the end keeps first-encounter
  // ordering AND reflects every merge -- no second structure to fall
  // out of sync with.
  final byGroup = <String, CutListLine>{};

  for (final cut in cuts) {
    final key =
        '${cut.profile.id}|${cut.length}|${cut.angleStart}|${cut.angleEnd}';
    final existing = byGroup[key];
    if (existing == null) {
      final profile = cut.profile;
      final line = CutListLine(
        profileId: profile.id,
        profileName: profile.name,
        reference: profile.reference,
        lengthMm: cut.length,
        angleStart: cut.angleStart,
        angleEnd: cut.angleEnd,
        quantity: cut.quantity,
        totalLengthMm: cut.length * cut.quantity,
        weightKg: profile.weightPerMeter > 0
            ? cut.length * cut.quantity / 1000 * profile.weightPerMeter
            : null,
        ruleDescriptions: [
          if (cut.ruleDescription != null) cut.ruleDescription!,
        ],
        contributingUsageIds: [cut.profileUsageId],
        contributingSectionIds: [cut.sectionId],
      );
      byGroup[key] = line;
      continue;
    }

    // Merge into the existing line: quantities and metres accumulate;
    // provenance lists grow without duplicates while keeping
    // first-encounter order. Every cut in a group shares the same
    // profile (the key includes profile id), so the weight recomputes
    // from the profile's single weightPerMeter.
    final quantity = existing.quantity + cut.quantity;
    final totalLengthMm = existing.totalLengthMm + cut.length * cut.quantity;
    final weightPerMeter = cut.profile.weightPerMeter;

    byGroup[key] = CutListLine(
      profileId: existing.profileId,
      profileName: existing.profileName,
      reference: existing.reference,
      lengthMm: existing.lengthMm,
      angleStart: existing.angleStart,
      angleEnd: existing.angleEnd,
      quantity: quantity,
      totalLengthMm: totalLengthMm,
      weightKg:
          weightPerMeter > 0 ? totalLengthMm / 1000 * weightPerMeter : null,
      ruleDescriptions: [
        ...existing.ruleDescriptions,
        if (cut.ruleDescription != null &&
            !existing.ruleDescriptions.contains(cut.ruleDescription))
          cut.ruleDescription!,
      ],
      contributingUsageIds: [
        ...existing.contributingUsageIds,
        cut.profileUsageId,
      ],
      contributingSectionIds: [
        ...existing.contributingSectionIds,
        if (!existing.contributingSectionIds.contains(cut.sectionId))
          cut.sectionId,
      ],
    );
  }
  return byGroup.values.toList();
}
