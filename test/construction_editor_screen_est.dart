import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/layout_direction.dart';
import 'package:aluminium_designer/core/models/opening.dart';
import 'package:aluminium_designer/core/models/section.dart';
import 'package:aluminium_designer/features/constructions/screens/construction_editor_screen.dart';

/// Wide enough to clear the workspace's `_kMinDesktopWidth` (900) floor.
const _desktopSize = Size(1400, 900);

Section _fixedSection({String id = 's1', int order = 0}) => Section(
  id: id,
  order: order,
  kind: SectionKind.fixed,
  width: 1000,
  height: 1200,
);

Section _ouvrantSection({String id = 's2', int order = 1}) => Section(
  id: id,
  order: order,
  kind: SectionKind.ouvrant,
  width: 800,
  height: 1200,
  openingType: OpeningType.francaise,
  vantauxCount: 1,
);

Construction _construction({List<Section>? sections}) => Construction(
  id: 'c1',
  name: 'Test Window',
  type: ConstructionType.window,
  width: 1800,
  height: 1200,
  manufacturer: '',
  system: '',
  sections: sections ?? [_fixedSection(), _ouvrantSection()],
  layoutDirection: SectionLayoutDirection.horizontal,
  profiles: const [],
);

Future<void> _pumpEditor(WidgetTester tester, Construction construction) async {
  tester.view.physicalSize = _desktopSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(home: ConstructionEditorScreen(construction: construction)),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ConstructionEditorScreen workspace', () {
    testWidgets('renders main working zones', (tester) async {
      await _pumpEditor(tester, _construction());

      // Toolbar actions.
      expect(find.byIcon(Icons.add_box_outlined), findsOneWidget);
      expect(find.byIcon(Icons.zoom_in), findsOneWidget);
      expect(find.byIcon(Icons.zoom_out), findsOneWidget);
      expect(find.byIcon(Icons.fit_screen_outlined), findsOneWidget);

      // Left structure tree shows construction + both sections.
      expect(find.text('Test Window'), findsOneWidget);
      expect(find.text('Section 1'), findsOneWidget);
      expect(find.text('Section 2'), findsOneWidget);

      // Center canvas exists.
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Bottom status bar shows dimensions and section count.
      expect(find.textContaining('1800'), findsWidgets);
      expect(find.text('2 section(s)'), findsOneWidget);
    });

    testWidgets(
      'construction selected by default shows General stage properties',
      (tester) async {
        await _pumpEditor(tester, _construction());

        // Default stage is General.
        expect(find.text('GÉNÉRAL'), findsOneWidget);
        expect(find.text('SYSTÈME'), findsOneWidget);
        // Geometry/Sections-only fields absent until those stages are active.
        expect(find.text('DIMENSIONS'), findsNothing);
        expect(find.text('DISPOSITION'), findsNothing);
        expect(find.text('TYPE'), findsNothing);
      },
    );

    testWidgets('Geometry stage shows dimensions and layout direction', (
      tester,
    ) async {
      await _pumpEditor(tester, _construction());

      await tester.tap(find.text('Geometry'));
      await tester.pumpAndSettle();

      expect(find.text('DIMENSIONS'), findsOneWidget);
      expect(find.text('DISPOSITION'), findsOneWidget);
      // General-only content absent.
      expect(find.text('SYSTÈME'), findsNothing);
    });

    testWidgets('selecting a section in the tree switches to Sections stage', (
      tester,
    ) async {
      await _pumpEditor(tester, _construction());

      await tester.tap(find.text('Section 1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('SECTION 1'), findsOneWidget);
      expect(find.text('TYPE'), findsOneWidget);
      // General/Geometry-only sections absent.
      expect(find.text('SYSTÈME'), findsNothing);
      expect(find.text('DIMENSIONS'), findsNothing);
    });

    testWidgets('fixed section does not show opening controls', (tester) async {
      await _pumpEditor(tester, _construction());

      await tester.tap(find.text('Section 1')); // fixed
      await tester.pumpAndSettle();

      expect(find.text('OUVERTURE'), findsNothing);
    });

    testWidgets('ouvrant section shows opening controls', (tester) async {
      await _pumpEditor(tester, _construction());

      await tester.tap(find.text('Section 2')); // ouvrant
      await tester.pumpAndSettle();

      expect(find.text('OUVERTURE'), findsOneWidget);
      expect(find.text("Type d'ouverture"), findsOneWidget);
      expect(find.text('Vantaux :'), findsOneWidget);
    });

    testWidgets('add section adds a new section and appears in tree', (
      tester,
    ) async {
      await _pumpEditor(tester, _construction(sections: [_fixedSection()]));

      expect(find.text('2 section(s)'), findsNothing);
      expect(find.text('1 section(s)'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_box_outlined));
      await tester.pumpAndSettle();

      // Dialog appears; fill width/height and save.
      await tester.enterText(find.widgetWithText(TextField, 'Largeur'), '500');
      await tester.enterText(find.widgetWithText(TextField, 'Hauteur'), '600');
      await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
      await tester.pumpAndSettle();

      expect(find.text('2 section(s)'), findsOneWidget);
      expect(find.text('Section 2'), findsOneWidget);
    });

    testWidgets('remove selected section removes it and clears selection', (
      tester,
    ) async {
      await _pumpEditor(tester, _construction());

      await tester.tap(find.text('Section 1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pumpAndSettle();

      expect(find.text('1 section(s)'), findsOneWidget);
      // Selection clears but the stage stays on Sections -- with nothing
      // selected, the panel prompts the user to pick or add a section
      // rather than silently jumping back to General.
      expect(
        find.text(
          'Sélectionnez une section dans la liste à gauche ou '
          'ajoutez-en une avec le bouton "Ajouter une section" '
          'de la barre d\'outils.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'remove is disabled when construction (not a section) is selected',
      (tester) async {
        await _pumpEditor(tester, _construction());

        final removeButton = tester.widget<IconButton>(
          find.ancestor(
            of: find.byIcon(Icons.delete_outline).first,
            matching: find.byType(IconButton),
          ),
        );
        expect(removeButton.onPressed, isNull);
      },
    );

    testWidgets('save pops with ConstructionEditorResult.saved', (
      tester,
    ) async {
      ConstructionEditorResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.push<ConstructionEditorResult>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ConstructionEditorScreen(
                        construction: _construction(),
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      tester.view.physicalSize = _desktopSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.isDeleted, isFalse);
      expect(result!.saved, isNotNull);
    });

    testWidgets(
      'delete confirms and pops with ConstructionEditorResult.deleted',
      (tester) async {
        ConstructionEditorResult? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await Navigator.push<ConstructionEditorResult>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ConstructionEditorScreen(
                          construction: _construction(),
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

        tester.view.physicalSize = _desktopSize;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.delete_outline).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Supprimer').last);
        await tester.pumpAndSettle();

        expect(result, isNotNull);
        expect(result!.isDeleted, isTrue);
        expect(result!.deletedId, 'c1');
      },
    );

    testWidgets('no overflow errors at supported desktop width', (
      tester,
    ) async {
      await _pumpEditor(tester, _construction());
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Section 2'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Next moves General -> Geometry -> Sections', (tester) async {
      await _pumpEditor(tester, _construction());

      expect(find.text('SYSTÈME'), findsOneWidget); // General

      await tester.tap(find.byTooltip('Étape suivante'));
      await tester.pumpAndSettle();
      expect(find.text('DISPOSITION'), findsOneWidget); // Geometry

      await tester.tap(find.byTooltip('Étape suivante'));
      await tester.pumpAndSettle();
      expect(
        find.byTooltip('Terminer'),
        findsOneWidget,
      ); // Sections (last stage)
    });

    testWidgets('Back moves Sections -> Geometry -> General', (tester) async {
      await _pumpEditor(tester, _construction());

      await tester.tap(find.text('Geometry')); // left nav direct jump
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sections'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Étape précédente'));
      await tester.pumpAndSettle();
      expect(find.text('DISPOSITION'), findsOneWidget); // Geometry

      await tester.tap(find.byTooltip('Étape précédente'));
      await tester.pumpAndSettle();
      expect(find.text('SYSTÈME'), findsOneWidget); // General
    });

    testWidgets('left nav jumps directly to a stage', (tester) async {
      await _pumpEditor(tester, _construction());

      await tester.tap(find.text('Sections'));
      await tester.pumpAndSettle();

      expect(find.text('TYPE'), findsNothing); // no section selected yet
      expect(find.textContaining('Sélectionnez une section'), findsOneWidget);
    });

    testWidgets('Finish (Terminer) saves and pops via the existing Save path', (
      tester,
    ) async {
      ConstructionEditorResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.push<ConstructionEditorResult>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ConstructionEditorScreen(
                        construction: _construction(),
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      tester.view.physicalSize = _desktopSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Étape suivante'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Étape suivante'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Terminer'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.isDeleted, isFalse);
      expect(result!.saved, isNotNull);
    });

    testWidgets(
      'Return to Project (top-bar back) with no unsaved changes pops immediately',
      (tester) async {
        ConstructionEditorResult? result;
        var popped = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await Navigator.push<ConstructionEditorResult>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ConstructionEditorScreen(
                          construction: _construction(),
                        ),
                      ),
                    );
                    popped = true;
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

        tester.view.physicalSize = _desktopSize;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Retour au projet'));
        await tester.pumpAndSettle();

        // Popped with no result at all -- not saved, not deleted.
        expect(popped, isTrue);
        expect(result, isNull);
      },
    );

    testWidgets(
      'Sections stage shows the "select a system first" empty state when '
      'no system has ever been selected',
      (tester) async {
        await _pumpEditor(tester, _construction());

        await tester.tap(find.text('Section 1'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Sélectionnez un système'), findsOneWidget);
        // Confirms the assignment UI itself does not render at all --
        // there is nothing to assign profiles from without a system.
        expect(find.text('PROFILS ASSIGNÉS'), findsNothing);
      },
    );

    testWidgets(
      'Sections stage shows the "system no longer exists" empty state -- '
      'not crashing -- when systemId points at nothing in the (empty, '
      'freshly-loaded) catalog',
      (tester) async {
        final construction = _construction().copyWith(
          manufacturer: 'Deleted Manufacturer',
          system: 'Deleted System',
          manufacturerId: 'mfr-gone',
          systemId: 'sys-gone',
        );
        await _pumpEditor(tester, construction);

        await tester.tap(find.text('Section 1'));
        await tester.pumpAndSettle();

        // Distinct wording from the "never selected" case -- confirms the
        // editor tells unresolved apart from unselected rather than
        // crashing on the stale systemId (Part 4B).
        expect(
          find.textContaining('n\'existe plus dans le catalogue'),
          findsOneWidget,
        );
        expect(find.text('PROFILS ASSIGNÉS'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Calculate action', () {
    testWidgets('Calculer toolbar button exists on the Sections stage', (
      tester,
    ) async {
      await _pumpEditor(tester, _construction());

      await tester.tap(find.text('Section 1'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.calculate_outlined), findsOneWidget);
    });

    testWidgets(
      'pressing Calculer with no system selected shows the "no rule set" '
      'message rather than crashing or silently doing nothing',
      (tester) async {
        // Default _construction() has no systemId -- calculateConstructionCuts
        // returns null for this before ever touching the (real, empty)
        // loaded catalog, so this doesn't depend on catalog I/O timing.
        await _pumpEditor(tester, _construction());

        await tester.tap(find.text('Section 1'));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.calculate_outlined), findsOneWidget);
        await tester.tap(find.byIcon(Icons.calculate_outlined));
        await tester.pumpAndSettle();

        expect(
          find.text('Aucune règle de calcul disponible pour ce système.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('the "no rule set" result banner is also shown with no section '
        'selected -- results are construction-wide, not tied to selection', (
      tester,
    ) async {
      await _pumpEditor(tester, _construction());

      // Navigate to the Sections stage without selecting a section --
      // via the left nav, since tapping a section in the tree would
      // select it (see `_selectSection`'s forced stage switch).
      await tester.tap(find.text('Sections'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.calculate_outlined));
      await tester.pumpAndSettle();

      expect(
        find.text('Aucune règle de calcul disponible pour ce système.'),
        findsOneWidget,
      );
      // The "select a section" prompt is still shown alongside it --
      // the banner doesn't replace that notice, it sits above it.
      expect(find.textContaining('Sélectionnez une section'), findsOneWidget);
    });

    testWidgets(
      'editing a section after calculating keeps the last shown result '
      'but marks it stale -- recalculation stays manual, the result is '
      'never silently discarded on edit',
      (tester) async {
        await _pumpEditor(tester, _construction());

        await tester.tap(find.text('Section 1'));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.calculate_outlined));
        await tester.pumpAndSettle();
        expect(
          find.text('Aucune règle de calcul disponible pour ce système.'),
          findsOneWidget,
        );
        expect(find.textContaining('Résultat obsolète'), findsNothing);

        // Edit the selected section's width -- _applySectionWidth goes
        // through _replaceSection, which already calls
        // _resetCalculationState(). _SyncedTextField fires onChanged per
        // keystroke, so entering text alone is enough -- no submit needed.
        await tester.enterText(
          find.widgetWithText(TextField, 'Largeur'),
          '950',
        );
        await tester.pumpAndSettle();

        // The outcome is still shown, not cleared...
        expect(
          find.text('Aucune règle de calcul disponible pour ce système.'),
          findsOneWidget,
        );
        // ...but now flagged as stale.
        expect(find.textContaining('Résultat obsolète'), findsOneWidget);

        // Recalculating clears the stale flag again without changing the
        // outcome (still no system selected).
        await tester.tap(find.byIcon(Icons.calculate_outlined));
        await tester.pumpAndSettle();
        expect(find.textContaining('Résultat obsolète'), findsNothing);
      },
    );

    testWidgets(
      'no per-section cut count badge appears in the structure tree when '
      'calculation has not run or found no rule set -- no fabricated '
      'zero/stale counts',
      (tester) async {
        await _pumpEditor(tester, _construction());

        // Before calculating at all -- Section 1's ListTile should have
        // no trailing badge.
        final tileBefore = tester.widget<ListTile>(
          find
              .ancestor(
                of: find.text('Section 1'),
                matching: find.byType(ListTile),
              )
              .first,
        );
        expect(tileBefore.trailing, isNull);

        await tester.tap(find.text('Section 1'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.calculate_outlined));
        await tester.pumpAndSettle();

        // "No rule set" result -- _calculationResult stays null, so the
        // tree must still show no badge for Section 1.
        expect(
          find.text('Aucune règle de calcul disponible pour ce système.'),
          findsOneWidget,
        );
        final tileAfter = tester.widget<ListTile>(
          find
              .ancestor(
                of: find.text('Section 1'),
                matching: find.byType(ListTile),
              )
              .first,
        );
        expect(tileAfter.trailing, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
