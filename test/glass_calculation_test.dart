import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/models/calculation_outcome.dart';
import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/glass_item.dart';
import 'package:aluminium_designer/core/models/layout_direction.dart';
import 'package:aluminium_designer/core/models/opening.dart';
import 'package:aluminium_designer/core/models/profile.dart';
import 'package:aluminium_designer/core/models/rules/dimension_expression.dart';
import 'package:aluminium_designer/core/models/rules/glass_calculation_rule.dart';
import 'package:aluminium_designer/core/models/rules/rule_condition.dart';
import 'package:aluminium_designer/core/models/rules/system_rule_set.dart';
import 'package:aluminium_designer/core/models/section.dart';

/// P1 commit 1: generic glass model + rule + selector. The calculator
/// does NOT yet evaluate glass rules (that lands in commit 4) -- these
/// tests pin the model shape, the rule matching, the selector's
/// specificity/ambiguity behaviour, and that `CalculationOutcome.glass`
/// defaults to `const []` so existing consumers compile unchanged.
Construction _construction() => Construction(
  id: 'c1',
  name: 'Test',
  type: ConstructionType.window,
  width: 2000,
  height: 1500,
  manufacturer: 'Test Manufacturer',
  system: 'Test System',
  sections: const [],
  layoutDirection: SectionLayoutDirection.horizontal,
  profiles: const [],
);

Section _section({
  SectionKind kind = SectionKind.ouvrant,
  OpeningType? openingType = OpeningType.francaise,
  int vantauxCount = 1,
}) {
  final isFixed = kind == SectionKind.fixed;
  return Section(
    id: 's1',
    order: 0,
    kind: kind,
    width: 2000,
    height: 1500,
    openingType: isFixed ? null : openingType,
    vantauxCount: isFixed ? 0 : vantauxCount,
  );
}

Profile _ouvrantProfile(String reference) => Profile(
  id: 'p-$reference',
  manufacturer: 'Test Manufacturer',
  system: 'Test System',
  reference: reference,
  name: 'Ouvrant $reference',
  type: ProfileType.ouvrant,
  width: 50,
  depth: 40,
  weightPerMeter: 0,
);

CalculationContext _glassContext({
  String reference = '14.802',
  SectionKind kind = SectionKind.ouvrant,
  OpeningType? openingType = OpeningType.francaise,
  int vantauxCount = 1,
}) {
  return CalculationContext(
    construction: _construction(),
    profile: _ouvrantProfile(reference),
    section: _section(
      kind: kind,
      openingType: openingType,
      vantauxCount: vantauxCount,
    ),
  );
}

