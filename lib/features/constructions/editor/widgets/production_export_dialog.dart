import 'dart:io' show Directory;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/models/calculation_outcome.dart';
import '../../../../core/models/construction.dart';
import '../../../../core/models/section.dart';
import '../../../../core/production_export/production_export.dart';

/// Lets the user export the current calculation as the two
/// production CSV files. The dialog is a small form: a single
/// `TextField` for a subdirectory name (default `production`) and
/// an "Exporter" button. On submit the exporter writes to
/// `<documents>/aluvis/exports/<subdir>/`; a [SnackBar] reports
/// the two file paths on success or the error on failure.
///
/// The dialog is the production surface for the `Exporter la
/// production` button on the calculation results banner. It does
/// NOT add a system directory-picker dependency: on a fresh install
/// the user gets a sensible default `<documents>/aluvis/exports/production/`,
/// and on a populated install they can name any subdirectory they
/// like. A native file-chooser is a follow-up; this dialog keeps the
/// milestone at zero new dependencies.
class ProductionExportDialog extends StatefulWidget {
  final CalculationOutcome outcome;
  final Construction construction;

  /// Name of the project the construction belongs to. Threaded from
  /// the editor screen; forwarded to the exporter for the header
  /// (`# Project:`) and filename slug. Required: never substitute
  /// the construction name.
  final String projectName;
  final List<Section> sections;
  final bool isStale;

  const ProductionExportDialog({
    super.key,
    required this.outcome,
    required this.construction,
    required this.projectName,
    required this.sections,
    required this.isStale,
  });

  static Future<void> show(
    BuildContext context, {
    required CalculationOutcome outcome,
    required Construction construction,
    required String projectName,
    required List<Section> sections,
    required bool isStale,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => ProductionExportDialog(
        outcome: outcome,
        construction: construction,
        projectName: projectName,
        sections: sections,
        isStale: isStale,
      ),
    );
  }

  @override
  State<ProductionExportDialog> createState() => _ProductionExportDialogState();
}

class _ProductionExportDialogState extends State<ProductionExportDialog> {
  late final TextEditingController _subdirController;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _subdirController = TextEditingController(text: 'production');
  }

  @override
  void dispose() {
    _subdirController.dispose();
    super.dispose();
  }

  /// Sanitizes a user-entered subdirectory name. Empty -> `production`.
  /// Path-traversal (`..`, `/`, `\`) is rejected; the dialog refuses
  /// to export to a path outside the export root.
  String? _validate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'production';
    if (trimmed.contains('/') || trimmed.contains('\\')) {
      return null;
    }
    if (trimmed == '.' || trimmed == '..') return null;
    if (trimmed.contains('..')) return null;
    return trimmed;
  }

  Future<void> _runExport() async {
    final subdir = _validate(_subdirController.text);
    if (subdir == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nom de sous-dossier invalide (pas de /, \\, .., ou .)',
          ),
        ),
      );
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final docs = await getApplicationDocumentsDirectory();
      final exportsRoot = Directory('${docs.path}/aluvis/exports');
      final target = Directory('${exportsRoot.path}/$subdir');
      if (!await target.exists()) {
        await target.create(recursive: true);
      }

      final exporter = ProductionExporter(exportedAt: DateTime.now());
      final written = await exporter.exportToDirectory(
        construction: widget.construction,
        projectName: widget.projectName,
        outcome: widget.outcome,
        sections: widget.sections,
        isStale: widget.isStale,
        directory: target,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      final paths = written.map((f) => f.path).join('\n');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exports écrits :\n$paths'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de l\'export : $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Exporter la production'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Les fichiers CSV (liste de découpe + BOM) sont écrits dans :',
          ),
          const SizedBox(height: 8),
          FutureBuilder<Directory>(
            future: getApplicationDocumentsDirectory(),
            builder: (context, snapshot) {
              final base = snapshot.data != null
                  ? '${snapshot.data!.path}/aluvis/exports/'
                  : '<documents>/aluvis/exports/';
              return Text(
                '$base<subdir>/',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subdirController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Sous-dossier',
              hintText: 'production',
            ),
            onSubmitted: (_) {
              if (!_busy) _runExport();
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _busy ? null : _runExport,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Exporter'),
        ),
      ],
    );
  }
}

// Imported at the top so this file stays a single source for the
// dialog and can be hidden if a future native file-chooser
// replaces it.
