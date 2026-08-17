import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:aluminium_designer/core/data/builtin_catalog_seed.dart';
import 'package:aluminium_designer/core/models/catalog.dart';
import 'package:aluminium_designer/core/models/catalog_json.dart';
import 'package:aluminium_designer/core/models/manufacturer.dart';
import 'package:aluminium_designer/core/models/profile_system.dart';
import 'package:aluminium_designer/core/storage/catalog_store.dart';

import 'support/fake_path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('withBuiltInCatalogSeed (pure merge logic)', () {
    test('manufacturer exists after seeding an empty catalog', () {
      final seeded = withBuiltInCatalogSeed(const Catalog());

      expect(
        seeded.manufacturers.any((m) => m.id == aluminiumDuMarocId),
        isTrue,
      );
      expect(
        seeded.manufacturers.firstWhere((m) => m.id == aluminiumDuMarocId).name,
        'Aluminium du Maroc',
      );
    });

    test('Cuzco 713 OM belongs to Aluminium du Maroc', () {
      final seeded = withBuiltInCatalogSeed(const Catalog());

      final system = seeded.profileSystems.firstWhere(
        (s) => s.id == cuzco713OmId,
      );
      expect(system.manufacturerId, aluminiumDuMarocId);
      expect(system.name, 'Cuzco 713 OM');

      // Confirms it's reachable via the same lookup the picker UI uses.
      expect(
        seeded.systemsFor(aluminiumDuMarocId).map((s) => s.id),
        contains(cuzco713OmId),
      );
    });

    test('no fake profiles were created -- Cuzco 713 OM.profiles is empty', () {
      final seeded = withBuiltInCatalogSeed(const Catalog());

      final system = seeded.profileSystems.firstWhere(
        (s) => s.id == cuzco713OmId,
      );
      expect(system.profiles, isEmpty);

      // Also confirms nothing anywhere in the seeded catalog carries a
      // Profile -- the only System introduced by this seed is Cuzco 713
      // OM, and it must be the empty-profiles case exactly as specified.
      final totalProfiles = seeded.profileSystems.fold<int>(
        0,
        (sum, s) => sum + s.profiles.length,
      );
      expect(totalProfiles, 0);
    });

    test('merging is idempotent -- running it twice does not duplicate', () {
      final once = withBuiltInCatalogSeed(const Catalog());
      final twice = withBuiltInCatalogSeed(once);

      expect(
        twice.manufacturers.where((m) => m.id == aluminiumDuMarocId).length,
        1,
      );
      expect(twice.profileSystems.where((s) => s.id == cuzco713OmId).length, 1);
    });

    test('does not touch existing user-created manufacturers/systems', () {
      const userManufacturer = Manufacturer(
        id: 'user-1',
        name: 'My Workshop',
        isBuiltIn: false,
      );
      const userSystem = ProfileSystem(
        id: 'user-sys-1',
        manufacturer: 'My Workshop',
        manufacturerId: 'user-1',
        name: 'Custom System',
        ruleSetId: 'generic-placeholder',
        profiles: [],
        supportedOpenings: [],
        isBuiltIn: false,
      );
      final existing = Catalog(
        manufacturers: const [userManufacturer],
        profileSystems: const [userSystem],
      );

      final seeded = withBuiltInCatalogSeed(existing);

      expect(seeded.manufacturers, contains(userManufacturer));
      expect(seeded.profileSystems, contains(userSystem));
      expect(
        seeded.manufacturers.any((m) => m.id == aluminiumDuMarocId),
        isTrue,
      );
    });

    test('catalogue survives a JSON round-trip after seeding', () {
      final seeded = withBuiltInCatalogSeed(const Catalog());
      final restored = catalogFromJson(seeded.toJson());

      expect(
        restored.manufacturers.any((m) => m.id == aluminiumDuMarocId),
        isTrue,
      );
      final restoredSystem = restored.profileSystems.firstWhere(
        (s) => s.id == cuzco713OmId,
      );
      expect(restoredSystem.name, 'Cuzco 713 OM');
      expect(restoredSystem.manufacturerId, aluminiumDuMarocId);
      expect(restoredSystem.profiles, isEmpty);
    });
  });

  group('CatalogStore seeding via real file I/O', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('aluvis_seed_test');
      PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('first-ever load seeds the built-in manufacturer/system', () async {
      final store = CatalogStore();
      final catalog = await store.load();

      expect(
        catalog.manufacturers.any((m) => m.id == aluminiumDuMarocId),
        isTrue,
      );
      expect(catalog.profileSystems.any((s) => s.id == cuzco713OmId), isTrue);
    });

    test('app restart persistence: a fresh CatalogStore instance still sees '
        'the seeded data after the first one seeded and saved it', () async {
      final firstRun = CatalogStore();
      await firstRun.load(); // Seeds and persists.

      // A brand-new store instance simulates the app being closed and
      // reopened -- no shared in-memory state with `firstRun`.
      final secondRun = CatalogStore();
      final reloaded = await secondRun.load();

      expect(
        reloaded.manufacturers.any((m) => m.id == aluminiumDuMarocId),
        isTrue,
      );
      expect(reloaded.profileSystems.any((s) => s.id == cuzco713OmId), isTrue);
    });

    test('deleting the built-in manufacturer and reloading does not '
        'resurrect it -- the one-time seed sentinel is respected', () async {
      final store = CatalogStore();
      final catalog = await store.load(); // Seeds on first load.

      // Simulate the user deleting the built-in manufacturer (and its
      // system) via the existing delete UI, then saving.
      final withoutBuiltIns = catalog.copyWith(
        manufacturers: catalog.manufacturers
            .where((m) => m.id != aluminiumDuMarocId)
            .toList(),
        profileSystems: catalog.profileSystems
            .where((s) => s.id != cuzco713OmId)
            .toList(),
      );
      await store.save(withoutBuiltIns);

      // Reload (simulating app restart) -- the deletion must stick.
      final reloadedStore = CatalogStore();
      final reloaded = await reloadedStore.load();

      expect(
        reloaded.manufacturers.any((m) => m.id == aluminiumDuMarocId),
        isFalse,
      );
      expect(reloaded.profileSystems.any((s) => s.id == cuzco713OmId), isFalse);
    });
  });
}
