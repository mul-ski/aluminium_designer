import 'package:flutter/material.dart';
import '../../../core/models/project.dart';
import 'project_workspace_screen.dart';

/// Creates a new, empty [Project].
///
/// A project is just a name + container now -- type, dimensions, and
/// sections belong to a *construction* created later inside the project
/// workspace, not to the project itself. See [ProjectWorkspaceScreen].
class NewProjectScreen extends StatefulWidget {
  const NewProjectScreen({super.key});

  @override
  State<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends State<NewProjectScreen> {
  final nameController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  void createProject() {
    final name = nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un nom de projet.')),
      );
      return;
    }

    final project = Project(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      constructions: const [],
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectWorkspaceScreen(project: project),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau projet')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Nom du projet'),
          ),

          const SizedBox(height: 24),

          FilledButton(
            onPressed: createProject,
            child: const Text('Créer le projet'),
          ),
        ],
      ),
    );
  }
}
