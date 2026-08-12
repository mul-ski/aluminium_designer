import 'package:flutter/material.dart';
import '../../../core/models/project.dart';

/// Creates a new, empty [Project] and returns it to the caller.
///
/// This screen only builds a `Project` and pops with it -- it does not
/// navigate anywhere else itself. Deciding what happens after creation
/// (adding the project to the in-memory list, then opening the workspace)
/// is `ProjectDashboard`'s job, since `ProjectDashboard` is the single
/// owner of project state. If this screen also pushed
/// `ProjectWorkspaceScreen`, the stack would become Dashboard ->
/// NewProjectScreen -> Workspace, and Dashboard's `Navigator.push` await
/// would only resolve once *both* screens popped -- which is exactly the
/// bug being fixed here.
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

    Navigator.pop(context, project);
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
