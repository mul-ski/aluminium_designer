import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/engine/construction_calculator.dart';
import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/layout_direction.dart';
import 'package:aluminium_designer/core/models/opening.dart';
import 'package:aluminium_designer/core/models/profile.dart';
import 'package:aluminium_designer/core/models/profile_usage.dart';
import 'package:aluminium_designer/core/models/rules/calculation_rule.dart';
import 'package:aluminium_designer/core/models/rules/dimension_expression.dart';
import 'package:aluminium_designer/core/models/rules/generic_placeholder_rules.dart';
import 'package:aluminium_designer/core/models/rules/rule_condition.dart';
import 'package:aluminium_designer/core/models/rules/system_rule_set.dart';
import 'package:aluminium_designer/core/models/section.dart';

Profile _profile(String id, {ProfileType type = ProfileType.montant}) =>
    Profile(
      id: id,
      manufacturer: 'Test Manufacturer',
      system: 'Test System',
      reference: id,
      name: 'Profile $id',
      type: type,
      width: 40,
      depth: 60,
      weightPerMeter: 1.2,
    );

Section _section(
  String id, {
  int order = 0,
  SectionKind kind = SectionKind.fixed,
  double width = 1000,
  double height = 1200,
  OpeningType? openingType,
  int vantauxCount = 0,
}) => Section(
  id: id,
  order: order,
  kind: kind,
  width: width,
  height: height,
  openingType: openingType,
  vantauxCount: vantauxCount,
);

ProfileUsage _usage(
  String id, {
  required String profileId,
  required String sectionId,
  ProfileUsageRole role = ProfileUsageRole.left,
}) => ProfileUsage(
  id: id,
  profileId: profileId,
  sectionId: sectionId,
  role: role,
);

Construction _construction({
  double? width = 1000,
  double? height = 1200,
  List<Section> sections = const [],
  List<ProfileUsage> profileUsages = const [],
}) => Construction(
  id: 'c1',
  name: 'Test Construction',
  type: ConstructionType.window,
  width: width,
  height: height,
  manufacturer: 'Test Manufacturer',
  system: 'Test System',
  sections: sections,
  layoutDirection: SectionLayoutDirection.horizontal,
  profiles: const [],
  profileUsages: profileUsages,
);

