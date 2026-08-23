import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;

import '../../../core/geometry/section_layout.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/construction.dart';
import '../../../core/models/construction_type.dart';
import '../../../core/storage/catalog_store.dart';
import '../editor/construction_editor_controller.dart';
import '../editor/construction_editor_result.dart';
import '../editor/editor_stage.dart';
import '../editor/editor_drafting_settings.dart';
import '../editor/editor_viewport.dart';
import '../editor/widgets/calculation_results_banner.dart';
import '../editor/widgets/editor_canvas.dart';
import '../editor/widgets/editor_properties_panels.dart';
import '../editor/widgets/editor_status_bar.dart';
import '../editor/widgets/editor_structure_panel.dart';
import '../editor/widgets/editor_toolbar.dart';
import '../editor/widgets/section_properties_panel.dart';
import '../widgets/section_list_editor.dart' show showSectionDialog;

// The editor's public result type used to live in this file; it moved to
// the editor module. Re-exported so existing callers that import the
// screen (ProjectWorkspaceScreen, widget tests) keep working unchanged.
export '../editor/construction_editor_result.dart'
    show ConstructionEditorResult;

/// Minimum desktop width this three-panel workspace is designed for. Below
/// this, the layout is not pretended to work well -- see [build]'s
/// `LayoutBuilder` fallback.
const double _kMinDesktopWidth = 900;

/// The one and only construction editing workspace: a professional,
/// desktop-first CAD-style layout (top app bar, toolbar, left structure
/// tree / center 2D viewport / right contextual properties, bottom status
/// bar).
///
/// RESPONSIBILITY SPLIT: this screen is deliberately thin. It owns only
/// what genuinely belongs at the screen level --
///
///   - assembling the working zones and wiring them together,
///   - navigation and its contracts (`PopScope`, save/delete results,
///     unsaved-changes confirmation),
///   - dialogs and snackbars,
///   - loading the persisted catalog from disk (async I/O timing, incl.
///     the mounted check),
///   - the viewport's `TransformationController` shared by the canvas and
///     the toolbar's zoom buttons.
///
/// Everything else lives in dedicated pieces:
/// `ConstructionEditorController` (in `../editor/`) owns the editable
/// session state -- the draft construction, its saved baseline, dirty
/// tracking, stage/selection, catalog snapshot, calculation outcome/stale
/// state -- and performs every draft mutation immutably via `copyWith`.
/// The extracted widgets under `../editor/widgets/` render that state:
/// [EditorToolbar], [EditorCanvas] (model-driven painting via
/// `ConstructionPainter`/`layoutConstruction`), [EditorStructurePanel],
/// the property panels ([EditorGeneralPropertiesPanel],
/// [EditorGeometryPropertiesPanel], [SectionPropertiesPanel],
/// [SectionProfileAssignmentPanel]), [CalculationResultsBanner], and
/// [EditorStatusBar]. The domain model remains the single source of
/// truth: no panel or painter keeps its own geometry, and every user
/// action funnels into one controller call followed by one rebuild.
///
/// SAVE / UNSAVED-CHANGES CONTRACT: every field edit updates the
/// controller's draft immediately, but does NOT by itself persist anything
/// -- there is no autosave. The controller tracks the last-saved baseline;
/// `isDirty` is true whenever the draft differs from it (compared via
/// `toJson()`, since neither `Construction` nor `Section` define `==`).
/// Pressing the top-bar Save button calls `commitSave()` on the controller
/// and pops `ConstructionEditorResult.saved(draft)` -- the caller
/// (`ProjectWorkspaceScreen`) is what actually writes to disk via
/// `ProjectStore`. Back/close with unsaved changes intercepts the pop and
/// asks Cancel/Discard/Save rather than silently doing either.
///
/// STAGE NAVIGATION: the properties panel is scoped by [EditorStage]
/// (General / Geometry / Sections) -- a pure UI concept layered on top of
/// the same draft. Stages never gate what data exists or what Save
/// persists; they only decide which subset of the *same* draft's fields
/// the right panel currently shows. Moving between stages never touches
/// the draft, the saved baseline, or the selected section (except where a
/// section selection itself implies the Sections stage).
class ConstructionEditorScreen extends StatefulWidget {
  final Construction construction;

