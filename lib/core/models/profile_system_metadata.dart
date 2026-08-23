import 'opening.dart';

/// One verified maximum-size entry for a [ProfileSystem] -- e.g. "à-frappe
/// sashes max 1350 x 1650 mm".
///
/// [openingType] is `null` when the limit applies regardless of opening
/// type (a whole-system baie limit); when set, the limit only applies to
/// sections/constructions of that opening behaviour.
///
/// Limits are ADVISORY data: they never feed the cut calculator -- they
/// exist so the editor can warn when a design exceeds documented maximums.
/// Every value must trace to a real source document recorded in the owning
/// metadata's [ProfileSystemMetadata.sourceDescription] (and in
/// `docs/VERIFIED_SOURCES.md`); nothing here is ever estimated.
class DimensionLimit {
  /// The opening type this limit applies to, or `null` for "any".
  final OpeningType? openingType;

  final double maxWidthMm;
  final double maxHeightMm;

  const DimensionLimit({
    this.openingType,
    required this.maxWidthMm,
    required this.maxHeightMm,
  });

  Map<String, dynamic> toJson() => {
    if (openingType != null) 'openingType': openingType!.name,
    'maxWidthMm': maxWidthMm,
    'maxHeightMm': maxHeightMm,
  };

  static DimensionLimit fromJson(Map<String, dynamic> json) => DimensionLimit(
    openingType: json['openingType'] == null
        ? null
        : OpeningType.values.byName(json['openingType'] as String),
    maxWidthMm: (json['maxWidthMm'] as num).toDouble(),
    maxHeightMm: (json['maxHeightMm'] as num).toDouble(),
  );
}

/// Verified technical data describing one [ProfileSystem], transcribed from
/// an identified source document.
///
/// Every field is optional: a system only carries the facts its source
/// actually states. Where a document states several options ("dormants de
/// 44 mm ou 66 mm"), the corresponding field is a list holding exactly the
/// stated options -- never a min/max range invented between them. Facts a
/// source does NOT state stay absent (`null`/empty): absence means
/// "unknown", never "zero" or "no". `thermalBreak` is deliberately
/// nullable rather than defaulting false -- an unstated thermal-break
/// status must not silently read as "none".
///
/// This is descriptive/specification data only: NOTHING here is consumed
/// by `ConstructionCalculator`. It exists so verified knowledge lives in
/// typed models instead of code comments, and so advisory features
/// (dimension-limit warnings) have something honest to read.
class ProfileSystemMetadata {
  /// Frame (dormant) depth options stated by the source, in mm.
  final List<double> frameDepthOptionsMm;

  /// Sash side-stile (montant latéral d'ouvrant) depth options, in mm.
  final List<double> sashStileDepthOptionsMm;

  /// Sash meeting-stile / central mullion depth, in mm, when stated as a
  /// single value distinct from the side stiles.
  final double? sashMeetingStileDepthMm;

  /// Glazing rebate (feuillure) depth, in mm.
  final double? glazingRebateMm;

  /// Minimum fillable glass thickness, in mm.
  final double? glazingMinMm;

  /// Maximum fillable glass thickness, in mm.
  final double? glazingMaxMm;

  /// Thermal-break status AS STATED by the source: true/false when the
  /// document says so, `null` when it does not mention it at all.
  final bool? thermalBreak;

  /// Short assembly note faithful to the source's wording (e.g. which cuts,
  /// which joining method). Never paraphrased into new engineering claims.
  final String? assemblyNote;

  /// Short drainage note, same rules as [assemblyNote].
  final String? drainageNote;

  /// Short surface-finish note (coating thicknesses, standards), same rules.
  final String? finishNote;

  /// Verified maximum dimensions, each with its applicable opening type (or
  /// any). Empty when the source documents no such table.
  final List<DimensionLimit> dimensionLimits;

  /// Citation of where this metadata came from -- document title/identity,
  /// issuer, and how it was obtained. The anchor of the project rule that
  /// every stored fabrication fact must be traceable to a dependable source
  /// (see also `docs/VERIFIED_SOURCES.md`).
  final String sourceDescription;

  const ProfileSystemMetadata({
    this.frameDepthOptionsMm = const [],
    this.sashStileDepthOptionsMm = const [],
    this.sashMeetingStileDepthMm,
    this.glazingRebateMm,
    this.glazingMinMm,
    this.glazingMaxMm,
    this.thermalBreak,
    this.assemblyNote,
    this.drainageNote,
    this.finishNote,
    this.dimensionLimits = const [],
    required this.sourceDescription,
  });

  Map<String, dynamic> toJson() => {
    'frameDepthOptionsMm': frameDepthOptionsMm,
    'sashStileDepthOptionsMm': sashStileDepthOptionsMm,
    if (sashMeetingStileDepthMm != null)
      'sashMeetingStileDepthMm': sashMeetingStileDepthMm,
    if (glazingRebateMm != null) 'glazingRebateMm': glazingRebateMm,
    if (glazingMinMm != null) 'glazingMinMm': glazingMinMm,
    if (glazingMaxMm != null) 'glazingMaxMm': glazingMaxMm,
    if (thermalBreak != null) 'thermalBreak': thermalBreak,
    if (assemblyNote != null) 'assemblyNote': assemblyNote,
    if (drainageNote != null) 'drainageNote': drainageNote,
    if (finishNote != null) 'finishNote': finishNote,
    'dimensionLimits': dimensionLimits.map((l) => l.toJson()).toList(),
    'sourceDescription': sourceDescription,
  };

  static ProfileSystemMetadata fromJson(Map<String, dynamic> json) {
    final limitsJson = json['dimensionLimits'] as List<dynamic>? ?? [];
    return ProfileSystemMetadata(
      frameDepthOptionsMm: [
        for (final v in json['frameDepthOptionsMm'] as List<dynamic>? ?? [])
          (v as num).toDouble(),
      ],
      sashStileDepthOptionsMm: [
        for (final v in json['sashStileDepthOptionsMm'] as List<dynamic>? ?? [])
          (v as num).toDouble(),
      ],
      sashMeetingStileDepthMm: json['sashMeetingStileDepthMm'] == null
          ? null
          : (json['sashMeetingStileDepthMm'] as num).toDouble(),
      glazingRebateMm: json['glazingRebateMm'] == null
          ? null
          : (json['glazingRebateMm'] as num).toDouble(),
      glazingMinMm: json['glazingMinMm'] == null
          ? null
          : (json['glazingMinMm'] as num).toDouble(),
      glazingMaxMm: json['glazingMaxMm'] == null
          ? null
          : (json['glazingMaxMm'] as num).toDouble(),
      thermalBreak: json['thermalBreak'] == null
          ? null
          : json['thermalBreak'] as bool,
      assemblyNote: json['assemblyNote'] as String?,
      drainageNote: json['drainageNote'] as String?,
      finishNote: json['finishNote'] as String?,
      dimensionLimits: [
        for (final l in limitsJson)
          DimensionLimit.fromJson(l as Map<String, dynamic>),
      ],
      sourceDescription: json['sourceDescription'] as String? ?? '',
    );
  }
}
