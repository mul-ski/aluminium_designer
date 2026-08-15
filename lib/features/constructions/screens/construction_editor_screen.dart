import 'package:flutter/material.dart';

import '../../../core/models/catalog.dart';
import '../../../core/models/construction.dart';
import '../../../core/models/construction_type.dart';
import '../../../core/models/layout_direction.dart';
import '../../../core/models/opening.dart';
import '../../../core/models/project_json.dart' show ConstructionJson;
import '../../../core/models/section.dart';
import '../../../core/models/section_geometry.dart';
import '../../../core/storage/catalog_store.dart';
import '../widgets/construction_painter.dart';
import '../widgets/manufacturer_system_picker.dart';
import '../widgets/section_list_editor.dart' show showSectionDialog;

/// The one and only construction editing workspace.
///
/// This milestone reshapes the screen into a professional, desktop-first
/// CAD-style workspace (top app bar, toolbar, left structure tree / center
/// free 2D viewport / right contextual properties, bottom status bar),
/// inspired by professional window/door design tools (RA Workshop,
/// Logikal) -- no branding, assets, or proprietary UI copied, only the
/// general working-zone layout idea.
///
/// It still edits exactly one shared `Construction` draft, still renders
/// via the same `ConstructionPainter`/`layoutConstruction` geometry used
/// before, and still pops a `ConstructionEditorResult` on save/delete --
/// none of that changes. What changes is that editing now happens through
/// a selection-driven tree + canvas + properties panel instead of one long
/// scrolling form. There is still deliberately no second construction
/// editor anywhere else in the app.
///
/// SAVE / UNSAVED-CHANGES CONTRACT: every field edit updates `_draft` and
/// the UI immediately, but does NOT by itself persist anything -- there is
/// no autosave. `_lastSaved` tracks the most recently saved (or initial)
/// `Construction` state; `_isDirty` is true whenever `_draft` differs from
/// `_lastSaved` (compared via `toJson()`, since neither `Construction` nor
/// `Section` define `==`). Pressing the top-bar Save button is the only
/// thing that pops `ConstructionEditorResult.saved(_draft)` and marks the
/// draft clean again -- the caller (`ProjectWorkspaceScreen`) is what
/// actually writes to disk via `ProjectStore` once it receives that
/// result, so a real Save here is durable immediately, not only once the
/// workspace itself later happens to close. Back/close with unsaved
/// changes intercepts the pop and asks Cancel/Discard/Save rather than
/// silently doing either.
class ConstructionEditorScreen extends StatefulWidget {
  final Construction construction;

  const ConstructionEditorScreen({super.key, required this.construction});

  @override
  State<ConstructionEditorScreen> createState() =>
      _ConstructionEditorScreenState();
}

/// Minimum desktop width this three-panel workspace is designed for. Below
/// this, the layout is not pretended to work well -- see [build]'s
/// `LayoutBuilder` fallback.
const double _kMinDesktopWidth = 900;

class _ConstructionEditorScreenState extends State<ConstructionEditorScreen> {
  final CatalogStore _catalogStore = CatalogStore();
  final TransformationController _viewController = TransformationController();

  late Construction _draft;

  /// The last `Construction` state actually returned via a successful
  /// Save (or the construction the editor was opened with, if never
  /// saved yet). Never touched by ordinary field edits -- only `_save()`
  /// advances it. This is what `_draft` is compared against to decide
  /// whether there are unsaved changes.
  late Construction _lastSaved;

  /// Null means the construction root is selected (construction-level
  /// properties shown). Otherwise the id of the selected [Section] --
  /// shared by the tree, the canvas (via `ConstructionPainter
  /// .selectedSectionId`), and the properties panel, so all three never
  /// disagree about what's selected.
  String? _selectedSectionId;

  Catalog _catalog = const Catalog();
  bool _loadingCatalog = true;

  @override
  void initState() {
    super.initState();
    _draft = widget.construction;
    _lastSaved = widget.construction;
    _loadCatalog();
  }