  /// Where this screen loads its [Catalog] snapshot from (and persists
  /// picker-created manufacturers/systems to). Defaults to the real
  /// on-disk [CatalogStore]; tests may inject a stub so widget tests never
  /// depend on platform channels or file I/O -- neither of which can
  /// complete under Flutter test fake-async, which would otherwise leave
  /// the catalog spinner spinning forever and make the editor's test
  /// suite unrunnable in isolation.
  final CatalogStore? catalogStore;

  const ConstructionEditorScreen({
    super.key,
    required this.construction,
    this.catalogStore,
  });

  @override
  State<ConstructionEditorScreen> createState() =>
      _ConstructionEditorScreenState();
}

class _ConstructionEditorScreenState extends State<ConstructionEditorScreen> {
  late final ConstructionEditorController _controller =
      ConstructionEditorController(construction: widget.construction);

  late final CatalogStore _catalogStore = widget.catalogStore ?? CatalogStore();

  /// Whether the persisted catalog has been loaded yet -- while false, the
  /// right panel shows a spinner rather than panels that would resolve
  /// against an (not-yet-loaded) empty catalog.
  bool _loadingCatalog = true;

  /// The single authoritative model→screen transform of the canvas. All
  /// pan/zoom/fit interactions -- toolbar buttons, wheel, gestures, and
  /// the one-time initial fit -- go through this instance; the canvas and
  /// painter only read from it.
  final EditorViewport _viewport = EditorViewport();

  /// Per-session drafting aids (snap on/off, grid visibility, snap
  /// increment). Same ownership pattern as the viewport: one instance per
  /// open editor, presentation state only -- never persisted, never part
  /// of undo history.
  final EditorDraftingSettings _draftingSettings = EditorDraftingSettings();

