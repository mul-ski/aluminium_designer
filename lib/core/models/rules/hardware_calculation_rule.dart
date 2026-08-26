import '../hardware_item.dart';
import 'dimension_expression.dart';
import 'rule_condition.dart';

/// One data-driven rule describing how to compute a [HardwareItem]
/// for a given [Section] in a [Construction].
///
/// Hardware items are per-section (a paumelle attaches to the section's
/// frame/sash, a joint runs around the section's perimeter) -- the
/// rule is evaluated once per section that meets its conditions, like
/// glass. The [CalculationContext] the selector uses carries the
/// section's dominant ouvrant [Profile] as `context.profile`, so the
/// existing `ProfileReferenceCondition` keys naturally on the sash
/// ref. Unlike glass, hardware rules MAY also match on a per-usage
/// basis (the calculator records contributing usage ids in
/// `HardwareItem.usageIds` so the workshop view can attribute the
/// item to specific profile placements).
///
/// Selection is pure AND-semantics over [conditions], exactly like
/// [ProfileCalculationRule] and [GlassCalculationRule]. There is NO
/// `appliesTo`/`ProfileType` gate here -- hardware rules do not
/// target a profile type; they target sections via their conditions.
/// The [category] field on the rule is metadata for downstream
/// grouping (P1 commit 3 aggregation, commit 6 BOM dialog) and is
/// NOT a gate.
///
/// WHY HARDWARE LIVES IN ITS OWN RULE CLASS (not a [ProfileCalculationRule]
/// or [GlassCalculationRule] field): the inputs (optional length
/// expression, category tag, per-section evaluation) and the output
/// (a [HardwareItem] carrying section + usage provenance) are
/// structurally different from a profile cut or a glass pane.
/// Extending either existing class would have meant a mixed-purpose
/// data shape that weakens the invariants of the existing item
/// classes. A separate rule class keeps each domain honest.
class HardwareCalculationRule {
  /// Additional conditions this rule requires. Empty means "matches
  /// every section" -- but no real manufacturer matches that, since
  /// every documented hardware rule is gated on at least the section's
  /// opening type, vantaux count, and configuration. All conditions
  /// must hold (AND semantics); there's no OR/NOT yet -- the
  /// `SystemRuleSet.selectHardware` selection logic mirrors
  /// `SystemRuleSet.select` / `SystemRuleSet.selectGlass`.
  final List<RuleCondition> conditions;

  /// How many physical pieces this rule produces per matched section.
  /// Plain int -- one matched section yields exactly this many. The
  /// calculator multiplies by the section's own count (currently
  /// always 1) to reach the final physical piece count on the
  /// [HardwareItem].
  final int quantity;

  /// Optional length expression producing the item's cut length in mm
  /// (e.g. "2L+2H" for a joint, "L" for weatherstripping). `null`
  /// when the item is count-only (paumelles, equerres, gaches --
  /// the source documents them as pieces, not cuts). When non-null
  /// the calculator evaluates it against the construction dimensions.
  final DimensionExpression? lengthExpression;

  /// Free-text reference as stated by the source (e.g. "AC-600",
  /// "JO-826"). Direct string equality with whatever the source
  /// lists; never inferred.
  final String reference;

  /// Display name (e.g. "Équerre à pions", "Joint de battue"). Source's
  /// own wording when available, otherwise the reference itself.
  final String name;

  /// Hardware vs accessory category (metal piece vs gasket). Metadata
  /// for downstream grouping; NOT a selector condition.
  final HardwareCategory category;

  /// True if this rule uses invented/generic numbers rather than a
  /// real manufacturer's fabrication data. Every real rule shipped with
  /// the app MUST set this to `false`; only placeholder / generic
  /// hardware rules stay `true`.
  final bool isPlaceholder;

  /// Optional human-readable description, useful for debugging /
  /// showing the user which rule produced a given item.
  final String? description;

  const HardwareCalculationRule({
    this.conditions = const [],
    required this.quantity,
    this.lengthExpression,
    required this.reference,
    required this.name,
    required this.category,
    required this.isPlaceholder,
    this.description,
  });

  /// True when every one of [conditions] holds for [context]. The
  /// selector will additionally run specificity ranking and throw
  /// [AmbiguousHardwareRuleMatchException] on ties (mirroring
  /// [SystemRuleSet.select] and [SystemRuleSet.selectGlass]).
  bool matches(CalculationContext context) {
    return conditions.every((condition) => condition.matches(context));
  }
}
