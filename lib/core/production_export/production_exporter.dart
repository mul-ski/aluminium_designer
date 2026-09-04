import 'dart:io';

import '../models/calculation_outcome.dart';
import '../models/construction.dart';
import '../models/section.dart';
import 'bom_csv_renderer.dart';
import 'cuts_csv_renderer.dart';
import 'production_header.dart';

/// Filesystem path + rendered contents for one export of one
/// construction. The exporter returns a list of these so the caller
/// (today: the editor's results banner; tomorrow: a batch export
/// command if a workshop asks) can decide what to do with them --
/// open one in a viewer, email one, archive one.
class ProductionExportFile {
  /// Absolute or relative path the file was written to. Set by
  /// [ProductionExporter.exportToDirectory].
  final String path;

  /// The full file contents. Held in memory so the caller can
  /// re-display, hash, or post-process without re-reading the disk.
  /// This is fine for production-document sizes (the largest
  /// realistic output is a few hundred KB; even a 50-section
  /// construction is well under 1 MB).
  final String contents;

  const ProductionExportFile({required this.path, required this.contents});
}

/// One export run for one construction. The exporter is a stateless
/// class with one [exportToDirectory] method; the same
/// [CalculationOutcome] + [Construction] pair produces the same bytes
/// for the same [ProductionHeader.exportedAt] (which tests pin to a
/// fixed value) -- the renderer is the single source of truth for
/// what an export file looks like, and the exporter is just a thin
/// orchestrator that wires header + renderer + filename + disk I/O.
///
/// Every value the exporter writes is data already on a model field
/// (or the exporter's [exportedAt] timestamp). The exporter does not
/// compute, estimate, or invent engineering numbers -- the same
/// rule that governs the on-screen cut list and BOM dialogs.
class ProductionExporter {
  /// `DateTime` stamped at the moment the export was produced. The
  /// production code path passes `DateTime.now()`; tests pass a fixed
  /// value to keep the rendered bytes deterministic.
  final DateTime exportedAt;

  const ProductionExporter({required this.exportedAt});

  /// Renders both CSV files for [construction] + [outcome] and writes
  /// them to [directory], creating it if it doesn't exist. Returns
  /// the two written files in source-declaration order (cut list
  /// first, BOM second) so a caller can pick the first entry if it
  /// only needs one.
  ///
  /// [directory] must be a `Directory`; the exporter does not perform
  /// any path-traversal or filename-escape logic beyond
  /// [ProductionHeader.slug] (which is already ASCII-safe). The
  /// filename format is the same for every system:
  ///
  ///   `aluvis-{project-slug}-{construction-slug}-{6-char-id}.cuts.csv`
  ///   `aluvis-{project-slug}-{construction-slug}-{6-char-id}.bom.csv`
  ///
  /// The 6-character id prefix is the first 6 chars of
  /// [Construction.id], stable across runs. The same construction
  /// re-exported to the same directory never overwrites a different
  /// construction's file (the construction id is unique per
  /// construction). Re-exporting the same construction overwrites its
  /// own previous export by design -- the user just re-ran Calculer
  /// and wants the new numbers.
  ///
  /// Throws [FileSystemException] if [directory] cannot be created or
  /// written. Throws [IOException] for I/O errors. The caller is
  /// expected to surface the error to the user (e.g. a SnackBar).
  Future<List<ProductionExportFile>> exportToDirectory({
    required Construction construction,
    required String projectName,
    required CalculationOutcome outcome,
    required List<Section> sections,
    required bool isStale,
    required Directory directory,
  }) async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final header = ProductionHeader.fromConstruction(
      exportedAt: exportedAt,
      projectName: projectName,
      construction: construction,
      isStale: isStale,
    );
    final cutsRenderer = CutsCsvRenderer(
      header: header,
      sections: sections,
      outcome: outcome,
    );
    final bomRenderer = BomCsvRenderer(
      header: header,
      sections: sections,
      outcome: outcome,
    );

    final cutsContents = cutsRenderer.render();
    final bomContents = bomRenderer.render();

    final baseName =
        'aluvis-${header.projectSlug()}-${header.slug()}-${header.shortId()}';
    final cutsPath = '${directory.path}/$baseName.cuts.csv';
    final bomPath = '${directory.path}/$baseName.bom.csv';

    final cutsFile = File(cutsPath);
    final bomFile = File(bomPath);
    await cutsFile.writeAsString(cutsContents, flush: false);
    await bomFile.writeAsString(bomContents, flush: false);

    return [
      ProductionExportFile(path: cutsPath, contents: cutsContents),
      ProductionExportFile(path: bomPath, contents: bomContents),
    ];
  }
}