  /// Whether the one-time automatic fit has already happened (or been
  /// superseded by a manual fit). See [_maybeInitialFit].
  bool _didInitialFit = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _draftingSettings.addListener(_onDraftingSettingsChanged);
    _loadCatalog();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
    // A dimension edit may have just made an incomplete construction
    // complete -- that is the auto-fit window closing moment.
    _maybeInitialFit();
  }

  /// Rebuild on drafting-aid changes so toolbar toggle visuals (and, from
  /// the grid/snapping milestones onward, canvas behavior) track the
  /// session settings.
  void _onDraftingSettingsChanged() {
    if (mounted) setState(() {});
  }

  /// Performs the ONE-TIME automatic fit-to-content, as soon as both the
  /// canvas size and a complete construction are available for the first
  /// time. Deliberately never runs again afterwards: re-fitting on every
  /// dimension keystroke would yank the view out from under the user's
  /// cursor while they type. A manual "Ajuster à la vue" also closes this
  /// window -- once the user has taken control of the viewport, automatic
  /// fitting stays out of the way.
  void _maybeInitialFit() {
    if (_didInitialFit) return;
    final canvas = _viewport.canvasSize;
    if (canvas == null || canvas.width <= 0 || canvas.height <= 0) return;
    // Wait until there is actual content to frame -- not just overall
    // dimensions partially typed in -- so the single automatic fit lands
    // on something meaningful.
    if (_controller.draft.sections.isEmpty) return;
    final layout = layoutConstruction(_controller.draft);
    if (layout == null) return;

    _didInitialFit = true;
    _viewport.fitToContent(
      contentWidth: layout.width,
      contentHeight: layout.height,
    );
  }

  Future<void> _loadCatalog() async {
    final catalog = await _catalogStore.load();
    if (!mounted) return;
    setState(() {
      _loadingCatalog = false;
    });
    _controller.setCatalog(catalog);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _draftingSettings.removeListener(_onDraftingSettingsChanged);
    _controller.dispose();
    _viewport.dispose();
    _draftingSettings.dispose();
    super.dispose();
  }

  // ---- Viewport controls ----

  void _zoomBy(double factor) {
    _viewport.zoomBy(factor);
  }

  void _fitToView() {
    final layout = layoutConstruction(_controller.draft);
    if (layout == null) return; // Nothing to fit yet.
    _didInitialFit = true; // Manual fit supersedes the automatic one.
    _viewport.fitToContent(
      contentWidth: layout.width,
      contentHeight: layout.height,
    );
  }

  // ---- Editing actions that involve dialogs/navigation ----

  Future<void> _addSection() async {
    final section = await showSectionDialog(
      context,
      order: _controller.draft.sections.length,
    );
    if (section == null) return;
    _controller.addSection(section);
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

  /// Applies a manufacturer/system selection made in the picker, asking
  /// for confirmation first when the switch would make existing profile
  /// assignments incompatible (checked against ALL current usages, since a
  /// construction can already carry stale usages from a deleted system).
  /// Cancelling makes no change at all -- the picker's own dropdown state
  /// reverts on rebuild since the draft never changed.
  Future<void> _applyManufacturerSystem(
    BuildContext context, {
    required String manufacturerName,
    required String systemName,
    String? manufacturerId,
    String? systemId,
  }) async {
    final incompatible = _controller.incompatibleUsagesFor(systemId);

    if (incompatible.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Changer de système'),
          content: Text(
            'Ce changement rendra ${incompatible.length} assignation(s) de '
            'profil incompatible(s) avec le nouveau système. Elles seront '
            'supprimées. Continuer ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continuer'),
            ),
          ],
        ),
      );
      if (confirmed != true) return; // Cancel: no change at all.
    }

    _controller.applyManufacturerSystem(
      manufacturerName: manufacturerName,
      systemName: systemName,
      manufacturerId: manufacturerId,
      systemId: systemId,
    );
  }

  void _applyCatalogChange(Catalog updated) {
    _controller.setCatalog(updated);
    // Persist immediately rather than waiting for this construction's
    // Save -- a manufacturer/system the user just created must survive
    // even if they back out of editing this construction without saving.
    _catalogStore.save(updated);
  }

  // ---- Save / delete / unsaved-changes-aware navigation ----

  /// The only path that pops `ConstructionEditorResult.saved(...)`. Marks
  /// the draft clean (`commitSave`) immediately after popping is requested,
  /// and reports success to the user -- this screen's job ends at "the
  /// caller received the updated Construction"; actually writing it to
  /// disk is `ProjectWorkspaceScreen`'s responsibility, so "success" here
  /// means "handed off for persistence", which is what the SnackBar says.
  void _save() {
    final saved = _controller.draft;
    _controller.commitSave();
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
          '"${_controller.draft.name.isEmpty ? _typeLabel(_controller.draft.type) : _controller.draft.name}" '
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

    Navigator.pop(
      context,
      ConstructionEditorResult.deleted(_controller.draft.id),
    );
  }

  /// Handles the top-bar back action and any other attempt to leave the
  /// editor (see `PopScope` in [build]). With no unsaved changes, returns
  /// immediately -- there is nothing to lose, so no dialog is warranted.
  /// With unsaved changes, asks Cancel/Discard/Save and never returns
  /// (i.e. never pops) on its own; only an explicit Discard or a
  /// successful Save does that, matching "do not silently save/discard".
  Future<void> _handleBackPressed() async {
    if (!_controller.isDirty) {
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
        // is touched.
        Navigator.pop(context);
        break;
      case _UnsavedChangesChoice.save:
        // Save synchronously pops with the saved result, so control
        // never returns here after a successful save.
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
      child: Shortcuts(
        // Desktop undo/redo shortcuts driving CONSTRUCTION history. The
        // editor's TextFields carry no undo controller of their own, so
        // there is exactly one undo system: Ctrl+Z/Ctrl+Shift+Z/Ctrl+Y
        // always operate on the Construction draft, never on individual
        // characters inside a field.
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.keyZ, control: true):
              _UndoEditorIntent(),
          SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
              _RedoEditorIntent(),
          SingleActivator(LogicalKeyboardKey.keyY, control: true):
              _RedoEditorIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _UndoEditorIntent: CallbackAction<_UndoEditorIntent>(
              onInvoke: (_) {
                if (_controller.canUndo) _controller.undo();
                return null;
              },
            ),
            _RedoEditorIntent: CallbackAction<_RedoEditorIntent>(
              onInvoke: (_) {
                if (_controller.canRedo) _controller.redo();
                return null;
              },
            ),
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
                    EditorToolbar(
                      canRemoveSection: _controller.selectedSection != null,
                      onAddSection: _addSection,
                      onRemoveSelectedSection: () =>
                          _controller.removeSelectedSection(),
                      onZoomIn: () => _zoomBy(1.2),
                      onZoomOut: () => _zoomBy(1 / 1.2),
                      onFitToView: _fitToView,
                      onCalculate: _controller.calculate,
                      canUndo: _controller.canUndo,
                      canRedo: _controller.canRedo,
                      onUndo: _controller.undo,
                      onRedo: _controller.redo,
                      snapEnabled: _draftingSettings.snapEnabled,
                      onSnapEnabledChanged: (value) =>
                          _draftingSettings.snapEnabled = value,
                      gridVisible: _draftingSettings.gridVisible,
                      onGridVisibleChanged: (value) =>
                          _draftingSettings.gridVisible = value,
                      snapIncrementMm: _draftingSettings.snapIncrementMm,
                      onSnapIncrementChanged: (value) =>
                          _draftingSettings.snapIncrementMm = value,
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: Row(
                        children: [
                          SizedBox(
                            width: 260,
                            child: EditorStructurePanel(
                              construction: _controller.draft,
                              stage: _controller.stage,
                              selectedSectionId: _controller.selectedSectionId,
                              calculationResult: _controller.calculationResult,
                              calculationIsStale:
                                  _controller.calculationIsStale,
                              onStageSelected: _controller.goToStage,
                              onSelectConstruction: () =>
                                  _controller.selectSection(null),
                              onSelectSection: _controller.selectSection,
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(child: _buildCanvas()),
                          const VerticalDivider(width: 1),
                          SizedBox(
                            width: 320,
                            child: _loadingCatalog
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : _buildPropertiesPanel(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    EditorStatusBar(
                      construction: _controller.draft,
                      selectedSection: _controller.selectedSection,
                      isDirty: _controller.isDirty,
                    ),
                  ],
                );
              },
            ),
          ),
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
              _controller.draft.name.isEmpty
                  ? _typeLabel(_controller.draft.type)
                  : _controller.draft.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_controller.isDirty) ...[
            const SizedBox(width: 8),
            const _UnsavedChangesBadge(),
          ],
        ],
      ),
      actions: [
        // Stage Back/Next/Finish, grouped separately from Return-to-Project
        // (the leading arrow_back) and Delete/Save below -- distinct icons
        // (chevron vs arrow_back/check) so "go back one design stage" is
        // never visually confused with "leave the editor".
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Étape précédente',
          onPressed: _controller.stage == EditorStage.general
              ? null
              : _controller.goBack,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            _stageLabel(_controller.stage),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        if (_controller.stage == EditorStage.sections)
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            tooltip: 'Terminer',
            onPressed: _save,
          )
        else
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Étape suivante',
            onPressed: _controller.goNext,
          ),
        const SizedBox(width: 8),
        const VerticalDivider(width: 1, indent: 14, endIndent: 14),
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

  String _stageLabel(EditorStage stage) {
    switch (stage) {
      case EditorStage.general:
        return 'Général';
      case EditorStage.geometry:
        return 'Géométrie';
      case EditorStage.sections:
        return 'Sections';
    }
  }

  Widget _buildCanvas() {
    return EditorCanvas(
      construction: _controller.draft,
      selectedSectionId: _controller.selectedSectionId,
      viewport: _viewport,
      draftingSettings: _draftingSettings,
      onSectionTap: _controller.selectSection,
      // The canvas learns its size after the first layout pass -- exactly
      // when the one-time initial fit becomes possible.
      onCanvasSizeChanged: _maybeInitialFit,
      // One completed boundary drag = exactly one committed mutation.
      onBoundaryDragCompleted: (boundaryIndex, positionMm) => _controller
          .moveBoundary(boundaryIndex: boundaryIndex, positionMm: positionMm),
    );
  }

  Widget _buildPropertiesPanel() {
    switch (_controller.stage) {
      case EditorStage.general:
        return EditorGeneralPropertiesPanel(
          draft: _controller.draft,
          catalog: _controller.catalog,
          typeLabel: _typeLabel,
          onNameChanged: _controller.setName,
          onTypeChanged: _controller.setType,
          onManufacturerSystemSelected:
              (manufacturerName, systemName, {manufacturerId, systemId}) =>
                  _applyManufacturerSystem(
                    context,
                    manufacturerName: manufacturerName,
                    systemName: systemName,
                    manufacturerId: manufacturerId,
                    systemId: systemId,
                  ),
          onCatalogChanged: _applyCatalogChange,
        );
      case EditorStage.geometry:
        return EditorGeometryPropertiesPanel(
          draft: _controller.draft,
          onWidthChanged: _controller.setWidth,
          onHeightChanged: _controller.setHeight,
          onLayoutDirectionChanged: _controller.setLayoutDirection,
        );
      case EditorStage.sections:
        final resultsBanner = _buildCalculationResultsBanner();
        final section = _controller.selectedSection;
        if (section == null) {
          return Column(
            children: [
              ?resultsBanner,
              const Expanded(child: NoSectionSelectedNotice()),
            ],
          );
        }
        // Section GEOMETRY editing (dimensions, fixed/ouvrant, opening
        // type, vantaux) has no dependency on the catalog, so it stays
        // available regardless of whether a system resolves -- a user
        // must not have to pick a manufacturer system before they can
        // type a section's dimensions. Only profile ASSIGNMENT is gated
        // on system resolution: without a system there is nothing to
        // assign profiles from, so that half of the panel is replaced by
        // an explanatory notice instead.
        final system = _controller.resolvedSystem;
        return Column(
          children: [
            ?resultsBanner,
            Expanded(
              child: SectionPropertiesPanel(
                section: section,
                onWidthChanged: (v) =>
                    _controller.applySectionWidth(section, v),
                onHeightChanged: (v) =>
                    _controller.applySectionHeight(section, v),
                onKindChanged: (k) => _controller.applySectionKind(section, k),
                onOpeningTypeChanged: (t) =>
                    _controller.applySectionOpeningType(section, t),
                onVantauxCountChanged: (c) =>
                    _controller.applySectionVantauxCount(section, c),
              ),
            ),
            const Divider(height: 1),
            if (system != null)
              Expanded(
                child: SectionProfileAssignmentPanel(
                  section: section,
                  system: system,
                  usages: _controller.draft.profileUsages
                      .where((u) => u.sectionId == section.id)
                      .toList(),
                  onAdd: ({required profileId, required role}) =>
                      _controller.addProfileUsage(
                        profileId: profileId,
                        sectionId: section.id,
                        role: role,
                      ),
                  onQuantityChanged: _controller.updateProfileUsageQuantity,
                  onRemove: _controller.removeProfileUsage,
                ),
              )
            else
              Expanded(
                // Covers BOTH "no system selected yet" (systemId == null)
                // and "selected system no longer exists in the catalog"
                // (systemId is set but doesn't resolve); the message below
                // distinguishes them via the id itself, since the user
                // benefits from knowing which case they're in even though
                // the available profiles (none, either way) are the same.
                child: NoSystemSelectedNotice(
                  unresolved: _controller.draft.systemId != null,
                ),
              ),
          ],
        );
    }
  }

  /// A compact summary of the last calculation run, shown above the
  /// Sections stage's per-section panels regardless of whether a section
  /// is currently selected. Returns null (renders nothing) when
  /// calculation has never been run at all -- once it has run, the banner
  /// keeps showing that outcome (marked stale if the draft has since
  /// changed) rather than disappearing.
  Widget? _buildCalculationResultsBanner() {
    if (!_controller.calculationHasRun) return null;
    return CalculationResultsBanner(
      result: _controller.calculationResult,
      error: _controller.calculationError,
      hadNoRuleSet: _controller.calculationHadNoRuleSet,
      sections: _controller.draft.sections,
      isStale: _controller.calculationIsStale,
    );
  }
}

/// The three ways a user can respond to the unsaved-changes dialog shown
/// by `_handleBackPressed`. A dedicated enum rather than a `bool?`/`String?`
/// so "cancel", "discard", and "save" can never be confused with each other
/// or with "dialog dismissed" (`null`, handled the same as `cancel`).
enum _UnsavedChangesChoice { cancel, discard, save }

/// Intents for the editor-wide undo/redo keyboard shortcuts. Deliberately
/// private and distinct from Flutter's text-editing intents so the two
/// shortcut systems can never intercept each other's activations.
class _UndoEditorIntent extends Intent {
  const _UndoEditorIntent();
}

class _RedoEditorIntent extends Intent {
  const _RedoEditorIntent();
}

/// Small "unsaved changes" pill shown in the top app bar's title next to
/// the construction name whenever the draft has unsaved edits.
/// Deliberately unobtrusive -- a small dot + short label, not a banner --
/// since it is informational, not a warning the user must act on
/// immediately (the dialog on back/close is what actually requires a
/// decision).
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
