import 'package:flutter/material.dart';

import '../../../core/models/opening.dart';
import '../../../core/models/section.dart';
import '../widgets/construction_painter.dart' show openingTypeLabel;

/// A basic add/edit/remove list editor for a [Construction]'s [Section]s.
///
/// This is deliberately list-based, not canvas-based -- dragging/resizing
/// sections directly on the 2D canvas is out of scope for this milestone
/// (see the construction editor's own doc comment). Each row edits one
/// section's fields via a dialog and calls [onSectionsChanged] with the
/// full updated list; this widget holds no section state of its own; the
/// construction being edited is always the single source of truth,
/// matching how the 2D canvas already reads directly from
/// `Construction.sections`.
class SectionListEditor extends StatelessWidget {
  final List<Section> sections;
  final ValueChanged<List<Section>> onSectionsChanged;

  const SectionListEditor({
    super.key,
    required this.sections,
    required this.onSectionsChanged,
  });

  Future<void> _addSection(BuildContext context) async {
    final section = await _showSectionDialog(context, order: sections.length);
    if (section == null) return;
    onSectionsChanged([...sections, section]);
  }

  Future<void> _editSection(BuildContext context, Section existing) async {
    final edited = await _showSectionDialog(
      context,
      order: existing.order,
      existing: existing,
    );
    if (edited == null) return;
    onSectionsChanged([
      for (final s in sections)
        if (s.id == existing.id) edited else s,
    ]);
  }

  void _removeSection(Section target) {
    final remaining = sections.where((s) => s.id != target.id).toList();
    // Reassign order 0..n-1 after removal so there's no gap -- order is
    // meaningful for layout (see `Section.order`'s doc comment), and a
    // gap left by a removed middle section would not itself break
    // anything (layoutConstruction sorts by order, doesn't require
    // contiguity) but would make order values misleading if inspected or
    // persisted, so it's cleaned up here rather than left as debt.
    final reordered = <Section>[];
    for (var i = 0; i < remaining.length; i++) {
      final s = remaining[i];
      reordered.add(
        Section(
          id: s.id,
          order: i,
          kind: s.kind,
          width: s.width,
          height: s.height,
          openingType: s.openingType,
          vantauxCount: s.vantauxCount,
        ),
      );
    }
    onSectionsChanged(reordered);
  }

  Future<Section?> _showSectionDialog(
    BuildContext context, {
    required int order,
    Section? existing,
  }) async {
    return showSectionDialog(context, order: order, existing: existing);
  }

  @override
  Widget build(BuildContext context) {
    final ordered = [...sections]..sort((a, b) => a.order.compareTo(b.order));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Sections',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: () => _addSection(context),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une section'),
            ),
          ],
        ),
        if (ordered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Aucune section pour le moment.'),
          )
        else
          for (final section in ordered)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  '${section.kind == SectionKind.fixed ? "Fixe" : "Ouvrant"} '
                  '-- ${section.width.toStringAsFixed(0)} × '
                  '${section.height.toStringAsFixed(0)} mm',
                ),
                subtitle: section.kind == SectionKind.ouvrant
                    ? Text(
                        '${openingTypeLabel(section.openingType!)} -- '
                        '${section.vantauxCount} vantaux',
                      )
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Modifier',
                      onPressed: () => _editSection(context, section),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Supprimer',
                      onPressed: () => _removeSection(section),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

/// Shows the add/edit section dialog. Extracted as a top-level function
/// (rather than only reachable via [SectionListEditor]) so the new
/// toolbar-driven "Add Section" action in `ConstructionEditorScreen` can
/// reuse the exact same dialog/validation instead of a second copy.
Future<Section?> showSectionDialog(
  BuildContext context, {
  required int order,
  Section? existing,
}) {
  return showDialog<Section>(
    context: context,
    builder: (dialogContext) =>
        _SectionDialog(order: order, existing: existing),
  );
}

/// Modal dialog for creating or editing one [Section]'s fields.
class _SectionDialog extends StatefulWidget {
  final int order;
  final Section? existing;

  const _SectionDialog({required this.order, this.existing});

  @override
  State<_SectionDialog> createState() => _SectionDialogState();
}

class _SectionDialogState extends State<_SectionDialog> {
  late final TextEditingController widthController;
  late final TextEditingController heightController;
  late SectionKind kind;
  OpeningType? openingType;
  late int vantauxCount;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    widthController = TextEditingController(
      text: existing == null ? '' : existing.width.toStringAsFixed(0),
    );
    heightController = TextEditingController(
      text: existing == null ? '' : existing.height.toStringAsFixed(0),
    );
    kind = existing?.kind ?? SectionKind.fixed;
    openingType = existing?.openingType;
    vantauxCount = existing?.vantauxCount ?? 0;
  }

  @override
  void dispose() {
    widthController.dispose();
    heightController.dispose();
    super.dispose();
  }

  void _submit() {
    final width = double.tryParse(widthController.text);
    final height = double.tryParse(heightController.text);

    if (width == null || height == null || width <= 0 || height <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Largeur et hauteur doivent être renseignées et '
            'supérieures à zéro.',
          ),
        ),
      );
      return;
    }

    if (kind == SectionKind.ouvrant && openingType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez choisir un type d'ouverture.")),
      );
      return;
    }

    final section = Section(
      id:
          widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      order: widget.order,
      kind: kind,
      width: width,
      height: height,
      openingType: kind == SectionKind.ouvrant ? openingType : null,
      vantauxCount: kind == SectionKind.ouvrant
          ? (vantauxCount < 1 ? 1 : vantauxCount)
          : 0,
    );

    Navigator.pop(context, section);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Nouvelle section' : 'Modifier la section',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: widthController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Largeur',
                suffixText: 'mm',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: heightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Hauteur',
                suffixText: 'mm',
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<SectionKind>(
              segments: const [
                ButtonSegment(value: SectionKind.fixed, label: Text('Fixe')),
                ButtonSegment(
                  value: SectionKind.ouvrant,
                  label: Text('Ouvrant'),
                ),
              ],
              selected: {kind},
              onSelectionChanged: (selection) {
                setState(() {
                  kind = selection.first;
                  if (kind == SectionKind.fixed) {
                    openingType = null;
                    vantauxCount = 0;
                  } else if (vantauxCount < 1) {
                    vantauxCount = 1;
                  }
                });
              },
            ),
            if (kind == SectionKind.ouvrant) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<OpeningType>(
                initialValue: openingType,
                decoration: const InputDecoration(
                  labelText: "Type d'ouverture",
                ),
                items: const [
                  DropdownMenuItem(
                    value: OpeningType.francaise,
                    child: Text('Française'),
                  ),
                  DropdownMenuItem(
                    value: OpeningType.anglaise,
                    child: Text('Anglaise'),
                  ),
                  DropdownMenuItem(
                    value: OpeningType.oscilloBattant,
                    child: Text('Oscillo-battant'),
                  ),
                  DropdownMenuItem(
                    value: OpeningType.coulissante,
                    child: Text('Coulissante'),
                  ),
                ],
                onChanged: (value) => setState(() => openingType = value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Nombre de vantaux :'),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: vantauxCount > 1
                        ? () => setState(() => vantauxCount--)
                        : null,
                  ),
                  Text(
                    '$vantauxCount',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() => vantauxCount++),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Enregistrer')),
      ],
    );
  }
}
