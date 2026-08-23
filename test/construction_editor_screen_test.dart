import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/geometry/section_layout.dart';
import 'package:aluminium_designer/core/models/catalog.dart';
import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/layout_direction.dart';
import 'package:aluminium_designer/core/models/opening.dart';
import 'package:aluminium_designer/core/models/section.dart';
import 'package:aluminium_designer/core/storage/catalog_store.dart';
import 'package:aluminium_designer/features/constructions/editor/editor_viewport.dart';
import 'package:aluminium_designer/features/constructions/editor/widgets/editor_canvas.dart';
import 'package:aluminium_designer/features/constructions/editor/widgets/editor_properties_panels.dart';
import 'package:aluminium_designer/features/constructions/editor/widgets/editor_status_bar.dart';
import 'package:aluminium_designer/features/constructions/editor/widgets/editor_structure_panel.dart';
import 'package:aluminium_designer/features/constructions/editor/widgets/editor_toolbar.dart';
import 'package:aluminium_designer/features/constructions/widgets/construction_painter.dart';
import 'package:aluminium_designer/features/constructions/screens/construction_editor_screen.dart';

/// Wide enough to clear the workspace's `_kMinDesktopWidth` (900) floor.
const _desktopSize = Size(1400, 900);

/// Deterministic stand-in for the real [CatalogStore]: serves a fixed
/// empty catalog and swallows saves without touching platform channels or
/// the filesystem. Neither of those can complete under flutter_test's
/// fake-async zone, which is what previously left the editor's catalog
/// spinner spinning forever and made this file unrunnable standalone.
///
/// Injected through `ConstructionEditorScreen.catalogStore` -- proper
/// dependency injection, no production test hooks involved.
class _StubCatalogStore extends CatalogStore {
  @override
  Future<Catalog> load() async => const Catalog();

  @override
  Future<void> save(Catalog catalog) async {}
}

