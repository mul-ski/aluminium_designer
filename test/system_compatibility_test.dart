import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/logic/system_compatibility.dart';
import 'package:aluminium_designer/core/models/profile.dart';
import 'package:aluminium_designer/core/models/profile_system.dart';
import 'package:aluminium_designer/core/models/profile_usage.dart';

Profile _profile(String id, {String system = 'sys'}) => Profile(
  id: id,
  manufacturer: 'Test Manufacturer',
  system: system,
  reference: id,
  name: 'Profile $id',
  type: ProfileType.montant,
  width: 40,
  depth: 60,
  weightPerMeter: 1.2,
);

ProfileSystem _system(String id, String name, List<Profile> profiles) =>
    ProfileSystem(
      id: id,
      manufacturer: 'Test Manufacturer',
      manufacturerId: 'mfr-1',
      name: name,
      ruleSetId: 'generic-placeholder',
      profiles: profiles,
      supportedOpenings: const [],
      isBuiltIn: false,
    );

ProfileUsage _usage(String profileId, {String sectionId = 'sec-1'}) =>
    ProfileUsage(
      id: 'usage-$profileId',
      profileId: profileId,
      sectionId: sectionId,
      role: ProfileUsageRole.left,
    );

void main() {
  group('compatibleProfileIds / isProfileCompatible', () {
    test('System A: A1, A2 are compatible; System B profiles are not', () {
      final a1 = _profile('A1');
      final a2 = _profile('A2');
      final systemA = _system('sys-a', 'System A', [a1, a2]);

      final b1 = _profile('B1');
      final b2 = _profile('B2');
      final systemB = _system('sys-b', 'System B', [b1, b2]);

      expect(compatibleProfileIds(systemA), {'A1', 'A2'});
      expect(isProfileCompatible('A1', systemA), isTrue);
      expect(isProfileCompatible('A2', systemA), isTrue);
      expect(isProfileCompatible('B1', systemA), isFalse);
      expect(isProfileCompatible('B2', systemA), isFalse);

      expect(compatibleProfileIds(systemB), {'B1', 'B2'});
      expect(isProfileCompatible('B1', systemB), isTrue);
      expect(isProfileCompatible('A1', systemB), isFalse);
    });

    test(
      'null system (unresolved/none selected) is compatible with nothing',
      () {
        expect(compatibleProfileIds(null), isEmpty);
        expect(isProfileCompatible('A1', null), isFalse);
      },
    );
  });

  group('incompatibleUsages', () {
    test('usages for A1/A2 under System A become incompatible when switching '
        'to System B (which does not contain A1/A2)', () {
      final systemA = _system('sys-a', 'System A', [
        _profile('A1'),
        _profile('A2'),
      ]);
      final systemB = _system('sys-b', 'System B', [
        _profile('B1'),
        _profile('B2'),
      ]);

      final usages = [_usage('A1'), _usage('A2')];

      // Sanity: both usages are compatible with the system they were
      // created under.
      expect(incompatibleUsages(usages, systemA), isEmpty);

      // Switching to System B: neither A1 nor A2 exists there.
      final incompatible = incompatibleUsages(usages, systemB);
      expect(incompatible.length, 2);
      expect(incompatible.map((u) => u.profileId).toSet(), {'A1', 'A2'});
    });

    test('a mix of compatible and incompatible usages is split correctly', () {
      final systemB = _system('sys-b', 'System B', [
        _profile('B1'),
        _profile('B2'),
      ]);

      // B1 belongs to System B; A1 does not (e.g. left over from a
      // previous system on the same construction).
      final usages = [_usage('B1'), _usage('A1')];

      final incompatible = incompatibleUsages(usages, systemB);
      expect(incompatible.length, 1);
      expect(incompatible.single.profileId, 'A1');
    });

    test('pre-existing stale usages (previous system deleted from catalog) are '
        'detected as incompatible against an unresolved (null) system', () {
      // Construction previously used System A; A1/A2 usages exist.
      final usages = [_usage('A1'), _usage('A2')];

      // System A has since been deleted from the catalog entirely --
      // the construction's systemId no longer resolves to anything, so
      // callers pass null here (see Construction's doc comment on what
      // an unresolved systemId means).
      final incompatible = incompatibleUsages(usages, null);

      expect(incompatible.length, 2);
      expect(incompatible.map((u) => u.profileId).toSet(), {'A1', 'A2'});
    });

    test('both already-stale usages AND the newly chosen system are accounted '
        'for together: selecting System B (which lacks A1/A2) after System A '
        'was deleted still flags both as incompatible', () {
      final systemB = _system('sys-b', 'System B', [
        _profile('B1'),
        _profile('B2'),
      ]);
      final usages = [_usage('A1'), _usage('A2')];

      final incompatible = incompatibleUsages(usages, systemB);

      expect(incompatible.length, 2);
      expect(incompatible.map((u) => u.profileId).toSet(), {'A1', 'A2'});
    });

    test('empty usages list is always compatible, regardless of system', () {
      final systemA = _system('sys-a', 'System A', [_profile('A1')]);
      expect(incompatibleUsages(const [], systemA), isEmpty);
      expect(incompatibleUsages(const [], null), isEmpty);
    });
  });
}
