import 'package:flutter/material.dart';

import '../../../../core/logic/cut_aggregation.dart';
import '../../../../core/logic/cut_grouping.dart';
import '../../../../core/models/calculation_outcome.dart';
import '../../../../core/models/construction.dart';
import '../../../../core/models/rules/system_rule_set.dart'
    show AmbiguousRuleMatchException;
import '../../../../core/models/section.dart';
import 'bom_dialog.dart';
import 'cut_list_dialog.dart';
import 'production_export_dialog.dart';

/// Compact summary of the last calculation run, shown at the top of the
/// Sections stage's right panel regardless of whether a section is
/// currently selected (cuts are construction-wide, not per-section, so
/// tying visibility to section selection would hide results whenever
/// nothing is selected).
///
/// Exactly one of [error], [hadNoRuleSet], or a non-null [result] is the
/// active case -- `ConstructionEditorController.calculate` only ever sets
/// one of the three. Cuts are grouped by `ProfileCut.sectionId` (see
/// `groupCutsBySectionId`) so a list mixing several sections' pieces
/// doesn't read as one undivided pile -- still a flat `Column` of `Text`
/// per group, matching the plain informational style of the no-section /
/// no-system notices rather than introducing a new visual language for
/// what is still a placeholder-rule-set result, not real fabrication data.
/// Each cut row also shows its producing rule's description (cut-level
/// provenance) when the rule carries one.
///
/// Usages that produced no cut are listed after the cut groups with their
/// skip reason (`CalculationOutcome.issues`) -- "fewer cuts than
/// usages" is always explainable, never silent.
///
/// [isStale] shows a small "outdated" notice above whichever outcome is
/// active, when the draft has changed since that outcome was computed --
/// see `ConstructionEditorController`'s stale-outcome doc. The outcome
/// itself is never hidden or replaced on staleness, only flagged --
/// recalculation stays a manual, explicit action.
class CalculationResultsBanner extends StatelessWidget {
  final CalculationOutcome? result;
  final Object? error;
  final bool hadNoRuleSet;
  final List<Section> sections;
  final bool isStale;

  /// The construction whose calculation is being shown. Required and
  /// non-nullable: the production-export action reads the export
  /// metadata block and filename inputs from it. The export button
  /// itself only renders in the populated-result branch, but the
  /// field is required at the class level so no call site can render
  /// a banner whose export path would crash on a null dereference.
  final Construction construction;

  /// Name of the project the construction belongs to. Threaded from
  /// the editor screen (which receives it from the project
  /// workspace); forwarded to the export dialog. Required: the
  /// export header and filename must carry the real project name.
  final String projectName;

  const CalculationResultsBanner({
    super.key,
    required this.result,
    required this.error,
    required this.hadNoRuleSet,
    required this.sections,
    required this.isStale,
    required this.projectName,
    required this.construction,
  });

