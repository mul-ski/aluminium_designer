import 'calculation_rule.dart';
import 'rule_condition.dart';

/// Thrown when more than one rule in a [SystemRuleSet] matches a given
/// [CalculationContext] with equal specificity, so there is no principled
/// way to pick a winner automatically.
///
/// This is a deliberate design choice per project requirement: ambiguous
/// rules must be reported, never silently resolved by picking the first
/// match.
class AmbiguousRuleMatchException implements Exception {
  final List<ProfileCalculationRule> matchedRules;

  const AmbiguousRuleMatchException(this.matchedRules);

  @override
  String toString() {
    final descriptions = matchedRules
        .map((rule) => rule.description ?? rule.appliesTo.toString())
        .join(', ');
    return 'AmbiguousRuleMatchException: ${matchedRules.length} rules '
        'matched with equal specificity: $descriptions. Add a '
        'distinguishing condition to one of them, or remove the overlap.';
  }
}

/// A named collection of [ProfileCalculationRule]s for one profile system
/// (e.g. one manufacturer's product line, or a generic placeholder system).
///
/// `ConstructionCalculator` consumes exactly one `SystemRuleSet` per
/// calculation run instead of having rules hardcoded in a switch statement.
/// This is what makes the engine "data-driven": swapping in a different
/// rule set (a different manufacturer, or eventually rules loaded from
/// CSV/JSON/DB) changes calculation behaviour with no code changes.
class SystemRuleSet {
  /// Identifier matching a `ProfileSystem.id`, or a synthetic id such as
  /// `'generic-placeholder'` for the built-in fallback rules.
  final String systemId;

  /// Human-readable name, e.g. "Generic placeholder rules" or a real
  /// manufacturer/system name once real data is available.
  final String name;

  /// True if none of the rules in this set represent verified
  /// manufacturer fabrication data.
  final bool isPlaceholder;

  /// True for rule sets shipped with the app; false for ones a user
  /// authors for their own [ProfileSystem]. Metadata only -- see
  /// `Manufacturer.isBuiltIn` for why this never changes how a rule set is
  /// evaluated, only how a future UI might treat it.
  final bool isBuiltIn;

  final List<ProfileCalculationRule> rules;

  const SystemRuleSet({
    required this.systemId,
    required this.name,
    required this.isPlaceholder,
    this.isBuiltIn = true,
    required this.rules,
  });

  /// Selects the single applicable rule for [context], or `null` if no rule
  /// matches — preserving the previous "no rule -> no cut" behaviour.
  ///
  /// Selection logic:
  /// 1. Find every rule whose [ProfileCalculationRule.matches] is true.
  /// 2. If none match, return `null`.
  /// 3. If exactly one matches, return it.
  /// 4. If several match, prefer the one(s) with the most conditions --
  ///    more conditions means a more specific rule (e.g. a rule scoped to
  ///    "oscillo-battant with 2 vantaux" beats a bare montant rule with no
  ///    conditions). If more than one rule remains tied at the highest
  ///    condition count, that's a genuine ambiguity: throw
  ///    [AmbiguousRuleMatchException] rather than guessing.
  ///
  /// This never silently falls back to "the first rule in the list" -- a
  /// tie is always either resolved by specificity or reported as an error.
  ProfileCalculationRule? select(CalculationContext context) {
    final matched = rules.where((rule) => rule.matches(context)).toList();

    if (matched.isEmpty) {
      return null;
    }
    if (matched.length == 1) {
      return matched.single;
    }

    final maxConditionCount = matched
        .map((rule) => rule.conditions.length)
        .reduce((a, b) => a > b ? a : b);
    final mostSpecific = matched
        .where((rule) => rule.conditions.length == maxConditionCount)
        .toList();

    if (mostSpecific.length == 1) {
      return mostSpecific.single;
    }

    throw AmbiguousRuleMatchException(mostSpecific);
  }
}
