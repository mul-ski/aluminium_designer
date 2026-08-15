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
      'construction selected by default shows construction properties',
      (tester) async {
        await _pumpEditor(tester, _construction());

        expect(find.text('GÉNÉRAL'), findsOneWidget);
        expect(find.text('DIMENSIONS'), findsOneWidget);
        expect(find.text('DISPOSITION'), findsOneWidget);
        expect(find.text('SYSTÈME'), findsOneWidget);
        // Section-only fields absent.
        expect(find.text('TYPE'), findsNothing);
      },
    );

    testWidgets('selecting a section in the tree shows section properties', (
      tester,
    ) async {
      await _pumpEditor(tester, _construction());

      await tester.tap(find.text('Section 1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('SECTION 1'), findsOneWidget);
      expect(find.text('TYPE'), findsOneWidget);
      // Construction-only sections absent.
      expect(find.text('SYSTÈME'), findsNothing);
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
      // Selection reverts to construction root -> construction props shown.
      expect(find.text('SYSTÈME'), findsOneWidget);
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
  });
}
