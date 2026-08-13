import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/project.dart';
import '../models/project_json.dart';

/// Local on-disk persistence for [Project]s.
///
/// Storage layout, inside the app's documents directory
/// (`getApplicationDocumentsDirectory()`, which is the standard
/// cross-platform location on both Linux desktop and Android via
/// `path_provider` -- no server, no cloud):
///
/// ```
/// <documents>/aluvis/projects/<project-id>.json   -- one file per project
/// <documents>/aluvis/projects/index.json          -- {id, name} listing
/// ```
///
/// One file per project (rather than a single monolithic file holding
/// every project) was chosen because:
/// - it matches the JSON-export requirement directly -- a project file
///   *is* a valid export/import unit with no separate serializer needed;
/// - saving one project never risks corrupting another's data;
/// - it avoids adding a SQL dependency (sqflite/drift) for a milestone
///   that explicitly asked not to overbuild persistence yet.
///
/// The `index.json` file exists purely so the dashboard can list project
/// names without reading and decoding every project file on every app
/// start -- it is a cache of `{id, name}` pairs, not a second source of
/// truth for project content. It is rewritten every time a project is
/// saved or deleted, kept in sync with the actual project files.
class ProjectStore {
  Directory? _projectsDir;

  Future<Directory> _dir() async {
    final cached = _projectsDir;
    if (cached != null) return cached;

    final documents = await getApplicationDocumentsDirectory();
    final dir = Directory('${documents.path}/aluvis/projects');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _projectsDir = dir;
    return dir;
  }

  File _projectFile(Directory dir, String id) => File('${dir.path}/$id.json');

  File _indexFile(Directory dir) => File('${dir.path}/index.json');

  /// Loads every persisted project, sorted by id (stable, since ids are
  /// millisecond timestamps at creation time -- oldest first).
  ///
  /// Reads project files directly rather than trusting `index.json` for
  /// content, since the index only caches names -- this guarantees the
  /// full `List<Construction>` for each project is loaded, matching
  /// requirement 5 (constructions must survive reopening a project).
  Future<List<Project>> loadAll() async {
    final dir = await _dir();
    final projects = <Project>[];

    final entries = dir.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.json') && !f.path.endsWith('index.json'),
    );

    for (final file in entries) {
      try {
        final contents = await file.readAsString();
        final json = jsonDecode(contents) as Map<String, dynamic>;
        projects.add(projectFromJson(json));
      } catch (_) {
        // Skip a corrupt/unreadable project file rather than failing the
        // whole app start -- the other projects should still load.
        continue;
      }
    }

    projects.sort((a, b) => a.id.compareTo(b.id));
    return projects;
  }

  /// Writes [project] to its own file and refreshes `index.json`.
  ///
  /// Called both for brand-new projects and for updates (e.g. after a
  /// construction is added) -- there is no separate "create" vs "update"
  /// path, since the file is always fully rewritten from the current
  /// `Project` state, which is itself the single source of truth.
  Future<void> save(Project project) async {
    final dir = await _dir();
    final file = _projectFile(dir, project.id);
    await file.writeAsString(jsonEncode(project.toJson()));
    await _rewriteIndex(dir);
  }

  /// Deletes [projectId]'s file and refreshes `index.json`. Not currently
  /// wired to any UI action -- provided for completeness/future use.
  Future<void> delete(String projectId) async {
    final dir = await _dir();
    final file = _projectFile(dir, projectId);
    if (await file.exists()) {
      await file.delete();
    }
    await _rewriteIndex(dir);
  }

  Future<void> _rewriteIndex(Directory dir) async {
    final projects = await loadAll();
    final index = projects.map((p) => {'id': p.id, 'name': p.name}).toList();
    await _indexFile(dir).writeAsString(jsonEncode(index));
  }
}
