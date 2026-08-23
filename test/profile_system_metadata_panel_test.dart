import 'package:aluminium_designer/core/models/catalog.dart';
import 'package:aluminium_designer/core/models/profile_system.dart';
import 'package:aluminium_designer/core/models/profile_system_metadata.dart';
import 'package:aluminium_designer/features/constructions/widgets/profile_system_metadata_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ProfileSystem _system() => const ProfileSystem(
  id: 'sys-1',
  manufacturer: 'Atelier',
  manufacturerId: 'man-1',
  name: 'Système test',
  ruleSetId: 'generic-placeholder',
  profiles: [],
  supportedOpenings: [],
  isBuiltIn: false,
  metadata: null,
);

ProfileSystem _populated(ProfileSystemMetadata metadata) {
  final system = _system();
  return ProfileSystem(
    id: system.id,
    manufacturer: system.manufacturer,
    manufacturerId: system.manufacturerId,
    name: system.name,
    ruleSetId: system.ruleSetId,
    profiles: system.profiles,
    supportedOpenings: system.supportedOpenings,
    isBuiltIn: system.isBuiltIn,
    metadata: metadata,
  );
}

/// Scrolls the panel's form until [finder] is built and visible -- the
/// fiche is a long ListView and its children are built lazily, so
/// off-screen fields genuinely do not exist in the tree yet.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  required Catalog catalog,
  required ProfileSystem system,
  required ValueChanged<Catalog> onCatalogChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProfileSystemMetadataPanel(
          catalog: catalog,
          system: system,
          onCatalogChanged: onCatalogChanged,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens pre-filled from existing metadata', (tester) async {
    final populated = _populated(
      const ProfileSystemMetadata(
        frameDepthOptionsMm: [44.0, 66.34],
        sashStileDepthOptionsMm: [56.0, 69.2],
        glazingRebateMm: 26.0,
        glazingMinMm: 6.0,
        glazingMaxMm: 22.0,
        dimensionLimits: [
          DimensionLimit(maxWidthMm: 1600, maxHeightMm: 1800),
          DimensionLimit(maxWidthMm: 2500, maxHeightMm: 2500),
        ],
        sourceDescription: 'PDF constructeur',
      ),
    );

    await _pumpPanel(
      tester,
      catalog: Catalog(profileSystems: [populated]),
      system: populated,
      onCatalogChanged: (_) => fail('opening the panel must not save'),
    );

    expect(find.text('44.00, 66.34'), findsOneWidget);
    expect(find.text('56.00, 69.20'), findsOneWidget);
    expect(find.text('26.00'), findsOneWidget);

    await _scrollTo(tester, find.text('Non renseigné'));
    expect(find.text('Non renseigné'), findsOneWidget);

    await _scrollTo(tester, find.text('1600'));
    expect(find.text('1600'), findsOneWidget);
    expect(find.text('1800'), findsOneWidget);

    // '2500' appears twice: the L max AND H max fields of the
    // 2500x2500 envelope row.
    await _scrollTo(tester, find.text('2500').first);
    expect(find.text('2500'), findsNWidgets(2));

    await _scrollTo(tester, find.text('PDF constructeur'));
    expect(find.text('PDF constructeur'), findsOneWidget);
  });

  testWidgets('editing a limit and saving updates the catalog system',
      (tester) async {
    final populated = _populated(
      const ProfileSystemMetadata(
        frameDepthOptionsMm: [44.0],
        dimensionLimits: [DimensionLimit(maxWidthMm: 1600, maxHeightMm: 1800)],
        sourceDescription: 'PDF constructeur',
      ),
    );
    Catalog? saved;

    await _pumpPanel(
      tester,
      catalog: Catalog(profileSystems: [populated]),
      system: populated,
      onCatalogChanged: (catalog) => saved = catalog,
    );

    await _scrollTo(tester, find.text('1600'));
    await tester.enterText(find.widgetWithText(TextField, '1600'), '2000');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    final updated = saved!.profileSystems.single;
    expect(updated.id, 'sys-1');
    expect(updated.ruleSetId, 'generic-placeholder');
    expect(updated.metadata!.frameDepthOptionsMm, [44.0]);
    expect(updated.metadata!.dimensionLimits.single.maxWidthMm, 2000);
    expect(updated.metadata!.dimensionLimits.single.maxHeightMm, 1800);
    expect(updated.metadata!.sourceDescription, 'PDF constructeur');
  });

  testWidgets('thermal-break tri-state saves true', (tester) async {
    final system = _system();
    Catalog? saved;

    await _pumpPanel(
      tester,
      catalog: Catalog(profileSystems: [system]),
      system: system,
      onCatalogChanged: (catalog) => saved = catalog,
    );

    await _scrollTo(tester, find.text('Non renseigné'));
    await tester.tap(find.text('Non renseigné'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oui').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(saved!.profileSystems.single.metadata!.thermalBreak, isTrue);
  });

  testWidgets('an incomplete limit row is dropped on save, not half-saved',
      (tester) async {
    final system = _system();
    Catalog? saved;

    await _pumpPanel(
      tester,
      catalog: Catalog(profileSystems: [system]),
      system: system,
      onCatalogChanged: (catalog) => saved = catalog,
    );

    await _scrollTo(tester, find.text('Ajouter une limite'));
    await tester.tap(find.text('Ajouter une limite'));
    await tester.pumpAndSettle();
    // Fill only the width of the new row -- the height stays empty.
    await _scrollTo(tester, find.text('L max'));
    await tester.enterText(find.widgetWithText(TextField, 'L max'), '2400');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    // Everything else is empty too, so the whole fiche clears to null
    // rather than persisting a half-entered limit.
    expect(saved!.profileSystems.single.metadata, isNull);
  });

  testWidgets('saving a completely empty form clears metadata to null',
      (tester) async {
    final populated = _populated(
      const ProfileSystemMetadata(
        frameDepthOptionsMm: [44.0],
        sourceDescription: 'PDF constructeur',
      ),
    );
    Catalog? saved;

    await _pumpPanel(
      tester,
      catalog: Catalog(profileSystems: [populated]),
      system: populated,
      onCatalogChanged: (catalog) => saved = catalog,
    );

    // The only two non-empty fields are the frame depths (top, visible)
    // and the source citation (bottom) -- clear both, save.
    await tester.enterText(
      find.widgetWithText(TextField, '44.00'),
      '',
    );
    await _scrollTo(tester, find.text('PDF constructeur'));
    await tester.enterText(
      find.widgetWithText(TextField, 'PDF constructeur'),
      '',
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(saved!.profileSystems.single.metadata, isNull);
  });
}
