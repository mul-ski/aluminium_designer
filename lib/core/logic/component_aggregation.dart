import '../models/cut.dart';
import '../models/glass_item.dart';
import '../models/hardware_item.dart';

/// Derived per-pane totals over a calculation run's glass items.
///
/// Pure aggregation of data already present on each [GlassItem] -- the
/// pane area is the product of its evaluated width/height; quantity
/// sums. Nothing here computes a new engineering quantity and nothing
/// is invented: a missing `glazingThicknessMm` is reported as
/// "unknown" via [unknownThicknessCount] (counted separately so the
/// workshop view can show "X panes with unstated thickness"), never
/// estimated.
///
/// This layer is the derivation step a future BOM reuses -- BOM
/// summaries must come from calculation results through pure functions
/// like this, never from hand-maintained UI state.
class GlassTotals {
  /// Number of distinct panes for this group.
  final int paneCount;

  /// Total area of all panes in m² (Σ width×height×quantity / 1e6).
  final double totalAreaM2;

  /// Number of panes whose [GlassItem.glazingThicknessMm] is `null`
  /// (the source did not state a per-pane thickness for them). Always
  /// ≤ [paneCount]; surfaces in the workshop view as "X panes with
  /// unstated thickness -- pick a glass when ordering".
  final int unknownThicknessCount;

  const GlassTotals({
    required this.paneCount,
    required this.totalAreaM2,
    required this.unknownThicknessCount,
  });
}

/// Aggregates [items] into a single [GlassTotals] over the whole run.
///
/// Empty input yields a zeroed `GlassTotals` (so the workshop view
/// can show "0 panes" cleanly without a null check).
GlassTotals aggregateGlassItems(List<GlassItem> items) {
  if (items.isEmpty) {
    return const GlassTotals(
      paneCount: 0,
      totalAreaM2: 0,
      unknownThicknessCount: 0,
    );
  }
  var paneCount = 0;
  var totalAreaM2 = 0.0;
  var unknownThicknessCount = 0;
  for (final item in items) {
    paneCount += item.quantity;
    totalAreaM2 +=
        item.widthMm * item.heightMm * item.quantity / 1e6;
    if (item.glazingThicknessMm == null) {
      unknownThicknessCount += item.quantity;
    }
  }
  return GlassTotals(
    paneCount: paneCount,
    totalAreaM2: totalAreaM2,
    unknownThicknessCount: unknownThicknessCount,
  );
}

/// One workshop-facing hardware/accessory line: every [HardwareItem]
/// sharing the same reference, name, category, and exact length
/// merged into a single row with its summed physical count -- what a
/// fabricator actually orders or cuts.
class HardwareLine {
  final String reference;
  final String name;
  final HardwareCategory category;

  /// Summed physical piece count across the merged items.
  final int quantity;

  /// `lengthMm` only when every merged item carries a length
  /// (count-only items keep it `null`). Mixed count-only + length-
  /// bearing merges are NOT supported -- they are a source-document
  /// tension, not an aggregation concern: the BOM would show the
  /// wrong totals silently. Mixed items are kept separate (see
  /// [aggregateHardwareItems] which never merges across the count-
  /// only / length-bearing boundary).
  final double? lengthMm;

  /// Σ `length × quantity` in mm when [lengthMm] is set; `0` when
  /// count-only.
  final double totalLengthMm;

  /// Distinct rule descriptions across the merged items, in
  /// first-encounter order -- provenance survives grouping, exactly
  /// as the profile-cut `CutListLine`.
  final List<String> ruleDescriptions;

  /// Distinct `HardwareItem.sectionId`s merged into this line,
  /// first-encounter order; consumers resolve display labels
  /// themselves.
  final List<String> contributingSectionIds;

  const HardwareLine({
    required this.reference,
    required this.name,
    required this.category,
    required this.quantity,
    required this.lengthMm,
    required this.totalLengthMm,
    required this.ruleDescriptions,
    required this.contributingSectionIds,
  });
}