  /// True whenever `_draft` differs from `_lastSaved`. `Construction` and
  /// `Section` are plain classes without `==` overrides (see the class
  /// doc), so this compares their JSON representations -- already exactly
  /// what `ProjectStore` persists, so "differs" here means exactly
  /// "differs in whatever would actually be written to disk".
  bool get _isDirty {
    return _draft.toJson().toString() != _lastSaved.toJson().toString();
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
    _viewController.dispose();
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

  Section? get _selectedSection {
    final id = _selectedSectionId;
    if (id == null) return null;
    for (final s in _draft.sections) {
      if (s.id == id) return s;
    }
    return null;
  }

  void _selectSection(String? id) {
    setState(() => _selectedSectionId = id);
  }

  // ---- Construction-level property edits ----

  void _applyName(String value) {
    setState(() => _draft = _draft.copyWith(name: value));
  }

  void _applyType(ConstructionType type) {
    setState(() => _draft = _draft.copyWith(type: type));
  }

  void _applyWidth(String value) {
    final parsed = double.tryParse(value);
    setState(() {
      // An empty/unparseable field means "not set yet" -- copyWith can't
      // express "set this back to null" (its null means "leave
      // unchanged"), so the draft is rebuilt directly here rather than
      // reusing copyWith for this one case.
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

  void _applyLayoutDirection(SectionLayoutDirection direction) {
    setState(() => _draft = _draft.copyWith(layoutDirection: direction));
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
    setState(() => _catalog = updated);
    // Persist immediately rather than waiting for this construction's
    // Save -- a manufacturer/system the user just created must survive
    // even if they back out of editing this construction without saving.
    await _catalogStore.save(updated);
  }

  // ---- Section-level property edits ----

  void _replaceSection(Section updated) {
    setState(() {
      _draft = _draft.copyWith(
        sections: [
          for (final s in _draft.sections)
            if (s.id == updated.id) updated else s,
        ],
      );
    });
  }

  void _applySectionWidth(Section section, String value) {
    final parsed = double.tryParse(value);
    if (parsed == null || parsed <= 0) return;
    _replaceSection(_withSectionFields(section, width: parsed));
  }

  void _applySectionHeight(Section section, String value) {
    final parsed = double.tryParse(value);
    if (parsed == null || parsed <= 0) return;
    _replaceSection(_withSectionFields(section, height: parsed));
  }

  void _applySectionKind(Section section, SectionKind kind) {
    if (kind == SectionKind.fixed) {
      _replaceSection(
        Section(
          id: section.id,
          order: section.order,
          kind: SectionKind.fixed,
          width: section.width,
          height: section.height,
        ),
      );
    } else {
      _replaceSection(
        Section(
          id: section.id,
          order: section.order,
          kind: SectionKind.ouvrant,
          width: section.width,
          height: section.height,
          openingType: section.openingType ?? OpeningType.francaise,
          vantauxCount: section.vantauxCount < 1 ? 1 : section.vantauxCount,
        ),
      );
    }
  }

  void _applySectionOpeningType(Section section, OpeningType type) {
    _replaceSection(_withSectionFields(section, openingType: type));
  }

  void _applySectionVantauxCount(Section section, int count) {
    if (count < 1) return;
    _replaceSection(_withSectionFields(section, vantauxCount: count));
  }

  Section _withSectionFields(
    Section s, {
    double? width,
    double? height,
    OpeningType? openingType,
    int? vantauxCount,
  }) {
    return Section(
      id: s.id,
      order: s.order,
      kind: s.kind,
      width: width ?? s.width,
      height: height ?? s.height,
      openingType: s.kind == SectionKind.ouvrant
          ? (openingType ?? s.openingType)
          : null,
      vantauxCount: s.kind == SectionKind.ouvrant
          ? (vantauxCount ?? s.vantauxCount)
          : 0,
    );
  }

  // ---- Section add/remove (toolbar + tree) ----

  Future<void> _addSection() async {
    final section = await showSectionDialog(
      context,
      order: _draft.sections.length,
    );
    if (section == null) return;
    setState(() {
      _draft = _draft.copyWith(sections: [..._draft.sections, section]);
      _selectedSectionId = section.id;
    });
  }

  void _removeSelectedSection() {
    final target = _selectedSection;
    if (target == null) return; // Cannot delete the construction root here.

    final remaining = _draft.sections.where((s) => s.id != target.id).toList();
    // Reassign order 0..n-1 so there's no gap left by the removed section.
    final reordered = <Section>[
      for (var i = 0; i < remaining.length; i++)
        Section(
          id: remaining[i].id,
          order: i,
          kind: remaining[i].kind,
          width: remaining[i].width,
          height: remaining[i].height,
          openingType: remaining[i].openingType,
          vantauxCount: remaining[i].vantauxCount,
        ),
    ];

    setState(() {
      _draft = _draft.copyWith(sections: reordered);
      _selectedSectionId = null;
    });
  }

  // ---- Viewport controls ----

  void _zoomBy(double factor) {
    final matrix = _viewController.value.clone();
    matrix.scaleByDouble(factor, factor, 1, 1);
    _viewController.value = matrix;
  }

  void _fitToView() {
    _viewController.value = Matrix4.identity();
  }

  // ---- Save / delete / unsaved-changes-aware navigation ----

  /// The only path that pops `ConstructionEditorResult.saved(...)`. Marks
  /// the draft clean (`_lastSaved = _draft`) immediately after popping is
  /// requested, and reports success to the user -- per spec this screen's
  /// job ends at "the caller received the updated Construction"; actually
  /// writing it to disk is `ProjectWorkspaceScreen`'s responsibility (see
  /// class doc), so "success" here means "handed off for persistence",
  /// which is what the SnackBar says.
  void _save() {
    final saved = _draft;
    setState(() => _lastSaved = saved);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Construction enregistrée.')));
    Navigator.pop(context, ConstructionEditorResult.saved(saved));
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

    if (confirmed != true || !mounted) return;

    Navigator.pop(context, ConstructionEditorResult.deleted(_draft.id));
  }

  /// Handles the top-bar back action and any other attempt to leave the
  /// editor (see `PopScope` in [build]). With no unsaved changes, returns
  /// immediately -- there is nothing to lose, so no dialog is warranted.
  /// With unsaved changes, asks Cancel/Discard/Save and never returns
  /// (i.e. never pops) on its own; only an explicit Discard or a
  /// successful Save does that, matching "do not silently save/discard".
  Future<void> _handleBackPressed() async {
    if (!_isDirty) {
      Navigator.pop(context);
      return;
    }

    final choice = await showDialog<_UnsavedChangesChoice>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Modifications non enregistrées'),
        content: const Text(
          'Cette construction contient des modifications non '
          'enregistrées. Que souhaitez-vous faire ?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _UnsavedChangesChoice.cancel),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _UnsavedChangesChoice.discard),
            child: const Text('Ignorer'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _UnsavedChangesChoice.save),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    switch (choice) {
      case _UnsavedChangesChoice.discard:
        // Discard: the draft is simply abandoned by popping with no
        // result at all -- ConstructionEditorResult is never constructed
        // for a discard, so ProjectWorkspaceScreen's `result == null`
        // early-return applies and nothing about the persisted project
        // is touched. This is the same "cancelled" contract `null` has
        // always had; discarding a dirty draft is a form of cancelling.
        Navigator.pop(context);
        break;
      case _UnsavedChangesChoice.save:
        // Save synchronously pops with the saved result, so control
        // never returns here after a successful save -- there is no
        // separate "then also pop" step to get wrong.
        _save();
        break;
      case _UnsavedChangesChoice.cancel:
      case null:
        // Cancel (or the dialog being dismissed): remain in the editor,
        // change nothing.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPressed();
      },
      child: Scaffold(
        appBar: _buildTopAppBar(),
        body: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < _kMinDesktopWidth) {
              return _NarrowViewportNotice(minWidth: _kMinDesktopWidth);
            }
            return Column(
              children: [
                _buildToolbar(),
                const Divider(height: 1),
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 260,
                        child: _StructureTree(
                          construction: _draft,
                          selectedSectionId: _selectedSectionId,
                          onSelectConstruction: () => _selectSection(null),
                          onSelectSection: _selectSection,
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: _buildCanvas()),
                      const VerticalDivider(width: 1),
                      SizedBox(
                        width: 320,
                        child: _loadingCatalog
                            ? const Center(child: CircularProgressIndicator())
                            : _buildPropertiesPanel(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _buildStatusBar(),
              ],
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildTopAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Retour au projet',
        onPressed: _handleBackPressed,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              _draft.name.isEmpty ? _typeLabel(_draft.type) : _draft.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_isDirty) ...[
            const SizedBox(width: 8),
            const _UnsavedChangesBadge(),
          ],
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Supprimer la construction',
          onPressed: _delete,
        ),
        IconButton(
          icon: const Icon(Icons.check),
          tooltip: 'Enregistrer',
          onPressed: _save,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _ToolbarButton(
            icon: Icons.near_me_outlined,
            label: 'Sélection',
            selected: true,
            onPressed: () {},
          ),
          _ToolbarButton(
            icon: Icons.add_box_outlined,
            label: 'Ajouter une section',
            onPressed: _addSection,
          ),
          _ToolbarButton(
            icon: Icons.delete_outline,
            label: 'Supprimer la sélection',
            onPressed: _selectedSection == null ? null : _removeSelectedSection,
          ),
          const VerticalDivider(width: 24, indent: 8, endIndent: 8),
          _ToolbarButton(
            icon: Icons.zoom_in,
            label: 'Zoom avant',
            onPressed: () => _zoomBy(1.2),
          ),
          _ToolbarButton(
            icon: Icons.zoom_out,
            label: 'Zoom arrière',
            onPressed: () => _zoomBy(1 / 1.2),
          ),
          _ToolbarButton(
            icon: Icons.fit_screen_outlined,
            label: 'Ajuster à la vue',
            onPressed: _fitToView,
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    final status = constructionGeometryStatus(_draft);
    final problems = validateSectionGeometry(_draft);

    return Container(
      color: const Color(0xFFF3F5F6),
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _viewController,
              minScale: 0.2,
              maxScale: 6,
              boundaryMargin: const EdgeInsets.all(2000),
              child: SizedBox(
                // Large fixed logical canvas so there is visible empty
                // workspace around the construction to pan into, rather
                // than a viewport that always exactly hugs the drawing.
                width: 2000,
                height: 1400,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) => _handleCanvasTap(
                        details.localPosition,
                        Size(constraints.maxWidth, constraints.maxHeight),
                      ),
                      child: CustomPaint(
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                        painter: ConstructionPainter(
                          construction: _draft,
                          selectedSectionId: _selectedSectionId,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (status == GeometryStatus.incomplete)
            Positioned(
              left: 16,
              top: 16,
              right: 16,
              child: _StatusBanner(
                color: const Color(0xFFFFF3CD),
                textColor: const Color(0xFF7A5C00),
                icon: Icons.edit_note,
                message:
                    'Construction en cours de création -- ajoutez les '
                    'dimensions et au moins une section pour voir l\'aperçu.',
              ),
            )
          else if (status == GeometryStatus.invalid)
            Positioned(
              left: 16,
              top: 16,
              right: 16,
              child: _StatusBanner(
                color: const Color(0xFFFDE2E1),
                textColor: const Color(0xFF8C2E27),
                icon: Icons.error_outline,
                message: problems.join(' '),
              ),
            ),
        ],
      ),
    );
  }

  /// Turns a tap in the (already pan/zoomed) canvas widget's own local
  /// coordinate space into a section selection. Because the
  /// `GestureDetector`/`CustomPaint` sit *inside* `InteractiveViewer`'s
  /// child, `details.localPosition` from `onTapUp` is already in the
  /// child's untransformed coordinate space -- `InteractiveViewer` applies
  /// its pan/zoom transform to the child as a whole and reports child-local
  /// coordinates for hits on that child, so no manual matrix math against
  /// `_viewController.value` is needed here for correctness.
  void _handleCanvasTap(Offset localPosition, Size size) {
    final painter = ConstructionPainter(
      construction: _draft,
      selectedSectionId: _selectedSectionId,
    );
    final hit = painter.sectionAt(localPosition, size);
    _selectSection(hit?.section.id);
  }

  Widget _buildPropertiesPanel() {
    final section = _selectedSection;
    if (section == null) {
      return _ConstructionPropertiesPanel(
        draft: _draft,
        catalog: _catalog,
        typeLabel: _typeLabel,
        onNameChanged: _applyName,
        onTypeChanged: _applyType,
        onWidthChanged: _applyWidth,
        onHeightChanged: _applyHeight,
        onLayoutDirectionChanged: _applyLayoutDirection,
        onManufacturerSystemSelected: _applyManufacturerSystem,
        onCatalogChanged: _applyCatalogChange,
      );
    }
    return _SectionPropertiesPanel(
      section: section,
      onWidthChanged: (v) => _applySectionWidth(section, v),
      onHeightChanged: (v) => _applySectionHeight(section, v),
      onKindChanged: (k) => _applySectionKind(section, k),
      onOpeningTypeChanged: (t) => _applySectionOpeningType(section, t),
      onVantauxCountChanged: (c) => _applySectionVantauxCount(section, c),
    );
  }

  Widget _buildStatusBar() {
    final status = constructionGeometryStatus(_draft);
    final section = _selectedSection;

    String statusLabel;
    Color statusColor;
    switch (status) {
      case GeometryStatus.valid:
        statusLabel = 'Géométrie valide';
        statusColor = const Color(0xFF2E7D32);
        break;
      case GeometryStatus.invalid:
        statusLabel = 'Géométrie invalide';
        statusColor = const Color(0xFFC62828);
        break;
      case GeometryStatus.incomplete:
        statusLabel = 'Incomplète';
        statusColor = const Color(0xFF7A5C00);
        break;
    }

    final width = _draft.width;
    final height = _draft.height;
    final dims = (width != null && height != null)
        ? '${width.toStringAsFixed(0)} × ${height.toStringAsFixed(0)} mm'
        : 'Dimensions non définies';

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFFEDEFF1),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: statusColor),
          const SizedBox(width: 6),
          Text(statusLabel, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 20),
          Text(dims, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 20),
          Text(
            '${_draft.sections.length} section(s)',
            style: const TextStyle(fontSize: 12),
          ),
          if (section != null) ...[
            const SizedBox(width: 20),
            Text(
              'Sélection : section ${section.order + 1}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
          const Spacer(),
          if (_isDirty)
            const Text(
              'Modifications non enregistrées',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Color(0xFF7A5C00),
              ),
            )
          else
            const Text(
              'Tout est enregistré',
              style: TextStyle(fontSize: 12, color: Color(0xFF5B6B76)),
            ),
        ],
      ),
    );
  }
}

/// The three ways a user can respond to the unsaved-changes dialog shown
/// by `_ConstructionEditorScreenState._handleBackPressed`. A dedicated
/// enum rather than a `bool?`/`String?` so "cancel", "discard", and
/// "save" can never be confused with each other or with "dialog
/// dismissed" (`null`, handled the same as `cancel`).
enum _UnsavedChangesChoice { cancel, discard, save }

/// Small "unsaved changes" pill shown in the top app bar's title next to
/// the construction name whenever `_isDirty` is true. Deliberately
/// unobtrusive -- a small dot + short label, not a banner -- since it is
/// informational, not a warning the user must act on immediately (the
/// dialog on back/close is what actually requires a decision).
class _UnsavedChangesBadge extends StatelessWidget {
  const _UnsavedChangesBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: Color(0xFFFFC107)),
          SizedBox(width: 4),
          Text('Non enregistré', style: TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

/// Distinguishes "user saved edits" from "user deleted this construction"
/// when `ConstructionEditorScreen` pops. Unchanged from before this
/// milestone.
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

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: label,
        child: IconButton(
          icon: Icon(icon),
          isSelected: selected,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

/// Left working zone: construction/section outline tree.
class _StructureTree extends StatelessWidget {
  final Construction construction;
  final String? selectedSectionId;
  final VoidCallback onSelectConstruction;
  final ValueChanged<String> onSelectSection;

  const _StructureTree({
    required this.construction,
    required this.selectedSectionId,
    required this.onSelectConstruction,
    required this.onSelectSection,
  });

  @override
  Widget build(BuildContext context) {
    final ordered = [...construction.sections]
      ..sort((a, b) => a.order.compareTo(b.order));

    return Material(
      color: const Color(0xFFFAFAFA),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
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

/// Right working zone, construction-level: shown when nothing is selected.
class _ConstructionPropertiesPanel extends StatelessWidget {
  final Construction draft;
  final Catalog catalog;
  final String Function(ConstructionType) typeLabel;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<ConstructionType> onTypeChanged;
  final ValueChanged<String> onWidthChanged;
  final ValueChanged<String> onHeightChanged;
  final ValueChanged<SectionLayoutDirection> onLayoutDirectionChanged;
  final void Function(String manufacturerName, String systemName)
  onManufacturerSystemSelected;
  final ValueChanged<Catalog> onCatalogChanged;

  const _ConstructionPropertiesPanel({
    required this.draft,
    required this.catalog,
    required this.typeLabel,
    required this.onNameChanged,
    required this.onTypeChanged,
    required this.onWidthChanged,
    required this.onHeightChanged,
    required this.onLayoutDirectionChanged,
    required this.onManufacturerSystemSelected,
    required this.onCatalogChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _PanelHeader('GÉNÉRAL'),
        TextFormField(
          key: ValueKey('name-${draft.id}'),
          initialValue: draft.name,
          decoration: const InputDecoration(labelText: 'Nom'),
          onChanged: onNameChanged,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ConstructionType>(
          initialValue: draft.type,
          decoration: const InputDecoration(labelText: 'Type'),
          items: [
            for (final type in ConstructionType.values)
              DropdownMenuItem(value: type, child: Text(typeLabel(type))),
          ],
          onChanged: (value) {
            if (value != null) onTypeChanged(value);
          },
        ),
        const SizedBox(height: 20),
        const _PanelHeader('DIMENSIONS'),
        TextFormField(
          key: ValueKey('width-${draft.id}-${draft.width}'),
          initialValue: draft.width?.toStringAsFixed(0) ?? '',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Largeur',
            suffixText: 'mm',
          ),
          onChanged: onWidthChanged,
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey('height-${draft.id}-${draft.height}'),
          initialValue: draft.height?.toStringAsFixed(0) ?? '',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Hauteur',
            suffixText: 'mm',
          ),
          onChanged: onHeightChanged,
        ),
        const SizedBox(height: 20),
        const _PanelHeader('DISPOSITION'),
        SegmentedButton<SectionLayoutDirection>(
          segments: const [
            ButtonSegment(
              value: SectionLayoutDirection.horizontal,
              label: Text('Horizontal'),
            ),
            ButtonSegment(
              value: SectionLayoutDirection.vertical,
              label: Text('Vertical'),
            ),
          ],
          selected: {draft.layoutDirection},
          onSelectionChanged: (selection) =>
              onLayoutDirectionChanged(selection.first),
        ),
        const SizedBox(height: 20),
        const _PanelHeader('SYSTÈME'),
        ManufacturerSystemPicker(
          catalog: catalog,
          selectedManufacturerName: draft.manufacturer.isEmpty
              ? null
              : draft.manufacturer,
          selectedSystemName: draft.system.isEmpty ? null : draft.system,
          onCatalogChanged: onCatalogChanged,
          onSelected: onManufacturerSystemSelected,
        ),
      ],
    );
  }
}

/// Right working zone, section-level: shown when a section is selected.
class _SectionPropertiesPanel extends StatelessWidget {
  final Section section;
  final ValueChanged<String> onWidthChanged;
  final ValueChanged<String> onHeightChanged;
  final ValueChanged<SectionKind> onKindChanged;
  final ValueChanged<OpeningType> onOpeningTypeChanged;
  final ValueChanged<int> onVantauxCountChanged;

  const _SectionPropertiesPanel({
    required this.section,
    required this.onWidthChanged,
    required this.onHeightChanged,
    required this.onKindChanged,
    required this.onOpeningTypeChanged,
    required this.onVantauxCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PanelHeader('GÉNÉRAL -- SECTION ${section.order + 1}'),
        const SizedBox(height: 8),
        const _PanelHeader('DIMENSIONS'),
        TextFormField(
          key: ValueKey('sec-width-${section.id}-${section.width}'),
          initialValue: section.width.toStringAsFixed(0),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Largeur',
            suffixText: 'mm',
          ),
          onChanged: onWidthChanged,
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey('sec-height-${section.id}-${section.height}'),
          initialValue: section.height.toStringAsFixed(0),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Hauteur',
            suffixText: 'mm',
          ),
          onChanged: onHeightChanged,
        ),
        const SizedBox(height: 20),
        const _PanelHeader('TYPE'),
        SegmentedButton<SectionKind>(
          segments: const [
            ButtonSegment(value: SectionKind.fixed, label: Text('Fixe')),
            ButtonSegment(value: SectionKind.ouvrant, label: Text('Ouvrant')),
          ],
          selected: {section.kind},
          onSelectionChanged: (selection) => onKindChanged(selection.first),
        ),
        if (section.kind == SectionKind.ouvrant) ...[
          const SizedBox(height: 20),
          const _PanelHeader('OUVERTURE'),
          DropdownButtonFormField<OpeningType>(
            initialValue: section.openingType,
            decoration: const InputDecoration(labelText: "Type d'ouverture"),
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
            onChanged: (value) {
              if (value != null) onOpeningTypeChanged(value);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Vantaux :'),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: section.vantauxCount > 1
                    ? () => onVantauxCountChanged(section.vantauxCount - 1)
                    : null,
              ),
              Text(
                '${section.vantauxCount}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () =>
                    onVantauxCountChanged(section.vantauxCount + 1),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final String text;

  const _PanelHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF5B6B76),
          letterSpacing: 0.5,
        ),
      ),
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

class _NarrowViewportNotice extends StatelessWidget {
  final double minWidth;

  const _NarrowViewportNotice({required this.minWidth});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.desktop_windows_outlined, size: 40),
            const SizedBox(height: 12),
            Text(
              'Cet espace de travail est conçu pour le bureau '
              '(largeur minimale ${minWidth.toStringAsFixed(0)}px). '
              'Agrandissez la fenêtre pour continuer.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
