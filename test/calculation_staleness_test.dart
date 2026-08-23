import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/logic/calculation_staleness.dart';
import 'package:aluminium_designer/core/models/catalog.dart';
import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/layout_direction.dart';
import 'package:aluminium_designer/core/models/profile.dart';
import 'package:aluminium_designer/core/models/profile_system.dart';
import 'package:aluminium_designer/core/models/profile_usage.dart';

Profile _profile(
  String id, {
  ProfileType type = ProfileType.montant,
  double weightPerMeter = 1.5,
  String name = 'Profile',
  String? reference,
  double width = 40,
  double depth = 60,
}) => Profile(
  id: id,
  manufacturer: 'Mfr',
  system: 'Sys',
  reference: reference ?? id,
  name: name,
  type: type,
  width: width,
  depth: depth,
  weightPerMeter: weightPerMeter,
);

ProfileSystem _system(
  String id, {
  String ruleSetId = 'generic-placeholder',
  List<Profile> profiles = const [],
}) => ProfileSystem(
  id: id,
  manufacturer: 'Mfr',
  manufacturerId: 'mfr-1',
  name: 'Test System',
  ruleSetId: ruleSetId,
  profiles: profiles,
  supportedOpenings: const [],
  isBuiltIn: false,
);

Construction _construction({
  String? systemId = 'sys-1',
  List<ProfileUsage> profileUsages = const [],
}) => Construction(
  id: 'c1',
  name: 'Test Construction',
  type: ConstructionType.window,
  width: 1000,
  height: 1200,
  manufacturer: '',
  system: '',
  systemId: systemId,
  sections: const [],
  layoutDirection: SectionLayoutDirection.horizontal,
  profiles: const [],
  profileUsages: profileUsages,
);

ProfileUsage _usage(String profileId) => ProfileUsage(
  id: 'u-$profileId',
  profileId: profileId,
  sectionId: 's1',
  role: ProfileUsageRole.left,
);

