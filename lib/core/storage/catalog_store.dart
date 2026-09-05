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
/// only the very first time it runs. The sentinel itself no longer
/// gates the merge (see below); it is kept so first-run behavior stays
/// observable and existing installs keep their marker.
///
/// MERGE ON EVERY LOAD (not just first launch): two facts made the old
/// one-time merge wrong. First, an install seeded BEFORE a built-in
/// system existed keeps missing that system forever -- e.g. pre-C4b
/// installs persist only `Aluminium du Maroc` / `Cuzco 713 OM` and
/// would never see Maghreb Extrusion or Sepalumic. Second, the old
/// rationale for one-time merging (deletion stickiness -- a user who
/// deletes a built-in must have that stick) is obsolete: the picker
/// no longer offers delete for `isBuiltIn` records, so re-adding a
/// missing built-in cannot resurrect a deliberate user deletion.
/// `withBuiltInCatalogSeed` is already add-only by id and returns the
/// same instance when there is nothing to add, so running it on every
/// load is a no-op for up-to-date installs (identity-checked, no
/// disk write). User-created records are never touched by the merge.
///
/// PRUNING: [pruneRemovedBuiltIns] drops `isBuiltIn` records whose ids
/// this build no longer ships (superseded seeds like the pre-C4b
/// `Aluminium du Maroc` set). Also identity-checked, also never
/// touches user records.
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
  /// On every load (not just the first): merges in any missing verified
  /// built-in records via `withBuiltInCatalogSeed`, prunes superseded
  /// built-ins via `pruneRemovedBuiltIns`, and persists + writes the
  /// `.catalog_seeded` sentinel only when something actually changed
  /// (both helpers return the same instance on no-op, detected by
  /// identity) -- see the class doc for why every-load merging is safe
  /// now that built-ins are no longer deletable via the picker.
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
    final merged = withBuiltInCatalogSeed(catalog);
    final pruned = pruneRemovedBuiltIns(merged);
    if (!identical(pruned, catalog)) {
      catalog = pruned;
      await save(catalog);
    }
    if (!await seededMarker.exists()) {
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
