import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/models/calculation_outcome.dart';
import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/hardware_item.dart';
import 'package:aluminium_designer/core/models/layout_direction.dart';
import 'package:aluminium_designer/core/models/opening.dart';
import 'package:aluminium_designer/core/models/profile.dart';
import 'package:aluminium_designer/core/models/rules/hardware_calculation_rule.dart';
import 'package:aluminium_designer/core/models/rules/rule_condition.dart';
import 'package:aluminium_designer/core/models/rules/system_rule_set.dart';
import 'package:aluminium_designer/core/models/section.dart';

/// P1 commit 2: generic hardware model + rule + selector. The
/// calculator does NOT yet evaluate hardware rules (that lands in
/// commit 4) -- these tests pin the model shape, the rule matching,
/// the selector's specificity/ambiguity behaviour, and that
/// `CalculationOutcome.hardware` defaults to `const []` so existing
/// consumers compile unchanged.
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

CalculationContext _hardwareContext({
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
  group('HardwareItem model', () {
    test('carries every documented domain field (count-only)', () {
      const item = HardwareItem(
        reference: 'AC-600',
        name: 'Équerre à pions',
        category: HardwareCategory.hardware,
        quantity: 8,
        sectionId: 's1',
        ruleDescription: 'test',
      );
      expect(item.reference, 'AC-600');
      expect(item.name, 'Équerre à pions');
      expect(item.category, HardwareCategory.hardware);
      expect(item.quantity, 8);
      expect(item.lengthMm, isNull);
      expect(item.sectionId, 's1');
      expect(item.usageIds, isEmpty);
      expect(item.ruleDescription, 'test');
    });

    test('carries lengthMm when the item is length-bearing', () {
      const item = HardwareItem(
        reference: 'JO-826',
        name: 'Joint de battue',
        category: HardwareCategory.accessory,
        quantity: 1,
        lengthMm: 7000.0,
        sectionId: 's1',
        usageIds: ['u1', 'u2'],
      );
      expect(item.category, HardwareCategory.accessory);
      expect(item.lengthMm, 7000.0);
      expect(item.usageIds, hasLength(2));
    });
  });

  group('HardwareCalculationRule matching', () {
    test('matches when every condition holds (count-only rule)', () {
      final rule = HardwareCalculationRule(
        conditions: const [
          OpeningTypeCondition(OpeningType.francaise),
          VantauxCountCondition(1),
        ],
        quantity: 8,
        reference: 'AC-600',
        name: 'Équerre à pions',
        category: HardwareCategory.hardware,
        isPlaceholder: false,
      );
      expect(rule.matches(_hardwareContext()), isTrue);
    });

    test('does not match when one condition fails', () {
      final rule = HardwareCalculationRule(
        conditions: const [OpeningTypeCondition(OpeningType.coulissante)],
        quantity: 1,
        reference: 'X',
        name: 'X',
        category: HardwareCategory.hardware,
        isPlaceholder: false,
      );
      expect(rule.matches(_hardwareContext()), isFalse);
    });

    test('ProfileReferenceCondition keys on the section dominant '
        'ouvrant ref', () {
      final rule = HardwareCalculationRule(
        conditions: const [ProfileReferenceCondition({'14.805'})],
        quantity: 1,
        reference: 'X',
        name: 'X',
        category: HardwareCategory.hardware,
        isPlaceholder: false,
      );
      expect(rule.matches(_hardwareContext(reference: '14.805')), isTrue);
      expect(rule.matches(_hardwareContext(reference: '14.802')), isFalse);
    });

    test('a rule with no conditions matches every context', () {
      final rule = HardwareCalculationRule(
        quantity: 1,
        reference: 'X',
        name: 'X',
        category: HardwareCategory.hardware,
        isPlaceholder: true,
      );
      expect(rule.matches(_hardwareContext()), isTrue);
    });
  });

  group('SystemRuleSet.selectHardware (specificity + ambiguity)', () {
    HardwareCalculationRule hardwareRule({
      String? description,
      List<RuleCondition> conditions = const [],
      HardwareCategory category = HardwareCategory.hardware,
      int quantity = 1,
    }) =>
        HardwareCalculationRule(
          conditions: conditions,
          quantity: quantity,
          reference: 'X',
          name: 'X',
          category: category,
          isPlaceholder: false,
          description: description,
        );

    SystemRuleSet ruleSet(List<HardwareCalculationRule> hardwareRules) =>
        SystemRuleSet(
          systemId: 'test',
          name: 'test',
          isPlaceholder: false,
          rules: const [],
          hardwareRules: hardwareRules,
        );

    test('returns null when no hardware rule matches', () {
      final set = ruleSet([]);
      expect(set.selectHardware(_hardwareContext()), isNull);
    });

    test('returns the only matching rule', () {
      final rule = hardwareRule(description: 'only');
      final set = ruleSet([rule]);
      final selected = set.selectHardware(_hardwareContext());
      expect(selected, same(rule));
    });

    test('prefers the rule with more conditions (specificity)', () {
      final bare = hardwareRule(description: 'bare');
      final specific = hardwareRule(
        description: 'specific',
        conditions: const [
          OpeningTypeCondition(OpeningType.francaise),
          VantauxCountCondition(1),
        ],
      );
      final set = ruleSet([bare, specific]);
      final selected = set.selectHardware(_hardwareContext());
      expect(selected, same(specific));
    });

    test('throws AmbiguousHardwareRuleMatchException on a tie', () {
      final a = hardwareRule(
        conditions: const [OpeningTypeCondition(OpeningType.francaise)],
        description: 'a',
      );
      final b = hardwareRule(
        conditions: const [VantauxCountCondition(1)],
        description: 'b',
      );
      final set = ruleSet([a, b]);
      expect(
        () => set.selectHardware(_hardwareContext()),
        throwsA(isA<AmbiguousHardwareRuleMatchException>()),
      );
    });
  });

  group('CalculationOutcome.hardware default', () {
    test('defaults to const [] so existing consumers compile', () {
      const outcome = CalculationOutcome(cuts: []);
      expect(outcome.hardware, isEmpty);
      expect(outcome.hardwareIssues, isEmpty);
    });

    test('isEmpty accounts for hardware + hardwareIssues', () {
      const empty = CalculationOutcome(cuts: []);
      expect(empty.isEmpty, isTrue);

      const withIssue = CalculationOutcome(
        cuts: [],
        hardwareIssues: [
          SectionHardwareIssue(
            sectionId: 's1',
            reason: SectionHardwareIssueReason.noRuleMatched,
          ),
        ],
      );
      expect(withIssue.isEmpty, isFalse);
    });
  });

  group('SectionHardwareIssue model', () {
    test('carries section id and reason', () {
      const issue = SectionHardwareIssue(
        sectionId: 's1',
        reason: SectionHardwareIssueReason.dominantOuvrantUnresolved,
      );
      expect(issue.sectionId, 's1');
      expect(
        issue.reason,
        SectionHardwareIssueReason.dominantOuvrantUnresolved,
      );
    });
  });

  group('SystemRuleSet backward-compat (existing tests still compile)',
      () {
    test('hardwareRules defaults to const [] when omitted', () {
      final set = SystemRuleSet(
        systemId: 't',
        name: 't',
        isPlaceholder: true,
        rules: const [],
      );
      expect(set.hardwareRules, isEmpty);
    });
  });
}