void main() {
  group('catalogCalculationFingerprint', () {
    test('unresolved system yields the stable no-system sentinel', () {
      final emptyCatalog = const Catalog();
      expect(
        catalogCalculationFingerprint(emptyCatalog, _construction()),
        'no-system',
      );
      // Same sentinel regardless of what else the catalog holds -- an
      // unrelated system's presence must not leak into another
      // construction's fingerprint.
      final otherCatalog = Catalog(
        profileSystems: [
          _system('sys-other', profiles: [_profile('P1')]),
        ],
      );
      expect(
        catalogCalculationFingerprint(otherCatalog, _construction()),
        'no-system',
      );
    });

    test('includes the resolved rule set identity', () {
      final catalog = Catalog(profileSystems: [_system('sys-1')]);
      final withPlaceholder = catalogCalculationFingerprint(
        catalog,
        _construction(),
      );

      final reidentifiedCatalog = Catalog(
        profileSystems: [
          _system('sys-1', ruleSetId: 'some-real-manufacturer-set'),
        ],
      );

      expect(withPlaceholder, isNot('no-system'));
      expect(
        withPlaceholder,
        isNot(
          catalogCalculationFingerprint(reidentifiedCatalog, _construction()),
        ),
      );
    });

    test(
      'covers referenced profiles only -- unrelated edits are invisible',
      () {
        final base = Catalog(
          profileSystems: [
            _system('sys-1', profiles: [_profile('M1')]),
          ],
        );
        final construction = _construction(profileUsages: [_usage('M1')]);
        final baseline = catalogCalculationFingerprint(base, construction);

        // Adding an unreferenced profile.
        final withExtra = Catalog(
          profileSystems: [
            _system('sys-1', profiles: [_profile('M1'), _profile('T9')]),
          ],
        );
        // Editing an unreferenced profile.
        final editedUnrelated = Catalog(
          profileSystems: [
            _system(
              'sys-1',
              profiles: [
                _profile('M1'),
                _profile('T9', type: ProfileType.traverse),
              ],
            ),
          ],
        );

        expect(
          catalogCalculationFingerprint(withExtra, construction),
          baseline,
        );
        expect(
          catalogCalculationFingerprint(editedUnrelated, construction),
          baseline,
        );
      },
    );

    test('a referenced profile disappearing (deleted or renamed id) changes '
        'the fingerprint', () {
      final construction = _construction(profileUsages: [_usage('M1')]);

      final present = Catalog(
        profileSystems: [
          _system('sys-1', profiles: [_profile('M1')]),
        ],
      );
      final deleted = const Catalog();

      expect(
        catalogCalculationFingerprint(present, construction),
        isNot(catalogCalculationFingerprint(deleted, construction)),
      );
    });

    test('type change on a referenced profile changes the fingerprint', () {
      final construction = _construction(profileUsages: [_usage('M1')]);

      final asMontant = Catalog(
        profileSystems: [
          _system(
            'sys-1',
            profiles: [_profile('M1', type: ProfileType.montant)],
          ),
        ],
      );
      final asTraverse = Catalog(
        profileSystems: [
          _system(
            'sys-1',
            profiles: [_profile('M1', type: ProfileType.traverse)],
          ),
        ],
      );

      expect(
        catalogCalculationFingerprint(asMontant, construction),
        isNot(catalogCalculationFingerprint(asTraverse, construction)),
      );
    });

    test('weightPerMeter change on a referenced profile changes the '
        'fingerprint', () {
      final construction = _construction(profileUsages: [_usage('M1')]);

      final light = Catalog(
        profileSystems: [
          _system('sys-1', profiles: [_profile('M1', weightPerMeter: 1.0)]),
        ],
      );
      final heavy = Catalog(
        profileSystems: [
          _system('sys-1', profiles: [_profile('M1', weightPerMeter: 2.0)]),
        ],
      );

      expect(
        catalogCalculationFingerprint(light, construction),
        isNot(catalogCalculationFingerprint(heavy, construction)),
      );
    });

    test('display-only edits keep the fingerprint identical', () {
      final construction = _construction(profileUsages: [_usage('M1')]);

      final before = Catalog(
        profileSystems: [
          _system('sys-1', profiles: [_profile('M1')]),
        ],
      );
      // Rename + cosmetic dimensions: none of these reach a computed number.
      final after = Catalog(
        profileSystems: [
          _system(
            'sys-1',
            profiles: [
              _profile(
                'M1',
                name: 'Nouveau nom',
                reference: 'REF-X',
                width: 99,
                depth: 77,
              ),
            ],
          ),
        ],
      );

      expect(
        catalogCalculationFingerprint(before, construction),
        catalogCalculationFingerprint(after, construction),
      );
    });

    test('independent of the system profile list ordering', () {
      final construction = _construction(profileUsages: [_usage('M1')]);

      final ordered = Catalog(
        profileSystems: [
          _system('sys-1', profiles: [_profile('A1'), _profile('M1')]),
        ],
      );
      final reordered = Catalog(
        profileSystems: [
          _system('sys-1', profiles: [_profile('M1'), _profile('A1')]),
        ],
      );

      expect(
        catalogCalculationFingerprint(ordered, construction),
        catalogCalculationFingerprint(reordered, construction),
      );
    });

    test('multiple referenced profiles all contribute; dropping one shows', () {
      final bothUsed = _construction(
        profileUsages: [_usage('M1'), _usage('T1')],
      );
      final onlyMontantUsed = _construction(profileUsages: [_usage('M1')]);

      final profilesBoth = Catalog(
        profileSystems: [
          _system(
            'sys-1',
            profiles: [
              _profile('M1'),
              _profile('T1', type: ProfileType.traverse),
            ],
          ),
        ],
      );

      final fpBoth = catalogCalculationFingerprint(profilesBoth, bothUsed);
      final fpOne = catalogCalculationFingerprint(
        profilesBoth,
        onlyMontantUsed,
      );

      expect(fpBoth, isNot(fpOne));
      // T1 is still IN the system for fpOne -- it just is not referenced,
      // proving scoping comes from usage references, not catalog contents.
    });
  });
}
