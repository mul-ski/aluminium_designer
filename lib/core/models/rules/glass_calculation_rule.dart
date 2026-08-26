import '../glass_item.dart';
import 'calculation_rule.dart';
import 'dimension_expression.dart';
import 'rule_condition.dart';

/// One data-driven rule describing how to compute a glass item for a
/// given [Section] in a [Construction].
///
/// Glass is NOT a per-usage rule: a single pane covers a whole opening
/// section. The rule is evaluated once per section that meets its
/// conditions; the [CalculationContext] the selector uses carries the
/// section's dominant ouvrant [Profile] (the sash carrier) as
/// `context.profile`, so the existing `ProfileReferenceCondition` keys
/// naturally on the ouvrant ref -- the same idea as C8's
/// [CompanionProfileReferenceCondition], but here the section is the
/// evaluated context rather than a single usage.
///
/// Selection is pure AND-semantics over [conditions], exactly like
/// [ProfileCalculationRule]. There is NO `appliesTo`/`ProfileType`
/// gate here -- glass rules do not target a profile type; they target
/// sections via their conditions. This keeps glass rules readable and
/// avoids a fake "appliesTo: glass" that would mean nothing to the
/// rest of the engine.
///
/// WHY GLASS LIVES IN ITS OWN RULE CLASS (not a [ProfileCalculationRule]
/// field): the inputs (width + height expressions, glazing type /
/// thickness) and the output (a [GlassItem] carrying section
/// provenance) are structurally different from a profile cut. Extending
/// [ProfileCalculationRule] would have meant a [ProfileCut] that
/// optionally carries glass fields, which both weakens the cut
/// invariant (a profile cut has one length, not a width × height pair)
/// and ties the glass model to the profile result pipeline. A separate
/// rule class keeps each domain's data shape honest.
class GlassCalculationRule {
  /// Additional conditions this rule requires. Empty means "matches
  /// every section" -- but no current manufacturer matches that, since
  /// every documented glass rule is gated on the section's opening type,
  /// vantaux count, AND dominant ouvrant reference. All conditions must
  /// hold (AND semantics); there's no OR/NOT yet -- the
  /// `SystemRuleSet.selectGlass` selection logic mirrors
  /// `SystemRuleSet.select`.
  final List<RuleCondition> conditions;

  /// Expression computing the pane's width in mm against the
  /// construction's dimensions (L, H, openingWidth/Height). The
  /// DimensionVariable set is the same as for profile cuts.
  final DimensionExpression widthExpression;

  /// Expression computing the pane's height in mm. Same variable set
  /// as [widthExpression].
  final DimensionExpression heightExpression;

  /// How many panes this rule produces per matched section. Mirrors
  /// `ProfileCalculationRule.quantity`'s per-placement semantics, but
  /// expressed as a plain int because there is exactly one matched
  /// context per section (no role decomposition here). The calculator
  /// multiplies by the section's own count (currently always 1) to
  /// reach the final physical pane count on the [GlassItem].
  final int quantity;

  /// Free-text glazing type label as stated by the source (e.g.
  /// "Simple vitrage", "Double vitrage"). `null` when the source does
  /// not state one for this cell.
  final String? glazingType;

  /// Stated glazing thickness in mm (e.g. 5, 6, 8, 10, 12...). `null`
  /// when the source does not state a per-pane commitment (a system
  /// range is metadata, not a per-pane value).
  final double? glazingThicknessMm;

  /// True if this rule uses invented/generic numbers rather than a
  /// real manufacturer's fabrication data. Every real rule shipped with
  /// the app MUST set this to `false`; only placeholder / generic
  /// glass rules stay `true`.
  final bool isPlaceholder;

  /// Optional human-readable description, useful for debugging /
  /// showing the user which rule produced a given pane.
  final String? description;

  const GlassCalculationRule({
    this.conditions = const [],
    required this.widthExpression,
    required this.heightExpression,
    this.quantity = 1,
    this.glazingType,
    this.glazingThicknessMm,
    required this.isPlaceholder,
    this.description,
  });

  /// True when every one of [conditions] holds for [context]. The
  /// selector will additionally run specificity ranking and throw
  /// [AmbiguousGlassRuleMatchException] on ties (mirroring
  /// [SystemRuleSet.selectGlass]).
  bool matches(CalculationContext context) {
    return conditions.every((condition) => condition.matches(context));
  }
}
