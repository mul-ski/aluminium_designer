import 'package:flutter/material.dart';

import '../../../core/logic/cut_grouping.dart';
import '../../../core/logic/rule_set_resolution.dart';
import '../../../core/logic/system_compatibility.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/construction.dart';
import '../../../core/models/construction_type.dart';
import '../../../core/models/cut.dart';
import '../../../core/models/layout_direction.dart';
import '../../../core/models/opening.dart';
import '../../../core/models/profile.dart';
import '../../../core/models/profile_system.dart';
import '../../../core/models/profile_usage.dart';
import '../../../core/models/project_json.dart' show ConstructionJson;
import '../../../core/models/rules/system_rule_set.dart'
    show AmbiguousRuleMatchException;
import '../../../core/models/section.dart';
import '../../../core/models/section_geometry.dart';
import '../../../core/storage/catalog_store.dart';
import '../widgets/construction_painter.dart';
import '../widgets/manufacturer_system_picker.dart';
import '../widgets/section_list_editor.dart' show showSectionDialog;

/// A `TextFormField` whose displayed text is driven by an external value
/// (`value`) that can change for reasons other than the user typing --
/// e.g. switching stages away and back, or a different section being
/// selected. Uses a `TextEditingController` kept in sync via
/// `didUpdateWidget` instead of keying the field by its own live value.
///
/// The previous implementation keyed each field as
/// `ValueKey('width-$id-${draft.width}')` -- including the live value in
/// the key. Every keystroke changed `draft.width`, which changed the key,
/// which made Flutter tear down and rebuild a brand-new `TextFormField`
/// on every character: focus, cursor position, and -- if the rebuild won
/// the race against that keystroke's `onChanged` call -- the keystroke
/// itself could be lost. That is exactly what going Back/Next or
/// reopening a stage could appear to "undo": the last character typed
/// before switching away had not reliably reached `_draft` yet. Syncing
/// a stable controller instead removes that race entirely -- the
/// controller is the single source of the field's text, updated
/// explicitly, never torn down by a keystroke.
class _SyncedTextField extends StatefulWidget {
  final String value;
  final String label;
  final String? suffixText;
  final TextInputType? keyboardType;
  final ValueChanged<String> onChanged;

  const _SyncedTextField({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    this.suffixText,
    this.keyboardType,
  });

  @override
  State<_SyncedTextField> createState() => _SyncedTextFieldState();
}

class _SyncedTextFieldState extends State<_SyncedTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(covariant _SyncedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only push an external change into the controller when the field's
    // current text doesn't already match it -- otherwise every keystroke
    // (which changes `widget.value` via the parent's `setState` in the
    // same frame) would fight the controller for cursor position. A
    // mismatch here means the value changed for some other reason (a
    // different section selected, a stage switch and back), so the
    // field's text needs to catch up.
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      keyboardType: widget.keyboardType,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: widget.suffixText,
      ),
      onChanged: widget.onChanged,
    );
  }
}

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
///
/// STAGE NAVIGATION: the right properties panel is additionally scoped by
/// `_stage` (General / Geometry / Sections) -- a pure UI concept layered
/// on top of the same `_draft`/`_selectedSectionId` state described above.
/// `_stage` never gates what data exists or what Save persists; it only
/// decides which subset of the *same* draft's fields the right panel
/// currently shows, and which item is highlighted in the left nav. Moving
/// between stages (via the left nav or the bottom Back/Next/Finish bar)
/// never touches `_draft`, `_lastSaved`, or the selected section.
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

