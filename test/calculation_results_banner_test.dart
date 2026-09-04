// Focused widget test for the populated calculation results banner.
//
// The banner's `Exporter la production` button is the only
// production-export surface inside the editor. This test pumps the
// banner directly (no editor screen, no catalog store, no disk) with
// a real ME 14800 1v française outcome and asserts:
//   1. the export button renders in the populated-result branch;
//   2. tapping it opens the `ProductionExportDialog` (assert the
//      dialog title), proving the banner forwards a non-null
//      construction + project name safely (no force-unwrap crash).
//
// The full end-to-end flow (editor -> Calculer -> export -> files on
// disk) stays in `test/production_export_ui_test.dart`; this file
// pins the banner contract in isolation.

import 'package:aluminium_designer/core/data/builtin_catalog_seed.dart';
import 'package:aluminium_designer/core/logic/rule_set_resolution.dart';
import 'package:aluminium_designer/core/models/catalog.dart';
import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/layout_direction.dart';
import 'package:aluminium_designer/core/models/opening.dart';
import 'package:aluminium_designer/core/models/profile_usage.dart';
import 'package:aluminium_designer/core/models/section.dart';
import 'package:aluminium_designer/features/constructions/editor/widgets/calculation_results_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final Catalog _catalog = withBuiltInCatalogSeed(const Catalog());

Construction _me14800_1v() {
  ProfileUsage usage(String id, String reference, ProfileUsageRole role) {
    final p = meSerie14800.profilesById.values
        .firstWhere((x) => x.reference == reference);
    return ProfileUsage(
      id: id,
      profileId: p.id,
      sectionId: 's1',
      role: role,
    );
  }

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
      usage('d-top', '14.800', ProfileUsageRole.top),
      usage('d-bottom', '14.800', ProfileUsageRole.bottom),
      usage('d-left', '14.800', ProfileUsageRole.left),
      usage('d-right', '14.800', ProfileUsageRole.right),
      usage('o-top', '14.802', ProfileUsageRole.top),
      usage('o-bottom', '14.802', ProfileUsageRole.bottom),
      usage('o-left', '14.802', ProfileUsageRole.left),
      usage('o-right', '14.802', ProfileUsageRole.right),
      usage('p-top', '14.810', ProfileUsageRole.top),
      usage('p-bottom', '14.810', ProfileUsageRole.bottom),
      usage('p-left', '14.810', ProfileUsageRole.left),
      usage('p-right', '14.810', ProfileUsageRole.right),
      usage('tige', '14.811', ProfileUsageRole.intermediate),
    ],
  );
}

void main() {
  testWidgets(
    'populated banner renders the export button and opens the export '
    'dialog on tap',
    (tester) async {
      final c = _me14800_1v();
      final outcome = calculateConstructionCuts(c, _catalog)!;
      expect(outcome.cuts, isNotEmpty);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalculationResultsBanner(
              result: outcome,
              error: null,
              hadNoRuleSet: false,
              sections: c.sections,
              isStale: false,
              projectName: 'Chantier Test',
              construction: c,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The export action sits next to the cut-list and BOM actions.
      expect(find.text('Exporter la production'), findsOneWidget);
      expect(find.text('Liste de découpe'), findsOneWidget);
      expect(find.text('BOM'), findsOneWidget);

      // Tapping opens the export dialog (which shows its own title +
      // subdirectory field). Reaching the dialog proves the banner
      // forwarded a non-null construction + project name -- the old
      // `construction!` force-unwrap path would have thrown here
      // instead.
      await tester.tap(find.text('Exporter la production'));
      await tester.pumpAndSettle();
      expect(find.text('Exporter la production'), findsWidgets);
      expect(find.text('Sous-dossier'), findsOneWidget);

      expect(tester.takeException(), isNull);
    },
  );
}