final _stubCatalogStore = _StubCatalogStore();

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
    MaterialApp(
      home: ConstructionEditorScreen(
        construction: construction,
        catalogStore: _stubCatalogStore,
      ),
    ),
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

      // Left structure tree shows construction + both sections. The
      // construction name also legitimately appears in the app bar title
      // and in the General panel's name field (an EditableText), so the
      // app-bar occurrence is asserted specifically rather than by count.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Test Window'),
        ),
        findsOneWidget,
      );
      expect(find.text('Section 1'), findsOneWidget);
      expect(find.text('Section 2'), findsOneWidget);

      // Center canvas exists, driven by the editor's own viewport.
      expect(find.byType(EditorCanvas), findsOneWidget);
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
      // General/Geometry-only content absent. ('DIMENSIONS' is NOT a
      // valid marker here: the section panel has its own DIMENSIONS
      // header for per-section width/height.)
      expect(find.text('SYSTÈME'), findsNothing);
      expect(find.text('DISPOSITION'), findsNothing);
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
      // The section properties panel scrolls: at the suite's window size
      // the vantaux row sits just below the fold, so bring it into view
      // before asserting on it.
      final vantauxFinder = find.text('Vantaux :', skipOffstage: false);
      await tester.ensureVisible(vantauxFinder);
      await tester.pumpAndSettle();
      expect(vantauxFinder, findsOneWidget);
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

      // Target the toolbar's remove button via its unique tooltip --
      // icon-based finders are ambiguous here because the app bar also
      // contains a delete icon (for deleting the whole construction).
      await tester.tap(find.byTooltip('Supprimer la sélection'));
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
          find.descendant(
            of: find.byTooltip('Supprimer la sélection'),
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
                        catalogStore: _stubCatalogStore,
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
                          catalogStore: _stubCatalogStore,
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

        // Target the app bar's delete action via its unique tooltip --
        // the toolbar also contains a delete icon (for removing the
        // selected section), so an icon-based finder is ambiguous.
        await tester.tap(find.byTooltip('Supprimer la construction'));
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
                        catalogStore: _stubCatalogStore,
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
                          catalogStore: _stubCatalogStore,
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

  group('Canvas viewport interaction', () {
    /// The global screen position of a model-space (millimetre) point on
    /// the canvas, computed with the same pinned fit math the viewport
    /// uses for its initial fit. Importing `fitConstructionToCanvas` here
    /// is deliberate coupling: that function's outputs are already
    /// exhaustively unit-tested in section_layout_test.dart, so the test
    /// stays honest about where geometry lands on screen without
    /// duplicating any logic under test.
    Offset canvasPointFor(WidgetTester tester, double modelX, double modelY) {
      final topLeft = tester.getTopLeft(find.byType(EditorCanvas));
      final size = tester.getSize(find.byType(EditorCanvas));
      final fit = fitConstructionToCanvas(
        contentWidth: 1800,
        contentHeight: 1200,
        canvasWidth: size.width,
        canvasHeight: size.height,
        padding: kViewportFitPadding,
      );
      return topLeft +
          Offset(
            fit.offsetX + modelX * fit.scale,
            fit.offsetY + modelY * fit.scale,
          );
    }

    testWidgets('tapping a section on the canvas selects it', (tester) async {
      await _pumpEditor(tester, _construction());

      // Section 1 spans 0..1000 mm wide; its centre is (500, 600) mm.
      await tester.tapAt(canvasPointFor(tester, 500, 600));
      await tester.pumpAndSettle();

      // Selection drives the whole workspace: Sections stage opens with
      // the selected section's properties panel.
      expect(find.textContaining('SECTION 1'), findsOneWidget);
    });

    testWidgets('tapping empty canvas space selects the construction root', (
      tester,
    ) async {
      await _pumpEditor(tester, _construction());

      await tester.tap(find.text('Section 1'));
      await tester.pumpAndSettle();
      expect(find.textContaining('SECTION 1'), findsOneWidget);

      // The top-left corner of the canvas lies inside the fit padding
      // margin -- model coordinates there are outside every section.
      final topLeft = tester.getTopLeft(find.byType(EditorCanvas));
      await tester.tapAt(topLeft + const Offset(8, 8));
      await tester.pumpAndSettle();

      expect(find.textContaining('SECTION 1'), findsNothing);
      expect(find.textContaining('Sélectionnez une section'), findsOneWidget);
    });

    testWidgets(
      'toolbar zoom scales about the center and Ajuster à la vue restores '
      'the fitted view',
      (tester) async {
        await _pumpEditor(tester, _construction());

        final viewport = tester
            .widget<EditorCanvas>(find.byType(EditorCanvas))
            .viewport;

        // The one-time initial fit has run by now -- the viewport does not
        // sit at identity.
        final fittedScale = viewport.matrix[0];
        final fittedOffset = Offset(viewport.matrix[12], viewport.matrix[13]);
        expect(fittedScale, isNot(1.0));

        await tester.tap(find.byTooltip('Zoom avant'));
        await tester.pumpAndSettle();

        expect(viewport.matrix[0], closeTo(fittedScale * 1.2, 1e-9));

        await tester.tap(find.byTooltip('Ajuster à la vue'));
        await tester.pumpAndSettle();

        // Deterministic refit reproduces exactly the original transform.
        expect(viewport.matrix[0], fittedScale);
        expect(Offset(viewport.matrix[12], viewport.matrix[13]), fittedOffset);
      },
    );

    testWidgets('editing dimensions after the initial fit does not re-fit '
        '(auto-fit runs at most once per session)', (tester) async {
      await _pumpEditor(tester, _construction());

      final viewport = tester
          .widget<EditorCanvas>(find.byType(EditorCanvas))
          .viewport;
      final before = Offset(viewport.matrix[12], viewport.matrix[13]);

      await tester.tap(find.text('Geometry'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Largeur'), '2400');
      await tester.pumpAndSettle();

      // The transform is untouched by dimension edits -- only the
      // toolbar button or a fresh session re-fits.
      expect(Offset(viewport.matrix[12], viewport.matrix[13]), before);
    });
  });

  group('Undo / redo', () {
    /// Navigates to the Geometry stage and types [value] into the width
    /// field, leaving focus inside the field (callers decide whether to
    /// unfocus before keyboard shortcuts).
    Future<void> editWidth(WidgetTester tester, String value) async {
      await tester.tap(find.text('Geometry'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Largeur'), value);
      await tester.pumpAndSettle();
    }

    IconButton undoButton(WidgetTester tester) => tester.widget<IconButton>(
      find.descendant(
        of: find.byTooltip('Annuler'),
        matching: find.byType(IconButton),
      ),
    );

    IconButton redoButton(WidgetTester tester) => tester.widget<IconButton>(
      find.descendant(
        of: find.byTooltip('Rétablir'),
        matching: find.byType(IconButton),
      ),
    );

    testWidgets('toolbar undo/redo buttons gate on history availability', (
      tester,
    ) async {
      await _pumpEditor(tester, _construction());

      // Nothing mutated yet: both disabled.
      expect(undoButton(tester).onPressed, isNull);
      expect(redoButton(tester).onPressed, isNull);

      await editWidth(tester, '999');
      expect(undoButton(tester).onPressed, isNotNull);
      expect(redoButton(tester).onPressed, isNull);

      await tester.tap(find.byTooltip('Annuler'));
      await tester.pumpAndSettle();
      expect(undoButton(tester).onPressed, isNull);
      expect(redoButton(tester).onPressed, isNotNull);
      // The width edit really was undone.
      expect(find.textContaining('1800'), findsWidgets);
    });

    testWidgets(
      'Ctrl+Z triggers construction undo -- even while a text field holds '
      'focus, since fields have no undo controller of their own',
      (tester) async {
        await _pumpEditor(tester, _construction());
        await editWidth(tester, '999');
        expect(find.textContaining('999 ×'), findsWidgets);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        expect(find.textContaining('1800'), findsWidgets);
        expect(find.textContaining('999 ×'), findsNothing);
      },
    );

    testWidgets('undo/redo never touches the viewport transform', (
      tester,
    ) async {
      await _pumpEditor(tester, _construction());

      final canvas = tester.widget<EditorCanvas>(find.byType(EditorCanvas));
      final viewport = canvas.viewport;

      // Zoom in twice so the transform is distinctly non-initial.
      await tester.tap(find.byTooltip('Zoom avant'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Zoom avant'));
      await tester.pumpAndSettle();
      final zoomedScale = viewport.matrix[0];
      final zoomedOffset = Offset(viewport.matrix[12], viewport.matrix[13]);

      // Mutate, then undo it via the toolbar.
      await editWidth(tester, '999');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.tap(find.byTooltip('Annuler'));
      await tester.pumpAndSettle();

      // The pan/zoom state survived the entire mutate+undo cycle untouched:
      // history contains Construction snapshots only.
      expect(viewport.matrix[0], zoomedScale);
      expect(Offset(viewport.matrix[12], viewport.matrix[13]), zoomedOffset);
    });
  });

  group('Boundary drag integration', () {
    testWidgets('dragging the interior boundary commits exactly one mutation '
        '(one undo entry) and updates the construction', (tester) async {
      await _pumpEditor(tester, _construction()); // [1000, 800], W=1800

      // This test pins RAW drag math (no snapping); the snapped variant
      // lives in its own test below. Snap is disabled through the REAL
      // toolbar toggle so the session settings path is exercised too.
      await tester.tap(find.byTooltip('Aimanter'));
      await tester.pumpAndSettle();

      final viewport = tester
          .widget<EditorCanvas>(find.byType(EditorCanvas))
          .viewport;

      // Grab the single interior boundary (at 1000 mm) and drag it
      // 60 logical px to the right.
      final grabPoint =
          tester.getTopLeft(find.byType(EditorCanvas)) +
          viewport.modelToScreen(const Offset(1000, 600));
      final scaleBefore = viewport.scale;

      final gesture = await tester.startGesture(grabPoint);
      await tester.pump();
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final expectedLeft = 1000 + 60 / scaleBefore;

      // Select section 1 and read its width from the properties field --
      // the status bar deliberately still shows the OVERALL dimensions
      // (invariant under boundary moves), so the section editor is the
      // observable here.
      await tester.tap(find.text('Section 1'));
      await tester.pumpAndSettle();
      final widthField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Largeur'),
      );
      expect(widthField.controller!.text, expectedLeft.toStringAsFixed(0));

      // Exactly ONE undo entry: a single Annuler restores the original
      // section size, and undo is then exhausted.
      await tester.tap(find.byTooltip('Annuler'));
      await tester.pumpAndSettle();
      final restoredField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Largeur'),
      );
      expect(restoredField.controller!.text, '1000');

      final undoButton = tester.widget<IconButton>(
        find.descendant(
          of: find.byTooltip('Annuler'),
          matching: find.byType(IconButton),
        ),
      );
      expect(undoButton.onPressed, isNull);
    });

    testWidgets('with default snapping the boundary lands exactly on the '
        '5 mm grid -- no microscopic cursor work needed', (tester) async {
      await _pumpEditor(tester, _construction()); // [1000, 800], W=1800

      final viewport = tester
          .widget<EditorCanvas>(find.byType(EditorCanvas))
          .viewport;
      final grabPoint =
          tester.getTopLeft(find.byType(EditorCanvas)) +
          viewport.modelToScreen(const Offset(1000, 600));
      final scaleBefore = viewport.scale;

      // Same gesture as the raw variant above (~+127 mm) -- but with snap
      // ON by default, the committed width must be an exact multiple of 5.
      final gesture = await tester.startGesture(grabPoint);
      await tester.pump();
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final raw = 1000 + 60 / scaleBefore;
      final expectedSnapped = (raw / 5).roundToDouble() * 5;

      await tester.tap(find.text('Section 1'));
      await tester.pumpAndSettle();
      final widthField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Largeur'),
      );
      expect(
        double.parse(widthField.controller!.text.replaceAll(',', '.')),
        closeTo(expectedSnapped, 1e-9),
      );
      expect(expectedSnapped % 5, 0);

      // Still exactly one undo entry for the whole snapped drag.
      await tester.tap(find.byTooltip('Annuler'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Largeur'))
            .controller!
            .text,
        '1000',
      );
    });
  });

  group('Workspace layout contract', () {
    testWidgets(
      'canvas is strictly bounded by toolbar, panels and status bar; '
      'painting is clipped to the canvas',
      (tester) async {
        await _pumpEditor(tester, _construction());

        final canvasRect = tester.getRect(find.byType(EditorCanvas));
        final leftRect = tester.getRect(find.byType(EditorStructurePanel));
        final rightRect = tester.getRect(
          find.byType(EditorGeneralPropertiesPanel),
        );
        final toolbarRect = tester.getRect(find.byType(EditorToolbar));
        final statusRect = tester.getRect(find.byType(EditorStatusBar));

        // One-pixel dividers may sit between regions; nothing may overlap.
        expect(leftRect.right, lessThanOrEqualTo(canvasRect.left + 0.5));
        expect(rightRect.left, greaterThanOrEqualTo(canvasRect.right - 0.5));
        expect(toolbarRect.bottom, lessThanOrEqualTo(canvasRect.top + 0.5));
        expect(statusRect.top, greaterThanOrEqualTo(canvasRect.bottom - 0.5));

        // The painter must be clipped to the canvas: RenderCustomPaint
        // does NOT clip on its own, so without the ClipRect a panned or
        // zoomed-out construction paints over neighbouring UI.
        expect(
          find.ancestor(
            of: find.byWidgetPredicate(
              (widget) =>
                  widget is CustomPaint &&
                  widget.painter is ConstructionPainter,
            ),
            matching: find.byType(ClipRect),
          ),
          findsOneWidget,
        );

        // The viewport receives the REAL central-canvas size -- this is
        // what fit-to-content and screen<->model conversion are based on.
        final viewport =
            tester.widget<EditorCanvas>(find.byType(EditorCanvas)).viewport;
        expect(viewport.canvasSize, tester.getSize(find.byType(EditorCanvas)));
      },
    );
  });

  group('Drafting aid toggles', () {
    /// The IconButton inside a tooltip-wrapped toolbar toggle.
    IconButton toggleButton(WidgetTester tester, String tooltip) =>
        tester.widget<IconButton>(
          find.descendant(
            of: find.byTooltip(tooltip),
            matching: find.byType(IconButton),
          ),
        );

    testWidgets('snap and grid start enabled by default', (tester) async {
      await _pumpEditor(tester, _construction());

      expect(toggleButton(tester, 'Aimanter').isSelected, isTrue);
      expect(toggleButton(tester, 'Afficher la grille').isSelected, isTrue);
      expect(
        (toggleButton(tester, 'Afficher la grille').icon as Icon).icon,
        Icons.grid_on,
      );
    });

    testWidgets('tapping the snap toggle flips it and sticks across rebuilds',
        (tester) async {
      await _pumpEditor(tester, _construction());

      await tester.tap(find.byTooltip('Aimanter'));
      await tester.pumpAndSettle();
      expect(toggleButton(tester, 'Aimanter').isSelected, isFalse);

      // An unrelated interaction (stage switch) rebuilds the toolbar; the
      // setting must survive it -- session state, not widget-local state.
      await tester.tap(find.text('Geometry'));
      await tester.pumpAndSettle();
      expect(toggleButton(tester, 'Aimanter').isSelected, isFalse);

      await tester.tap(find.byTooltip('Aimanter'));
      await tester.pumpAndSettle();
      expect(toggleButton(tester, 'Aimanter').isSelected, isTrue);
    });

    testWidgets('grid visibility toggle flips icon and selection', (
      tester,
    ) async {
      await _pumpEditor(tester, _construction());

      await tester.tap(find.byTooltip('Afficher la grille'));
      await tester.pumpAndSettle();

      final button = toggleButton(tester, 'Afficher la grille');
      expect(button.isSelected, isFalse);
      expect((button.icon as Icon).icon, Icons.grid_off);

      await tester.tap(find.byTooltip('Afficher la grille'));
      await tester.pumpAndSettle();
      expect(
        (toggleButton(tester, 'Afficher la grille').icon as Icon).icon,
        Icons.grid_on,
      );
    });

    testWidgets('toggles do not create undo history (interaction aids are '
        'not domain mutations)', (tester) async {
      await _pumpEditor(tester, _construction());

      await tester.tap(find.byTooltip('Aimanter'));
      await tester.tap(find.byTooltip('Afficher la grille'));
      await tester.pumpAndSettle();

      final undoButton = tester.widget<IconButton>(
        find.descendant(
          of: find.byTooltip('Annuler'),
          matching: find.byType(IconButton),
        ),
      );
      expect(undoButton.onPressed, isNull);
    });

    testWidgets('increment picker shows the default and applies a choice', (
      tester,
    ) async {
      await _pumpEditor(tester, _construction());

      expect(find.text('5 mm'), findsOneWidget);

      await tester.tap(find.text('5 mm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('25 mm').last);
      await tester.pumpAndSettle();

      expect(find.text('25 mm'), findsOneWidget);
      expect(find.text('5 mm'), findsNothing);
    });

    testWidgets('increment picker is disabled while snapping is off -- no '
        'interactive-looking but inert control', (tester) async {
      await _pumpEditor(tester, _construction());

      // NOTE: find.byType(PopupMenuButton) would miss the instance --
      // generics are reified, so its runtimeType is
      // PopupMenuButton<double>.
      PopupMenuButton<double> picker() =>
          tester.widget<PopupMenuButton<double>>(
            find.byWidgetPredicate((w) => w is PopupMenuButton<double>),
          );
      expect(picker().enabled, isTrue);

      await tester.tap(find.byTooltip('Aimanter'));
      await tester.pumpAndSettle();
      expect(picker().enabled, isFalse);
    });
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
