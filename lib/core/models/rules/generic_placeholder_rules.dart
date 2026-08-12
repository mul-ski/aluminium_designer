import '../profile.dart';
import 'calculation_rule.dart';
import 'dimension_expression.dart';
import 'system_rule_set.dart';

/// A generic, clearly-marked placeholder rule set.
///
/// ⚠️ THIS IS NOT REAL MANUFACTURER DATA. ⚠️
///
/// It reproduces the same behaviour as the old hardcoded switch statement
/// (2x montant/dormant at full height, 2x traverse at full width, both
/// mitred 45°/45°) but expressed as data-driven rules, so the calculator
/// has a safe default to fall back on when no real `SystemRuleSet` has been
/// supplied for a construction's profile system yet.
///
/// Replace/extend this with real rule sets once actual manufacturer
/// fabrication data (Aluminium du Maroc, Maghreb Extrusion, Sepalumic,
/// Madilak, GPRAL, etc.) is available. Do not hand-edit the numbers here to
/// "guess" real deductions.
const genericPlaceholderRuleSet = SystemRuleSet(
  systemId: 'generic-placeholder',
  name: 'Generic placeholder rules (no real manufacturer data)',
  isPlaceholder: true,
  rules: [
    ProfileCalculationRule(
      appliesTo: ProfileType.montant,
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionHeight,
      ),
      quantity: CutQuantity.fixed(2),
      angles: CutAngles.mitred45(),
      isPlaceholder: true,
      description: 'Placeholder: 2x montant at full construction height',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionHeight,
      ),
      quantity: CutQuantity.fixed(2),
      angles: CutAngles.mitred45(),
      isPlaceholder: true,
      description: 'Placeholder: 2x dormant at full construction height',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.traverse,
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionWidth,
      ),
      quantity: CutQuantity.fixed(2),
      angles: CutAngles.mitred45(),
      isPlaceholder: true,
      description: 'Placeholder: 2x traverse at full construction width',
    ),
  ],
);
