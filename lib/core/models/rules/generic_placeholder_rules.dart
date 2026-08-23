import '../profile.dart';
import 'calculation_rule.dart';
import 'dimension_expression.dart';
import 'system_rule_set.dart';

/// A generic, clearly-marked placeholder rule set.
///
/// ⚠️ THIS IS NOT REAL MANUFACTURER DATA. ⚠️
///
/// Each rule yields ONE piece per matched `ProfileUsage` (quantity 1), at
/// the full construction dimension for that profile type, mitred 45°/45°.
/// This is per-usage semantics, matching how the engine evaluates every
/// role-scoped usage individually: a frame with a left AND a right montant
/// gets its two pieces from two usages, not from one rule multiplying
/// itself. The earlier fixed(2) counts here were legacy whole-construction
/// thinking from the pre-usage hardcoded switch statement; they produced
/// doubled totals once usages became the iteration source. The numbers are
/// placeholder either way -- no real deduction or count data is claimed.
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
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: true,
      description:
          'Placeholder: montant per assignment, full construction height',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionHeight,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: true,
      description:
          'Placeholder: dormant per assignment, full construction height',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.traverse,
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionWidth,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: true,
      description:
          'Placeholder: traverse per assignment, full construction width',
    ),
  ],
);
