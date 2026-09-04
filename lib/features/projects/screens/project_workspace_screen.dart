import 'package:flutter/material.dart';
import '../../../core/models/construction.dart';
import '../../../core/models/construction_type.dart';
import '../../../core/models/project.dart';
import '../../../core/storage/project_store.dart';
import '../../constructions/screens/construction_editor_screen.dart';
import 'new_construction_screen.dart';

/// The workspace for one [Project]: shows its constructions and lets the
/// user add more.
///
/// This replaces the old `ProjectEditorScreen`, which treated a project as
/// a single construction and displayed its sections directly. That no
/// longer matches the domain model -- a project is a container of zero or
/// more [Construction]s -- so this screen shows the project at the
/// container level (name, construction count/list) instead.
///
/// State is held locally in this screen while the user is working inside
/// it: `Project` is immutable, so adding a construction rebuilds the
/// `Project` via `copyWith` and this widget's `_project` field is updated
/// to the new instance. On pop (back button, back gesture, or system back),
/// this screen always returns its current `_project` to the caller
/// (`ProjectDashboard`), which re-saves it via `ProjectStore` too -- but
/// that is now a redundant safety net, not the only save path: see
/// `_openConstruction` below for why a construction Save must be durable
/// the moment it happens, not only once this screen itself later closes.
class ProjectWorkspaceScreen extends StatefulWidget {
  final Project project;

  /// Optional store override -- same DI seam as
  /// `ConstructionEditorScreen.catalogStore`: production code passes
  /// nothing and gets the real on-disk [ProjectStore]; tests may inject a
  /// stub so widget tests never touch the filesystem (real dart:io I/O
  /// cannot complete inside a widget test's fake async zone).
  final ProjectStore? store;

  const ProjectWorkspaceScreen({super.key, required this.project, this.store});

  @override
  State<ProjectWorkspaceScreen> createState() => _ProjectWorkspaceScreenState();
}

