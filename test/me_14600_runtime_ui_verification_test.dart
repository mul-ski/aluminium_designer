// System-completion phase runtime UI verification for ME 14600 2-vantaux
// coulissante, the canonical configuration documented in
// docs/VERIFIED_SOURCES.md section S-1 (p. 24, "2 vantaux" column).
// Mirrors the ME 14800 P1 runtime test (test/me_14800_runtime_ui_p1_
// verification_test.dart): pumps the REAL ConstructionEditorScreen with
// the REAL seeded catalog and asserts the EXACT values the user would
// see in the banner, the cut list, and the BOM dialogs.
//
// Source: every length, formula, and provenance string in this test
// traces verbatim to the p. 24 débitage table. No fabrication, no
// re-derivation -- the test is the contractual proof that the editor's
// UI surfaces the same numbers the calculator's domain layer produces
// and the source document's table prescribes.

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

const _desktopSize = Size(1400, 900);

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
  final p = meSerie14600.profilesById.values
      .firstWhere((x) => x.reference == reference);
  return ProfileUsage(
    id: id,
    profileId: p.id,
    sectionId: 's1',
    role: role,
  );
}

/// The documented 2-vantaux unit at L=2000 / H=1500:
///   Dormant 14 617 ........ 2+2 × (L ; H)
///   Montant latéral 14 622/14 623 .. 2 × (H−74)
///   Traverse 14 621 ....... 4 × (L−64)/2
/// All quantities / formulas transcribed from p. 24 (S-1).
Construction me14600_2vCoulissante() => Construction(
  id: 'c-14600',
  name: 'ME 14600 2v coulissante',
  type: ConstructionType.window,
  width: 2000.0,
  height: 1500.0,
  manufacturer: 'Maghreb Extrusion (ME)',
  system: 'Série 14600 Coulissant',
  manufacturerId: meSerie14600Id,
  systemId: meSerie14600Id,
  sections: [
    Section(
      id: 's1',
      order: 0,
      kind: SectionKind.ouvrant,
      width: 2000.0,
      height: 1500.0,
      openingType: OpeningType.coulissante,
      vantauxCount: 2,
    ),
  ],
  layoutDirection: SectionLayoutDirection.horizontal,
  profiles: const [],
  profileUsages: [
    _usage('d-top', '14 617', ProfileUsageRole.top),
    _usage('d-bottom', '14 617', ProfileUsageRole.bottom),
    _usage('d-left', '14 617', ProfileUsageRole.left),
    _usage('d-right', '14 617', ProfileUsageRole.right),
    _usage('m-left', '14 622', ProfileUsageRole.left),
    _usage('m-right', '14 623', ProfileUsageRole.right),
    _usage('t-top', '14 621', ProfileUsageRole.top),
    _usage('t-bottom', '14 621', ProfileUsageRole.bottom),
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
        projectName: 'Chantier Test',
        catalogStore: _RealSeedCatalogStore(catalog),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'system-completion: ME 14600 2v coulissante end-to-end',
    (tester) async {
      await _pump(tester, me14600_2vCoulissante());

      // The user starts on the General tab; navigate to Sections so
      // the Calculer toolbar action is visible.
      await tester.tap(find.text('Sections'));
      await tester.pumpAndSettle();

      // Press Calculer.
      await tester.tap(find.byIcon(Icons.calculate_outlined));
      await tester.pumpAndSettle();

      // -- RESULTS BANNER --
      // 8 cuts at L=2000/H=1500: 2 dormant at L + 2 at H + 2 montant
      // at (H−74) + 2 traverse at (L−64)/2. The banner's cut count
      // is per-cut, not per-piece: the 2 traverse placements carry
      // quantity=2 each, but the banner shows the per-cut count.
      expect(find.text('8 coupe(s)'), findsOneWidget);
      expect(find.text('Liste de découpe'), findsOneWidget);
      expect(find.text('BOM'), findsOneWidget);

      // -- LISTE DE DÉCOUPE --
      // The workshop view groups identical cuts. The p. 24 unit's
      // expected groups:
      //   14 617 — Dormant : 2 pièces — 2000 mm — (45°/45°)   (top+bottom)
      //   14 617 — Dormant : 2 pièces — 1500 mm — (45°/45°)   (left+right)
      //   14 622 — Montant latéral : 1 pièce — 1426 mm — (45°/45°)
      //   14 623 — Montant latéral : 1 pièce — 1426 mm — (45°/45°)
      //   14 621 — Traverse : 4 pièces — 968 mm — (45°/45°)    (top+bottom merged)
      // All lengths toStringAsFixed(0): (H−74)=1426, (L−64)/2=968.
      // The banner also surfaces the per-cut rows behind the dialog,
      // so the per-length text appears at least once.
      await tester.tap(find.text('Liste de découpe'));
      await tester.pumpAndSettle();
      expect(find.text('Liste de découpe'), findsWidgets);
      expect(find.textContaining('2000 mm'), findsAtLeastNWidgets(1));
      expect(find.textContaining('1500 mm'), findsAtLeastNWidgets(1));
      expect(find.textContaining('1426 mm'), findsAtLeastNWidgets(1));
      expect(find.textContaining('968 mm'), findsAtLeastNWidgets(1));
      // Total piece count: 2+2+1+1+4 = 10.
      expect(find.textContaining('10 pièces'), findsAtLeastNWidgets(1));
      // Close the cut-list dialog.
      await tester.tap(find.byTooltip('Fermer').first);
      await tester.pumpAndSettle();

      // -- BOM --
      // ME 14600 has no glass rules and no hardware rules in the
      // seeded system (S-1 documents profile cuts only; glass/hardware
      // tables in the source are not transcribed). The BOM dialog
      // renders the Profilés section with the same 4 grouped lines as
      // the cut list, and surfaces the noRuleMatched diagnostic for
      // glass and hardware domains.
      await tester.tap(find.text('BOM'));
      await tester.pumpAndSettle();
      // The Profilés domain is present.
      expect(find.text('Profilés'), findsOneWidget);
      // Vitrage / Quincaillerie / Accessoires are NOT present -- the
      // byDomain map does not contain them. This is the honest
      // "no source-backed data" surface for this system.
      expect(find.text('Vitrage'), findsNothing);
      expect(find.text('Quincaillerie'), findsNothing);
      expect(find.text('Accessoires'), findsNothing);
      // The diagnostics for missing glass / hardware are surfaced in
      // the BOM dialog per the per-section diagnostic block.
      expect(find.text('Sections sans vitrage'), findsOneWidget);
      expect(find.text('Sections sans quincaillerie'), findsOneWidget);
      // The Profilés lines themselves (the same 4 grouped lines as
      // the cut list, plus their secondary metrage row).
      expect(find.textContaining('14 617'), findsAtLeastNWidgets(1));
      expect(find.textContaining('14 622'), findsAtLeastNWidgets(1));
      expect(find.textContaining('14 623'), findsAtLeastNWidgets(1));
      expect(find.textContaining('14 621'), findsAtLeastNWidgets(1));
      // Total metrage: 2×2000 + 2×1500 + 2×1426 + 4×968 = 13724 mm
      // = 13.72 m. The Profilés domain's grand total appears as
      // "Total : 10 pièces — 13.72 m" (or similar per the dialog
      // format); we assert the metrage value which is unambiguous.
      expect(find.textContaining('13.72 m'), findsAtLeastNWidgets(1));

      // No layout exceptions anywhere in the workflow.
      expect(tester.takeException(), isNull);

      // Close the BOM dialog.
      await tester.tap(find.byTooltip('Fermer').first);
      await tester.pumpAndSettle();
    },
  );
}
