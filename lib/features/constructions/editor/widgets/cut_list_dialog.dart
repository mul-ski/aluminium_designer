import 'package:flutter/material.dart';

import '../../../../core/logic/cut_aggregation.dart';
import '../../../../core/logic/cut_grouping.dart';
import '../../../../core/models/calculation_outcome.dart';
import '../../../../core/models/section.dart';

/// Full-screen workshop view of the last calculation run: grouped,
/// physical cut lines ("what the fabricator actually cuts") derived
/// PURELY from [outcome] via `buildCutListLines` -- identical cuts merge
/// with summed quantities while usage/section/rule provenance stays on
/// every line.
///
/// Opened from `CalculationResultsBanner`'s "Liste de découpe" action;
/// the banner itself stays compact and scannable. Same visual language
/// as the banner (plain informational rows, French), including:
/// - the stale flag passed through ([isStale]) -- an outdated outcome is
///   flagged, never hidden; recalculation stays manual;
/// - weight shown only when derivable from positive `weightPerMeter`
///   (unknown disappears rather than becoming a zero);
/// - per-usage diagnostics listed after the cut lines, warning-toned.
class CutListDialog extends StatelessWidget {
  final CalculationOutcome outcome;
  final List<Section> sections;
  final bool isStale;

  const CutListDialog({
    super.key,
    required this.outcome,
    required this.sections,
    required this.isStale,
  });

  /// Opens the workshop view for [outcome] over [sections].
  static Future<void> show(
    BuildContext context, {
    required CalculationOutcome outcome,
    required List<Section> sections,
    required bool isStale,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog.fullscreen(
        child: CutListDialog(
          outcome: outcome,
          sections: sections,
          isStale: isStale,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = buildCutListLines(outcome.cuts);
    final summary = sumCutListLines(lines);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste de découpe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Fermer',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (isStale) ...[
            const Row(
              children: [
                Icon(Icons.update, size: 14, color: Color(0xFF8A6D00)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Résultat obsolète -- appuyez sur Calculer pour '
                    'actualiser.',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF8A6D00),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          // Header summary over the GROUPED lines: pieces and metres
          // match the banner's grand totals (same derivation inputs),
          // weight appears only when derivable.
          Text(
            'Total : ${summary.pieces} '
            '${summary.pieces > 1 ? 'pièces' : 'pièce'} — '
            '${(summary.totalLengthMm / 1000).toStringAsFixed(2)} m'
            '${summary.weightKg == null ? '' : ' — ${summary.weightKg!.toStringAsFixed(2)} kg'}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          for (final line in lines) ...[
            _CutListLineTile(line: line, sections: sections),
            const Divider(height: 1),
          ],
          if (lines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Aucune coupe produite.',
                style: TextStyle(color: Color(0xFF5B6B76), fontSize: 12),
              ),
            ),
          if (outcome.issues.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${outcome.issues.length} assignation(s) sans coupe',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8A6D00),
              ),
            ),
            const SizedBox(height: 2),
            for (final issue in outcome.issues)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  'Assignation ${issue.profileUsageId} — '
                  '${_issueReasonLabel(issue.reason)}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF8A6D00)),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Same wording as the results banner's issue rows -- the two views
  /// must never disagree about why a usage produced no cut.
  static String _issueReasonLabel(ProfileUsageIssueReason reason) {
    switch (reason) {
      case ProfileUsageIssueReason.profileUnresolved:
        return 'profil introuvable dans le système';
      case ProfileUsageIssueReason.noRuleMatched:
        return 'aucune règle de calcul ne correspond';
    }
  }
}

class _CutListLineTile extends StatelessWidget {
  final CutListLine line;
  final List<Section> sections;

  const _CutListLineTile({required this.line, required this.sections});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main workshop row: reference + name, cut length × physical
          // quantity, angles -- everything a fabricator sets on the saw,
          // in one scannable line.
          Text(
            '${line.reference} — ${line.profileName} : '
            '${line.lengthMm.toStringAsFixed(0)} mm × '
            '${line.quantity} '
            '(${line.angleStart.toStringAsFixed(0)}° / '
            '${line.angleEnd.toStringAsFixed(0)}°)',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 2),
          // Derived line totals (metres + weight when known).
          Text(
            '${line.quantity} ${line.quantity > 1 ? 'pièces' : 'pièce'} — '
            '${(line.totalLengthMm / 1000).toStringAsFixed(2)} m'
            '${line.weightKg == null
                ? ''
                : ' — ${line.weightKg!.toStringAsFixed(2)} kg'}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF5B6B76)),
          ),
          // Section traceability: which section(s) produced this line --
          // shown only when the caller could resolve labels.
          if (line.contributingSectionIds.isNotEmpty)
            Text(
              'Sections : ${line.contributingSectionIds
                  .map((id) => sectionLabelForCutGroup(id, sections))
                  .join(', ')}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF5B6B76)),
            ),
          // Rule provenance survives grouping: one dim line per distinct
          // producing rule, never invented.
          for (final description in line.ruleDescriptions)
            Text(
              description,
              style: const TextStyle(fontSize: 11, color: Color(0xFF5B6B76)),
            ),
        ],
      ),
    );
  }
}
