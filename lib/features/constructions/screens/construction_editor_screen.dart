import 'package:flutter/material.dart';

import '../../../core/models/catalog.dart';
import '../../../core/models/construction.dart';
import '../../../core/models/construction_type.dart';
import '../../../core/models/layout_direction.dart';
import '../../../core/models/section_geometry.dart';
import '../../../core/storage/catalog_store.dart';
import '../widgets/construction_painter.dart';
import '../widgets/manufacturer_system_picker.dart';
import '../widgets/section_list_editor.dart';

/// The one and only construction editing workspace.
///
/// Started as a read-only 2D visualizer; this milestone turns it into the
/// central place a [Construction] is actually built: manufacturer/system
/// selection, overall dimensions, layout direction, and sections are all
/// edited here, with the 2D canvas (`ConstructionPainter`) rendering
/// directly from the same `Construction` state being edited -- never a
/// separate geometry model. There is deliberately no second construction
/// editor anywhere else in the app.
///
/// Editing state lives in `_draft`, a working copy of the `Construction`
/// passed in. `Construction` is immutable, so every field edit rebuilds
/// `_draft` via `Construction.copyWith`, the same pattern
/// `ProjectWorkspaceScreen` already uses for `Project`. Nothing is written
/// back to the caller until the user taps Save, at which point this screen
/// pops with the final `_draft` -- `ProjectWorkspaceScreen` is responsible
/// for merging it into `Project.constructions` and persisting, mirroring
/// how it already handles a brand-new construction from
/// `NewConstructionScreen`.
///
/// A construction reaching this screen may be incomplete (no dimensions,
/// no sections yet) -- that is the normal starting state for a freshly
/// created construction (see `NewConstructionScreen`), not an error. This
/// screen surfaces that honestly via `constructionGeometryStatus` (a
/// yellow "still being built" banner) rather than fabricating placeholder
/// dimensions or a placeholder section just to make validation pass.
class ConstructionEditorScreen extends StatefulWidget {
  final Construction construction;

  const ConstructionEditorScreen({super.key, required this.construction});

  @override
  State<ConstructionEditorScreen> createState() =>
      _ConstructionEditorScreenState();
}

class _ConstructionEditorScreenState extends State<ConstructionEditorScreen> {
  final CatalogStore _catalogStore = CatalogStore();

  late Construction _draft;
  late TextEditingController _nameController;
  late TextEditingController _widthController;
  late TextEditingController _heightController;

  Catalog _catalog = const Catalog();
  bool _loadingCatalog = true;

