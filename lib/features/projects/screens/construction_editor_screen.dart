import 'package:flutter/material.dart';

import '../../../core/models/construction.dart';
import '../../../core/models/opening.dart';
import '../../../core/models/section.dart';
import '../widgets/construction_elevation_painter.dart';
import '../widgets/section_layout_geometry.dart';

/// First milestone of the 2D construction editor: a read-only elevation
/// view of a [Construction] with section selection.
///
/// `Construction`/`Section` remain the sole source of truth for geometry.
/// Nothing here is persisted -- `_selectedSectionId` is transient editor UI
/// state, held only for as long as this screen is open, and is never
/// written onto `Construction`/`Section`, never returned to the caller,
/// and never saved. This screen does not modify the construction it's
/// given in any way in this milestone: dragging, resizing, adding/removing
/// sections, inline editing, profile/calculation/3D work are all
/// deliberately out of scope here.
class ConstructionEditorScreen extends StatefulWidget {
  final Construction construction;

  const ConstructionEditorScreen({super.key, required this.construction});

  @override
  State<ConstructionEditorScreen> createState() =>
      _ConstructionEditorScreenState();
}

class _ConstructionEditorScreenState extends State<ConstructionEditorScreen> {
  String? _selectedSectionId;

  /// Handles a tap on the canvas: finds which section rectangle (if any)
  /// contains the tap point, using the exact same [layoutSectionRects]
  /// geometry the painter draws from -- see that function's doc comment
  /// for why hit testing and painting share one geometry source rather
  /// than each computing their own. Tapping outside every section rect
  /// (empty canvas space) clears the selection.
  void _handleTapDown(TapDownDetails details, Size canvasSize) {
    const margin = 48.0;
    final canvasRect = Rect.fromLTWH(
      margin,
      margin,
      canvasSize.width - margin * 2,
      canvasSize.height - margin * 2,
    );

    final sectionRects = layoutSectionRects(
      construction: widget.construction,
      canvasRect: canvasRect,
    );

    final hit = sectionRects.where(
      (sr) => sr.rect.contains(details.localPosition),
    );

    setState(() {
      _selectedSectionId = hit.isEmpty ? null : hit.first.section.id;
    });
  }

  Section? get _selectedSection {
    final id = _selectedSectionId;
    if (id == null) return null;
    for (final section in widget.construction.sections) {
      if (section.id == id) return section;
    }
    return null;
  }

  String _openingTypeLabel(OpeningType type) {
    switch (type) {
      case OpeningType.fixe:
        return 'Fixe';
      case OpeningType.francaise:
        return 'Française';
      case OpeningType.anglaise:
        return 'Anglaise';
      case OpeningType.oscilloBattant:
        return 'Oscillo-battant';
      case OpeningType.coulissante:
        return 'Coulissante';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.construction.name)),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final canvasSize = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => _handleTapDown(details, canvasSize),
                  child: CustomPaint(
                    size: canvasSize,
                    painter: ConstructionElevationPainter(
                      construction: widget.construction,
                      selectedSectionId: _selectedSectionId,
                    ),
                  ),
                );
              },
            ),
          ),
          _SectionPropertiesPanel(
            section: _selectedSection,
            openingTypeLabel: _openingTypeLabel,
          ),
        ],
      ),
    );
  }
}

/// Read-only panel showing the currently selected section's properties, or
/// a placeholder message when nothing is selected.
class _SectionPropertiesPanel extends StatelessWidget {
  final Section? section;
  final String Function(OpeningType) openingTypeLabel;

  const _SectionPropertiesPanel({
    required this.section,
    required this.openingTypeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final section = this.section;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: const Border(top: BorderSide(color: Colors.black12)),
      ),
      child: section == null
          ? const Text('Aucune section sélectionnée.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Section ${section.order + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _PropertyRow(
                  label: 'Type',
                  value: section.kind == SectionKind.ouvrant
                      ? 'Ouvrant'
                      : 'Fixe',
                ),
                _PropertyRow(
                  label: 'Largeur',
                  value: '${section.width} mm',
                ),
                _PropertyRow(
                  label: 'Hauteur',
                  value: '${section.height} mm',
                ),
                if (section.kind == SectionKind.ouvrant) ...[
                  _PropertyRow(
                    label: "Type d'ouverture",
                    value: openingTypeLabel(section.openingType!),
                  ),
                  _PropertyRow(
                    label: 'Vantaux',
                    value: '${section.vantauxCount}',
                  ),
                ],
              ],
            ),
    );
  }
}

class _PropertyRow extends StatelessWidget {
  final String label;
  final String value;

  const _PropertyRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