/// The three-stage design workflow this milestone adds: General ->
/// Geometry -> Sections. Purely a UI concept -- see the class doc's
/// "STAGE NAVIGATION" note. Order in this enum is the canonical
/// Back/Next order used by [_ConstructionEditorScreenState._goNext] and
/// [_ConstructionEditorScreenState._goBack].
enum _Stage { general, geometry, sections }

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

  /// Which of the three design stages the right panel currently shows.
  /// Defaults to General -- the natural start of the General -> Geometry
  /// -> Sections route described in the class doc.
  _Stage _stage = _Stage.general;

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

  /// The [ProfileSystem] `_draft.systemId` currently resolves to in
  /// `_catalog`, or `null` if no system is selected, or if it was
  /// selected but has since been deleted from the catalog (unresolved --
  /// see `Construction.systemId`'s doc comment for why those two cases
  /// are NOT distinguished by this getter; callers that need to tell them
  /// apart check `_draft.systemId` directly alongside this).
  ProfileSystem? get _resolvedSystem => _catalog.systemById(_draft.systemId);

  /// Whether `_calculationResult`/`_calculationError`/
  /// `_calculationHadNoRuleSet` reflect the CURRENT `_draft`, or an
  /// earlier one -- `true` means the draft has changed since the last
  /// `_calculate()` run (see `_resetCalculationState`) and the fields
  /// above are stale, not necessarily still accurate for `_draft` as it
  /// stands now. Recalculation stays manual (the user presses Calculer)
  /// rather than automatic -- deliberately, so an edit never triggers a
  /// calculation pass on its own; today's `genericPlaceholderRuleSet` is
  /// cheap, but a real per-manufacturer rule set is not guaranteed to
  /// be, and several mutators (e.g. `_applySectionWidth`) fire on every
  /// keystroke via `_SyncedTextField`'s `onChanged` -- auto-recalculating
  /// there would mean re-running the calculator once per character
  /// typed. Instead of silently clearing the last result on every edit
  /// (which is what happened before this field existed), the stale
  /// result/error is kept and shown with a "stale" indicator -- see
  /// `_CalculationResultsBanner.isStale`/`_LeftPanel`'s badge -- so
  /// going out of date is visible rather than invisible, without ever
  /// triggering extra calculation work.
  bool _calculationIsStale = false;

  /// Result of the last `_calculate()` run, or `null` if calculation
  /// hasn't been run yet, or `calculateConstructionCuts` itself
  /// returned `null` (no rule set could be resolved -- see that
  /// function's doc comment). An empty (but non-null) list is a
  /// meaningful, distinct result: the rule set resolved fine, there was
  /// just nothing to cut (e.g. no profile usages assigned yet). Not part
  /// of `_draft` -- it's a derived view, not saved data, so it must never
  /// affect `_isDirty`/`toJson()` comparison or `_save()`. May be stale
  /// relative to the current `_draft` -- see `_calculationIsStale`.
  List<ProfileCut>? _calculationResult;

  /// Non-null exactly when the last `_calculate()` run failed, holding
  /// either `AmbiguousRuleMatchException` or `StateError` (the two
  /// exception types `calculateConstructionCuts`/
  /// `ConstructionCalculator.calculate` can throw -- see their doc
  /// comments). May be stale relative to the current `_draft` -- see
  /// `_calculationIsStale`.
  Object? _calculationError;

  /// Whether `_calculate()` has been run at least once since the last
  /// `_resetCalculationState()` (i.e. either `_calculationResult` or
  /// `_calculationError` is set) but resolved no rule set at all
  /// (`calculateConstructionCuts` returned `null`) -- distinct from a
  /// resolved rule set that simply produced zero cuts
  /// (`_calculationResult` is a non-null empty list). Only meaningful
  /// once `_calculationHasRun` is true. May be stale relative to the
  /// current `_draft` -- see `_calculationIsStale`.
  bool _calculationHadNoRuleSet = false;

  /// Marks the current calculation outcome as stale, with no `setState`
  /// of its own -- every mutator that can affect a calculation result
  /// already wraps its own change in a `setState` (e.g. `_replaceSection`,
  /// `_applyWidth`, `_addProfileUsage`), so this is called from inside
  /// that existing block rather than opening a second one. Deliberately
  /// does NOT clear `_calculationResult`/`_calculationError`/
  /// `_calculationHadNoRuleSet` -- see `_calculationIsStale`'s doc
  /// comment for why the last outcome is kept, marked stale, rather than
  /// discarded.
  void _resetCalculationState() {
    _calculationIsStale = true;
  }

  /// Runs `calculateConstructionCuts(_draft, _catalog)` and stores the
  /// outcome in `_calculationResult`/`_calculationError`/
  /// `_calculationHadNoRuleSet` for `_buildPropertiesPanel`'s Sections
  /// stage to display.
  ///
  /// `calculateConstructionCuts` returning `null` (unresolved
  /// system/rule set -- see that function's doc comment) is recorded via
  /// `_calculationHadNoRuleSet` rather than folded into an empty result
  /// list, so the properties panel can tell "no rule set available for
  /// this system yet" apart from "rule set resolved, zero cuts produced".
  /// `StateError` (missing construction dimensions) and
  /// `AmbiguousRuleMatchException` (genuine rule ambiguity -- see
  /// `SystemRuleSet.select`'s doc comment) are both caught here rather
  /// than left to crash the widget tree; either becomes
  /// `_calculationError` for display. No other exception type is caught --
  /// anything else is a real bug and should still surface as one.
  void _calculate() {
    try {
      final cuts = calculateConstructionCuts(_draft, _catalog);
      setState(() {
        _calculationResult = cuts;
        _calculationError = null;
        _calculationHadNoRuleSet = cuts == null;
        _calculationIsStale = false;
      });
    } on AmbiguousRuleMatchException catch (e) {
      setState(() {
        _calculationResult = null;
        _calculationError = e;
        _calculationHadNoRuleSet = false;
        _calculationIsStale = false;
      });
    } on StateError catch (e) {
      setState(() {
        _calculationResult = null;
        _calculationError = e;
        _calculationHadNoRuleSet = false;
        _calculationIsStale = false;
      });
    }
  }

  /// Whether `_calculate()` has been run at least once since the last
  /// `_resetCalculationState()`.
  bool get _calculationHasRun =>
      _calculationResult != null ||
      _calculationError != null ||
      _calculationHadNoRuleSet;

  void _selectSection(String? id) {
    setState(() {
      _selectedSectionId = id;
      // Selecting a section from the tree or canvas only makes sense to
      // look at alongside the Sections stage's properties -- if the user
      // was on General or Geometry, jump them there so the right panel
      // they now see actually matches what they just selected. Selecting
      // the construction root (id == null) does NOT force a stage change:
      // General/Geometry both operate on the construction root already,
      // so there's no mismatch to correct there.
      if (id != null) {
        _stage = _Stage.sections;
      }
    });
  }

  /// Left-nav / bottom-bar direct stage change. Never touches `_draft` or
  /// `_selectedSectionId` -- see the class doc's "STAGE NAVIGATION" note.
  void _goToStage(_Stage stage) {
    setState(() => _stage = stage);
  }

  void _goNext() {
    switch (_stage) {
      case _Stage.general:
        _goToStage(_Stage.geometry);
        break;
      case _Stage.geometry:
        _goToStage(_Stage.sections);
        break;
      case _Stage.sections:
        // No "next" past Sections -- the bottom bar shows Finish instead
        // of Next here (see [_buildBottomNav]), so this should not be
        // reachable, but do nothing rather than wrap around if it is.
        break;
    }
  }

  void _goBack() {
    switch (_stage) {
      case _Stage.general:
        // No "back" before General -- see [_buildBottomNav].
        break;
      case _Stage.geometry:
        _goToStage(_Stage.general);
        break;
      case _Stage.sections:
        _goToStage(_Stage.geometry);
        break;
    }
  }

  // ---- Construction-level property edits ----

  void _applyName(String value) {
    setState(() => _draft = _draft.copyWith(name: value));
  }

  void _applyType(ConstructionType type) {
    setState(() {
      _draft = _draft.copyWith(type: type);
      _resetCalculationState();
    });
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
      _resetCalculationState();
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
      _resetCalculationState();
    });
  }

  void _applyLayoutDirection(SectionLayoutDirection direction) {
    setState(() => _draft = _draft.copyWith(layoutDirection: direction));
  }

  /// Applies a manufacturer/system selection made in the picker.
  ///
  /// [manufacturerId]/[systemId] are the new authoritative ids (may be
  /// `null` -- e.g. manufacturer chosen but no system yet, or the
  /// selection was cleared). [manufacturerName]/[systemName] are the
  /// display-name fallbacks stored alongside them (see `Construction`'s
  /// doc comment on why both exist).
  ///
  /// Per the approved policy: if [systemId] differs from the currently
  /// resolved system AND any existing `_draft.profileUsages` would become
  /// incompatible with the new system (checked via
  /// `incompatibleUsages` against ALL current usages, not just ones known
  /// to be tied to the previous system -- see that function's doc for
  /// why), this asks for confirmation before proceeding. Cancelling makes
  /// no change at all -- the picker's own dropdown state reverts on
  /// rebuild since `_draft` never changed. Confirming removes exactly the
  /// incompatible usages and applies the new selection in one `setState`.
  Future<void> _applyManufacturerSystem(
    BuildContext context, {
    required String manufacturerName,
    required String systemName,
    String? manufacturerId,
    String? systemId,
  }) async {
    ProfileSystem? newSystem;
    if (systemId != null) {
      for (final s in _catalog.profileSystems) {
        if (s.id == systemId) {
          newSystem = s;
          break;
        }
      }
    }

    final incompatible = incompatibleUsages(_draft.profileUsages, newSystem);

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

    setState(() {
      _draft = _draft.copyWith(
        manufacturer: manufacturerName,
        system: systemName,
        manufacturerId: manufacturerId,
        clearManufacturerId: manufacturerId == null,
        systemId: systemId,
        clearSystemId: systemId == null,
        profileUsages: incompatible.isEmpty
            ? _draft.profileUsages
            : _draft.profileUsages
                  .where((u) => !incompatible.contains(u))
                  .toList(),
      );
      _resetCalculationState();
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
      _resetCalculationState();
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

  // ---- Profile assignment (ProfileUsage) for the selected section ----

  /// Adds a new [ProfileUsage] for [profileId] on [sectionId] with [role],
  /// quantity defaulting to `1` (see `ProfileUsage.quantity`'s doc for
  /// what this default represents). [profileId] is expected to already
  /// belong to the currently resolved system -- callers (the assignment
  /// UI) only ever offer profiles from `_resolvedSystem.profiles`, so this
  /// does not re-check compatibility itself; it trusts its caller the same
  /// way `_applySectionWidth` trusts a parsed value from its caller.
  void _addProfileUsage({
    required String profileId,
    required String sectionId,
    required ProfileUsageRole role,
  }) {
    final usage = ProfileUsage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      profileId: profileId,
      sectionId: sectionId,
      role: role,
    );
    setState(() {
      _draft = _draft.copyWith(profileUsages: [..._draft.profileUsages, usage]);
      _resetCalculationState();
    });
  }

  void _updateProfileUsageQuantity(ProfileUsage usage, int quantity) {
    if (quantity < 1) return;
    setState(() {
      _draft = _draft.copyWith(
        profileUsages: [
          for (final u in _draft.profileUsages)
            if (u.id == usage.id)
              ProfileUsage(
                id: u.id,
                profileId: u.profileId,
                sectionId: u.sectionId,
                role: u.role,
                quantity: quantity,
              )
            else
              u,
        ],
      );
      _resetCalculationState();
    });
  }

  void _removeProfileUsage(ProfileUsage usage) {
    setState(() {
      _draft = _draft.copyWith(
        profileUsages: _draft.profileUsages
            .where((u) => u.id != usage.id)
            .toList(),
      );
      _resetCalculationState();
    });
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
      // Match `_selectSection`'s behavior: a newly added section is only
      // useful to look at alongside the Sections stage's properties.
      _stage = _Stage.sections;
      _resetCalculationState();
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
      _resetCalculationState();
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
                        child: _LeftPanel(
                          construction: _draft,
                          stage: _stage,
                          selectedSectionId: _selectedSectionId,
                          onStageSelected: _goToStage,
                          onSelectConstruction: () => _selectSection(null),
                          onSelectSection: _selectSection,
                          calculationResult: _calculationResult,
                          calculationIsStale: _calculationIsStale,
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
        // Stage Back/Next/Finish, grouped separately from Return-to-Project
        // (the leading arrow_back) and Delete/Save below -- distinct icons
        // (chevron vs arrow_back/check) so "go back one design stage" is
        // never visually confused with "leave the editor".
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Étape précédente',
          onPressed: _stage == _Stage.general ? null : _goBack,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            _stageLabel(_stage),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        if (_stage == _Stage.sections)
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            tooltip: 'Terminer',
            onPressed: _save,
          )
        else
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Étape suivante',
            onPressed: _goNext,
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

  String _stageLabel(_Stage stage) {
    switch (stage) {
      case _Stage.general:
        return 'Général';
      case _Stage.geometry:
        return 'Géométrie';
      case _Stage.sections:
        return 'Sections';
    }
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
          const VerticalDivider(width: 24, indent: 8, endIndent: 8),
          _ToolbarButton(
            icon: Icons.calculate_outlined,
            label: 'Calculer',
            onPressed: _calculate,
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
    switch (_stage) {
      case _Stage.general:
        return _GeneralPropertiesPanel(
          draft: _draft,
          catalog: _catalog,
          typeLabel: _typeLabel,
          onNameChanged: _applyName,
          onTypeChanged: _applyType,
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
      case _Stage.geometry:
        return _GeometryPropertiesPanel(
          draft: _draft,
          onWidthChanged: _applyWidth,
          onHeightChanged: _applyHeight,
          onLayoutDirectionChanged: _applyLayoutDirection,
        );
      case _Stage.sections:
        final resultsBanner = _buildCalculationResultsBanner();
        final section = _selectedSection;
        if (section == null) {
          return Column(
            children: [
              ?resultsBanner,
              const Expanded(child: _NoSectionSelectedNotice()),
            ],
          );
        }
        final system = _resolvedSystem;
        if (system == null) {
          // Covers BOTH "no system selected yet" (_draft.systemId == null)
          // and "selected system no longer exists in the catalog"
          // (_draft.systemId is set but doesn't resolve) -- see
          // `_resolvedSystem`'s doc comment for why this getter doesn't
          // distinguish them; the messages below do, using
          // `_draft.systemId` directly, since the user benefits from
          // knowing which case they're in even though the *available
          // profiles* (none, either way) are the same.
          return Column(
            children: [
              ?resultsBanner,
              Expanded(
                child: _NoSystemSelectedNotice(
                  unresolved: _draft.systemId != null,
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            ?resultsBanner,
            Expanded(
              child: _SectionPropertiesPanel(
                section: section,
                onWidthChanged: (v) => _applySectionWidth(section, v),
                onHeightChanged: (v) => _applySectionHeight(section, v),
                onKindChanged: (k) => _applySectionKind(section, k),
                onOpeningTypeChanged: (t) =>
                    _applySectionOpeningType(section, t),
                onVantauxCountChanged: (c) =>
                    _applySectionVantauxCount(section, c),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _SectionProfileAssignmentPanel(
                section: section,
                system: system,
                usages: _draft.profileUsages
                    .where((u) => u.sectionId == section.id)
                    .toList(),
                onAdd: ({required profileId, required role}) =>
                    _addProfileUsage(
                      profileId: profileId,
                      sectionId: section.id,
                      role: role,
                    ),
                onQuantityChanged: _updateProfileUsageQuantity,
                onRemove: _removeProfileUsage,
              ),
            ),
          ],
        );
    }
  }

  /// A compact summary of the last `_calculate()` run, shown above the
  /// Sections stage's existing per-section panel regardless of whether a
  /// section is currently selected (cuts are construction-wide, not
  /// per-section, so tying visibility to section selection like the rest
  /// of that panel would hide results whenever nothing is selected).
  /// Returns `null` (renders nothing) when `_calculate()` has never been
  /// run at all -- see `_calculationHasRun`. Once it has run at least
  /// once, the banner keeps showing that outcome (marked stale via
  /// `_calculationIsStale` if `_draft` has since changed) rather than
  /// disappearing -- see `_calculationIsStale`'s doc comment.
  Widget? _buildCalculationResultsBanner() {
    if (!_calculationHasRun) return null;
    return _CalculationResultsBanner(
      result: _calculationResult,
      error: _calculationError,
      hadNoRuleSet: _calculationHadNoRuleSet,
      sections: _draft.sections,
      isStale: _calculationIsStale,
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

/// Left working zone: the DESIGN stage navigator (General / Geometry /
/// Sections) plus the existing construction/section structure tree below
/// it, preserved unchanged from before this milestone -- selecting a
/// section here still drives canvas/properties selection exactly as it
/// did previously (see `_ConstructionEditorScreenState._selectSection`).
class _LeftPanel extends StatelessWidget {
  final Construction construction;
  final _Stage stage;
  final String? selectedSectionId;
  final ValueChanged<_Stage> onStageSelected;
  final VoidCallback onSelectConstruction;
  final ValueChanged<String> onSelectSection;

  /// The last `_calculate()` result, or `null` if calculation has never
  /// been run at all -- same meaning as
  /// `_ConstructionEditorScreenState._calculationResult`, passed
  /// straight through rather than this widget re-deriving it. `null`
  /// here covers BOTH "never calculated" and "calculation ran but
  /// failed/found no rule set" -- this tree only shows a per-section
  /// count when there's an actual cut list to count, same rule
  /// `_CalculationResultsBanner` already applies to itself; it does not
  /// try to show its own error/no-rule-set state, since that's already
  /// shown once in the results banner and repeating it here per section
  /// would be redundant, not more informative. May be stale relative to
  /// `construction` if `_draft` has changed since the last calculation --
  /// see [calculationIsStale]; a stale result is still shown here, not
  /// hidden, matching `_calculationIsStale`'s doc comment on why the last
  /// outcome is kept rather than discarded on edit.
  final List<ProfileCut>? calculationResult;

  /// Whether [calculationResult] (if non-null) reflects the CURRENT
  /// [construction], or an earlier one -- see
  /// `_ConstructionEditorScreenState._calculationIsStale`'s doc comment.
  /// When true, a badge is still shown (never hidden -- recalculation is
  /// manual, so hiding it would just mean the count is gone every time
  /// the user makes an edit) but visually marked as outdated.
  final bool calculationIsStale;

  const _LeftPanel({
    required this.construction,
    required this.stage,
    required this.selectedSectionId,
    required this.onStageSelected,
    required this.onSelectConstruction,
    required this.onSelectSection,
    required this.calculationResult,
    required this.calculationIsStale,
  });

  @override
  Widget build(BuildContext context) {
    final ordered = [...construction.sections]
      ..sort((a, b) => a.order.compareTo(b.order));
    final cutsBySection = calculationResult == null
        ? const <String, List<ProfileCut>>{}
        : groupCutsBySectionId(calculationResult!);

    return Material(
      color: const Color(0xFFFAFAFA),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: _PanelHeader('DESIGN'),
          ),
          _StageNavItem(
            icon: Icons.info_outline,
            label: 'General',
            selected: stage == _Stage.general,
            onTap: () => onStageSelected(_Stage.general),
          ),
          _StageNavItem(
            icon: Icons.straighten,
            label: 'Geometry',
            selected: stage == _Stage.geometry,
            onTap: () => onStageSelected(_Stage.geometry),
          ),
          _StageNavItem(
            icon: Icons.dashboard_customize_outlined,
            label: 'Sections',
            selected: stage == _Stage.sections,
            onTap: () => onStageSelected(_Stage.sections),
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
                        count: cutsBySection[section.id]!.length,
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

/// Small pill showing how many cuts a section produced in the last
/// calculation -- only ever built for a section that
/// `_LeftPanel.calculationResult` actually has cuts for (see that
/// build's `cutsBySection.containsKey` check), so [count] is always >=
/// 1; a section with zero cuts (no profile usages assigned, or usages
/// whose rule matched but produced nothing) simply shows no badge at
/// all, same as a section that hasn't been calculated yet -- neither
/// case is distinguished here, since both mean "nothing to show", and
/// `_CalculationResultsBanner` already states which one it is at the
/// construction level.
///
/// [isStale] dims the badge (rather than hiding it) when `_draft` has
/// changed since [count] was computed -- see
/// `_ConstructionEditorScreenState._calculationIsStale`'s doc comment
/// for why the count stays visible instead of disappearing on edit.
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

/// Right working zone, construction-level: shown when nothing is selected.
/// Right panel, General stage: construction identity + manufacturer
/// system -- everything from the old combined panel except dimensions and
/// layout direction, which moved to [_GeometryPropertiesPanel].
class _GeneralPropertiesPanel extends StatelessWidget {
  final Construction draft;
  final Catalog catalog;
  final String Function(ConstructionType) typeLabel;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<ConstructionType> onTypeChanged;
  final void Function(
    String manufacturerName,
    String systemName, {
    String? manufacturerId,
    String? systemId,
  })
  onManufacturerSystemSelected;
  final ValueChanged<Catalog> onCatalogChanged;

  const _GeneralPropertiesPanel({
    required this.draft,
    required this.catalog,
    required this.typeLabel,
    required this.onNameChanged,
    required this.onTypeChanged,
    required this.onManufacturerSystemSelected,
    required this.onCatalogChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _PanelHeader('GÉNÉRAL'),
        _SyncedTextField(
          value: draft.name,
          label: 'Nom',
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
        const _PanelHeader('SYSTÈME'),
        ManufacturerSystemPicker(
          catalog: catalog,
          selectedManufacturerId: draft.manufacturerId,
          selectedSystemId: draft.systemId,
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

/// Right panel, Geometry stage: construction width/height + layout
/// direction -- the dimensions/layout portion of the old combined panel.
class _GeometryPropertiesPanel extends StatelessWidget {
  final Construction draft;
  final ValueChanged<String> onWidthChanged;
  final ValueChanged<String> onHeightChanged;
  final ValueChanged<SectionLayoutDirection> onLayoutDirectionChanged;

  const _GeometryPropertiesPanel({
    required this.draft,
    required this.onWidthChanged,
    required this.onHeightChanged,
    required this.onLayoutDirectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _PanelHeader('DIMENSIONS'),
        _SyncedTextField(
          value: draft.width?.toStringAsFixed(0) ?? '',
          label: 'Largeur',
          suffixText: 'mm',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onWidthChanged,
        ),
        const SizedBox(height: 12),
        _SyncedTextField(
          value: draft.height?.toStringAsFixed(0) ?? '',
          label: 'Hauteur',
          suffixText: 'mm',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
      ],
    );
  }
}

/// Shown in the Sections stage's right panel when no section is currently
/// selected (e.g. the user just switched to this stage, or just removed
/// the selected section). Directs the user to either pick an existing
/// section or add one via the toolbar, rather than showing an empty panel.
class _NoSectionSelectedNotice extends StatelessWidget {
  const _NoSectionSelectedNotice();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Text(
          'Sélectionnez une section dans la liste à gauche ou '
          'ajoutez-en une avec le bouton "Ajouter une section" '
          'de la barre d\'outils.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF5B6B76)),
        ),
      ),
    );
  }
}

/// Shown in the Sections stage's right panel when a section IS selected
/// but no valid [ProfileSystem] is resolved for the construction -- either
/// none was ever selected, or one was selected and its id no longer
/// resolves in the catalog (deleted system/manufacturer). See
/// `_ConstructionEditorScreenState._resolvedSystem`'s doc comment.
///
/// [unresolved] distinguishes the two cases in the message shown (the
/// underlying fact -- no profiles are available to assign -- is the same
/// either way), matching Part 4's requirement that a deleted-system
/// construction show an informative state, not crash or silently behave
/// like nothing was ever selected.
class _NoSystemSelectedNotice extends StatelessWidget {
  final bool unresolved;

  const _NoSystemSelectedNotice({required this.unresolved});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              unresolved ? Icons.link_off : Icons.info_outline,
              color: const Color(0xFF5B6B76),
            ),
            const SizedBox(height: 8),
            Text(
              unresolved
                  ? 'Le système précédemment sélectionné n\'existe plus '
                        'dans le catalogue. Sélectionnez un système valide '
                        'dans l\'onglet Général pour gérer les profils.'
                  : 'Sélectionnez un système dans l\'onglet Général pour '
                        'pouvoir assigner des profils à cette section.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF5B6B76)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact summary of the last calculation run, shown at the top of the
/// Sections stage's right panel -- see
/// `_ConstructionEditorScreenState._buildCalculationResultsBanner`'s doc
/// comment for why this isn't gated on a section being selected the way
/// the rest of that panel is.
///
/// Exactly one of [error], [hadNoRuleSet], or a non-null [result] is the
/// active case -- `_calculate()` only ever sets one of the three. Cuts
/// are grouped by `ProfileCut.sectionId` (see [_groupBySectionId]) so a
/// list mixing several sections' pieces doesn't read as one undivided
/// pile -- still a flat `Column` of `Text` per group, matching the plain
/// informational style of `_NoSectionSelectedNotice`/
/// `_NoSystemSelectedNotice` rather than introducing a new visual
/// language (table, card, etc.) for what is still a placeholder-rule-set
/// result, not real fabrication data -- see this milestone's "keep the
/// UI simple, no redesign" constraint.
///
/// [isStale] shows a small "outdated" notice above whichever outcome is
/// active, when `_draft` has changed since that outcome was computed --
/// see `_ConstructionEditorScreenState._calculationIsStale`'s doc
/// comment. The outcome itself is never hidden or replaced on staleness,
/// only flagged -- recalculation stays a manual, explicit action.
class _CalculationResultsBanner extends StatelessWidget {
  final List<ProfileCut>? result;
  final Object? error;
  final bool hadNoRuleSet;
  final List<Section> sections;
  final bool isStale;

  const _CalculationResultsBanner({
    required this.result,
    required this.error,
    required this.hadNoRuleSet,
    required this.sections,
    required this.isStale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: const Color(0xFFF3F5F6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isStale) ...[
            const Row(
              children: [
                Icon(Icons.update, size: 14, color: Color(0xFF8A6D00)),
                SizedBox(width: 6),
                Text(
                  'Résultat obsolète -- appuyez sur Calculer pour '
                  'actualiser.',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF8A6D00),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          _buildContent(),
        ],
      ),
    );
  }

  /// See `groupCutsBySectionId` in `lib/core/logic/cut_grouping.dart`.
  Map<String, List<ProfileCut>> _groupBySectionId(List<ProfileCut> cuts) =>
      groupCutsBySectionId(cuts);

  /// See `sectionLabelForCutGroup` in `lib/core/logic/cut_grouping.dart`.
  String _sectionLabel(String sectionId) =>
      sectionLabelForCutGroup(sectionId, sections);

  Widget _buildContent() {
    final error = this.error;
    if (error != null) {
      // AmbiguousRuleMatchException and StateError are the only two
      // types `_calculate()` catches -- see that method's doc comment.
      // Both already have a clear `toString()` (AmbiguousRuleMatchException
      // names the tied rules; StateError carries the message it was
      // thrown with), so it's shown directly rather than re-worded here.
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

    final cuts = result;
    if (cuts == null || cuts.isEmpty) {
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

    final grouped = _groupBySectionId(cuts);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${cuts.length} coupe(s)',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        for (final entry in grouped.entries) ...[
          Text(
            _sectionLabel(entry.key),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5B6B76),
            ),
          ),
          for (final cut in entry.value)
            Padding(
              padding: const EdgeInsets.only(bottom: 2, left: 8),
              child: Text(
                '${cut.profile.name} — ${cut.length.toStringAsFixed(0)} mm '
                '× ${cut.quantity} (${cut.angleStart.toStringAsFixed(0)}° / '
                '${cut.angleEnd.toStringAsFixed(0)}°)',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}

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
        _SyncedTextField(
          key: ValueKey('sec-width-${section.id}'),
          value: section.width.toStringAsFixed(0),
          label: 'Largeur',
          suffixText: 'mm',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onWidthChanged,
        ),
        const SizedBox(height: 12),
        _SyncedTextField(
          key: ValueKey('sec-height-${section.id}'),
          value: section.height.toStringAsFixed(0),
          label: 'Hauteur',
          suffixText: 'mm',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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

/// Sections stage: assigns [Profile]s (from the currently resolved
/// [ProfileSystem] ONLY -- see class doc) to [section] as [ProfileUsage]
/// records.
///
/// This is intentionally a *separate* panel from [_SectionPropertiesPanel]
/// rather than folded into it -- profile assignment is a distinct concern
/// (which catalog profile plays which role) from section geometry (width/
/// height/kind/opening), and keeping them visually separated (see
/// `_buildPropertiesPanel`'s `Column` of two `Expanded` panels) avoids
/// this becoming one long undifferentiated form, per the milestone's UI
/// requirement.
///
/// [system]'s `.profiles` is the ONLY source of assignable profiles --
/// this never reads `Construction.profiles` (the old, retired path; see
/// `Construction`'s doc comment) and never lets the user pick a profile
/// from any other system.
class _SectionProfileAssignmentPanel extends StatelessWidget {
  final Section section;
  final ProfileSystem system;
  final List<ProfileUsage> usages;
  final void Function({
    required String profileId,
    required ProfileUsageRole role,
  })
  onAdd;
  final void Function(ProfileUsage usage, int quantity) onQuantityChanged;
  final ValueChanged<ProfileUsage> onRemove;

  const _SectionProfileAssignmentPanel({
    required this.section,
    required this.system,
    required this.usages,
    required this.onAdd,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  String _roleLabel(ProfileUsageRole role) {
    switch (role) {
      case ProfileUsageRole.left:
        return 'Gauche';
      case ProfileUsageRole.right:
        return 'Droite';
      case ProfileUsageRole.top:
        return 'Haut';
      case ProfileUsageRole.bottom:
        return 'Bas';
      case ProfileUsageRole.intermediate:
        return 'Intermédiaire';
    }
  }

  Profile? _profileFor(String profileId) {
    for (final p in system.profiles) {
      if (p.id == profileId) return p;
    }
    return null;
  }

  Future<void> _showAddDialog(BuildContext context) async {
    if (system.profiles.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Aucun profil disponible'),
          content: Text(
            'Le système "${system.name}" ne contient encore aucun profil. '
            'Ajoutez-en un via "Profils du système" dans l\'onglet Général.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
      return;
    }

    String? selectedProfileId = system.profiles.first.id;
    var selectedRole = ProfileUsageRole.left;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Assigner un profil'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedProfileId,
                    decoration: const InputDecoration(labelText: 'Profil'),
                    isExpanded: true,
                    items: [
                      for (final p in system.profiles)
                        DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            '${p.reference} -- ${p.name}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => selectedProfileId = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ProfileUsageRole>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(labelText: 'Rôle'),
                    items: [
                      for (final role in ProfileUsageRole.values)
                        DropdownMenuItem(
                          value: role,
                          child: Text(_roleLabel(role)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedRole = value);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Assigner'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && selectedProfileId != null) {
      onAdd(profileId: selectedProfileId!, role: selectedRole);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              const Expanded(child: _PanelHeader('PROFILS ASSIGNÉS')),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Assigner un profil',
                onPressed: () => _showAddDialog(context),
              ),
            ],
          ),
        ),
        if (usages.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Aucun profil assigné à cette section.',
              style: TextStyle(color: Color(0xFF5B6B76)),
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final usage in usages)
                  _ProfileUsageTile(
                    usage: usage,
                    profile: _profileFor(usage.profileId),
                    roleLabel: _roleLabel(usage.role),
                    onQuantityChanged: (q) => onQuantityChanged(usage, q),
                    onRemove: () => onRemove(usage),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One row in [_SectionProfileAssignmentPanel]'s list.
///
/// [profile] is nullable to handle the (should-not-normally-happen but
/// must not crash) case of a `ProfileUsage.profileId` that no longer
/// resolves in the current system's profile list -- e.g. the profile was
/// deleted from the system after this usage was created (see Part 4A's
/// deletion-integrity requirement). Shown with a warning treatment rather
/// than throwing or silently omitting the row, so the user can see and
/// remove the broken assignment.
class _ProfileUsageTile extends StatelessWidget {
  final ProfileUsage usage;
  final Profile? profile;
  final String roleLabel;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  const _ProfileUsageTile({
    required this.usage,
    required this.profile,
    required this.roleLabel,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p == null
                        ? 'Profil introuvable (${usage.profileId})'
                        : '${p.reference} -- ${p.name}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: p == null ? const Color(0xFFC62828) : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    roleLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5B6B76),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: usage.quantity > 1
                  ? () => onQuantityChanged(usage.quantity - 1)
                  : null,
              tooltip: 'Réduire la quantité',
            ),
            Text('${usage.quantity}'),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => onQuantityChanged(usage.quantity + 1),
              tooltip: 'Augmenter la quantité',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Retirer cette assignation',
              onPressed: onRemove,
            ),
          ],
        ),
      ),
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