  @override
  Widget build(BuildContext context) {
    // Cap the banner at 1/3 of the viewport so a long calculation result
    // (13+ cuts with totals + diagnostics) can never overflow the right
    // properties panel. The user scrolls within the banner once it
    // reaches the bound -- the panel itself stays pinned. Without the
    // cap, a full result pushes the section panels off-screen because
    // the banner has no intrinsic height limit.
    final maxHeight = MediaQuery.of(context).size.height / 3;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
      color: const Color(0xFFF3F5F6),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
          if (isStale) ...[
            const Row(
              children: [
                Icon(Icons.update, size: 14, color: Color(0xFF8A6D00)),
                SizedBox(width: 6),
                // Expanded so the long notice wraps on narrow panels
                // instead of overflowing the Row horizontally (every
                // other text row in this banner is already Expanded).
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
            const SizedBox(height: 6),
          ],
          _buildContent(context),
        ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final error = this.error;
    if (error != null) {
      // AmbiguousRuleMatchException and StateError are the only two
      // exception types `calculate()` catches -- see that method's doc.
      // Both already have a clear `toString()` (AmbiguousRuleMatchException
      // names the tied rules; StateError carries the message it was thrown
      // with), so it's shown directly rather than re-worded here.
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFC62828), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error is AmbiguousRuleMatchException
                  ? 'Règles ambiguës : ${error.toString()}'
                  : error.toString(),
              style: const TextStyle(color: Color(0xFFC62828), fontSize: 12),
            ),
          ),
        ],
      );
    }

    if (hadNoRuleSet) {
      return const Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: Color(0xFF5B6B76)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Aucune règle de calcul disponible pour ce système.',
              style: TextStyle(color: Color(0xFF5B6B76), fontSize: 12),
            ),
          ),
        ],
      );
    }

    final outcome = result;
    if (outcome == null || outcome.isEmpty) {
      return const Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: Color(0xFF5B6B76)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Calcul effectué : aucune coupe produite.',
              style: TextStyle(color: Color(0xFF5B6B76), fontSize: 12),
            ),
          ),
        ],
      );
    }

    final grouped = groupCutsBySectionId(outcome.cuts);
    final profileTotals = aggregateProfileTotals(outcome.cuts);
    final grand = sumProfileTotals(profileTotals);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wrap rather than Row+Spacer: at narrow panel widths the
        // workshop button wraps below the count instead of overflowing
        // (the banner must never RenderFlex-overflow for any outcome
        // text length).
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 0,
          children: [
            Text(
              '${outcome.cuts.length} coupe(s)',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            // Workshop view: grouped physical cut lines derived purely
            // from this outcome. Hidden when there is nothing to list --
            // a button that opens an empty view would be inert UI.
            TextButton.icon(
              onPressed: () => CutListDialog.show(
                context,
                outcome: outcome,
                sections: sections,
                isStale: isStale,
              ),
              icon: const Icon(Icons.content_cut, size: 16),
              label: const Text(
                'Liste de découpe',
                style: TextStyle(fontSize: 12),
              ),
            ),
            // Unified BOM: profile + glass + hardware + accessories
            // grouped by domain. Opened in parallel with the cut list;
            // the two views are complementary, not redundant.
            TextButton.icon(
              onPressed: () => BomDialog.show(
                context,
                outcome: outcome,
                sections: sections,
                isStale: isStale,
              ),
              icon: const Icon(Icons.inventory_2_outlined, size: 16),
              label: const Text(
                'BOM',
                style: TextStyle(fontSize: 12),
              ),
            ),
            // Production documents: writes the cut list and BOM to
            // disk as two CSV files in a subdirectory of
            // <documents>/aluvis/exports/. Hidden when there is
            // nothing to export -- a button that exports empty files
            // would be inert UI. The button opens a small dialog
            // asking for a subdirectory name (default `production`),
            // then writes both files and surfaces the paths in a
            // SnackBar.
            TextButton.icon(
              onPressed: () => ProductionExportDialog.show(
                context,
                outcome: outcome,
                construction: construction,
                projectName: projectName,
                sections: sections,
                isStale: isStale,
              ),
              icon: const Icon(Icons.file_download_outlined, size: 16),
              label: const Text(
                'Exporter la production',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final entry in grouped.entries) ...[
          Text(
            sectionLabelForCutGroup(entry.key, sections),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5B6B76),
            ),
          ),
          for (final cut in entry.value)
            Padding(
              padding: const EdgeInsets.only(bottom: 2, left: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${cut.profile.name} — ${cut.length.toStringAsFixed(0)} mm '
                    '× ${cut.quantity} (${cut.angleStart.toStringAsFixed(0)}° / '
                    '${cut.angleEnd.toStringAsFixed(0)}°)',
                    style: const TextStyle(fontSize: 12),
                  ),
                  // Cut-level provenance: which rule produced this piece
                  // (only when the rule carries a description -- never
                  // invented here). A second dim line keeps the main
                  // numbers scannable.
                  if (cut.ruleDescription != null)
                    Text(
                      cut.ruleDescription!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF5B6B76),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 4),
        ],
        // Derived totals over the produced cuts -- pure aggregation of
        // data already on the cuts (pieces, linear metres) plus the
        // user-entered weightPerMeter. Weight is shown only when known;
        // nothing here estimates or invents a value.
        if (outcome.cuts.isNotEmpty) ...[
          const Text(
            'Récapitulatif',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5B6B76),
            ),
          ),
          const SizedBox(height: 2),
          for (final totals in profileTotals)
            Padding(
              padding: const EdgeInsets.only(bottom: 2, left: 8),
              child: Text(
                '${totals.profileName} ${totals.reference} : '
                '${_piecesLabel(totals.pieces)} — '
                '${(totals.totalLengthMm / 1000).toStringAsFixed(2)} m'
                '${_weightSuffix(totals.weightKg)}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              'Total : ${_piecesLabel(grand.pieces)} — '
              '${(grand.totalLengthMm / 1000).toStringAsFixed(2)} m'
              '${_weightSuffix(grand.weightKg)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 4),
        ],
        // Per-usage diagnostics: every usage that produced no cut, with
        // why. Warning-toned (matching the stale notice) rather than
        // error-red -- a skipped usage is usually a mid-editing state,
        // not a failure.
        if (outcome.issues.isNotEmpty) ...[
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
              padding: const EdgeInsets.only(bottom: 2, left: 8),
              child: Text(
                '${_usageLabel(issue.profileUsageId)} — '
                '${_labelForIssue(issue.reason)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF8A6D00)),
              ),
            ),
        ],
      ],
    );
  }

  /// `'2 pièces'` / `'1 pièce'` -- French plural handled at the only
  /// place that knows the count's display context.
  static String _piecesLabel(int pieces) =>
      '$pieces ${pieces > 1 ? 'pièces' : 'pièce'}';

  /// `' — 4.32 kg'` when a weight is known, '' otherwise -- the suffix
  /// simply disappears rather than showing an invented or zero value.
  static String _weightSuffix(double? weightKg) =>
      weightKg == null ? '' : ' — ${weightKg.toStringAsFixed(2)} kg';

  /// Short label for an issue row. Usages have no user-facing names yet,
  /// so the row leads with the usage id -- stable and already visible in
  /// no other place; when a named usage model arrives this is the one
  /// spot to swap.
  static String _usageLabel(String profileUsageId) =>
      'Assignation $profileUsageId';

  static String _labelForIssue(ProfileUsageIssueReason reason) {
    switch (reason) {
      case ProfileUsageIssueReason.profileUnresolved:
        return 'profil introuvable dans le système';
      case ProfileUsageIssueReason.noRuleMatched:
        return 'aucune règle de calcul ne correspond';
    }
  }
}