  @override
  void initState() {
    super.initState();
    _draft = widget.construction;
    _nameController = TextEditingController(text: _draft.name);
    _widthController = TextEditingController(
      text: _draft.width == null ? '' : _draft.width!.toStringAsFixed(0),
    );
    _heightController = TextEditingController(
      text: _draft.height == null ? '' : _draft.height!.toStringAsFixed(0),
    );
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    final catalog = await _catalogStore.load();
    if (!mounted) return;
    setState(() {
      _catalog = catalog;
      _loadingCatalog = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  String _typeLabel(ConstructionType type) {
    switch (type) {
      case ConstructionType.window:
        return 'Fenêtre';
      case ConstructionType.door:
        return 'Porte';
      case ConstructionType.curtainWall:
        return 'Mur rideau';
    }
  }

  void _applyName(String value) {
    setState(() {
      _draft = _draft.copyWith(name: value);
    });
  }

  void _applyType(ConstructionType type) {
    setState(() {
      _draft = _draft.copyWith(type: type);
    });
  }

  void _applyWidth(String value) {
    final parsed = double.tryParse(value);
    setState(() {
      // An empty/unparseable field means "not set yet" -- copyWith can't
      // express "set this back to null" (its null means "leave
      // unchanged", matching every other copyWith in this codebase), so
      // the draft is rebuilt directly here rather than reusing copyWith
      // for this one case.
      _draft = Construction(
        id: _draft.id,
        name: _draft.name,
        type: _draft.type,
        width: parsed,
        height: _draft.height,
        manufacturer: _draft.manufacturer,
        system: _draft.system,
        sections: _draft.sections,
        layoutDirection: _draft.layoutDirection,
        profiles: _draft.profiles,
        profileUsages: _draft.profileUsages,
      );
    });
  }

  void _applyHeight(String value) {
    final parsed = double.tryParse(value);
    setState(() {
      _draft = Construction(
        id: _draft.id,
        name: _draft.name,
        type: _draft.type,
        width: _draft.width,
        height: parsed,
        manufacturer: _draft.manufacturer,
        system: _draft.system,
        sections: _draft.sections,
        layoutDirection: _draft.layoutDirection,
        profiles: _draft.profiles,
        profileUsages: _draft.profileUsages,
      );
    });
  }

  void _applyManufacturerSystem(String manufacturerName, String systemName) {
    setState(() {
      _draft = _draft.copyWith(
        manufacturer: manufacturerName,
        system: systemName,
      );
    });
  }

  Future<void> _applyCatalogChange(Catalog updated) async {
    setState(() {
      _catalog = updated;
    });
    // Persist immediately rather than waiting for this construction's
    // Save -- a manufacturer/system the user just created must survive
    // even if they back out of editing this construction without saving
    // it, per "closing the app must not delete them".
    await _catalogStore.save(updated);
  }

  void _save() {
    Navigator.pop(context, ConstructionEditorResult.saved(_draft));
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la construction'),
        content: Text(
          'Supprimer '
          '"${_draft.name.isEmpty ? _typeLabel(_draft.type) : _draft.name}" '
          '? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    Navigator.pop(context, ConstructionEditorResult.deleted(_draft.id));
  }

  @override
  Widget build(BuildContext context) {
    final status = constructionGeometryStatus(_draft);
    final problems = validateSectionGeometry(_draft);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _draft.name.isEmpty ? _typeLabel(_draft.type) : _draft.name,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Supprimer',
            onPressed: _delete,
          ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Enregistrer',
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nom'),
            onChanged: _applyName,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ConstructionType>(
            initialValue: _draft.type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: [
              for (final type in ConstructionType.values)
                DropdownMenuItem(value: type, child: Text(_typeLabel(type))),
            ],
            onChanged: (value) {
              if (value != null) _applyType(value);
            },
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Fabricant et système',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_loadingCatalog)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            ManufacturerSystemPicker(
              catalog: _catalog,
              selectedManufacturerName: _draft.manufacturer.isEmpty
                  ? null
                  : _draft.manufacturer,
              selectedSystemName: _draft.system.isEmpty ? null : _draft.system,
              onCatalogChanged: _applyCatalogChange,
              onSelected: _applyManufacturerSystem,
            ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Dimensions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _widthController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Largeur totale',
                    suffixText: 'mm',
                  ),
                  onChanged: _applyWidth,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _heightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Hauteur totale',
                    suffixText: 'mm',
                  ),
                  onChanged: _applyHeight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<SectionLayoutDirectionLabel>(
            segments: const [
              ButtonSegment(
                value: SectionLayoutDirectionLabel.horizontal,
                label: Text('Horizontal'),
              ),
              ButtonSegment(
                value: SectionLayoutDirectionLabel.vertical,
                label: Text('Vertical'),
              ),
            ],
            selected: {
              _draft.layoutDirection == SectionLayoutDirection.horizontal
                  ? SectionLayoutDirectionLabel.horizontal
                  : SectionLayoutDirectionLabel.vertical,
            },
            onSelectionChanged: (selection) {
              setState(() {
                _draft = _draft.copyWith(
                  layoutDirection:
                      selection.first == SectionLayoutDirectionLabel.horizontal
                      ? SectionLayoutDirection.horizontal
                      : SectionLayoutDirection.vertical,
                );
              });
            },
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          SectionListEditor(
            sections: _draft.sections,
            onSectionsChanged: (sections) {
              setState(() {
                _draft = _draft.copyWith(sections: sections);
              });
            },
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Aperçu 2D',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (status == GeometryStatus.incomplete)
            _StatusBanner(
              color: const Color(0xFFFFF3CD),
              textColor: const Color(0xFF7A5C00),
              icon: Icons.edit_note,
              message:
                  'Construction en cours de création -- ajoutez les '
                  'dimensions et au moins une section pour voir '
                  'l\'aperçu.',
            )
          else if (status == GeometryStatus.invalid)
            _StatusBanner(
              color: const Color(0xFFFDE2E1),
              textColor: const Color(0xFF8C2E27),
              icon: Icons.error_outline,
              message: problems.join(' '),
            ),

          const SizedBox(height: 12),

          SizedBox(
            height: 360,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: ConstructionPainter(construction: _draft),
                  );
                },
              ),
            ),
          ),
          const _Legend(),
        ],
      ),
    );
  }
}

/// Distinguishes "user saved edits" from "user deleted this construction"
/// when `ConstructionEditorScreen` pops -- a plain nullable `Construction`
/// (as before) could not represent deletion at all, which is the root
/// cause of the ghost-canvas bug: there was no way for the caller
/// (`ProjectWorkspaceScreen`) to learn a construction was deleted, so it
/// never removed it from `Project.constructions`, and the (now-detached)
/// `ConstructionPainter` for that construction kept rendering wherever it
/// was still being built from stale state.
///
/// `null` from `Navigator.pop` (back button/gesture without saving or
/// deleting) still means "cancelled", exactly as before.
class ConstructionEditorResult {
  final Construction? saved;
  final String? deletedId;

  const ConstructionEditorResult._({this.saved, this.deletedId});

  factory ConstructionEditorResult.saved(Construction construction) =>
      ConstructionEditorResult._(saved: construction);

  factory ConstructionEditorResult.deleted(String id) =>
      ConstructionEditorResult._(deletedId: id);

  bool get isDeleted => deletedId != null;
}

/// Local, UI-only enum used purely to drive `SegmentedButton`'s selection
/// with a stable label type -- not a duplicate of `SectionLayoutDirection`
/// as a concept, just a display-layer stand-in so the segmented button
/// isn't built directly around the domain enum. Converted to/from
/// `SectionLayoutDirection` immediately on read/write; the domain model
/// (`Construction.layoutDirection`) remains the single source of truth.
enum SectionLayoutDirectionLabel { horizontal, vertical }

/// Small static legend explaining the fixed/ouvrant fill colors used by
/// [ConstructionPainter].
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
      child: Wrap(
        spacing: 20,
        runSpacing: 8,
        children: const [
          _LegendEntry(color: Color(0xFFDCE3E8), label: 'Fixe'),
          _LegendEntry(color: Color(0xFFCDE7D8), label: 'Ouvrant'),
        ],
      ),
    );
  }
}

class _LegendEntry extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendEntry({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: const Color(0xFF5B6B76)),
          ),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final Color color;
  final Color textColor;
  final IconData icon;
  final String message;

  const _StatusBanner({
    required this.color,
    required this.textColor,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: textColor)),
          ),
        ],
      ),
    );
  }
}
