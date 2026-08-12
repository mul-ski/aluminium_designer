import '../models/construction.dart';
import '../models/cut.dart';
import '../models/profile.dart';
import '../models/rules/dimension_expression.dart';
import '../models/rules/generic_placeholder_rules.dart';
import '../models/rules/rule_condition.dart';
import '../models/rules/system_rule_set.dart';

/// Computes the list of [ProfileCut]s for a [Construction] by evaluating a
/// data-driven [SystemRuleSet] against that construction's dimensions.
///
/// This replaces the old hardcoded switch-statement logic. Behaviour is now
/// entirely determined by which `SystemRuleSet` is supplied -- pass
/// [genericPlaceholderRuleSet] (the default) to get the same placeholder
/// behaviour as before, or a real manufacturer rule set once one exists.
class ConstructionCalculator {
  /// The rule set this calculator evaluates against. Defaults to the
  /// built-in generic placeholder rules if none is supplied.
  final SystemRuleSet ruleSet;

  const ConstructionCalculator({this.ruleSet = genericPlaceholderRuleSet});

  /// Produces cut pieces for every profile in [construction].
  ///
  /// For each profile, builds a [CalculationContext] and asks [ruleSet] to
  /// [SystemRuleSet.select] the single applicable rule. If no rule matches,
  /// the profile is skipped -- same no-op behaviour as before (previously
  /// `default: break;`, now "no rule matched"). If more than one rule
  /// matches with equal specificity, [AmbiguousRuleMatchException]
  /// propagates out of this call rather than being silently resolved --
  /// see `SystemRuleSet.select` for the selection/tie-breaking rules.
  List<ProfileCut> calculate(Construction construction) {
    final variables = <DimensionVariable, double>{
      DimensionVariable.constructionWidth: construction.width,
      DimensionVariable.constructionHeight: construction.height,
    };

    final cuts = <ProfileCut>[];

    for (final profile in construction.profiles) {
      final context = CalculationContext(
        construction: construction,
        profile: profile,
      );

      final rule = ruleSet.select(context);
      if (rule == null) {
        continue;
      }

      final length = rule.lengthExpression.evaluate(variables);

      cuts.add(
        ProfileCut(
          profile: profile,
          length: length,
          quantity: rule.quantity.fixedCount,
          angleStart: rule.angles.start,
          angleEnd: rule.angles.end,
        ),
      );
    }

    return cuts;
  }
}