/// Sums the per-line quantities and lengths across hardware lines,
/// mirroring [sumCutListLines]'s weight-presence pattern. A BOM-level
/// weight is out of scope for P1 (metallic hardware is sold per piece,
/// not by weight; weight data isn't on the catalogue `Profile` for
/// accessories like joints). The "weight unknown" semantic is
/// "irrelevant here" rather than "unknown" -- a workshop BOM doesn't
/// need it.
class HardwareSummary {
  final int pieces;
  final double totalLengthMm;

  const HardwareSummary({
    required this.pieces,
    required this.totalLengthMm,
  });
}

HardwareSummary sumHardwareLines(List<HardwareLine> lines) {
  var pieces = 0;
  var totalLengthMm = 0.0;
  for (final line in lines) {
    pieces += line.quantity;
    totalLengthMm += line.totalLengthMm;
  }
  return HardwareSummary(
    pieces: pieces,
    totalLengthMm: totalLengthMm,
  );
}

/// Groups [items] into workshop hardware lines keyed by
/// (`reference`, `name`, `category`, exact length), first-encounter
/// order -- the same calculation-order convention as
/// [buildCutListLines] and the rest of the aggregation layer.
///
/// Mixed count-only + length-bearing items with the SAME reference
/// are kept separate (two lines for the same reference, one count-
/// only and one length-bearing) rather than merged. The source
/// catalogues are consistent in this regard (a paumelle is always
/// count-only, a joint is always length-bearing), so the "two lines
/// for one reference" state is a documented source conflict, not a
/// normal aggregation case -- a workshop view that sees it can show a
/// diagnostic ("two hardware entries for the same reference with
/// different physical types") rather than silently wrong totals.
List<HardwareLine> buildHardwareLines(List<HardwareItem> items) {
  // Insertion-ordered map: Dart literal maps preserve key insertion
  // order, so returning its values at the end keeps first-encounter
  // ordering AND reflects every merge -- no second structure to fall
  // out of sync with.
  final byGroup = <String, HardwareLine>{};

  for (final item in items) {
    final lengthKey = item.lengthMm?.toStringAsFixed(6) ?? 'null';
    final key = '${item.reference}|${item.category.name}|$lengthKey';
    final existing = byGroup[key];
    if (existing == null) {
      byGroup[key] = HardwareLine(
        reference: item.reference,
        name: item.name,
        category: item.category,
        quantity: item.quantity,
        lengthMm: item.lengthMm,
        totalLengthMm: (item.lengthMm ?? 0) * item.quantity,
        ruleDescriptions: [
          if (item.ruleDescription != null) item.ruleDescription!,
        ],
        contributingSectionIds: [item.sectionId],
      );
      continue;
    }

    // Merge into the existing line: quantities and metres accumulate;
    // provenance lists grow without duplicates while keeping
    // first-encounter order. Every item in a group shares the same
    // reference + category + length (by construction of the key), so
    // the length stays the existing value.
    final quantity = existing.quantity + item.quantity;
    final totalLengthMm =
        existing.totalLengthMm + (item.lengthMm ?? 0) * item.quantity;

    byGroup[key] = HardwareLine(
      reference: existing.reference,
      name: existing.name,
      category: existing.category,
      quantity: quantity,
      lengthMm: existing.lengthMm,
      totalLengthMm: totalLengthMm,
      ruleDescriptions: [
        ...existing.ruleDescriptions,
        if (item.ruleDescription != null &&
            !existing.ruleDescriptions.contains(item.ruleDescription))
          item.ruleDescription!,
      ],
      contributingSectionIds: [
        ...existing.contributingSectionIds,
        if (!existing.contributingSectionIds.contains(item.sectionId))
          item.sectionId,
      ],
    );
  }
  return byGroup.values.toList();
}