void main() {
  group('GlassItem model', () {
    test('carries every documented domain field', () {
      const item = GlassItem(
        profileReference: '14.802',
        widthMm: 1868.0,
        heightMm: 1368.0,
        quantity: 1,
        glazingType: 'Simple vitrage',
        glazingThicknessMm: 6,
        sectionId: 's1',
        ruleDescription: 'test',
      );
      expect(item.profileReference, '14.802');
      expect(item.widthMm, 1868.0);
      expect(item.heightMm, 1368.0);
      expect(item.quantity, 1);
      expect(item.glazingType, 'Simple vitrage');
      expect(item.glazingThicknessMm, 6);
      expect(item.sectionId, 's1');
      expect(item.ruleDescription, 'test');
    });

    test('glazingType and glazingThicknessMm are null when not stated '
        '(never invented)', () {
      const item = GlassItem(
        profileReference: '14.802',
        widthMm: 1868.0,
        heightMm: 1368.0,
        quantity: 1,
        sectionId: 's1',
      );
      expect(item.glazingType, isNull);
      expect(item.glazingThicknessMm, isNull);
      expect(item.ruleDescription, isNull);
    });
  });

  group('GlassCalculationRule matching', () {
    test('matches when every condition holds', () {
      final rule = GlassCalculationRule(
        conditions: [
          const OpeningTypeCondition(OpeningType.francaise),
          const VantauxCountCondition(1),
        ],
        widthExpression: BinaryExpression(
          left: DimensionExpression.variable(
            DimensionVariable.constructionWidth,
          ),
          operator: BinaryOperator.subtract,
          right: DimensionExpression.constant(132.0),
        ),
        heightExpression: BinaryExpression(
          left: DimensionExpression.variable(
            DimensionVariable.constructionHeight,
          ),
          operator: BinaryOperator.subtract,
          right: DimensionExpression.constant(132.0),
        ),
        quantity: 1,
        isPlaceholder: false,
        description: 'test',
      );
      expect(
        rule.matches(
          _glassContext(),
        ),
        isTrue,
      );
    });

    test('does not match when one condition fails (different '
        'opening type)', () {
      final rule = GlassCalculationRule(
        conditions: [
          const OpeningTypeCondition(OpeningType.coulissante),
        ],
        widthExpression:
            DimensionExpression.constant(1868.0),
        heightExpression:
            DimensionExpression.constant(1368.0),
        quantity: 1,
        isPlaceholder: false,
      );
      expect(rule.matches(_glassContext()), isFalse);
    });

    test('ProfileReferenceCondition keys on the section dominant '
        'ouvrant ref (same contract as C8 sibling ref)', () {
      final rule = GlassCalculationRule(
        conditions: const [
          ProfileReferenceCondition({'14.802'}),
        ],
        widthExpression:
            DimensionExpression.constant(1868.0),
        heightExpression:
            DimensionExpression.constant(1368.0),
        quantity: 1,
        isPlaceholder: false,
      );
      expect(rule.matches(_glassContext(reference: '14.802')), isTrue);
      expect(rule.matches(_glassContext(reference: '14.805')), isFalse);
    });

    test('a rule with no conditions matches every context', () {
      final rule = GlassCalculationRule(
        widthExpression:
            DimensionExpression.constant(1868.0),
        heightExpression:
            DimensionExpression.constant(1368.0),
        quantity: 1,
        isPlaceholder: true,
      );
      expect(rule.matches(_glassContext()), isTrue);
    });
  });

  group('SystemRuleSet.selectGlass (specificity + ambiguity)', () {
    GlassCalculationRule glassRule({
      String? description,
      List<RuleCondition> conditions = const [],
    }) =>
        GlassCalculationRule(
          conditions: conditions,
          widthExpression: DimensionExpression.constant(1868.0),
          heightExpression: DimensionExpression.constant(1368.0),
          quantity: 1,
          isPlaceholder: false,
          description: description,
        );

    SystemRuleSet ruleSet(List<GlassCalculationRule> glassRules) =>
        SystemRuleSet(
          systemId: 'test',
          name: 'test',
          isPlaceholder: false,
          rules: const [],
          glassRules: glassRules,
        );

    test('returns null when no glass rule matches', () {
      final set = ruleSet([]);
      expect(set.selectGlass(_glassContext()), isNull);
    });

    test('returns the only matching rule', () {
      final rule = glassRule(description: 'only');
      final set = ruleSet([rule]);
      final selected = set.selectGlass(_glassContext());
      expect(selected, same(rule));
    });

    test('prefers the rule with more conditions (specificity)', () {
      final bare = glassRule(description: 'bare');
      final specific = glassRule(
        description: 'specific',
        conditions: const [
          OpeningTypeCondition(OpeningType.francaise),
          VantauxCountCondition(1),
        ],
      );
      final set = ruleSet([bare, specific]);
      final selected = set.selectGlass(_glassContext());
      expect(selected, same(specific));
    });

    test('throws AmbiguousGlassRuleMatchException on a specificity tie',
        () {
      final a = glassRule(
        conditions: const [OpeningTypeCondition(OpeningType.francaise)],
        description: 'a',
      );
      final b = glassRule(
        conditions: const [VantauxCountCondition(1)],
        description: 'b',
      );
      final set = ruleSet([a, b]);
      expect(
        () => set.selectGlass(_glassContext()),
        throwsA(isA<AmbiguousGlassRuleMatchException>()),
      );
    });
  });

  group('CalculationOutcome.glass default', () {
    test('defaults to const [] so existing consumers compile', () {
      const outcome = CalculationOutcome(cuts: []);
      expect(outcome.glass, isEmpty);
      expect(outcome.glassIssues, isEmpty);
    });

    test('isEmpty accounts for glass + glassIssues', () {
      const empty = CalculationOutcome(cuts: []);
      expect(empty.isEmpty, isTrue);

      const withIssue = CalculationOutcome(
        cuts: [],
        glassIssues: [
          SectionGlassIssue(
            sectionId: 's1',
            reason: SectionGlassIssueReason.noRuleMatched,
          ),
        ],
      );
      expect(withIssue.isEmpty, isFalse);
    });
  });

  group('SectionGlassIssue model', () {
    test('carries section id and reason', () {
      const issue = SectionGlassIssue(
        sectionId: 's1',
        reason: SectionGlassIssueReason.dominantOuvrantUnresolved,
      );
      expect(issue.sectionId, 's1');
      expect(issue.reason, SectionGlassIssueReason.dominantOuvrantUnresolved);
    });
  });

  group('SystemRuleSet backward-compat (existing tests still compile)',
      () {
    test('glassRules defaults to const [] when omitted', () {
      final set = SystemRuleSet(
        systemId: 't',
        name: 't',
        isPlaceholder: true,
        rules: const [],
      );
      expect(set.glassRules, isEmpty);
    });
  });
}
