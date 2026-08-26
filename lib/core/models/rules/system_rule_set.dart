import 'calculation_rule.dart';
import 'glass_calculation_rule.dart';
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

/// Thrown when more than one [GlassCalculationRule] in a [SystemRuleSet]
/// matches a given [CalculationContext] with equal specificity.
///
/// Same "ambiguous rules must be reported" contract as the profile-rule
/// ambiguity exception -- a different rule list to keep the type honest
/// and the message precise.
class AmbiguousGlassRuleMatchException implements Exception {
  final List<GlassCalculationRule> matchedRules;

  const AmbiguousGlassRuleMatchException(this.matchedRules);

  @override
  String toString() {
    final descriptions = matchedRules
        .map((rule) => rule.description ?? '<glass rule>')
        .join(', ');
    return 'AmbiguousGlassRuleMatchException: ${matchedRules.length} '
        'glass rules matched with equal specificity: $descriptions. Add '
        'a distinguishing condition to one of them, or remove the '
        'overlap.';
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
///
/// P1 evolution: in addition to profile [rules], a rule set may carry
/// [glassRules] (one glass pane per matched opening section) and
/// [hardwareRules] (P1 commit 2) -- both are optional, default `const []`
/// so the existing built-in rule sets (me-14600, sep-4200, me-14800,
/// me-14700) compile unchanged. Each domain's rules are evaluated by a
/// separate selector (see [select] for profiles, [selectGlass] for glass)
/// -- one selector per component domain so each stays single-purpose and
/// no domain's specificity arithmetic can interfere with another's.
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
  /// [Manufacturer.isBuiltIn] for why this never changes how a rule set is
  /// evaluated, only how a future UI might treat it (e.g. preventing
  /// deletion).
  final bool isBuiltIn;

  /// Profile cut rules. Evaluated per [ProfileUsage] in the construction
  /// -- the original engine loop.
  final List<ProfileCalculationRule> rules;

  /// Glass rules. Evaluated once per opening section (the section's
  /// dominant ouvrant ref becomes `context.profile` so the existing
  /// `ProfileReferenceCondition` keys naturally on the sash ref). Empty
  /// by default -- a system that doesn't ship glass rules simply has
  /// empty `glass` on its [CalculationOutcome]. The `generic-placeholder`
  /// rule set intentionally ships no glass rules; placeholder cuts stay
  /// placeholder glass too.
  final List<GlassCalculationRule> glassRules;

  const SystemRuleSet({
    required this.systemId,
    required this.name,
    required this.isPlaceholder,
    this.isBuiltIn = true,
    required this.rules,
    this.glassRules = const [],
  });

  /// Selects the single applicable profile rule for [context], or `null`
  /// if no rule matches — preserving the previous "no rule -> no cut"
  /// behaviour.
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

  /// Selects the single applicable glass rule for [context], or `null`
  /// if no rule matches. Mirrors [select]'s specificity ranking and
  /// ambiguity reporting. Glass rules have no `appliesTo`/`ProfileType`
  /// gate (their `conditions` ARE the gate); the evaluated context's
  /// `profile` is expected to be the section's dominant ouvrant ref.
  GlassCalculationRule? selectGlass(CalculationContext context) {
    final matched =
        glassRules.where((rule) => rule.matches(context)).toList();

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

    throw AmbiguousGlassRuleMatchException(mostSpecific);
  }
}
