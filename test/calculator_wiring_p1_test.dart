import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/engine/construction_calculator.dart';
import 'package:aluminium_designer/core/models/calculation_outcome.dart';
import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/hardware_item.dart';
import 'package:aluminium_designer/core/models/layout_direction.dart';
import 'package:aluminium_designer/core/models/opening.dart';
import 'package:aluminium_designer/core/models/profile.dart';
import 'package:aluminium_designer/core/models/profile_usage.dart';
import 'package:aluminium_designer/core/models/rules/dimension_expression.dart';
import 'package:aluminium_designer/core/models/rules/glass_calculation_rule.dart';
import 'package:aluminium_designer/core/models/rules/hardware_calculation_rule.dart';
import 'package:aluminium_designer/core/models/rules/rule_condition.dart';
import 'package:aluminium_designer/core/models/rules/system_rule_set.dart';
import 'package:aluminium_designer/core/models/section.dart';

/// P1 commit 4: calculator wiring for glass + hardware. The actual ME
/// 14800 data lands in commit 5; this file proves the wiring works
/// end-to-end with a tiny synthetic rule set + the existing
/// ConstructionCalculator.calculate pipeline. All previous test
/// suites (475 → 536 → 611 tests) stay green because the new result
/// fields default to `const []` and the profile loop is byte-
/// identical to its pre-P1 form.
Profile _ouvrant(String id) => Profile(
  id: id,
  manufacturer: 'M',
  system: 'S',
  reference: id,
  name: 'Ouvrant $id',
  type: ProfileType.ouvrant,
  width: 50,
  depth: 40,
  weightPerMeter: 0,
);

Section _ouvrantSection(String id,
        {double width = 2000, double height = 1500, int vantauxCount = 1}) =>
    Section(
      id: id,
      order: 0,
      kind: SectionKind.ouvrant,
      width: width,
      height: height,
      openingType: OpeningType.francaise,
      vantauxCount: vantauxCount,
    );

Section _fixedSection(String id) => Section(
      id: id,
      order: 1,
      kind: SectionKind.fixed,
      width: 1000,
      height: 1500,
      // Fixed: no openingType, no vantaux.
    );

ProfileUsage _stile(String id, String sectionId, Profile profile) =>
    ProfileUsage(
      id: id,
      profileId: profile.id,
      sectionId: sectionId,
      role: ProfileUsageRole.left,
    );

SystemRuleSet _ruleSet({
  List<GlassCalculationRule> glassRules = const [],
  List<HardwareCalculationRule> hardwareRules = const [],
}) =>
    SystemRuleSet(
      systemId: 'test',
      name: 'test',
      isPlaceholder: false,
      rules: const [],
      glassRules: glassRules,
      hardwareRules: hardwareRules,
    );

