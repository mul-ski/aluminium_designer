import '../profile.dart';
import 'dimension_expression.dart';
import 'rule_condition.dart';

/// Which quantity of pieces a rule produces for a given construction.
///
/// Kept as a small typed model instead of a bare `int` so it can later grow
/// (e.g. per-vantail counts) without breaking the rule's shape.
class CutQuantity {
  /// Fixed number of identical pieces this rule produces, independent of
  /// the construction's opening count (e.g. "2 montants" for a simple
  /// fixed frame).
  final int fixedCount;

  const CutQuantity.fixed(this.fixedCount);
}

/// Cut angles for both ends of a piece, in degrees.
///
/// 45/45 is a common mitred corner; 90/90 is a square cut. This is stored
/// per-rule rather than assumed, since it varies by profile type and
/// system.
class CutAngles {
  final double start;
  final double end;

  const CutAngles({required this.start, required this.end});

  const CutAngles.square() : start = 90, end = 90;

  const CutAngles.mitred45() : start = 45, end = 45;
}

/// A single, data-driven rule describing how to produce cut pieces for one
/// [ProfileType] within a [ProfileSystem].
///
/// This is the placeholder-safe replacement for the hardcoded
/// switch-statement logic that used to live directly in
/// `ConstructionCalculator`. A rule says, declaratively:
///
///   "For profile type X, cut `lengthExpression` pieces, `quantity` of
///    them, with these corner angles."
///
/// No manufacturer-specific deduction values are provided here — every
/// concrete rule set built from this model must be explicit about whether
/// its numbers are real manufacturer data or a placeholder.
class ProfileCalculationRule {
  /// The profile type this rule applies to (montant, traverse, etc.).
  final ProfileType appliesTo;

  /// Additional conditions this rule requires, beyond matching
  /// [appliesTo]. Empty means "applies to every context of this profile
  /// type" — i.e. today's generic placeholder behaviour. All conditions
  /// must hold (AND semantics); there's no OR/NOT yet — see
  /// [system_rule_set.dart]'s doc comment for why that's deferred.
  final List<RuleCondition> conditions;

  /// Expression computing the cut length for a single piece, in mm.
  final DimensionExpression lengthExpression;

  /// How many pieces this rule produces.
  final CutQuantity quantity;

  /// Corner angles applied to both ends of each produced piece.
  final CutAngles angles;

  /// True if this rule uses invented/generic numbers rather than a real
  /// manufacturer's fabrication data. Every rule currently shipped with the
  /// app must set this to `true` until real data is supplied — see project
  /// constraint "do not invent real-world aluminium fabrication formulas".
  final bool isPlaceholder;

  /// Optional human-readable description, useful for debugging / showing
  /// the user which rule produced a given cut, and in ambiguity error
  /// messages.
  final String? description;

  const ProfileCalculationRule({
    required this.appliesTo,
    this.conditions = const [],
    required this.lengthExpression,
    required this.quantity,
    required this.angles,
    required this.isPlaceholder,
    this.description,
  });

  /// True if [appliesTo] matches the context's profile type and every one
  /// of [conditions] holds for that context.
  bool matches(CalculationContext context) {
    if (context.profile.type != appliesTo) {
      return false;
    }
    return conditions.every((condition) => condition.matches(context));
  }
}
