// P1 runtime UI verification: the user asked for an end-to-end real
// workflow. Driving the real mouse through a live Wayland window is
// not reliable (wtype routes to the wrong surface when the compositor's
// focus state doesn't match what we expected), so this is a Flutter
// integration test that pumps the REAL `ConstructionEditorScreen`
// (which is what the user sees in the running app) with a real ME
// 14800 1v française construction. The test asserts the SAME values
// the user would see in the banner, the cut list, and the BOM -- the
// dialogs are the canonical surface, and the assertions below pin the
// printed formulas from p. 65 verbatim.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// Wide enough to clear the workspace's `_kMinDesktopWidth` (900) floor
/// and the dialogs' `Dialog.fullscreen` size.
const _desktopSize = Size(1400, 900);

/// Stub store that returns a [Catalog] built from the REAL built-in seed
/// (so the test exercises the real 14800 profile/rule set) and swallows
/// saves (no filesystem I/O under flutter_test's fake-async zone).
class _RealSeedCatalogStore extends CatalogStore {
  final Catalog catalog;
  _RealSeedCatalogStore(this.catalog);
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

Construction me14800_1vFrancaise() => Construction(
  id: 'c-14800',
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
  // The full per-usage placement the user asked for: 4 dormant
  // (top/bottom/left/right), 4 ouvrant 14.802, 4 parclose 14.810,
  // 1 tige 14.811.
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

Future<void> _pump(WidgetTester tester, Construction c) async {
  tester.view.physicalSize = _desktopSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final catalog = withBuiltInCatalogSeed(const Catalog());
  await tester.pumpWidget(
    MaterialApp(
      home: ConstructionEditorScreen(
        construction: c,
        catalogStore: _RealSeedCatalogStore(catalog),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'P1 runtime UI verification: ME 14800 1v française end-to-end',
    (tester) async {
      await _pump(tester, me14800_1vFrancaise());

      // The user starts on the General tab; navigate to Sections so the
      // Calculer toolbar action is visible.
      await tester.tap(find.text('Sections'));
      await tester.pumpAndSettle();

      // Press Calculer (the toolbar action).
      await tester.tap(find.byIcon(Icons.calculate_outlined));
      await tester.pumpAndSettle();

      // -- RESULTS BANNER --
      // The banner shows "13 coupe(s)" (4 dormant + 4 ouvrant + 4
      // parclose + 1 tige = 13) and a "Liste de découpe" + "BOM" button
      // (P1 commit 6 added the BOM button).
      expect(find.text('13 coupe(s)'), findsOneWidget);
      expect(find.text('Liste de découpe'), findsOneWidget);
      expect(find.text('BOM'), findsOneWidget);

      // -- LISTE DE DÉCOUPE --
      // The workshop view shows the 13 cuts grouped by section. Lengths
      // are formatted with toStringAsFixed(0) (whole mm) -- the exact
      // printed formulas from p. 65 of the 1v française column:
      // - 14.800 top/bottom: L = 2000 mm
      // - 14.800 left/right: H = 1500 mm
      // - 14.802 top/bottom: L - 35.2 = 1965 mm
      // - 14.802 left/right: H - 35.2 = 1465 mm
      // - 14.810 top/bottom beside 14.802: L - 117.6 = 1882 mm
      // - 14.810 left/right beside 14.802: H - 157.6 = 1342 mm
      // - 14.811 tige: H - 90 = 1410 mm
      // The dialog groups identical cuts into one line (×quantity), so
      // each value appears at least once (cut-list dialog row); the
      // banner also shows per-cut rows behind the fullscreen dialog,
      // so we use findsAtLeastNWidgets(1) rather than findsOneWidget
      // to keep the assertion robust to that overlap.
      await tester.tap(find.text('Liste de découpe'));
      await tester.pumpAndSettle();
      expect(find.text('Liste de découpe'), findsWidgets);
      expect(find.textContaining('2000 mm'), findsAtLeastNWidgets(1));
      expect(find.textContaining('1965 mm'), findsAtLeastNWidgets(1));
      expect(find.textContaining('1882 mm'), findsAtLeastNWidgets(1));
      expect(find.textContaining('1500 mm'), findsAtLeastNWidgets(1));
      expect(find.textContaining('1465 mm'), findsAtLeastNWidgets(1));
      expect(find.textContaining('1342 mm'), findsAtLeastNWidgets(1));
      expect(find.textContaining('1410 mm'), findsAtLeastNWidgets(1));
      // Close the cut-list dialog.
      await tester.tap(find.byTooltip('Fermer').first);
      await tester.pumpAndSettle();

      // -- BOM --
      // P1 commit 6: the BOM dialog groups profile + glass + hardware +
      // accessories into 4 sections. Verify the user can open it and
      // every domain is visible with the exact p. 65 quantities.
      await tester.tap(find.text('BOM'));
      await tester.pumpAndSettle();
      // BOM header: total pieces (profile + glass + hardware +
      // accessory quantities) + vitrage m² + hardware m.
      // Vitrage 1868×1368 = 2,555,424 mm² = 2.56 m²; hardware
      // 3 joints × 7000 mm = 21,000 mm = 21.00 m.
      expect(find.textContaining('2.56 m²'), findsAtLeastNWidgets(1));
      expect(find.textContaining('21.00 m'), findsAtLeastNWidgets(1));
      // Four domain section titles.
      expect(find.text('Profilés'), findsOneWidget);
      expect(find.text('Vitrage'), findsOneWidget);
      expect(find.text('Quincaillerie'), findsOneWidget);
      expect(find.text('Accessoires'), findsOneWidget);
      // 1868×1368 glass line for 14.802 (the dominant ouvrant).
      expect(find.textContaining('1868 × 1368 mm'), findsAtLeastNWidgets(1));
      // Hardware: 3 length-bearing joints at 7000 mm × 1 each. The
      // other 8 hardware items are count-only and appear with their
      // quantity ("N pièces") in the main row.
      expect(find.textContaining('7000 mm'), findsAtLeastNWidgets(1));
      expect(find.textContaining('8 pièces'), findsAtLeastNWidgets(1));

      // No layout exceptions anywhere in the workflow.
      expect(tester.takeException(), isNull);

      // Close the BOM dialog.
      await tester.tap(find.byTooltip('Fermer').first);
      await tester.pumpAndSettle();
    },
  );
}
