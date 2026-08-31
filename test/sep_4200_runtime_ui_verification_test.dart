// System-completion phase runtime UI verification for Sepalumic Série
// 4200 OF 1-vantail française and OF 2-vantaux française, the
// canonical configurations documented in docs/VERIFIED_SOURCES.md
// section M-2 (Catalogue Technique Éd. 05, sheets E070/E150).
// Mirrors the ME 14600/14800 runtime tests
// (test/me_14600_runtime_ui_verification_test.dart,
// test/me_14800_runtime_ui_p1_verification_test.dart): pumps the REAL
// ConstructionEditorScreen with the REAL seeded catalog and asserts
// the EXACT values the user would see in the banner, the cut list,
// and the BOM dialogs.

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
  final p = sepSerie4200.profilesById.values
      .firstWhere((x) => x.reference == reference);
  return ProfileUsage(
    id: id,
    profileId: p.id,
    sectionId: 's1',
    role: role,
  );
}

/// OF 1 vantail française (sheet E070) at L=2000 / H=1500:
///   Dormant 4220 ............ 2+2 × (L ; H)
///   Ouvrant 4211 ............ 2 × (L−43.5) + 2 × (H−43.5)
/// All quantities / formulas transcribed from sheet E070 (M-2).
/// 8 cuts, 8 pieces, all 45° mitres.
Construction sep4200Of1vFrancaise() => Construction(
  id: 'c-sep-4200-1v',
  name: 'Sepalumic 4200 OF 1v',
  type: ConstructionType.window,
  width: 2000.0,
  height: 1500.0,
  manufacturer: 'Sepalumic',
  system: 'Série 4200',
  manufacturerId: sepalumicId,
  systemId: sepSerie4200Id,
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
    _usage('d-top', '4220', ProfileUsageRole.top),
    _usage('d-bottom', '4220', ProfileUsageRole.bottom),
    _usage('d-left', '4220', ProfileUsageRole.left),
    _usage('d-right', '4220', ProfileUsageRole.right),
    _usage('o-top', '4211', ProfileUsageRole.top),
    _usage('o-bottom', '4211', ProfileUsageRole.bottom),
    _usage('o-left', '4211', ProfileUsageRole.left),
    _usage('o-right', '4211', ProfileUsageRole.right),
  ],
);

