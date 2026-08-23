import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/models/catalog.dart';
import 'package:aluminium_designer/core/models/catalog_json.dart';
import 'package:aluminium_designer/core/models/manufacturer.dart';
import 'package:aluminium_designer/core/models/opening.dart';
import 'package:aluminium_designer/core/models/profile.dart';
import 'package:aluminium_designer/core/models/profile_system.dart';
import 'package:aluminium_designer/core/models/profile_system_json.dart';
import 'package:aluminium_designer/core/models/profile_system_metadata.dart';

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

    test('a system WITHOUT metadata round-trips with metadata absent -- '
        'pre-metadata saved catalogs read back unchanged', () {
      final catalog = Catalog(
        profileSystems: const [
          ProfileSystem(
            id: 'sys-1',
            manufacturer: 'ACME',
            manufacturerId: 'mfr-1',
            name: 'Old System',
            ruleSetId: 'generic-placeholder',
            profiles: [],
            supportedOpenings: [],
            isBuiltIn: false,
          ),
        ],
      );

      final restored = catalogFromJson(catalog.toJson());

      expect(restored.profileSystems.single.metadata, isNull);
    });

    test('a system WITH full metadata round-trips every field, including '
        'dimension limits and the null thermal-break "unknown" state', () {
      final catalog = Catalog(
        profileSystems: [
          ProfileSystem(
            id: 'sys-1',
            manufacturer: 'ACME',
            manufacturerId: 'mfr-1',
            name: 'Documented System',
            ruleSetId: 'generic-placeholder',
            profiles: [],
            supportedOpenings: const [],
            isBuiltIn: false,
            metadata: ProfileSystemMetadata(
              frameDepthOptionsMm: const [44, 66],
              sashStileDepthOptionsMm: const [56, 69],
              sashMeetingStileDepthMm: 41,
              glazingRebateMm: 26,
              glazingMinMm: 6,
              glazingMaxMm: 22,
              // Unknown stays null and must survive as null.
              assemblyNote:
                  "Dormants assemblés en coupe d'onglet avec équerres.",
              dimensionLimits: [
                const DimensionLimit(maxWidthMm: 2400, maxHeightMm: 2200),
                const DimensionLimit(
                  openingType: OpeningType.coulissante,
                  maxWidthMm: 2000,
                  maxHeightMm: 2100,
                ),
              ],
              sourceDescription: 'Descriptif test document',
            ),
          ),
        ],
      );

      final restored = catalogFromJson(catalog.toJson());

      final meta = restored.profileSystems.single.metadata;
      expect(meta, isNotNull);
      expect(meta!.frameDepthOptionsMm, [44, 66]);
      expect(meta.sashStileDepthOptionsMm, [56, 69]);
      expect(meta.sashMeetingStileDepthMm, 41);
      expect(meta.glazingRebateMm, 26);
      expect(meta.glazingMinMm, 6);
      expect(meta.glazingMaxMm, 22);
      expect(meta.thermalBreak, isNull);
      expect(meta.assemblyNote, contains("coupe d'onglet"));
      expect(meta.dimensionLimits, hasLength(2));
      expect(meta.dimensionLimits[0].openingType, isNull);
      expect(meta.dimensionLimits[0].maxWidthMm, 2400);
      expect(meta.dimensionLimits[1].openingType, OpeningType.coulissante);
      expect(meta.dimensionLimits[1].maxHeightMm, 2100);
      expect(meta.sourceDescription, 'Descriptif test document');

      // Re-serializing the restored catalog yields the same metadata JSON
      // (stability across load/save cycles).
      expect(
        restored.profileSystems.single.toJson()['metadata'],
        catalog.profileSystems.single.toJson()['metadata'],
      );
    });
  });
}
