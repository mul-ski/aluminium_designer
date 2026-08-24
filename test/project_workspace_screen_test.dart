import 'dart:io';

import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/project.dart';
import 'package:aluminium_designer/core/models/section.dart';
import 'package:aluminium_designer/core/storage/project_store.dart';
import 'package:aluminium_designer/features/projects/screens/project_workspace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'support/fake_path_provider.dart';

Construction _window() => Construction(
  id: 'c1',
  name: 'Fenêtre sud',
  type: ConstructionType.window,
  width: 1200,
  height: 1400,
  manufacturer: '',
  system: '',
  sections: [
    Section(id: 'c1-s1', order: 0, kind: SectionKind.fixed, width: 1200, height: 1400),
  ],
  profiles: const [],
);

Construction _door() => Construction(
  id: 'c2',
  name: 'Porte nord',
  type: ConstructionType.door,
  width: 900,
  height: 2100,
  manufacturer: '',
  system: '',
  sections: [
    Section(id: 'c2-s1', order: 0, kind: SectionKind.fixed, width: 900, height: 2100),
  ],
  profiles: const [],
);

Project _project({List<Construction> constructions = const []}) =>
    Project(id: 'p1', name: 'Chantier A', constructions: constructions);

/// Records every save instead of touching the disk -- the widget-level
/// counterpart of the editor tests' `_StubCatalogStore`. Real dart:io
/// I/O cannot complete inside a widget test's fake async zone; the disk
/// behaviour of `ProjectStore.save` itself is covered by the project
/// JSON/store tests.
class _RecordingStore extends ProjectStore {
  final List<Project> saved = [];

  @override
  Future<void> save(Project project) async {
    saved.add(project);
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('aluvis_workspace_test');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // Cards display the construction TYPE label ('Fenêtre'/'Porte'), not
  // the construction name -- find each card's delete action through the
  // label the card actually renders.
  Finder cardDeleteButton(String typeLabel) => find.descendant(
    of: find.ancestor(of: find.text(typeLabel), matching: find.byType(Card)),
    matching: find.byTooltip('Supprimer'),
  );

  Future<void> confirmDelete(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
    await tester.pumpAndSettle();
  }

  testWidgets('each construction card shows a visible delete action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectWorkspaceScreen(
          project: _project(constructions: [_window(), _door()]),
          store: _RecordingStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(cardDeleteButton('Fenêtre'), findsOneWidget);
    expect(cardDeleteButton('Porte'), findsOneWidget);
  });

  testWidgets('tapping delete asks for confirmation before deleting', (
    tester,
  ) async {
    final store = _RecordingStore();
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectWorkspaceScreen(
          project: _project(constructions: [_window()]),
          store: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(cardDeleteButton('Fenêtre'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Supprimer la construction'), findsOneWidget);
    // The dialog names the construction being deleted...
    expect(find.textContaining('Fenêtre sud'), findsOneWidget);
    // ...and offers cancel + confirm.
    expect(find.text('Annuler'), findsOneWidget);
    expect(find.text('Supprimer'), findsOneWidget);
    // Nothing was deleted (or persisted) by merely opening the dialog.
    expect(store.saved, isEmpty);
  });

  testWidgets('cancelling the confirmation leaves the construction in '
      'place and nothing is persisted', (tester) async {
    final store = _RecordingStore();
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectWorkspaceScreen(
          project: _project(constructions: [_window()]),
          store: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(cardDeleteButton('Fenêtre'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    // Still visible in the list, still unsaved-on top of the initial
    // state -- cancel changed nothing.
    expect(find.text('Fenêtre'), findsOneWidget);
    expect(find.text('1 construction'), findsOneWidget);
    expect(store.saved, isEmpty);
  });

  testWidgets('confirming removes only the targeted construction, keeps '
      'the others, and persists immediately', (tester) async {
    final store = _RecordingStore();
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectWorkspaceScreen(
          project: _project(constructions: [_window(), _door()]),
          store: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(cardDeleteButton('Fenêtre'));
    await tester.pumpAndSettle();
    await confirmDelete(tester);

    // UI: only the targeted construction is gone.
    expect(find.text('Fenêtre'), findsNothing);
    expect(find.text('Porte'), findsOneWidget);
    expect(find.text('1 construction'), findsOneWidget);

    // Persistence: the updated project was pushed to the store right
    // away -- not deferred to screen pop -- and contains exactly the
    // remaining constructions.
    expect(store.saved, hasLength(1));
    expect(store.saved.single.id, 'p1');
    expect(store.saved.single.constructions, hasLength(1));
    expect(store.saved.single.constructions.single.id, 'c2');
  });

  testWidgets('deleting the last construction leaves a valid empty '
      'project, persisted', (tester) async {
    final store = _RecordingStore();
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectWorkspaceScreen(
          project: _project(constructions: [_window()]),
          store: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(cardDeleteButton('Fenêtre'));
    await tester.pumpAndSettle();
    await confirmDelete(tester);

    // The project itself remains, with its empty-state UI.
    expect(find.text('Chantier A'), findsNWidgets(2));
    expect(find.text('Aucune construction'), findsOneWidget);
    expect(
      find.textContaining('ne contient encore aucune construction'),
      findsOneWidget,
    );

    // The persisted project is still there -- just with zero
    // constructions, which is a valid project state.
    expect(store.saved, hasLength(1));
    expect(store.saved.single.id, 'p1');
    expect(store.saved.single.constructions, isEmpty);
  });

  testWidgets('popping the workspace after a deletion hands back the '
      'updated project so the dashboard stays in sync', (tester) async {
    final store = _RecordingStore();
    Project? popped;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () {
                  Navigator.push<Project>(context, MaterialPageRoute(
                    builder: (_) => ProjectWorkspaceScreen(
                      project: _project(constructions: [_window(), _door()]),
                      store: store,
                    ),
                  )).then((value) => popped = value);
                },
                child: const Text('ouvrir le projet'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ouvrir le projet'));
    await tester.pumpAndSettle();

    await tester.tap(cardDeleteButton('Fenêtre'));
    await tester.pumpAndSettle();
    await confirmDelete(tester);

    await tester.tap(find.byTooltip('Retour à Mes projets'));
    await tester.pumpAndSettle();

    expect(popped, isNotNull);
    expect(
      popped!.constructions.map((c) => c.id),
      ['c2'],
      reason: 'the dashboard receives the project without the deleted '
          'construction',
    );
  });

  testWidgets('deleting the second construction removes exactly that '
      'one, then the first -- never the wrong entry', (tester) async {
    final store = _RecordingStore();
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectWorkspaceScreen(
          project: _project(constructions: [_window(), _door()]),
          store: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(cardDeleteButton('Porte'));
    await tester.pumpAndSettle();
    await confirmDelete(tester);
    expect(find.text('Porte'), findsNothing);
    expect(find.text('Fenêtre'), findsOneWidget);

    await tester.tap(cardDeleteButton('Fenêtre'));
    await tester.pumpAndSettle();
    await confirmDelete(tester);
    expect(find.text('Fenêtre'), findsNothing);
    expect(find.text('Aucune construction'), findsOneWidget);

    expect(store.saved, hasLength(2));
    expect(store.saved[0].constructions.map((c) => c.id), ['c1']);
    expect(store.saved[1].constructions, isEmpty);
  });
}
