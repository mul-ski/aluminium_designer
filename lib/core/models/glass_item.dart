/// One computed glass item for a [Construction] run -- the kind of
/// information a workshop needs to order and cut glass: a width, a
/// height, a quantity, and the section/usage provenance that produced
/// it.
///
/// Glass is NOT a per-usage component: a single glass pane covers an
/// entire opening section, so [sectionId] is the natural granularity
/// (no per-usage tracing -- the same pane is produced by the section's
/// configuration, not by any one profile usage). [profileReference] is
/// the dominant ouvrant reference (the sash carrier) the glass rule
/// matched against -- the same `CompanionProfileReferenceCondition` idea
/// from C8, but the section is the evaluated context, not a single
/// usage. The reference is stored so the workshop view can show WHY
/// this pane was sized for this section.
///
/// Like [ProfileCut], every field is data that the calculator either
/// already had or produced by evaluating a rule -- nothing here is
/// invented. [glazingType] (e.g. "Simple", "Double") and
/// [glazingThicknessMm] carry the documented glazing choice when the
/// rule states it; null otherwise (the absence is data the workshop
/// can show as "not specified by the source", never an invented value).
class GlassItem {
  /// Reference of the dominant opening profile this pane sizes for
  /// (e.g. "14.802"). Direct string equality with the source's
  /// `Profile.reference` -- never display names.
  final String profileReference;

  /// Width of the pane in millimetres, after evaluating the rule's
  /// width expression against the construction dimensions.
  final double widthMm;

  /// Height of the pane in millimetres, after evaluating the rule's
  /// height expression against the construction dimensions.
  final double heightMm;

  /// Physical number of panes this rule produces. Mirrors
  /// `ProfileCut.quantity` semantics: `usage.quantity` (here: section
  /// count) × rule's quantity.
  final int quantity;

  /// Free-text glazing type as stated by the source (e.g. "Simple
  /// vitrage", "Double vitrage"); null when the rule does not state one.
  final String? glazingType;

  /// Glazing thickness in mm when stated by the source (e.g. 5, 6, 8,
  /// 10, 12...); null otherwise. Stored ONLY when the rule carries it --
  /// never inferred from system metadata ranges alone (those are
  /// system-level ranges, not a per-pane commitment).
  final double? glazingThicknessMm;

  /// Id of the [Section] this pane belongs to.
  final String sectionId;

  /// Human-readable description of the [GlassCalculationRule] that
  /// produced this pane. Same convention as [ProfileCut.ruleDescription]:
  /// never invented, null when the rule has no description.
  final String? ruleDescription;

  const GlassItem({
    required this.profileReference,
    required this.widthMm,
    required this.heightMm,
    required this.quantity,
    this.glazingType,
    this.glazingThicknessMm,
    required this.sectionId,
    this.ruleDescription,
  });
}