/// One grouped line in the unified bill of materials -- a single
/// (reference, name, category, length, angleStart, angleEnd,
/// profileId) row that the workshop reads top-to-bottom. Lives in
/// THIS file (not a "BOM" enum) so the model layer stays free of an
/// import cycle: the BOM is a pure derivation over `cuts` + `glass`
/// + `hardware` + issue lists, and adding a `BOM` enum / class to
/// `CalculationOutcome` would couple the result model to the
/// aggregation. Instead, [buildBom] returns a flat list of lines
/// and the totals; consumers compose them.
class BomLine {
  final BomDomain domain;
  final String reference;
  final String name;
  final String? profileId;
  final int quantity;
  final double? lengthMm;
  final double? widthMm;
  final double? heightMm;
  final double? angleStart;
  final double? angleEnd;

  /// Distinct rule descriptions across the merged source records, in
  /// first-encounter order -- provenance survives grouping, matching
  /// the per-domain lines.
  final List<String> ruleDescriptions;

  const BomLine({
    required this.domain,
    required this.reference,
    required this.name,
    this.profileId,
    required this.quantity,
    this.lengthMm,
    this.widthMm,
    this.heightMm,
    this.angleStart,
    this.angleEnd,
    required this.ruleDescriptions,
  });
}

/// Which component domain a [BomLine] belongs to. Mirrors
/// [HardwareCategory] for the hardware/accessory split, plus a `glass`
/// and `profile` domain. Kept as a small closed enum so the BOM view
/// can group/order without an open-ended string.
enum BomDomain { profile, glass, hardware, accessory }

/// The unified bill of materials for one [CalculationOutcome]. One
/// derivation layer that pulls together the profile cut list, the
/// glass items, and the hardware items into a single flat
/// component-grouped summary the workshop reads top-to-bottom.
///
/// Construction-wide totals over the BOM (pieces across all domains,
/// plus per-domain sub-totals so the view can show the glass area and
/// the hardware length without recomputing them).
class BomSummary {
  final int totalPieces;
  final double glassAreaM2;
  final double hardwareTotalLengthMm;

  const BomSummary({
    required this.totalPieces,
    required this.glassAreaM2,
    required this.hardwareTotalLengthMm,
  });
}

BomSummary _emptyBomSummary() => const BomSummary(
      totalPieces: 0,
      glassAreaM2: 0,
      hardwareTotalLengthMm: 0,
    );

