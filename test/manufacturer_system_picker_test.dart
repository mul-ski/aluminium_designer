import 'package:aluminium_designer/core/data/builtin_catalog_seed.dart';
import 'package:aluminium_designer/core/models/catalog.dart';
import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/manufacturer.dart';
import 'package:aluminium_designer/core/models/profile_system.dart';
import 'package:aluminium_designer/core/models/section.dart';
import 'package:aluminium_designer/core/storage/catalog_store.dart';
import 'package:aluminium_designer/features/constructions/screens/construction_editor_screen.dart';
import 'package:aluminium_designer/features/constructions/widgets/manufacturer_system_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _desktopSize = Size(1400, 900);

/// Records saves instead of touching the disk. Same DI seam the existing
/// editor screen tests use -- real `dart:io` I/O cannot complete under
/// `testWidgets` fake-async, and the disk behaviour itself is covered by
/// `catalog_json_test.dart` / `project_json_test.dart`.
class _RecordingStore extends CatalogStore {
  Catalog catalog;
  _RecordingStore(this.catalog);
  @override
  Future<Catalog> load() async => catalog;
  @override
  Future<void> save(Catalog catalog) async {
    this.catalog = catalog;
  }
}

Construction _stubConstruction({
  String manufacturer = '',
  String manufacturerId = '',
  String system = '',
  String systemId = '',
}) => Construction(
  id: 'c-picker',
  name: 'Picker test',
  type: ConstructionType.window,
  width: 2000,
  height: 1500,
  manufacturer: manufacturer,
  manufacturerId: manufacturerId.isEmpty ? null : manufacturerId,
  system: system,
  systemId: systemId.isEmpty ? null : systemId,
  sections: [Section(id: 's1', order: 0, kind: SectionKind.fixed, width: 2000, height: 1500)],
  profiles: const [],
);

