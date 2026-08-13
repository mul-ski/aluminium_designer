import 'package:flutter/material.dart';
import '../../../core/models/project.dart';
import '../../../core/storage/project_store.dart';
import 'new_project_screen.dart';
import 'project_workspace_screen.dart';

/// Owns the list of [Project]s for the app.
///
/// This is the single place `Project` state lives in memory, and the
/// single place that talks to [ProjectStore] for persistence.
/// `NewProjectScreen` creates a `Project` and hands it back via
/// `Navigator.pop`; this screen appends it to `_projects`, saves it to
/// disk, and is the one that pushes `ProjectWorkspaceScreen`.
/// `ProjectWorkspaceScreen` returns its (possibly updated, e.g. with new
/// constructions) `Project` when popped, and this screen replaces the
/// matching entry in `_projects` by id and re-saves it -- so the
/// workspace's local copy is transient UI state, not a second source of
/// truth, and disk is never out of sync with what's shown after a
/// successful save.
///
/// On start, `_projects` is loaded from [ProjectStore.loadAll] so projects
/// survive closing and reopening the app.
class ProjectDashboard extends StatefulWidget {
  const ProjectDashboard({super.key});

  @override
  State<ProjectDashboard> createState() => _ProjectDashboardState();
}

class _ProjectDashboardState extends State<ProjectDashboard> {
  final ProjectStore _store = ProjectStore();
  List<Project> _projects = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final projects = await _store.loadAll();
    if (!mounted) return;
    setState(() {
      _projects = projects;
      _loading = false;
    });
  }

  Future<void> _createProject() async {
    final project = await Navigator.push<Project>(
      context,
      MaterialPageRoute(builder: (_) => const NewProjectScreen()),
    );

    if (project == null) {
      return;
    }

    await _store.save(project);

    setState(() {
      _projects = [..._projects, project];
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

    await _store.save(updated);

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
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_projects.isEmpty)
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