/// Aggregates a complete BOM from the three result lists a calculator
/// produces. Pure derivation: profile lines reuse [CutListLine] data
/// (angles, length, weight -- the [BomLine] copies the relevant
/// fields and drops the weightKg to keep the BOM shape a flat row of
/// component entries; the workshop view can recompute weight from
/// the [BomLine.profileId] if needed), glass lines reuse [GlassItem]
/// data, hardware lines reuse [HardwareItem] data.
///
/// Input shapes:
/// - [profileCuts] = `CalculationOutcome.cuts` (already-grouped cut
///   lines are NOT the input -- the BOM wants raw cuts here; grouping
///   to [BomLine] keys on (reference, length, angleStart, angleEnd)
///   to match the workshop view's row).
/// - [glass] = `CalculationOutcome.glass` (each pane is its own line;
///   panes with the same reference + length + width merge by construction
///   since the calculator evaluates one rule per section).
/// - [hardware] = `CalculationOutcome.hardware` (count-only and
///   length-bearing items are kept as two separate BOM lines per
///   reference if both occur; [buildHardwareLines]'s "no mixed merge"
///   contract carries through).
List<BomLine> buildBom({
  required List<ProfileCut> profileCuts,
  required List<GlassItem> glass,
  required List<HardwareItem> hardware,
}) {
  final lines = <BomLine>[];

  // Profile lines: key on (reference, length, angleStart, angleEnd).
  // Insertion-ordered map preserves first-encounter grouping.
  final byProfile = <String, BomLine>{};
  for (final cut in profileCuts) {
    final key =
        '${cut.profile.reference}|${cut.length}|${cut.angleStart}|${cut.angleEnd}';
    final existing = byProfile[key];
    if (existing == null) {
      byProfile[key] = BomLine(
        domain: BomDomain.profile,
        reference: cut.profile.reference,
        name: cut.profile.name,
        profileId: cut.profile.id,
        quantity: cut.quantity,
        lengthMm: cut.length,
        angleStart: cut.angleStart,
        angleEnd: cut.angleEnd,
        ruleDescriptions: [
          if (cut.ruleDescription != null) cut.ruleDescription!,
        ],
      );
      continue;
    }
    byProfile[key] = BomLine(
      domain: existing.domain,
      reference: existing.reference,
      name: existing.name,
      profileId: existing.profileId,
      quantity: existing.quantity + cut.quantity,
      lengthMm: existing.lengthMm,
      angleStart: existing.angleStart,
      angleEnd: existing.angleEnd,
      ruleDescriptions: existing.ruleDescriptions,
    );
  }
  lines.addAll(byProfile.values);

  // Glass lines: each input GlassItem becomes one BomLine. The calculator
  // already produces per-section GlassItems that don't collide on
  // (reference, width, height) -- grouping at the BOM level is
  // therefore not done. If a future system ever produces two panes with
  // identical (reference, width, height), the buildBom output would
  // carry two lines; the workshop view can surface a diagnostic.
  for (final item in glass) {
    lines.add(
      BomLine(
        domain: BomDomain.glass,
        reference: item.profileReference,
        // GlassItem has no display name (the profile reference is the
        // displayed identity) -- the BOM line carries the reference as
        // its name so the workshop view can render the pane in the
        // same column as every other component.
        name: item.profileReference,
        quantity: item.quantity,
        widthMm: item.widthMm,
        heightMm: item.heightMm,
        ruleDescriptions: [
          if (item.ruleDescription != null) item.ruleDescription!,
        ],
      ),
    );
  }

  // Hardware lines: reuse the hardware grouping so the BOM's
  // hardware rows are the same shape as the dedicated
  // [HardwareLine] view.
  final hardwareLines = buildHardwareLines(hardware);
  for (final line in hardwareLines) {
    lines.add(
      BomLine(
        domain: line.category == HardwareCategory.hardware
            ? BomDomain.hardware
            : BomDomain.accessory,
        reference: line.reference,
        name: line.name,
        quantity: line.quantity,
        lengthMm: line.lengthMm,
        ruleDescriptions: line.ruleDescriptions,
      ),
    );
  }

  return lines;
}

/// Sums construction-wide totals over the BOM. Sums all domains'
/// piece counts (the grand total a workshop view shows as "X
/// components total"), the glass area (m²), and the hardware
/// total length (mm). Profile length is not summed at this layer
/// because the workshop view already has [sumCutListLines] for the
/// cut-list dialog; the BOM is the *unified* view, not a replacement
/// of the cut list.
BomSummary summarizeBom(List<BomLine> lines) {
  if (lines.isEmpty) return _emptyBomSummary();
  var totalPieces = 0;
  var glassAreaM2 = 0.0;
  var hardwareTotalLengthMm = 0.0;
  for (final line in lines) {
    totalPieces += line.quantity;
    switch (line.domain) {
      case BomDomain.profile:
        // Profile total length stays in [sumCutListLines]; the BOM
        // grand total is "pieces across all domains" only.
        break;
      case BomDomain.glass:
        if (line.widthMm != null && line.heightMm != null) {
          glassAreaM2 +=
              line.widthMm! * line.heightMm! * line.quantity / 1e6;
        }
        break;
      case BomDomain.hardware:
      case BomDomain.accessory:
        // `BomLine` stores per-piece length + quantity (matching the
        // flat-row shape of [CutListLine]); the grand total re-derives
        // by multiplying, just as `sumCutListLines` sums lengths and
        // weights on per-line totals. Count-only lines carry lengthMm
        // = null and contribute 0 to the length total.
        if (line.lengthMm != null) {
          hardwareTotalLengthMm += line.lengthMm! * line.quantity;
        }
        break;
    }
  }
  return BomSummary(
    totalPieces: totalPieces,
    glassAreaM2: glassAreaM2,
    hardwareTotalLengthMm: hardwareTotalLengthMm,
  );
}
