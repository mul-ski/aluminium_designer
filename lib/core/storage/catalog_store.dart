import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../data/builtin_catalog_seed.dart';
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
/// <documents>/aluvis/.catalog_seeded
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
///
/// SEEDING: `.catalog_seeded` is a tiny sentinel file (its content is
/// unused; only its presence matters) marking "the built-in
/// manufacturer/system seed has already been applied at least once."
/// [load] merges in `withBuiltInCatalogSeed` and creates this sentinel
/// only the very first time it runs -- never again after that, on
/// purpose. Without this, re-running the seed merge on every load would
/// make a built-in manufacturer/system effectively undeletable: the
/// existing delete UI in `ManufacturerSystemPicker` applies to built-in
/// entries exactly like user-created ones (there's no protection against
/// it), so a user who deletes "Aluminium du Maroc" must have that
/// deletion actually stick on the next app restart, not have it silently
/// reappear. A separate sentinel file (rather than, say, a field on
/// `Catalog` itself) keeps this concern entirely inside the storage layer
/// -- the domain model has no reason to know whether it was ever seeded.
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

  File _seededMarkerFile(Directory dir) => File('${dir.path}/.catalog_seeded');

  /// Loads the persisted catalog, or an empty [Catalog] if no catalog file
  /// exists yet (e.g. first run) or the file is unreadable/corrupt --
  /// matching `ProjectStore.loadAll`'s "skip corrupt data rather than
  /// crash app start" behaviour.
  ///
  /// On the very first call ever (no `.catalog_seeded` sentinel present),
  /// merges in the verified built-in manufacturer/system records from
  /// `builtin_catalog_seed.dart`, persists the merged result, and writes
  /// the sentinel so this never happens again -- see the class doc's
  /// "SEEDING" note for why a one-time merge, not a merge on every load.
  Future<Catalog> load() async {
    final dir = await _dir();
    final file = _catalogFile(dir);

    Catalog catalog;
    if (!await file.exists()) {
      catalog = const Catalog();
    } else {
      try {
        final contents = await file.readAsString();
        final json = jsonDecode(contents) as Map<String, dynamic>;
        catalog = catalogFromJson(json);
      } catch (_) {
        catalog = const Catalog();
      }
    }

    final seededMarker = _seededMarkerFile(dir);
    if (!await seededMarker.exists()) {
      final seeded = withBuiltInCatalogSeed(catalog);
      if (seeded.manufacturers.length != catalog.manufacturers.length ||
          seeded.profileSystems.length != catalog.profileSystems.length) {
        catalog = seeded;
        await save(catalog);
      }
      await seededMarker.writeAsString('1');
    }

    // Adopt real built-in rule sets on EVERY load -- not just the
    // seeding pass. Installs seeded before a built-in system's rules
    // landed keep the sentinel above, so pure add-only merging would
    // leave them calculating placeholder cuts forever. Identity
    // comparison detects "nothing refreshed" (no write). Deletion
    // stickiness is preserved: only records still present are touched.
    final adopted = adoptBuiltInRuleSets(catalog);
    if (!identical(adopted, catalog)) {
      catalog = adopted;
      await save(catalog);
    }

    return catalog;
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

  /// Test-only access to the storage directory: tests that simulate
  /// pre-seeded installs must place `.catalog_seeded` next to
  /// `catalog.json` before calling [load].
  // Not @visibleForTesting only because `meta` isn't a direct dependency;
  // the doc comment carries the same contract.
  Future<Directory> directoryForTest() => _dir();
}
