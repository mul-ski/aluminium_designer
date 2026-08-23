import 'package:flutter/material.dart';

import '../../../../core/logic/cut_grouping.dart';
import '../../../../core/models/calculation_outcome.dart';
import '../../../../core/models/construction.dart';
import '../../../../core/models/cut.dart';
import '../../../../core/models/section.dart';
import '../editor_stage.dart';
import 'panel_header.dart';

/// The editor's left working zone: the DESIGN stage navigator (General /
/// Geometry / Sections) plus the construction/section structure tree --
/// selecting a section here drives canvas/properties selection exactly as
/// it did before this panel was extracted.
///
/// [calculationResult] is the last manual calculation run's outcome (or
/// null when calculation never ran / found no rule set) -- used only to
/// show a per-section cut-count badge (from the outcome's cuts); no
/// error/no-rule-set state is repeated per section, since the results
/// banner already shows that once at the construction level. A stale
/// result is still shown, dimmed via [calculationIsStale] -- see
/// `ConstructionEditorController`'s stale-outcome doc for why counts stay
/// visible instead of disappearing on edit.
class EditorStructurePanel extends StatelessWidget {
  final Construction construction;
  final EditorStage stage;
  final String? selectedSectionId;
  final CalculationOutcome? calculationResult;
  final bool calculationIsStale;
  final ValueChanged<EditorStage> onStageSelected;
  final VoidCallback onSelectConstruction;
  final ValueChanged<String> onSelectSection;

  const EditorStructurePanel({
    super.key,
    required this.construction,
    required this.stage,
    required this.selectedSectionId,
    required this.calculationResult,
    required this.calculationIsStale,
    required this.onStageSelected,
    required this.onSelectConstruction,
    required this.onSelectSection,
  });

  @override
  Widget build(BuildContext context) {
    final ordered = [...construction.sections]
      ..sort((a, b) => a.order.compareTo(b.order));
    final cuts = calculationResult?.cuts ?? const <ProfileCut>[];
    final cutsBySection = groupCutsBySectionId(cuts);

    return Material(
      color: const Color(0xFFFAFAFA),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: PanelHeader('DESIGN'),
          ),
          _StageNavItem(
            icon: Icons.info_outline,
            label: 'General',
            selected: stage == EditorStage.general,
            onTap: () => onStageSelected(EditorStage.general),
          ),
          _StageNavItem(
            icon: Icons.straighten,
            label: 'Geometry',
            selected: stage == EditorStage.geometry,
            onTap: () => onStageSelected(EditorStage.geometry),
          ),
          _StageNavItem(
            icon: Icons.dashboard_customize_outlined,
            label: 'Sections',
            selected: stage == EditorStage.sections,
            onTap: () => onStageSelected(EditorStage.sections),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Divider(height: 1),
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.view_quilt_outlined),
            title: Text(
              construction.name.isEmpty ? 'Construction' : construction.name,
              overflow: TextOverflow.ellipsis,
            ),
            selected: selectedSectionId == null,
            selectedTileColor: const Color(0xFFE3EEFB),
            onTap: onSelectConstruction,
          ),
          for (final section in ordered)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: ListTile(
                dense: true,
                leading: Icon(
                  section.kind == SectionKind.fixed
                      ? Icons.crop_square
                      : Icons.sensor_window_outlined,
                  size: 20,
                ),
                title: Text('Section ${section.order + 1}'),
                subtitle: Text(
                  section.kind == SectionKind.fixed ? 'Fixe' : 'Ouvrant',
                ),
                trailing: cutsBySection.containsKey(section.id)
                    ? _CutCountBadge(
                        // Physical pieces, not cut lines: quantities
                        // multiply per usage (see the quantity-composition
                        // rule), so a qty-3 placement must read as 3.
                        count: cutsBySection[section.id]!.fold<int>(
                          0,
                          (sum, cut) => sum + cut.quantity,
                        ),
                        isStale: calculationIsStale,
                      )
                    : null,
                selected: section.id == selectedSectionId,
                selectedTileColor: const Color(0xFFE3EEFB),
                onTap: () => onSelectSection(section.id),
              ),
            ),
        ],
      ),
    );
  }
}

/// One row in the DESIGN stage navigator. A plain `ListTile` would work
/// too, but this makes the "active stage must be visually identifiable"
/// requirement explicit via a left accent bar rather than relying only on
/// background-color contrast.
class _StageNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StageNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: selected ? const Color(0xFF1565C0) : Colors.transparent,
              width: 3,
            ),
          ),
          color: selected ? const Color(0xFFE3EEFB) : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? const Color(0xFF1565C0) : null,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? const Color(0xFF1565C0) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small pill showing how many physical pieces a section produced in the
/// last calculation (summed cut quantities -- quantities multiply per
/// usage, so this is a piece count, not a count of cut lines) -- only ever
/// built for a section that the calculation result actually has cuts for
/// (see the build's `cutsBySection.containsKey` check), so [count] is
/// always >= 1; a section with zero cuts (no profile usages assigned, or
/// usages that were skipped -- reported in the results banner's issues
/// block) simply shows no badge at all, same as a section that hasn't been
/// calculated yet -- neither case is distinguished here, since both mean
/// "nothing to show", and `CalculationResultsBanner` already states which
/// one it is at the construction level.
///
/// [isStale] dims the badge (rather than hiding it) when the draft has
/// changed since [count] was computed -- see
/// `ConstructionEditorController`'s stale-outcome doc for why the count
/// stays visible instead of disappearing on edit.
class _CutCountBadge extends StatelessWidget {
  final int count;
  final bool isStale;

  const _CutCountBadge({required this.count, required this.isStale});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isStale
            ? const Color(0xFFE3EEFB).withValues(alpha: 0.5)
            : const Color(0xFFE3EEFB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isStale ? const Color(0xFF5B6B76) : null,
        ),
      ),
    );
  }
}
