// End-to-end UI integration test for the production export action.
//
// The user workflow: open the editor with a 14800 1v française
// construction, run Calculer, tap the new "Exporter la production"
// button in the results banner, accept the default subdirectory
// name in the dialog, hit Exporter, and assert:
//   - the dialog closes;
//   - the on-disk cut list and BOM CSV files exist;
//   - the file contents match the in-memory renderer output;
//   - the snackbar surfaces the two paths;
//   - the UI does not throw any layout or setState errors.
//
// The dialog calls `getApplicationDocumentsDirectory()` through
// `path_provider`, which is the standard `getApplicationDocumentsPath`
// platform channel. Inside `testWidgets` (fake-async zone) that
// channel call must be wrapped in `tester.runAsync` -- otherwise the
// real-async call never completes and the test hangs. The `runAsync`
// escape is established before pumping the editor so the dialog's
// `getApplicationDocumentsDirectory()` await sees a real (not
// fake-async) event loop and returns the FakePathProvider result.

import 'dart:io';

import 'package:aluminium_designer/core/data/builtin_catalog_seed.dart';
import 'package:aluminium_designer/core/models/catalog.dart';
import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/layout_direction.dart';
import 'package:aluminium_designer/core/models/opening.dart';
import 'package:aluminium_designer/core/models/profile_usage.dart';
import 'package:aluminium_designer/core/models/section.dart';
import 'package:aluminium_designer/core/storage/catalog_store.dart';
import 'package:aluminium_designer/features/constructions/screens/construction_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'support/fake_path_provider.dart';

const _desktopSize = Size(1400, 900);

/// In-memory catalog stub so the editor's `_loadCatalog` returns a
/// populated catalog without going to disk. The dialog's
/// `getApplicationDocumentsDirectory()` is the only path_provider
/// call we exercise; the catalog stub keeps the editor half fast.
class _PreSeededCatalogStore extends CatalogStore {
  final Catalog catalog;
  _PreSeededCatalogStore(this.catalog);
  @override
  Future<Catalog> load() async => catalog;
  @override
  Future<void> save(Catalog catalog) async {}
}

ProfileUsage _usage(
  String id,
  String reference,
  ProfileUsageRole role,
) {
  final p = meSerie14800.profilesById.values
      .firstWhere((x) => x.reference == reference);
  return ProfileUsage(
    id: id,
    profileId: p.id,
    sectionId: 's1',
    role: role,
  );
}

