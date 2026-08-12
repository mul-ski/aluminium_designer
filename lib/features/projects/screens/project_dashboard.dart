import 'package:flutter/material.dart';
import '../../../core/models/project.dart';
import 'new_project_screen.dart';
import 'project_workspace_screen.dart';

/// Owns the in-memory list of [Project]s for the current app session.
///
/// This is the single place `Project` state lives. `NewProjectScreen`
/// creates a `Project` and hands it back via `Navigator.pop`; this screen
/// appends it to `_projects` and is the one that pushes
/// `ProjectWorkspaceScreen`. `ProjectWorkspaceScreen` returns its
/// (possibly updated, e.g. with new constructions) `Project` when popped,
/// and this screen replaces the matching entry in `_projects` by id --
/// so the workspace's local copy is transient UI state, not a second
/// source of truth. No persistence yet: `_projects` lives only as long as
/// this widget does, which for now is the app's lifetime (it's the root
/// screen).
class ProjectDashboard extends StatefulWidget {
  const ProjectDashboard({super.key});

  @override
  State<ProjectDashboard> createState() => _ProjectDashboardState();
}

class _ProjectDashboardState extends State<ProjectDashboard> {
  final List<Project> _projects = [];

  Future<void> _createProject() async {
    final project = await Navigator.push<Project>(
      context,
      MaterialPageRoute(builder: (_) => const NewProjectScreen()),
    );

    if (project == null) {
      return;
    }

    setState(() {
      _projects.add(project);
    });

    if (!mounted) return;
    await _openProject(project);
  }

  Future<void> _openProject(Project project) async {
    final updated = await Navigator.push<Project>(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectWorkspaceScreen(project: project),
      ),
    );

    if (updated == null) {
      return;
    }

    setState(() {
      final index = _projects.indexWhere((p) => p.id == updated.id);
      if (index != -1) {
        _projects[index] = updated;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AluVis',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mes projets',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('Créez et gérez vos constructions en aluminium.'),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _createProject,
                    icon: const Icon(Icons.add),
                    label: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Nouveau projet'),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_projects.isEmpty)
                  const Text('Aucun projet pour le moment.')
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: _projects.length,
                      itemBuilder: (context, index) {
                        final project = _projects[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(project.name),
                            subtitle: Text(
                              '${project.constructions.length} construction'
                              '${project.constructions.length > 1 ? 's' : ''}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openProject(project),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