/// OF 2 vantaux française (sheet E150) at L=2000 / H=1500:
///   Dormant 4220 ............ 2+2 × (L ; H)
///   Ouvrant 4211 ............ 2 × ((L/2)−24) traverses + 2 × (H−43.5) montants
///   Battue centrale 4206 ..... 1 × (H−102) intermediate (90°)
/// 9 cuts, 13 pieces.
Construction sep4200Of2vFrancaise() => Construction(
  id: 'c-sep-4200-2v',
  name: 'Sepalumic 4200 OF 2v',
  type: ConstructionType.window,
  width: 2000.0,
  height: 1500.0,
  manufacturer: 'Sepalumic',
  system: 'Série 4200',
  manufacturerId: sepalumicId,
  systemId: sepSerie4200Id,
  sections: [
    Section(
      id: 's1',
      order: 0,
      kind: SectionKind.ouvrant,
      width: 2000.0,
      height: 1500.0,
      openingType: OpeningType.francaise,
      vantauxCount: 2,
    ),
  ],
  layoutDirection: SectionLayoutDirection.horizontal,
  profiles: const [],
  profileUsages: [
    _usage('d-top', '4220', ProfileUsageRole.top),
    _usage('d-bottom', '4220', ProfileUsageRole.bottom),
    _usage('d-left', '4220', ProfileUsageRole.left),
    _usage('d-right', '4220', ProfileUsageRole.right),
    _usage('o-top', '4211', ProfileUsageRole.top),
    _usage('o-bottom', '4211', ProfileUsageRole.bottom),
    _usage('o-left', '4211', ProfileUsageRole.left),
    _usage('o-right', '4211', ProfileUsageRole.right),
    _usage('bc-intermediate', '4206', ProfileUsageRole.intermediate),
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

Future<void> _runCutListAndBomAssertions(
  WidgetTester tester, {
  required int expectedCutCount,
  required int expectedPieces,
  required String expectedMetrage,
  required List<String> expectedLengthsMm,
}) async {
  // -- BANNER --
  expect(
    find.text('$expectedCutCount coupe(s)'),
    findsOneWidget,
  );
  expect(find.text('Liste de découpe'), findsOneWidget);
  expect(find.text('BOM'), findsOneWidget);

  // -- LISTE DE DÉCOUPE --
  await tester.tap(find.text('Liste de découpe'));
  await tester.pumpAndSettle();
  expect(find.text('Liste de découpe'), findsWidgets);
  for (final length in expectedLengthsMm) {
    expect(
      find.textContaining('$length mm'),
      findsAtLeastNWidgets(1),
      reason: 'Cut-list dialog should surface $length mm (printed at '
          'whole-mm precision per toStringAsFixed(0)).',
    );
  }
  expect(
    find.textContaining('$expectedPieces pièces'),
    findsAtLeastNWidgets(1),
    reason: 'Cut-list total pieces must match the source-derived count.',
  );
  expect(
    find.textContaining(expectedMetrage),
    findsAtLeastNWidgets(1),
    reason: 'Cut-list grand total metrage must match the source-derived '
        'value.',
  );
  // Close the cut-list dialog.
  await tester.tap(find.byTooltip('Fermer').first);
  await tester.pumpAndSettle();

  // -- BOM --
  await tester.tap(find.text('BOM'));
  await tester.pumpAndSettle();
  expect(find.text('Profilés'), findsOneWidget);
  // 4200 has no glass / hardware / accessories rules (M-2 documents
  // profile cuts only). The three other domain sections are NOT
  // rendered -- this is the honest "no source-backed data" state.
  expect(find.text('Vitrage'), findsNothing);
  expect(find.text('Quincaillerie'), findsNothing);
  expect(find.text('Accessoires'), findsNothing);
  // The noRuleMatched diagnostics for glass / hardware ARE surfaced
  // because every opening section fires one.
  expect(find.text('Sections sans vitrage'), findsOneWidget);
  expect(find.text('Sections sans quincaillerie'), findsOneWidget);
  // Profilés lines themselves (per-line total text appears in the
  // dialog for each grouped cut).
  expect(find.textContaining('4220'), findsAtLeastNWidgets(1));
  expect(find.textContaining('4211'), findsAtLeastNWidgets(1));
  // No layout exceptions anywhere in the workflow.
  expect(tester.takeException(), isNull);
  // Close the BOM dialog.
  await tester.tap(find.byTooltip('Fermer').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'system-completion: Sepalumic 4200 OF 1v française end-to-end (E070)',
    (tester) async {
      // L=2000 / H=1500. 8 cuts, 8 pieces: 4 dormant (2 L + 2 H) + 4
      // ouvrant 4211 (2 (L-43.5) + 2 (H-43.5)).
      // (L-43.5)=1956.5 -> 1957 mm; (H-43.5)=1456.5 -> 1457 mm.
      // Total length: 2*2000 + 2*1500 + 2*1957 + 2*1457 = 13826 mm
      // = 13.83 m.
      await _pump(tester, sep4200Of1vFrancaise());
      await tester.tap(find.text('Sections'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.calculate_outlined));
      await tester.pumpAndSettle();

      await _runCutListAndBomAssertions(
        tester,
        expectedCutCount: 8,
        expectedPieces: 8,
        expectedMetrage: '13.83 m',
        expectedLengthsMm: ['2000', '1500', '1957', '1457'],
      );
    },
  );

  testWidgets(
    'system-completion: Sepalumic 4200 OF 2v française end-to-end (E150)',
    (tester) async {
      // L=2000 / H=1500. 9 cuts, 13 pieces:
      //   dormant 4220 x 4 ........ 2x2000 + 2x1500
      //   ouvrant 4211 x 4 ....... 2x((L/2)-24)=2x976 travers + 2x(H-43.5)=2x1456.5 montants,
      //                              each with quantity=2 (paired top+bottom / left+right)
      //   battue 4206 x 1 ........ 1x(H-102)=1x1398 intermediate (90°)
      // Total length: 2*2000 + 2*1500 + 4*976 + 4*1456.5 + 1*1398
      //              = 4000 + 3000 + 3904 + 5826 + 1398 = 18128 mm
      //              = 18.13 m.
      await _pump(tester, sep4200Of2vFrancaise());
      await tester.tap(find.text('Sections'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.calculate_outlined));
      await tester.pumpAndSettle();

      await _runCutListAndBomAssertions(
        tester,
        expectedCutCount: 9,
        expectedPieces: 13,
        expectedMetrage: '18.13 m',
        expectedLengthsMm: ['2000', '1500', '976', '1457', '1398'],
      );

      // The battue centrale is the only 90° cut in the 4200 rule set.
      // The banner surfaces per-cut rows behind the dialog, so the
      // 90° angles text appears via the battue's per-cut row.
      expect(
        find.textContaining('(90° / 90°)'),
        findsAtLeastNWidgets(1),
        reason: 'Battue centrale 4206 is the only square-cut rule in the '
            'encoded 4200 debit; its row must reach the user.',
      );
    },
  );
}
