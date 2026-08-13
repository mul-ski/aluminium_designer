import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/catalog.dart';
import '../models/catalog_json.dart';

/// Local on-disk persistence for the global [Catalog] (manufacturers and
/// profile systems).
///
/// Storage layout, inside the same app documents directory [ProjectStore]
/// uses:
///
/// ```
/// <documents>/aluvis/catalog.json
/// ```
///
/// A single file rather than one-per-entry (unlike `ProjectStore`, which
/// is one file per project) because the catalog is one app-wide list a
/// user builds up gradually, not a set of independently
/// created/deleted/exported units the way projects are -- there's no
/// equivalent need to export "one manufacturer" as its own file, and a
/// single small JSON file is simplest for something this size. This
/// mirrors `ProjectStore`'s reasoning in the opposite direction: same
/// constraints, different answer, because the data shape is different.
///
/// Deliberately not merged into `ProjectStore` or written inside any
/// project file -- the catalog is app-level data, not project-level data,
/// so it lives in its own file and is loaded/saved independently of any
/// project.
class CatalogStore {
  Directory? _appDir;

  Future<Directory> _dir() async {
    final cached = _appDir;
    if (cached != null) return cached;

    final documents = await getApplicationDocumentsDirectory();
    final dir = Directory('${documents.path}/aluvis');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _appDir = dir;
    return dir;
  }

  File _catalogFile(Directory dir) => File('${dir.path}/catalog.json');

  /// Loads the persisted catalog, or an empty [Catalog] if no catalog file
  /// exists yet (e.g. first run) or the file is unreadable/corrupt --
  /// matching `ProjectStore.loadAll`'s "skip corrupt data rather than
  /// crash app start" behaviour.
  Future<Catalog> load() async {
    final dir = await _dir();
    final file = _catalogFile(dir);

    if (!await file.exists()) {
      return const Catalog();
    }

    try {
      final contents = await file.readAsString();
      final json = jsonDecode(contents) as Map<String, dynamic>;
      return catalogFromJson(json);
    } catch (_) {
      return const Catalog();
    }
  }

  /// Writes [catalog] to disk, fully replacing the previous file.
  ///
  /// Like `ProjectStore.save`, there is no separate create/update path --
  /// the file is always rewritten from the current `Catalog` state, which
  /// is itself the single source of truth.
  Future<void> save(Catalog catalog) async {
    final dir = await _dir();
    final file = _catalogFile(dir);
    await file.writeAsString(jsonEncode(catalog.toJson()));
  }
}