class _ProjectWorkspaceScreenState extends State<ProjectWorkspaceScreen> {
  late final ProjectStore _store = widget.store ?? ProjectStore();
  late Project _project;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
  }

  /// Creates a bare construction stub via [NewConstructionScreen], adds it
  /// to the project immediately, then opens it straight in
  /// `ConstructionEditorScreen` -- matching the desired flow of "Add
  /// construction" being a lightweight entry point into the editor, not a
  /// geometry form in its own right (see `NewConstructionScreen`'s doc
  /// comment).
  ///
  /// The stub is added to `_project.constructions` *before* opening the
  /// editor (not only after Save) so it isn't lost if the user backs out
  /// of the editor without saving -- it will simply remain in its initial,
  /// honestly incomplete state (see `GeometryStatus.incomplete`), the same
  /// state it's in the moment it's created. It is also persisted to disk
  /// immediately (see `_persist`) for the same reason: the stub must
  /// survive an app close even if the user never explicitly saves it
  /// again inside the editor.
  Future<void> addConstruction() async {
    final construction = await Navigator.push<Construction>(
      context,
      MaterialPageRoute(builder: (_) => const NewConstructionScreen()),
    );

    if (construction == null) {
      return;
    }

    setState(() {
      _project = _project.copyWith(
        constructions: [..._project.constructions, construction],
      );
    });
    await _persist();

    await _openConstruction(construction);
  }

  /// Opens the construction editor for [construction] and either merges
  /// saved edits back into `_project.constructions` by id, or removes the
  /// construction entirely if it was deleted.
  ///
  /// `ConstructionEditorScreen` now pops with a `ConstructionEditorResult`
  /// that distinguishes "saved" from "deleted" from `null` ("cancelled" --
  /// user backed out/discarded without saving or deleting). Previously it
  /// only ever popped a plain `Construction?`, so there was no way to
  /// represent deletion at all: the editor closed, but this screen had no
  /// signal to remove the construction from `_project.constructions`,
  /// leaving the deleted construction's data around as a ghost. Rebuilding
  /// the constructions list here -- via `setState`, which is what actually
  /// drives the workspace's `ListView` and any editor re-render -- is what
  /// makes the removal visible; simply closing the editor was never enough
  /// on its own.
  ///
  /// CRITICAL: after merging, this always calls `_persist()` before
  /// returning. The construction editor's own Save action only hands the
  /// updated `Construction` back through `Navigator.pop` -- it never
  /// touches disk itself (see `ConstructionEditorScreen`'s class doc).
  /// Without this call, a saved edit would only survive as long as this
  /// screen's in-memory `_project`, and would be lost on app close unless
  /// the user also happened to pop this screen afterward (which is what
  /// used to make Save "not reliably persisted": it depended on a second,
  /// unrelated navigation action). Persisting here makes the editor's
  /// Save durable the moment it happens.
  ///
  /// Replacing/removing by id rather than by list position keeps this
  /// correct even if `_project.constructions` has been reordered or
  /// changed elsewhere between opening and closing the editor.
  Future<void> _openConstruction(Construction construction) async {
    final result = await Navigator.push<ConstructionEditorResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ConstructionEditorScreen(
          construction: construction,
          projectName: _project.name,
        ),
      ),
    );

    if (result == null) {
      return;
    }

    if (result.isDeleted) {
      setState(() {
        _project = _project.copyWith(
          constructions: [
            for (final c in _project.constructions)
              if (c.id != result.deletedId) c,
          ],
        );
      });
      await _persist();
      return;
    }

    final edited = result.saved!;
    setState(() {
      _project = _project.copyWith(
        constructions: [
          for (final c in _project.constructions)
            if (c.id == edited.id) edited else c,
        ],
      );
    });
    await _persist();
  }

  /// Writes the current `_project` through the real `ProjectStore`
  /// persistence path. Called after every mutation to
  /// `_project.constructions` (add, edited-and-saved, deleted) so disk is
  /// never more than one mutation behind what's shown -- not deferred
  /// until this screen itself is popped.
  Future<void> _persist() async {
    await _store.save(_project);
  }

  /// Deletes one construction from the project, after explicit
  /// confirmation -- the list-level counterpart of the editor's own
  /// delete flow (which reaches this same state via
  /// `_openConstruction`'s `ConstructionEditorResult.isDeleted` branch).
  ///
  /// Same shape as `ProjectDashboard._deleteProject`: confirmation
  /// dialog first, cancel (or dismissing the dialog) leaves everything
  /// unchanged, confirmation removes ONLY the targeted construction by
  /// id and persists the updated project immediately. Removing by id
  /// (not list position) keeps this safe even if the list changed since
  /// the card was built. The project itself and every other construction
  /// stay untouched; deleting the last construction simply leaves a
  /// valid empty project (the existing empty-state UI already covers
  /// that).
  Future<void> _deleteConstruction(Construction construction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer la construction'),
        content: Text(
          'Supprimer cette construction (${construction.name}) du projet '
          '"${_project.name}" ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _project = _project.copyWith(
        constructions: _project.constructions
            .where((c) => c.id != construction.id)
            .toList(),
      );
    });
    await _persist();
  }

  String _typeLabel(ConstructionType type) {
    switch (type) {
      case ConstructionType.window:
        return 'Fenêtre';
      case ConstructionType.door:
        return 'Porte';
      case ConstructionType.curtainWall:
        return 'Mur rideau';
    }
  }

  @override
  Widget build(BuildContext context) {
    final constructions = _project.constructions;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _project);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_project.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.home_outlined),
              tooltip: 'Retour à Mes projets',
              onPressed: () => Navigator.pop(context, _project),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: addConstruction,
          icon: const Icon(Icons.add),
          label: const Text('Ajouter une construction'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              _project.name,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              constructions.isEmpty
                  ? 'Aucune construction'
                  : '${constructions.length} construction'
                        '${constructions.length > 1 ? 's' : ''}',
            ),

            const SizedBox(height: 24),

            if (constructions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'Ce projet ne contient encore aucune construction.\n'
                    'Utilisez "Ajouter une construction" pour commencer.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              for (final construction in constructions)
                _ConstructionCard(
                  construction: construction,
                  typeLabel: _typeLabel(construction.type),
                  onTap: () => _openConstruction(construction),
                  onDelete: () => _deleteConstruction(construction),
                ),
          ],
        ),
      ),
    );
  }
}

class _ConstructionCard extends StatelessWidget {
  final Construction construction;
  final String typeLabel;
  final VoidCallback onTap;

  /// Deletes this construction from the project (after its own
  /// confirmation, handled by the parent) -- same trailing-icon pattern
  /// as the project cards on `ProjectDashboard`.
  final VoidCallback onDelete;

  const _ConstructionCard({
    required this.construction,
    required this.typeLabel,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      typeLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      construction.width == null || construction.height == null
                          ? 'Dimensions non définies'
                          : '${construction.width!.toStringAsFixed(0)} × '
                                '${construction.height!.toStringAsFixed(0)} mm',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${construction.sections.length} section'
                      '${construction.sections.length > 1 ? 's' : ''}',
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Supprimer',
                onPressed: onDelete,
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
