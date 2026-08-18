import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/engine/construction_calculator.dart';
import 'package:aluminium_designer/core/logic/rule_set_resolution.dart';
import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/layout_direction.dart';
import 'package:aluminium_designer/core/models/profile.dart';
import 'package:aluminium_designer/core/models/profile_system.dart';
import 'package:aluminium_designer/core/models/profile_usage.dart';
import 'package:aluminium_designer/core/models/rules/generic_placeholder_rules.dart';
import 'package:aluminium_designer/core/models/section.dart';

ProfileSystem _system(String id, String ruleSetId) => ProfileSystem(
  id: id,
  manufacturer: 'Test Manufacturer',
  manufacturerId: 'mfr-1',
  name: 'Test System',
  ruleSetId: ruleSetId,
  profiles: const [],
  supportedOpenings: const [],
  isBuiltIn: false,
);

void main() {
  group('resolveRuleSetById', () {
    test('resolves the registered generic-placeholder id', () {
      final resolved = resolveRuleSetById('generic-placeholder');
      expect(resolved, same(genericPlaceholderRuleSet));
    });

    test('returns null for an unregistered id', () {
      expect(
        resolveRuleSetById('some-manufacturer-that-does-not-exist'),
        isNull,
      );
    });

    test('returns null for an empty id', () {
      expect(resolveRuleSetById(''), isNull);
    });
  });

  group('resolveRuleSetForSystem', () {
    test("resolves a ProfileSystem's ruleSetId to its SystemRuleSet", () {
      final system = _system('sys-1', 'generic-placeholder');
      expect(resolveRuleSetForSystem(system), same(genericPlaceholderRuleSet));
    });

    test('returns null when the ProfileSystem itself is null (unresolved)', () {
      expect(resolveRuleSetForSystem(null), isNull);
    });

    test('returns null when the ProfileSystem points at an unregistered '
        'ruleSetId (e.g. saved before that rule set existed, or a typo)', () {
      final system = _system('sys-1', 'nonexistent-rule-set');
      expect(resolveRuleSetForSystem(system), isNull);
    });
  });

  group('end-to-end: ProfileSystem.ruleSetId -> SystemRuleSet -> '
      'ConstructionCalculator', () {
    test('a resolved rule set actually drives a real calculate() call, not '
        'just DimensionExpression/SystemRuleSet in isolation', () {
      // Mirrors how a real call site would go: start from a
      // ProfileSystem (as would be resolved from Catalog.profileSystems
      // via Construction.systemId), resolve its rule set, then hand
      // that rule set to ConstructionCalculator -- the full documented
      // chain from the milestone brief.
      final system = _system('sys-1', 'generic-placeholder');
      final ruleSet = resolveRuleSetForSystem(system);
      expect(ruleSet, isNotNull);

      final calculator = ConstructionCalculator(ruleSet: ruleSet!);

      final section = Section(
        id: 's1',
        order: 0,
        kind: SectionKind.fixed,
        width: 1000,
        height: 1200,
      );
      final montant = Profile(
        id: 'M1',
        manufacturer: 'Test Manufacturer',
        system: 'Test System',
        reference: 'M1',
        name: 'Montant',
        type: ProfileType.montant,
        width: 40,
        depth: 60,
        weightPerMeter: 1.2,
      );
      final construction = Construction(
        id: 'c1',
        name: 'Test Construction',
        type: ConstructionType.window,
        width: 1000,
        height: 1200,
        manufacturer: 'Test Manufacturer',
        system: 'Test System',
        systemId: 'sys-1',
        sections: [section],
        layoutDirection: SectionLayoutDirection.horizontal,
        profiles: const [],
        profileUsages: [
          ProfileUsage(
            id: 'u1',
            profileId: 'M1',
            sectionId: 's1',
            role: ProfileUsageRole.left,
          ),
        ],
      );

      final cuts = calculator.calculate(
        construction,
        profilesById: {'M1': montant},
      );

      expect(cuts.length, 1);
      expect(cuts.single.profile.id, 'M1');
      // genericPlaceholderRuleSet's montant rule: full construction
      // height, mitred 45/45, quantity 2 -- see
      // generic_placeholder_rules.dart.
      expect(cuts.single.length, 1200);
      expect(cuts.single.quantity, 2);
      expect(cuts.single.angleStart, 45);
      expect(cuts.single.angleEnd, 45);
    });

    test('an unresolved ProfileSystem (null) correctly yields no rule set to '
        'calculate with -- the caller must decide what to do, this does not '
        'guess', () {
      final ruleSet = resolveRuleSetForSystem(null);
      expect(ruleSet, isNull);
    });
  });
}