void main() {
  group('CalculationContext role-awareness', () {
    test('usage is null by default', () {
      final context = CalculationContext(
        construction: _construction(),
        profile: _profile('P1'),
      );
      expect(context.usage, isNull);
    });

    test('carries the supplied usage', () {
      final usage = _usage('u1', profileId: 'P1', sectionId: 's1');
      final context = CalculationContext(
        construction: _construction(),
        profile: _profile('P1'),
        usage: usage,
      );
      expect(context.usage, same(usage));
    });
  });

  group('ProfileUsageRoleCondition', () {
    test('matches when usage role equals the condition role', () {
      const condition = ProfileUsageRoleCondition(ProfileUsageRole.left);
      final context = CalculationContext(
        construction: _construction(),
        profile: _profile('P1'),
        usage: _usage(
          'u1',
          profileId: 'P1',
          sectionId: 's1',
          role: ProfileUsageRole.left,
        ),
      );
      expect(condition.matches(context), isTrue);
    });

    test('does not match when usage role differs', () {
      const condition = ProfileUsageRoleCondition(ProfileUsageRole.left);
      final context = CalculationContext(
        construction: _construction(),
        profile: _profile('P1'),
        usage: _usage(
          'u1',
          profileId: 'P1',
          sectionId: 's1',
          role: ProfileUsageRole.right,
        ),
      );
      expect(condition.matches(context), isFalse);
    });

    test('fails safely (does not match) when usage is null', () {
      const condition = ProfileUsageRoleCondition(ProfileUsageRole.left);
      final context = CalculationContext(
        construction: _construction(),
        profile: _profile('P1'),
      );
      expect(condition.matches(context), isFalse);
    });
  });

  group('ProfileCalculationRule.matches with role + section conditions', () {
    test('matches only the section/role combination it targets', () {
      final rule = ProfileCalculationRule(
        appliesTo: ProfileType.montant,
        conditions: const [
          SectionKindCondition(SectionKind.ouvrant),
          ProfileUsageRoleCondition(ProfileUsageRole.left),
        ],
        lengthExpression: const DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        quantity: const CutQuantity.fixed(1),
        angles: const CutAngles.mitred45(),
        isPlaceholder: true,
      );

      final ouvrantSection = _section(
        's1',
        kind: SectionKind.ouvrant,
        openingType: OpeningType.francaise,
        vantauxCount: 1,
      );
      final fixedSection = _section('s2');

      final matchingContext = CalculationContext(
        construction: _construction(),
        profile: _profile('P1'),
        section: ouvrantSection,
        usage: _usage(
          'u1',
          profileId: 'P1',
          sectionId: 's1',
          role: ProfileUsageRole.left,
        ),
      );
      expect(rule.matches(matchingContext), isTrue);

      final wrongRoleContext = CalculationContext(
        construction: _construction(),
        profile: _profile('P1'),
        section: ouvrantSection,
        usage: _usage(
          'u2',
          profileId: 'P1',
          sectionId: 's1',
          role: ProfileUsageRole.right,
        ),
      );
      expect(rule.matches(wrongRoleContext), isFalse);

      final wrongSectionContext = CalculationContext(
        construction: _construction(),
        profile: _profile('P1'),
        section: fixedSection,
        usage: _usage(
          'u3',
          profileId: 'P1',
          sectionId: 's2',
          role: ProfileUsageRole.left,
        ),
      );
      expect(rule.matches(wrongSectionContext), isFalse);
    });
  });

  group('SystemRuleSet.select', () {
    test('returns null when zero rules match', () {
      const ruleSet = SystemRuleSet(
        systemId: 'sys',
        name: 'Test',
        isPlaceholder: true,
        rules: [],
      );
      final context = CalculationContext(
        construction: _construction(),
        profile: _profile('P1'),
      );
      expect(ruleSet.select(context), isNull);
    });

    test('returns the single matching rule', () {
      const rule = ProfileCalculationRule(
        appliesTo: ProfileType.montant,
        lengthExpression: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        quantity: CutQuantity.fixed(2),
        angles: CutAngles.mitred45(),
        isPlaceholder: true,
      );
      const ruleSet = SystemRuleSet(
        systemId: 'sys',
        name: 'Test',
        isPlaceholder: true,
        rules: [rule],
      );
      final context = CalculationContext(
        construction: _construction(),
        profile: _profile('P1'),
      );
      expect(ruleSet.select(context), same(rule));
    });

    test('resolves ambiguity by preferring the more specific rule', () {
      const generalRule = ProfileCalculationRule(
        appliesTo: ProfileType.montant,
        lengthExpression: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        quantity: CutQuantity.fixed(2),
        angles: CutAngles.mitred45(),
        isPlaceholder: true,
        description: 'general',
      );
      const specificRule = ProfileCalculationRule(
        appliesTo: ProfileType.montant,
        conditions: [ProfileUsageRoleCondition(ProfileUsageRole.left)],
        lengthExpression: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        quantity: CutQuantity.fixed(1),
        angles: CutAngles.mitred45(),
        isPlaceholder: true,
        description: 'specific',
      );
      const ruleSet = SystemRuleSet(
        systemId: 'sys',
        name: 'Test',
        isPlaceholder: true,
        rules: [generalRule, specificRule],
      );
      final context = CalculationContext(
        construction: _construction(),
        profile: _profile('P1'),
        usage: _usage(
          'u1',
          profileId: 'P1',
          sectionId: 's1',
          role: ProfileUsageRole.left,
        ),
      );
      expect(ruleSet.select(context), same(specificRule));
    });

    test('throws AmbiguousRuleMatchException on a genuine tie', () {
      const ruleA = ProfileCalculationRule(
        appliesTo: ProfileType.montant,
        lengthExpression: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        quantity: CutQuantity.fixed(1),
        angles: CutAngles.mitred45(),
        isPlaceholder: true,
        description: 'A',
      );
      const ruleB = ProfileCalculationRule(
        appliesTo: ProfileType.montant,
        lengthExpression: DimensionExpression.variable(
          DimensionVariable.constructionWidth,
        ),
        quantity: CutQuantity.fixed(1),
        angles: CutAngles.square(),
        isPlaceholder: true,
        description: 'B',
      );
      const ruleSet = SystemRuleSet(
        systemId: 'sys',
        name: 'Test',
        isPlaceholder: true,
        rules: [ruleA, ruleB],
      );
      final context = CalculationContext(
        construction: _construction(),
        profile: _profile('P1'),
      );
      expect(
        () => ruleSet.select(context),
        throwsA(isA<AmbiguousRuleMatchException>()),
      );
    });
  });

  group('DimensionExpression evaluation', () {
    test('evaluates a variable reference', () {
      const expr = DimensionExpression.variable(
        DimensionVariable.constructionHeight,
      );
      expect(expr.evaluate({DimensionVariable.constructionHeight: 1200}), 1200);
    });

    test('evaluates a binary expression', () {
      const expr = BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(90),
      );
      expect(expr.evaluate({DimensionVariable.constructionHeight: 1200}), 1110);
    });

    test('throws when a required variable is missing', () {
      const expr = DimensionExpression.variable(
        DimensionVariable.constructionWidth,
      );
      expect(
        () => expr.evaluate({DimensionVariable.constructionHeight: 1200}),
        throwsStateError,
      );
    });
  });

  group('ConstructionCalculator.calculate', () {
    test('throws StateError when width/height are missing', () {
      const calculator = ConstructionCalculator();
      final construction = _construction(width: null, height: null);
      expect(() => calculator.calculate(construction), throwsStateError);
    });

    test(
      'produces cuts for role-aware usages via the placeholder rule set',
      () {
        const calculator = ConstructionCalculator(
          ruleSet: genericPlaceholderRuleSet,
        );
        final section = _section('s1');
        final montant = _profile('M1', type: ProfileType.montant);
        final traverse = _profile('T1', type: ProfileType.traverse);
        final construction = _construction(
          width: 1000,
          height: 1200,
          sections: [section],
          profileUsages: [
            _usage(
              'u1',
              profileId: 'M1',
              sectionId: 's1',
              role: ProfileUsageRole.left,
            ),
            _usage(
              'u2',
              profileId: 'T1',
              sectionId: 's1',
              role: ProfileUsageRole.top,
            ),
          ],
        );

        final cuts = calculator.calculate(
          construction,
          profilesById: {'M1': montant, 'T1': traverse},
        );

        expect(cuts.length, 2);
        expect(cuts[0].profile.id, 'M1');
        expect(cuts[0].length, 1200);
        expect(cuts[1].profile.id, 'T1');
        expect(cuts[1].length, 1000);
      },
    );

    test('skips a usage whose profile cannot be resolved', () {
      const calculator = ConstructionCalculator();
      final construction = _construction(
        sections: [_section('s1')],
        profileUsages: [_usage('u1', profileId: 'missing', sectionId: 's1')],
      );

      final cuts = calculator.calculate(construction, profilesById: const {});

      expect(cuts, isEmpty);
    });

    test('skips a usage when no rule matches', () {
      const emptyRuleSet = SystemRuleSet(
        systemId: 'sys',
        name: 'Empty',
        isPlaceholder: true,
        rules: [],
      );
      const calculator = ConstructionCalculator(ruleSet: emptyRuleSet);
      final profile = _profile('M1');
      final construction = _construction(
        sections: [_section('s1')],
        profileUsages: [_usage('u1', profileId: 'M1', sectionId: 's1')],
      );

      final cuts = calculator.calculate(
        construction,
        profilesById: {'M1': profile},
      );

      expect(cuts, isEmpty);
    });

    test('propagates AmbiguousRuleMatchException from rule selection', () {
      const ruleA = ProfileCalculationRule(
        appliesTo: ProfileType.montant,
        lengthExpression: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        quantity: CutQuantity.fixed(1),
        angles: CutAngles.mitred45(),
        isPlaceholder: true,
        description: 'A',
      );
      const ruleB = ProfileCalculationRule(
        appliesTo: ProfileType.montant,
        lengthExpression: DimensionExpression.variable(
          DimensionVariable.constructionWidth,
        ),
        quantity: CutQuantity.fixed(1),
        angles: CutAngles.square(),
        isPlaceholder: true,
        description: 'B',
      );
      const ambiguousRuleSet = SystemRuleSet(
        systemId: 'sys',
        name: 'Ambiguous',
        isPlaceholder: true,
        rules: [ruleA, ruleB],
      );
      const calculator = ConstructionCalculator(ruleSet: ambiguousRuleSet);
      final profile = _profile('M1');
      final construction = _construction(
        sections: [_section('s1')],
        profileUsages: [_usage('u1', profileId: 'M1', sectionId: 's1')],
      );

      expect(
        () => calculator.calculate(construction, profilesById: {'M1': profile}),
        throwsA(isA<AmbiguousRuleMatchException>()),
      );
    });

    test('builds a context with section: null for an unresolved sectionId', () {
      const roleOnlyRuleSet = SystemRuleSet(
        systemId: 'sys',
        name: 'Role only',
        isPlaceholder: true,
        rules: [
          ProfileCalculationRule(
            appliesTo: ProfileType.montant,
            conditions: [ProfileUsageRoleCondition(ProfileUsageRole.left)],
            lengthExpression: DimensionExpression.variable(
              DimensionVariable.constructionHeight,
            ),
            quantity: CutQuantity.fixed(1),
            angles: CutAngles.mitred45(),
            isPlaceholder: true,
          ),
        ],
      );
      const calculator = ConstructionCalculator(ruleSet: roleOnlyRuleSet);
      final profile = _profile('M1');
      // No sections at all -- usage references a sectionId that doesn't
      // resolve to any Section in the construction.
      final construction = _construction(
        sections: const [],
        profileUsages: [
          _usage(
            'u1',
            profileId: 'M1',
            sectionId: 'ghost-section',
            role: ProfileUsageRole.left,
          ),
        ],
      );

      final cuts = calculator.calculate(
        construction,
        profilesById: {'M1': profile},
      );

      // Role condition still matches (usage is present) even though the
      // section itself couldn't be resolved.
      expect(cuts.length, 1);
    });

    group('openingWidth/openingHeight variables', () {
      test('openingHeight is usable end-to-end in a real calculation', () {
        // Section geometry deliberately differs from the construction's
        // overall width/height, so a passing result proves the value came
        // from the section, not from constructionWidth/constructionHeight.
        const openingOnlyRuleSet = SystemRuleSet(
          systemId: 'sys',
          name: 'Opening height rule',
          isPlaceholder: true,
          rules: [
            ProfileCalculationRule(
              appliesTo: ProfileType.montant,
              lengthExpression: DimensionExpression.variable(
                DimensionVariable.openingHeight,
              ),
              quantity: CutQuantity.fixed(1),
              angles: CutAngles.mitred45(),
              isPlaceholder: true,
            ),
          ],
        );
        const calculator = ConstructionCalculator(ruleSet: openingOnlyRuleSet);
        final profile = _profile('M1');
        final section = _section('s1', width: 500, height: 850);
        final construction = _construction(
          width: 1000,
          height: 1200,
          sections: [section],
          profileUsages: [_usage('u1', profileId: 'M1', sectionId: 's1')],
        );

        final cuts = calculator.calculate(
          construction,
          profilesById: {'M1': profile},
        );

        expect(cuts.length, 1);
        expect(cuts[0].length, 850);
      });

      test('openingWidth is usable end-to-end in a real calculation', () {
        const openingOnlyRuleSet = SystemRuleSet(
          systemId: 'sys',
          name: 'Opening width rule',
          isPlaceholder: true,
          rules: [
            ProfileCalculationRule(
              appliesTo: ProfileType.traverse,
              lengthExpression: DimensionExpression.variable(
                DimensionVariable.openingWidth,
              ),
              quantity: CutQuantity.fixed(1),
              angles: CutAngles.square(),
              isPlaceholder: true,
            ),
          ],
        );
        const calculator = ConstructionCalculator(ruleSet: openingOnlyRuleSet);
        final profile = _profile('T1', type: ProfileType.traverse);
        final section = _section('s1', width: 640, height: 900);
        final construction = _construction(
          width: 1000,
          height: 1200,
          sections: [section],
          profileUsages: [_usage('u1', profileId: 'T1', sectionId: 's1')],
        );

        final cuts = calculator.calculate(
          construction,
          profilesById: {'T1': profile},
        );

        expect(cuts.length, 1);
        expect(cuts[0].length, 640);
      });

      test('a rule combining opening and construction variables evaluates '
          'both from their correct sources', () {
        // height - 2 * (constructionHeight - openingHeight) is a
        // deliberately synthetic (non-manufacturer) expression whose
        // only purpose is proving both variable sources resolve
        // correctly together in one expression, per usage.
        const combinedRuleSet = SystemRuleSet(
          systemId: 'sys',
          name: 'Combined rule',
          isPlaceholder: true,
          rules: [
            ProfileCalculationRule(
              appliesTo: ProfileType.montant,
              lengthExpression: BinaryExpression(
                left: DimensionExpression.variable(
                  DimensionVariable.openingWidth,
                ),
                operator: BinaryOperator.subtract,
                right: DimensionExpression.variable(
                  DimensionVariable.constructionWidth,
                ),
              ),
              quantity: CutQuantity.fixed(1),
              angles: CutAngles.mitred45(),
              isPlaceholder: true,
            ),
          ],
        );
        const calculator = ConstructionCalculator(ruleSet: combinedRuleSet);
        final profile = _profile('M1');
        final section = _section('s1', width: 300, height: 1200);
        final construction = _construction(
          width: 1000,
          height: 1200,
          sections: [section],
          profileUsages: [_usage('u1', profileId: 'M1', sectionId: 's1')],
        );

        final cuts = calculator.calculate(
          construction,
          profilesById: {'M1': profile},
        );

        expect(cuts.length, 1);
        // openingWidth (300) - constructionWidth (1000) = -700
        expect(cuts[0].length, -700);
      });

      test('throws StateError when a rule references openingWidth but the '
          "usage's section did not resolve", () {
        const openingOnlyRuleSet = SystemRuleSet(
          systemId: 'sys',
          name: 'Opening width rule',
          isPlaceholder: true,
          rules: [
            ProfileCalculationRule(
              appliesTo: ProfileType.montant,
              lengthExpression: DimensionExpression.variable(
                DimensionVariable.openingWidth,
              ),
              quantity: CutQuantity.fixed(1),
              angles: CutAngles.mitred45(),
              isPlaceholder: true,
            ),
          ],
        );
        const calculator = ConstructionCalculator(ruleSet: openingOnlyRuleSet);
        final profile = _profile('M1');
        // No sections at all -- usage's sectionId doesn't resolve, so
        // openingWidth can never be populated for this usage.
        final construction = _construction(
          width: 1000,
          height: 1200,
          sections: const [],
          profileUsages: [
            _usage('u1', profileId: 'M1', sectionId: 'ghost-section'),
          ],
        );

        expect(
          () =>
              calculator.calculate(construction, profilesById: {'M1': profile}),
          throwsStateError,
        );
      });

      test('construction width/height rules are unaffected by section '
          'geometry (existing behaviour still works)', () {
        const calculator = ConstructionCalculator(
          ruleSet: genericPlaceholderRuleSet,
        );
        // Section geometry deliberately differs from the construction's
        // overall dimensions -- constructionWidth/Height must still come
        // from the construction, not leak values from the section.
        final section = _section('s1', width: 400, height: 500);
        final montant = _profile('M1', type: ProfileType.montant);
        final traverse = _profile('T1', type: ProfileType.traverse);
        final construction = _construction(
          width: 1000,
          height: 1200,
          sections: [section],
          profileUsages: [
            _usage(
              'u1',
              profileId: 'M1',
              sectionId: 's1',
              role: ProfileUsageRole.left,
            ),
            _usage(
              'u2',
              profileId: 'T1',
              sectionId: 's1',
              role: ProfileUsageRole.top,
            ),
          ],
        );

        final cuts = calculator.calculate(
          construction,
          profilesById: {'M1': montant, 'T1': traverse},
        );

        expect(cuts.length, 2);
        expect(cuts[0].length, 1200); // constructionHeight, unchanged
        expect(cuts[1].length, 1000); // constructionWidth, unchanged
      });
    });
  });
}