Future<void> _pump(WidgetTester tester, Catalog catalog, {Construction? c}) async {
  tester.view.physicalSize = _desktopSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: ConstructionEditorScreen(
        construction: c ?? _stubConstruction(),
        catalogStore: _RecordingStore(catalog),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'built-in manufacturer (isBuiltIn: true) hides the delete button',
    (tester) async {
      // The seeded catalog from `withBuiltInCatalogSeed` carries
      // `isBuiltIn: true` on every record. The picker must not surface
      // a delete affordance for those -- removing them would leave
      // existing constructions unresolvable and the seeding pass is
      // add-only on first launch.
      final seeded = withBuiltInCatalogSeed(const Catalog());
      await _pump(
        tester,
        seeded,
        c: _stubConstruction(
          manufacturer: 'Maghreb Extrusion (ME)',
          manufacturerId: maghrebExtrusionId,
        ),
      );

      expect(
        find.descendant(
          of: find.widgetWithText(ManufacturerSystemPicker, 'Fabricant'),
          matching: find.byTooltip('Supprimer ce fabricant'),
        ),
        findsNothing,
        reason:
            'Built-in manufacturers must not show a delete affordance. '
            'The trash button is hidden (not just disabled) for '
            'isBuiltIn: true records so the user cannot trigger a '
            'confirmation flow the app would not honor anyway.',
      );
    },
  );

  testWidgets(
    'user-created manufacturer (isBuiltIn: false) shows the delete button',
    (tester) async {
      // A hand-rolled, non-built-in manufacturer. The picker must
      // surface the trash button so the user can remove their own
      // record.
      const userMfrId = 'mfr-user-1';
      final userMfr = Manufacturer(
        id: userMfrId,
        name: 'User Manufacturer',
        isBuiltIn: false,
      );
      final catalog = Catalog(
        manufacturers: [userMfr],
        profileSystems: const [],
      );
      await _pump(
        tester,
        catalog,
        c: _stubConstruction(
          manufacturer: userMfr.name,
          manufacturerId: userMfrId,
        ),
      );

      expect(
        find.descendant(
          of: find.widgetWithText(ManufacturerSystemPicker, 'Fabricant'),
          matching: find.byTooltip('Supprimer ce fabricant'),
        ),
        findsOneWidget,
        reason:
            'User-created manufacturers must show the delete affordance '
            'with its existing confirmation flow.',
      );
    },
  );

  testWidgets(
    'built-in system (isBuiltIn: true) hides the delete button',
    (tester) async {
      // Same rule for systems: the seeded ME 14800 system (which the
      // p. 65 calculator needs to be present) must not be deletable.
      final seeded = withBuiltInCatalogSeed(const Catalog());
      await _pump(
        tester,
        seeded,
        c: _stubConstruction(
          manufacturer: 'Maghreb Extrusion (ME)',
          manufacturerId: maghrebExtrusionId,
          system: 'Série 14800 Frappe',
          systemId: meSerie14800Id,
        ),
      );

      expect(
        find.descendant(
          of: find.widgetWithText(ManufacturerSystemPicker, 'Système'),
          matching: find.byTooltip('Supprimer ce système'),
        ),
        findsNothing,
        reason:
            'Built-in systems must not show a delete affordance. The '
            'calculator routes every 14800-backed construction through '
            'this rule set; deleting it would silently break every '
            'downstream calculation.',
      );
    },
  );

  testWidgets(
    'user-created system (isBuiltIn: false) shows the delete button '
    'even under a built-in manufacturer',
    (tester) async {
      // A user-created system under a built-in manufacturer: the
      // manufacturer itself is built-in (so its delete stays hidden)
      // but the system is user-created so its delete shows.
      final seeded = withBuiltInCatalogSeed(const Catalog());
      final me = seeded.manufacturers.firstWhere(
        (m) => m.id == maghrebExtrusionId,
      );
      const userSysId = 'sys-user-1';
      final userSystem = ProfileSystem(
        id: userSysId,
        manufacturer: me.name,
        manufacturerId: me.id,
        name: 'My custom system',
        ruleSetId: 'generic-placeholder',
        profiles: const [],
        supportedOpenings: const [],
        isBuiltIn: false,
      );
      final catalog = seeded.copyWith(
        profileSystems: [...seeded.profileSystems, userSystem],
      );
      await _pump(
        tester,
        catalog,
        c: _stubConstruction(
          manufacturer: me.name,
          manufacturerId: me.id,
          system: userSystem.name,
          systemId: userSysId,
        ),
      );

      // Manufacturer delete hidden (built-in), system delete shown
      // (user-created).
      expect(
        find.descendant(
          of: find.widgetWithText(ManufacturerSystemPicker, 'Fabricant'),
          matching: find.byTooltip('Supprimer ce fabricant'),
        ),
        findsNothing,
        reason: 'Built-in manufacturer: delete stays hidden.',
      );
      expect(
        find.descendant(
          of: find.widgetWithText(ManufacturerSystemPicker, 'Système'),
          matching: find.byTooltip('Supprimer ce système'),
        ),
        findsOneWidget,
        reason: 'User-created system: delete is shown.',
      );
    },
  );

  testWidgets(
    'built-in system remains selectable and inspectable (Profils + Fiche)',
    (tester) async {
      // The guard must not turn built-in systems into dead UI. They
      // stay selectable, and the Profils / Fiche système buttons
      // remain reachable for the user to inspect their content.
      final seeded = withBuiltInCatalogSeed(const Catalog());
      await _pump(
        tester,
        seeded,
        c: _stubConstruction(
          manufacturer: 'Maghreb Extrusion (ME)',
          manufacturerId: maghrebExtrusionId,
          system: 'Série 14800 Frappe',
          systemId: meSerie14800Id,
        ),
      );

      // The two inspect-only affordances are still there.
      expect(find.text('Profils (21)'), findsOneWidget,
          reason: 'The 14800 system has 21 seeded profiles.');
      expect(find.text('Fiche système'), findsOneWidget);
    },
  );
}
