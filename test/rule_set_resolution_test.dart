import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/engine/construction_calculator.dart';
import 'package:aluminium_designer/core/logic/rule_set_resolution.dart';
import 'package:aluminium_designer/core/models/catalog.dart';
import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/layout_direction.dart';
import 'package:aluminium_designer/core/models/profile.dart';
import 'package:aluminium_designer/core/models/profile_system.dart';
import 'package:aluminium_designer/core/models/profile_usage.dart';
import 'package:aluminium_designer/core/models/rules/generic_placeholder_rules.dart';
import 'package:aluminium_designer/core/models/section.dart';

ProfileSystem _system(
  String id,
  String ruleSetId, {
  List<Profile> profiles = const [],
}) => ProfileSystem(
  id: id,
  manufacturer: 'Test Manufacturer',
  manufacturerId: 'mfr-1',
  name: 'Test System',
  ruleSetId: ruleSetId,
  profiles: profiles,
  supportedOpenings: const [],
  isBuiltIn: false,
);

Profile _montant(String id) => Profile(
  id: id,
  manufacturer: 'Test Manufacturer',
  system: 'Test System',
  reference: id,
  name: 'Montant $id',
  type: ProfileType.montant,
  width: 40,
  depth: 60,
  weightPerMeter: 1.2,
);

Construction _construction({
  String? systemId,
  List<Section> sections = const [],
  List<ProfileUsage> profileUsages = const [],
}) => Construction(
  id: 'c1',
  name: 'Test Construction',
  type: ConstructionType.window,
  width: 1000,
  height: 1200,
  manufacturer: 'Test Manufacturer',
  system: 'Test System',
  systemId: systemId,
  sections: sections,
  layoutDirection: SectionLayoutDirection.horizontal,
  profiles: const [],
  profileUsages: profileUsages,
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

  group('resolveRuleSetForConstruction (Construction + Catalog)', () {
    test('resolves the full chain: systemId -> Catalog -> ProfileSystem -> '
        'ruleSetId -> SystemRuleSet', () {
      final system = _system('sys-1', 'generic-placeholder');
      final catalog = Catalog(profileSystems: [system]);
      final construction = _construction(systemId: 'sys-1');

      expect(
        resolveRuleSetForConstruction(construction, catalog),
        same(genericPlaceholderRuleSet),
      );
    });

    test('returns null when construction.systemId is null', () {
      final catalog = Catalog(
        profileSystems: [_system('sys-1', 'generic-placeholder')],
      );
      final construction = _construction(systemId: null);

      expect(resolveRuleSetForConstruction(construction, catalog), isNull);
    });

    test('returns null when construction.systemId does not resolve in the '
        'catalog (system deleted) -- does not fall back to '
        'generic-placeholder', () {
      final catalog = Catalog(
        profileSystems: [_system('sys-1', 'generic-placeholder')],
      );
      final construction = _construction(systemId: 'sys-deleted');

      expect(resolveRuleSetForConstruction(construction, catalog), isNull);
    });

    test(
      "returns null when the resolved system's ruleSetId is unregistered",
      () {
        final catalog = Catalog(
          profileSystems: [_system('sys-1', 'nonexistent-rule-set')],
        );
        final construction = _construction(systemId: 'sys-1');

        expect(resolveRuleSetForConstruction(construction, catalog), isNull);
      },
    );
  });

  group('calculateConstructionCuts (full application-layer pipeline)', () {
    test(
      'resolves system + rule set + profiles from Catalog and produces '
      'real cuts, matching manually-driven ConstructionCalculator output',
      () {
        final montant = _montant('M1');
        final system = _system(
          'sys-1',
          'generic-placeholder',
          profiles: [montant],
        );
        final catalog = Catalog(profileSystems: [system]);
        final section = Section(
          id: 's1',
          order: 0,
          kind: SectionKind.fixed,
          width: 1000,
          height: 1200,
        );
        final construction = _construction(
          systemId: 'sys-1',
          sections: [section],
          profileUsages: [
            ProfileUsage(
              id: 'u1',
              profileId: 'M1',
              sectionId: 's1',
              role: ProfileUsageRole.left,
            ),
          ],
        );

        final cuts = calculateConstructionCuts(construction, catalog);

        expect(cuts, isNotNull);
        expect(cuts!.length, 1);
        expect(cuts.single.profile.id, 'M1');
        expect(cuts.single.length, 1200);
        expect(cuts.single.quantity, 2);
      },
    );

    test('returns null (does not throw, does not fall back) when the '
        "construction's system does not resolve", () {
      final catalog = Catalog(
        profileSystems: [_system('sys-1', 'generic-placeholder')],
      );
      final construction = _construction(systemId: 'sys-deleted');

      expect(calculateConstructionCuts(construction, catalog), isNull);
    });

    test('returns null when no system has been selected on the construction '
        'at all', () {
      final catalog = Catalog(
        profileSystems: [_system('sys-1', 'generic-placeholder')],
      );
      final construction = _construction(systemId: null);

      expect(calculateConstructionCuts(construction, catalog), isNull);
    });

    test('still propagates StateError from ConstructionCalculator.calculate '
        'when construction dimensions are missing -- this function does not '
        'swallow that error', () {
      final system = _system('sys-1', 'generic-placeholder');
      final catalog = Catalog(profileSystems: [system]);
      final construction = Construction(
        id: 'c2',
        name: 'No dimensions yet',
        type: ConstructionType.window,
        width: null,
        height: null,
        manufacturer: 'Test Manufacturer',
        system: 'Test System',
        systemId: 'sys-1',
        sections: const [],
        layoutDirection: SectionLayoutDirection.horizontal,
        profiles: const [],
      );

      expect(
        () => calculateConstructionCuts(construction, catalog),
        throwsStateError,
      );
    });
  });

  group('Catalog.systemById', () {
    test('resolves a matching id', () {
      final system = _system('sys-1', 'generic-placeholder');
      final catalog = Catalog(profileSystems: [system]);
      expect(catalog.systemById('sys-1'), same(system));
    });

    test('returns null for a null id', () {
      final catalog = Catalog(
        profileSystems: [_system('sys-1', 'generic-placeholder')],
      );
      expect(catalog.systemById(null), isNull);
    });

    test('returns null for an id not present in the catalog', () {
      final catalog = Catalog(
        profileSystems: [_system('sys-1', 'generic-placeholder')],
      );
      expect(catalog.systemById('sys-missing'), isNull);
    });
  });

  group('ProfileSystem.profilesById', () {
    test('keys profiles by their id', () {
      final m1 = _montant('M1');
      final m2 = _montant('M2');
      final system = _system(
        'sys-1',
        'generic-placeholder',
        profiles: [m1, m2],
      );

      expect(system.profilesById, {'M1': m1, 'M2': m2});
    });

    test('is empty for a system with no profiles', () {
      final system = _system('sys-1', 'generic-placeholder');
      expect(system.profilesById, isEmpty);
    });
  });
}
