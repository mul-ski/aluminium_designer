import 'package:flutter/material.dart';
import '../../../core/models/construction.dart';
import '../../../core/models/construction_type.dart';
import '../../../core/models/project.dart';
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
/// State is held locally for this milestone since there is no persistence
/// layer yet: `Project` is immutable, so adding a construction rebuilds
/// the `Project` via `copyWith` and this widget's `_project` state field is
/// updated to the new instance.
class ProjectWorkspaceScreen extends StatefulWidget {
  final Project project;

  const ProjectWorkspaceScreen({super.key, required this.project});

  @override
  State<ProjectWorkspaceScreen> createState() => _ProjectWorkspaceScreenState();
}

class _ProjectWorkspaceScreenState extends State<ProjectWorkspaceScreen> {
  late Project _project;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
  }

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

    return Scaffold(
      appBar: AppBar(title: Text(_project.name)),
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
              ),
        ],
      ),
    );
  }
}

class _ConstructionCard extends StatelessWidget {
  final Construction construction;
  final String typeLabel;

  const _ConstructionCard({
    required this.construction,
    required this.typeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              typeLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('${construction.width} × ${construction.height} mm'),
            const SizedBox(height: 4),
            Text(
              '${construction.sections.length} section'
              '${construction.sections.length > 1 ? 's' : ''}',
            ),
          ],
        ),
      ),
    );
  }
}