void main() {
  group('ConstructionCalculator wiring: glass', () {
    test('opening section with a glass rule produces one GlassItem', () {
      final ouv = _ouvrant('p-glass');
      final glassRule = GlassCalculationRule(
        conditions: const [
          OpeningTypeCondition(OpeningType.francaise),
          VantauxCountCondition(1),
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
        glazingType: 'Simple vitrage',
        glazingThicknessMm: 6,
        isPlaceholder: false,
        description: 'glass-test',
      );
      final set = _ruleSet(glassRules: [glassRule]);
      final calc = ConstructionCalculator(ruleSet: set);

      final construction = Construction(
        id: 'c',
        name: 'c',
        type: ConstructionType.window,
        width: 2000,
        height: 1500,
        manufacturer: 'M',
        system: 'S',
        systemId: 'test',
        sections: [_ouvrantSection('s1')],
        layoutDirection: SectionLayoutDirection.horizontal,
        profiles: const [],
        profileUsages: [
          _stile('u1', 's1', ouv),
        ],
      );

      final outcome = calc.calculate(
        construction,
        profilesById: {ouv.id: ouv},
      );

      expect(outcome.glass, hasLength(1));
      expect(outcome.glass.first.profileReference, 'p-glass');
      expect(outcome.glass.first.widthMm, 2000 - 132);
      expect(outcome.glass.first.heightMm, 1500 - 132);
      expect(outcome.glass.first.quantity, 1);
      expect(outcome.glass.first.glazingType, 'Simple vitrage');
      expect(outcome.glass.first.glazingThicknessMm, 6);
      expect(outcome.glass.first.sectionId, 's1');
      expect(outcome.glassIssues, isEmpty);
    });

    test('opening section with no glass rule produces a noRuleMatched '
        'issue (not a crash)', () {
      final ouv = _ouvrant('p-glass');
      final calc = ConstructionCalculator(
        ruleSet: _ruleSet(), // no glass rules
      );
      final construction = Construction(
        id: 'c',
        name: 'c',
        type: ConstructionType.window,
        width: 2000,
        height: 1500,
        manufacturer: 'M',
        system: 'S',
        systemId: 'test',
        sections: [_ouvrantSection('s1')],
        layoutDirection: SectionLayoutDirection.horizontal,
        profiles: const [],
        profileUsages: [_stile('u1', 's1', ouv)],
      );
      final outcome = calc.calculate(
        construction,
        profilesById: {ouv.id: ouv},
      );
      expect(outcome.glass, isEmpty);
      expect(outcome.glassIssues, hasLength(1));
      expect(outcome.glassIssues.first.sectionId, 's1');
      expect(
        outcome.glassIssues.first.reason,
        SectionGlassIssueReason.noRuleMatched,
      );
    });

    test('opening section with NO sash carrier (no profileUsage) produces '
        'a dominantOuvrantUnresolved issue', () {
      final calc = ConstructionCalculator(ruleSet: _ruleSet());
      final construction = Construction(
        id: 'c',
        name: 'c',
        type: ConstructionType.window,
        width: 2000,
        height: 1500,
        manufacturer: 'M',
        system: 'S',
        systemId: 'test',
        sections: [_ouvrantSection('s1')],
        layoutDirection: SectionLayoutDirection.horizontal,
        profiles: const [],
        // Note: no profileUsages -- the section has no sash.
        profileUsages: const [],
      );
      final outcome = calc.calculate(construction);
      expect(outcome.glass, isEmpty);
      expect(outcome.glassIssues, hasLength(1));
      expect(
        outcome.glassIssues.first.reason,
        SectionGlassIssueReason.dominantOuvrantUnresolved,
      );
    });

    test('fixed sections are skipped (no glass)', () {
      final calc = ConstructionCalculator(ruleSet: _ruleSet());
      final construction = Construction(
        id: 'c',
        name: 'c',
        type: ConstructionType.window,
        width: 2000,
        height: 1500,
        manufacturer: 'M',
        system: 'S',
        systemId: 'test',
        sections: [_fixedSection('s1')],
        layoutDirection: SectionLayoutDirection.horizontal,
        profiles: const [],
        profileUsages: const [],
      );
      final outcome = calc.calculate(construction);
      expect(outcome.glass, isEmpty);
      // No glass issues either: fixed sections are skipped BEFORE
      // the diagnostic path, so they produce no entries at all (no
      // false "missing glass" noise for sections that aren't supposed
      // to have glass).
      expect(outcome.glassIssues, isEmpty);
    });
  });

  group('ConstructionCalculator wiring: hardware', () {
    test('opening section with a count-only hardware rule produces one '
        'HardwareItem with no lengthMm', () {
      final ouv = _ouvrant('p-hw');
      final hardwareRule = HardwareCalculationRule(
        conditions: const [
          OpeningTypeCondition(OpeningType.francaise),
          VantauxCountCondition(1),
        ],
        quantity: 8,
        reference: 'AC-600',
        name: 'Équerre à pions',
        category: HardwareCategory.hardware,
        isPlaceholder: false,
        description: 'hw-test',
      );
      final calc = ConstructionCalculator(
        ruleSet: _ruleSet(hardwareRules: [hardwareRule]),
      );
      final construction = Construction(
        id: 'c',
        name: 'c',
        type: ConstructionType.window,
        width: 2000,
        height: 1500,
        manufacturer: 'M',
        system: 'S',
        systemId: 'test',
        sections: [_ouvrantSection('s1')],
        layoutDirection: SectionLayoutDirection.horizontal,
        profiles: const [],
        profileUsages: [_stile('u1', 's1', ouv)],
      );
      final outcome = calc.calculate(
        construction,
        profilesById: {ouv.id: ouv},
      );
      expect(outcome.hardware, hasLength(1));
      expect(outcome.hardware.first.reference, 'AC-600');
      expect(outcome.hardware.first.category, HardwareCategory.hardware);
      expect(outcome.hardware.first.quantity, 8);
      expect(outcome.hardware.first.lengthMm, isNull);
      expect(outcome.hardware.first.sectionId, 's1');
      expect(outcome.hardwareIssues, isEmpty);
    });

    test('opening section with a length-bearing hardware rule evaluates '
        'the length expression', () {
      final ouv = _ouvrant('p-hw');
      final hardwareRule = HardwareCalculationRule(
        conditions: const [OpeningTypeCondition(OpeningType.francaise)],
        quantity: 1,
        lengthExpression: BinaryExpression(
          left: BinaryExpression(
            left: DimensionExpression.variable(
              DimensionVariable.constructionWidth,
            ),
            operator: BinaryOperator.multiply,
            right: DimensionExpression.constant(2.0),
          ),
          operator: BinaryOperator.add,
          right: BinaryExpression(
            left: DimensionExpression.variable(
              DimensionVariable.constructionHeight,
            ),
            operator: BinaryOperator.multiply,
            right: DimensionExpression.constant(2.0),
          ),
        ),
        reference: 'JO-826',
        name: 'Joint de battue',
        category: HardwareCategory.accessory,
        isPlaceholder: false,
      );
      final calc = ConstructionCalculator(
        ruleSet: _ruleSet(hardwareRules: [hardwareRule]),
      );
      final construction = Construction(
        id: 'c',
        name: 'c',
        type: ConstructionType.window,
        width: 2000,
        height: 1500,
        manufacturer: 'M',
        system: 'S',
        systemId: 'test',
        sections: [_ouvrantSection('s1')],
        layoutDirection: SectionLayoutDirection.horizontal,
        profiles: const [],
        profileUsages: [_stile('u1', 's1', ouv)],
      );
      final outcome = calc.calculate(
        construction,
        profilesById: {ouv.id: ouv},
      );
      expect(outcome.hardware, hasLength(1));
      // 2L + 2H = 2*2000 + 2*1500 = 7000
      expect(outcome.hardware.first.lengthMm, 7000.0);
      expect(outcome.hardware.first.category, HardwareCategory.accessory);
    });
  });

  group('ConstructionCalculator wiring: edge-case diagnostics', () {
    test('mixed-sash section (two distinct ouvrant refs) produces a '
        'mixedSashCarrier diagnostic, not a silently-mapped item', () {
      // Two distinct ProfileType.ouvrant refs in the same section.
      // C8's CompanionProfileReferenceCondition (universal quantifier)
      // fails closed on this state for the profile side; the glass /
      // hardware wiring must mirror that contract so the same
      // construction doesn't report contradictory diagnostics across
      // domains.
      final ouvA = _ouvrant('p-14.802');
      final ouvB = _ouvrant('p-14.805');
      final glassRule = GlassCalculationRule(
        conditions: const [OpeningTypeCondition(OpeningType.francaise)],
        widthExpression: DimensionExpression.constant(1000.0),
        heightExpression: DimensionExpression.constant(1000.0),
        quantity: 1,
        isPlaceholder: false,
      );
      final calc = ConstructionCalculator(
        ruleSet: _ruleSet(glassRules: [glassRule]),
      );
      final construction = Construction(
        id: 'c',
        name: 'c',
        type: ConstructionType.window,
        width: 2000,
        height: 1500,
        manufacturer: 'M',
        system: 'S',
        systemId: 'test',
        sections: [_ouvrantSection('s1')],
        layoutDirection: SectionLayoutDirection.horizontal,
        profiles: const [],
        profileUsages: [
          _stile('u-a', 's1', ouvA),
          _stile('u-b', 's1', ouvB),
        ],
      );
      final outcome = calc.calculate(
        construction,
        profilesById: {ouvA.id: ouvA, ouvB.id: ouvB},
      );
      // Honest diagnostic, not a fabricated item.
      expect(outcome.glass, isEmpty);
      expect(outcome.hardware, isEmpty);
      expect(outcome.glassIssues, hasLength(1));
      expect(
        outcome.glassIssues.single.reason,
        SectionGlassIssueReason.mixedSashCarrier,
      );
      expect(outcome.hardwareIssues, hasLength(1));
      expect(
        outcome.hardwareIssues.single.reason,
        SectionHardwareIssueReason.mixedSashCarrier,
      );
    });

    test('glass-rule ambiguity (two equal-specificity rules) is caught '
        'and reported as noRuleMatched, not an uncaught exception', () {
      // Both rules have ONE condition each (equal specificity); the
      // selector throws AmbiguousGlassRuleMatchException. The wiring
      // must catch it and report a diagnostic so the rest of the run
      // continues -- a future refactor that removes the local catch
      // would otherwise propagate the exception to the editor and
      // crash (the editor controller only catches the profile-side
      // AmbiguousRuleMatchException, not the glass/hardware ones).
      final ouv = _ouvrant('p-amb');
      final rule1 = GlassCalculationRule(
        conditions: const [OpeningTypeCondition(OpeningType.francaise)],
        widthExpression: DimensionExpression.constant(1000.0),
        heightExpression: DimensionExpression.constant(1000.0),
        quantity: 1,
        isPlaceholder: false,
        description: 'rule-1',
      );
      final rule2 = GlassCalculationRule(
        conditions: const [VantauxCountCondition(1)],
        widthExpression: DimensionExpression.constant(1000.0),
        heightExpression: DimensionExpression.constant(1000.0),
        quantity: 1,
        isPlaceholder: false,
        description: 'rule-2',
      );
      final calc = ConstructionCalculator(
        ruleSet: _ruleSet(glassRules: [rule1, rule2]),
      );
      final construction = Construction(
        id: 'c',
        name: 'c',
        type: ConstructionType.window,
        width: 2000,
        height: 1500,
        manufacturer: 'M',
        system: 'S',
        systemId: 'test',
        sections: [_ouvrantSection('s1')],
        layoutDirection: SectionLayoutDirection.horizontal,
        profiles: const [],
        profileUsages: [_stile('u1', 's1', ouv)],
      );
      final outcome = calc.calculate(
        construction,
        profilesById: {ouv.id: ouv},
      );
      expect(outcome.glass, isEmpty);
      expect(outcome.glassIssues, hasLength(1));
      expect(
        outcome.glassIssues.single.reason,
        SectionGlassIssueReason.noRuleMatched,
      );
    });

    test('hardware: all matching rules apply (per-section "all matches" '
        'semantics, no ambiguity)', () {
      // Hardware is NOT a per-usage "most-specific rule" selector
      // (that's the profile-side contract). It is a per-section
      // "all matching rules apply" selector, because the source's
      // ACCESSOIRES model lists multiple items that share the same
      // gating conditions (e.g. ME 14800 p. 65's 11 items all gated
      // on vantaux 1 + française). This test pins that contract: two
      // rules with the SAME matched conditions both apply, and the
      // calculator emits one hardware item per matching rule.
      final ouv = _ouvrant('p-all-h');
      final rule1 = HardwareCalculationRule(
        conditions: const [VantauxCountCondition(1)],
        quantity: 1,
        reference: 'A',
        name: 'A',
        category: HardwareCategory.hardware,
        isPlaceholder: false,
      );
      final rule2 = HardwareCalculationRule(
        conditions: const [VantauxCountCondition(1)],
        quantity: 1,
        reference: 'B',
        name: 'B',
        category: HardwareCategory.hardware,
        isPlaceholder: false,
      );
      final calc = ConstructionCalculator(
        ruleSet: _ruleSet(hardwareRules: [rule1, rule2]),
      );
      final construction = Construction(
        id: 'c',
        name: 'c',
        type: ConstructionType.window,
        width: 2000,
        height: 1500,
        manufacturer: 'M',
        system: 'S',
        systemId: 'test',
        sections: [_ouvrantSection('s1')],
        layoutDirection: SectionLayoutDirection.horizontal,
        profiles: const [],
        profileUsages: [_stile('u1', 's1', ouv)],
      );
      final outcome = calc.calculate(
        construction,
        profilesById: {ouv.id: ouv},
      );
      expect(outcome.hardware, hasLength(2));
      expect(outcome.hardwareIssues, isEmpty);
    });
  });

  group('ConstructionCalculator wiring: existing profile path is '
      'byte-identical', () {
    test('a construction with no glass/hardware rules still produces the '
        'same cuts and the same issues as before P1', () {
      final ouv = _ouvrant('p-c');
      final calc = ConstructionCalculator(
        ruleSet: SystemRuleSet(
          systemId: 'test',
          name: 'test',
          isPlaceholder: false,
          rules: const [],
        ),
      );
      final construction = Construction(
        id: 'c',
        name: 'c',
        type: ConstructionType.window,
        width: 2000,
        height: 1500,
        manufacturer: 'M',
        system: 'S',
        systemId: 'test',
        sections: [_ouvrantSection('s1')],
        layoutDirection: SectionLayoutDirection.horizontal,
        profiles: const [],
        profileUsages: [_stile('u1', 's1', ouv)],
      );
      final outcome = calc.calculate(
        construction,
        profilesById: {ouv.id: ouv},
      );
      // No profile rules either: the profile usage produces a
      // noRuleMatched issue (existing pre-P1 behavior, unchanged).
      // The new wiring: glass and hardware evaluation runs per
      // section; with no glass/hardware rules in the set, those
      // sections produce noRuleMatched diagnostics. The pre-P1
      // contract was that "everything else" stays as it was -- and
      // the only new observable difference is the EXTRA diagnostics
      // the new domains contribute. This test pins both invariants.
      expect(outcome.cuts, isEmpty);
      expect(outcome.issues, hasLength(1));
      expect(
        outcome.issues.single.reason,
        ProfileUsageIssueReason.noRuleMatched,
      );
      expect(outcome.glass, isEmpty);
      expect(outcome.hardware, isEmpty);
      // The opening section produced diagnostics (no glass rule, no
      // hardware rule in the synthetic empty set).
      expect(outcome.glassIssues, hasLength(1));
      expect(
        outcome.glassIssues.single.reason,
        SectionGlassIssueReason.noRuleMatched,
      );
      expect(outcome.hardwareIssues, hasLength(1));
      expect(
        outcome.hardwareIssues.single.reason,
        SectionHardwareIssueReason.noRuleMatched,
      );
      expect(outcome.isEmpty, isFalse);
    });
  });
}