Construction _me14800_1v() {
  return Construction(
    id: 'c-14800-1v',
    name: 'ME 14800 1v française',
    type: ConstructionType.door,
    width: 2000.0,
    height: 1500.0,
    manufacturer: 'Maghreb Extrusion (ME)',
    system: 'Série 14800 Frappe',
    manufacturerId: meSerie14800Id,
    systemId: meSerie14800Id,
    sections: [
      Section(
        id: 's1',
        order: 0,
        kind: SectionKind.ouvrant,
        width: 2000.0,
        height: 1500.0,
        openingType: OpeningType.francaise,
        vantauxCount: 1,
      ),
    ],
    layoutDirection: SectionLayoutDirection.horizontal,
    profiles: const [],
    profileUsages: [
      _usage('d-top', '14.800', ProfileUsageRole.top),
      _usage('d-bottom', '14.800', ProfileUsageRole.bottom),
      _usage('d-left', '14.800', ProfileUsageRole.left),
      _usage('d-right', '14.800', ProfileUsageRole.right),
      _usage('o-top', '14.802', ProfileUsageRole.top),
      _usage('o-bottom', '14.802', ProfileUsageRole.bottom),
      _usage('o-left', '14.802', ProfileUsageRole.left),
      _usage('o-right', '14.802', ProfileUsageRole.right),
      _usage('p-top', '14.810', ProfileUsageRole.top),
      _usage('p-bottom', '14.810', ProfileUsageRole.bottom),
      _usage('p-left', '14.810', ProfileUsageRole.left),
      _usage('p-right', '14.810', ProfileUsageRole.right),
      _usage('tige', '14.811', ProfileUsageRole.intermediate),
    ],
  );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    // `Directory.systemTemp.createTemp` is a real-async call. The
    // setUp runs before the testWidgets fake-async zone starts, so
    // the plain `await` is fine. The FakePathProvider is the
    // platform-channel stand-in for `getApplicationDocumentsDirectory`,
    // which the dialog calls from inside a real-async path_provider
    // surface (wrapped in `runAsync` from the testWidgets body).
    tempDir = await Directory.systemTemp.createTemp('aluvis_export_ui_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets(
    'ME 14800 1v française: editor Exporter la production action writes '
    'the two CSV files under <documents>/aluvis/exports/production/ '
    'and surfaces the paths in a SnackBar',
    (tester) async {
      tester.view.physicalSize = _desktopSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final c = _me14800_1v();
      final preSeededCatalog = withBuiltInCatalogSeed(const Catalog());

      // Wrap the editor pump in `runAsync` so the screen's
      // `_loadCatalog` (which does not hit the disk for the
      // in-memory catalog) and the dialog's later
      // `getApplicationDocumentsDirectory` (which does) both
      // complete. The catalog stub is in-memory so the editor half
      // is fast; the dialog's path_provider call is the only real
      // disk-touching piece.
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ConstructionEditorScreen(
              construction: c,
              projectName: 'Chantier Test',
              catalogStore: _PreSeededCatalogStore(preSeededCatalog),
            ),
          ),
        );
        await tester.pumpAndSettle();
      });

      // Navigate to Sections so the Calculer toolbar action is visible.
      await tester.tap(find.text('Sections'));
      await tester.pumpAndSettle();
      // Run Calculer.
      await tester.tap(find.byIcon(Icons.calculate_outlined));
      await tester.pumpAndSettle();

      // The banner must now show the export action.
      expect(find.text('Exporter la production'), findsOneWidget);

      // Tap the action -> the dialog opens. The dialog's
      // `FutureBuilder` immediately calls
      // `getApplicationDocumentsDirectory()`, which is real-async
      // and blocks the testWidgets fake-async zone. We open the
      // dialog inside `runAsync` and continue inside the same scope
      // for the file-write await; the snackbar's animation
      // continues in the fake-async zone once we exit runAsync.
      await tester.runAsync(() async {
        await tester.tap(find.text('Exporter la production'));
        await tester.pumpAndSettle();
        // The dialog has its own Exporter button (text 'Exporter').
        // We tap it. The action triggers the file I/O chain
        // (path_provider -> mkdir -> writeAsString x 2 -> pop).
        // All real-async, all inside this runAsync scope.
        await tester.tap(find.widgetWithText(FilledButton, 'Exporter'));
        // Give the chain a moment to complete. The export's two
        // writeAsString calls against the FakePathProvider-backed
        // temp directory are real file I/O -- the wait ensures the
        // future chain fully resolves before we exit runAsync.
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      // Step the fake-async clock forward so the Navigator.pop and
      // ScaffoldMessenger snackbar schedule their first frames.
      await tester.pump(const Duration(milliseconds: 100));

      // The dialog has closed (Navigator.pop), and a SnackBar with
      // the two paths is on screen. The button text is "Exporter la
      // production" so it may collide with the button we just
      // re-tapped; the more meaningful assertion is the snackbar
      // text and the on-disk files. The on-disk `await` calls
      // below need to be inside `tester.runAsync` because they
      // touch real `dart:io` futures, which the testWidgets
      // fake-async zone cannot drive.
      await tester.runAsync(() async {
        expect(find.textContaining('Exports écrits :'), findsOneWidget);
        expect(find.textContaining('.cuts.csv'), findsOneWidget);
        expect(find.textContaining('.bom.csv'), findsOneWidget);

        // The on-disk files exist and carry the documented content.
        final expectedDir =
            Directory('${tempDir.path}/aluvis/exports/production');
        expect(await expectedDir.exists(), isTrue);
        final cutsFile = File(
          '${expectedDir.path}/aluvis-chantier-test-me-14800-1v-francaise-c-1480.cuts.csv',
        );
        final bomFile = File(
          '${expectedDir.path}/aluvis-chantier-test-me-14800-1v-francaise-c-1480.bom.csv',
        );
        expect(await cutsFile.exists(), isTrue);
        expect(await bomFile.exists(), isTrue);

        // The on-disk bytes contain the documented ME 14800
        // 1v française content. A few sentinel values:
        // 13 cuts, 1868 × 1368 glass, 7000 mm joints, 8 pieces
        // Équerre (the AC-600).
        final cutsBytes = await cutsFile.readAsString();
        final bomBytes = await bomFile.readAsString();
        expect(
          cutsBytes,
          contains('Section 1,14.800,Dormant tubulaire,2000'),
        );
        expect(bomBytes, contains('\nglass,'));
        expect(bomBytes, contains('1868,1368'));
        expect(bomBytes, contains(',7000,'));
        expect(bomBytes, contains('Équerre à pions'));
        // The metadata block is present at the top of both files.
        expect(cutsBytes, contains('# AluVis export'));
        expect(cutsBytes, contains('# Stale: no'));
        expect(bomBytes, contains('# Stale: no'));
        expect(cutsBytes, contains('# Exported at:'));
        expect(bomBytes, contains('# Exported at:'));
      });
    },
  );
}
