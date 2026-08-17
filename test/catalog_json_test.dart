import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/models/catalog.dart';
import 'package:aluminium_designer/core/models/catalog_json.dart';
import 'package:aluminium_designer/core/models/manufacturer.dart';
import 'package:aluminium_designer/core/models/profile.dart';
import 'package:aluminium_designer/core/models/profile_system.dart';

void main() {
  group('Catalog JSON round-trip', () {
    test('empty catalog round-trips', () {
      const catalog = Catalog();

      final restored = catalogFromJson(catalog.toJson());

      expect(restored.manufacturers, isEmpty);
      expect(restored.profileSystems, isEmpty);
    });

    test('manufacturer and system with no profiles round-trip', () {
      final catalog = Catalog(
        manufacturers: const [
          Manufacturer(id: 'mfr-1', name: 'ACME', isBuiltIn: false),
        ],
        profileSystems: const [
          ProfileSystem(
            id: 'sys-1',
            manufacturer: 'ACME',
            manufacturerId: 'mfr-1',
            name: 'Custom Window 2026',
            ruleSetId: 'generic-placeholder',
            profiles: [],
            supportedOpenings: [],
            isBuiltIn: false,
          ),
        ],
      );

      final restored = catalogFromJson(catalog.toJson());

      expect(restored.manufacturers, hasLength(1));
      expect(restored.manufacturers.single.id, 'mfr-1');
      expect(restored.profileSystems, hasLength(1));
      expect(restored.profileSystems.single.id, 'sys-1');
      expect(restored.profileSystems.single.manufacturerId, 'mfr-1');
      expect(restored.profileSystems.single.profiles, isEmpty);
    });

    test('a ProfileSystem carrying Profiles survives a full catalog JSON '
        'round-trip -- profiles are nested inside the system, not a '
        'separate top-level catalog collection', () {
      final profileA = Profile(
        id: 'A1',
        manufacturer: 'ACME',
        system: 'Custom Window 2026',
        reference: 'REF-A1',
        name: 'Montant A1',
        type: ProfileType.montant,
        width: 45,
        depth: 60,
        weightPerMeter: 1.2,
      );
      final profileB = Profile(
        id: 'A2',
        manufacturer: 'ACME',
        system: 'Custom Window 2026',
        reference: 'REF-A2',
        name: 'Traverse A2',
        type: ProfileType.traverse,
        width: 50,
        depth: 65,
        weightPerMeter: 1.5,
      );

      final catalog = Catalog(
        manufacturers: const [
          Manufacturer(id: 'mfr-1', name: 'ACME', isBuiltIn: false),
        ],
        profileSystems: [
          ProfileSystem(
            id: 'sys-1',
            manufacturer: 'ACME',
            manufacturerId: 'mfr-1',
            name: 'Custom Window 2026',
            ruleSetId: 'generic-placeholder',
            profiles: [profileA, profileB],
            supportedOpenings: const [],
            isBuiltIn: false,
          ),
        ],
      );

      final restored = catalogFromJson(catalog.toJson());

      final restoredSystem = restored.profileSystems.single;
      expect(restoredSystem.profiles, hasLength(2));
      expect(restoredSystem.profiles.map((p) => p.id).toSet(), {'A1', 'A2'});
      expect(
        restoredSystem.profiles.firstWhere((p) => p.id == 'A1').reference,
        'REF-A1',
      );
      expect(
        restoredSystem.profiles.firstWhere((p) => p.id == 'A1').type,
        ProfileType.montant,
      );
      expect(
        restoredSystem.profiles.firstWhere((p) => p.id == 'A2').type,
        ProfileType.traverse,
      );
    });

    test('schemaVersion is present and defaults correctly when missing', () {
      const catalog = Catalog();
      final json = catalog.toJson();

      expect(json['schemaVersion'], catalogSchemaVersion);

      final withoutVersion = Map<String, dynamic>.from(json)
        ..remove('schemaVersion');
      final restored = catalogFromJson(withoutVersion);
      expect(restored.manufacturers, isEmpty);
    });
  });
}
