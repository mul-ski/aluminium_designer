import 'package:flutter/foundation.dart';

import '../../../core/logic/boundary_manipulation.dart';
import '../../../core/logic/calculation_staleness.dart';
import '../../../core/logic/rule_set_resolution.dart';
import '../../../core/logic/system_compatibility.dart';
import '../../../core/models/calculation_outcome.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/construction.dart';
import '../../../core/models/construction_type.dart';
import '../../../core/models/layout_direction.dart';
import '../../../core/models/opening.dart';
import '../../../core/models/profile_system.dart';
import '../../../core/models/profile_usage.dart';
import '../../../core/models/project_json.dart'
    show ConstructionJson, ProfileUsageJson;
import '../../../core/models/rules/system_rule_set.dart'
    show AmbiguousRuleMatchException;
import '../../../core/models/section.dart';
import 'editor_stage.dart';

/// Maximum number of past states retained on the editor's undo stack.
///
/// Entries are references to immutable `Construction` trees -- tiny object
/// graphs of a handful of sections/usages -- so even the cap itself costs
/// kilobytes at worst; the cap exists so an unbounded editing session can
/// never grow history indefinitely.
const int kUndoHistoryLimit = 100;

/// Tag identifying a construction-name edit run for undo coalescing --
/// consecutive name keystrokes collapse into a single history entry.
const String kUndoTagName = 'construction.name';

/// Tag for construction-type edits.
const String kUndoTagType = 'construction.type';

/// Tag for overall-width edits -- consecutive typing collapses.
const String kUndoTagWidth = 'construction.width';

/// Tag for overall-height edits -- consecutive typing collapses.
const String kUndoTagHeight = 'construction.height';

/// Tag for layout-direction switches.
const String kUndoTagLayoutDirection = 'construction.layoutDirection';

/// Tag for manufacturer/system selection changes (including the atomic
/// pruning of now-incompatible profile usages).
const String kUndoTagSystem = 'construction.system';

/// Owns the editable session state of one [Construction] being edited, and
/// is the single place where editor mutations happen.
///
/// Extracted from what used to be one large `_ConstructionEditorScreenState`
/// so the screen widget only assembles UI and handles navigation/dialogs,
/// while this controller coordinates:
///
///   - the working draft ([draft]) and its last-saved baseline
///     (see [isDirty] for the dirty-state contract),
///   - which stage/section is currently selected
///     ([stage]/[selectedSectionId]),
///   - the app catalog snapshot the editor resolves manufacturer/system
///     selection against ([catalog]),
///   - the outcome of the last manual calculation run and whether that
///     outcome has gone stale since (see [_markCalculationStale]).
///
/// DOMAIN MODEL BOUNDARY: this class coordinates editing; it does not own
/// geometry math, validation, or calculation rules. Those stay in their
/// existing `lib/core` layers (`validateSectionGeometry`, `layoutConstruction`,
/// `calculateConstructionCuts`, ...) -- the controller only calls them and
/// records their outcomes. The draft [Construction] remains the single
/// source of truth: every mutation rebuilds it immutably via `copyWith`
/// (or a direct constructor where `copyWith` cannot express the change),
/// exactly as the screen's mutators did before this class existed.
///
/// NOTIFICATIONS: every state change ends in [notifyListeners]. Mutators
/// that are no-ops (e.g. an unparseable dimension value, removing a
/// section while none is selected) return without notifying, mirroring the
/// previous behaviour where those code paths skipped `setState`.
///
/// This class deliberately knows nothing about BuildContext, dialogs,
/// snackbars, Navigator, or storage. Confirmations (unsaved changes,
/// system-switch incompatibility, delete) and persistence hand-off stay
/// the screen's job -- see `ConstructionEditorScreen`'s class doc.
///
/// UNDO / REDO: every accepted draft mutation is recorded as an immutable
/// Construction snapshot (a reference -- no copying) on a bounded stack,
/// with same-tag consecutive edits coalescing into single entries so
/// text-field keystrokes don't flood history. Only the Construction is
/// historical: stage, section selection, catalog snapshot, viewport
/// transform, and the calculation outcome are presentation/derived state
/// that stays outside the stacks -- selection merely reconciles after a
/// jump (falls back to root when its section no longer exists), and the
/// outcome's staleness is recomputed against the calculator-relevant
/// inputs of whatever draft a jump restores.
class ConstructionEditorController extends ChangeNotifier {
  /// The construction being edited. Every mutation replaces this with a
  /// new immutable instance; nothing mutates a `Construction` in place.
  Construction _draft;

  /// The last [Construction] state actually handed off through a successful
  /// Save (or the construction the editor was opened with, if never saved).
  /// Never touched by ordinary field edits -- only [commitSave] advances
  /// it. This is what [_draft] is compared against to decide whether there
  /// are unsaved changes.
  Construction _lastSaved;

  /// Which of the three design stages the properties panel currently
  /// shows. Defaults to General -- the natural start of the General ->
  /// Geometry -> Sections route.
  EditorStage _stage = EditorStage.general;

  /// Null means the construction root is selected (construction-level
  /// properties shown). Otherwise the id of the selected [Section] --
  /// shared by the structure tree, the canvas (via the painter's
  /// `selectedSectionId`), and the properties panel, so all three never
  /// disagree about what's selected.
  String? _selectedSectionId;

  /// The catalog snapshot this editor resolves manufacturers/systems
  /// against. Starts empty and is replaced once the screen finishes
  /// loading the persisted catalog from disk (the load itself stays in the
  /// screen -- see `ConstructionEditorScreen._loadCatalog`).
  Catalog _catalog = const Catalog();

  // ---- Undo / redo history ----

  /// Past immutable drafts, newest last. References only -- snapshots are
  /// free because every mutation already produced a fresh tree.
  final List<Construction> _undoStack = [];

  /// Future drafts invalidated by an undo, oldest first. Cleared by any
  /// new accepted mutation.
  final List<Construction> _redoStack = [];

  /// Tag of the most recent ACCEPTED mutation, used to coalesce runs of
  /// the same continuous edit (e.g. typing a width digit by digit) into a
  /// single history entry. Reset to null by undo/redo jumps so the next
  /// edit always starts a fresh entry.
  String? _lastMutationTag;

  // ---- Last calculation outcome ----

  /// Result of the last [calculate] run, or `null` if calculation hasn't
  /// been run yet, or `calculateConstructionCuts` itself returned `null`
  /// (no rule set could be resolved). An empty (but non-null) outcome is
  /// a meaningful, distinct result: the rule set resolved fine, there was
  /// just nothing to cut and nothing to report (e.g. no profile usages
  /// assigned yet). Not part of the draft -- it's a derived view, not
  /// saved data, so it must never affect [isDirty]/`toJson()` comparison
  /// or [commitSave].
  CalculationOutcome? _calculationResult;

  /// Non-null exactly when the last [calculate] run failed, holding either
  /// `AmbiguousRuleMatchException` or `StateError` (the two exception types
  /// `calculateConstructionCuts`/`ConstructionCalculator.calculate` can
  /// throw).
  Object? _calculationError;

  /// Whether [calculate] has been run at least once since the last stale
  /// reset but resolved no rule set at all -- distinct from a resolved
  /// rule set that simply produced zero cuts. Only meaningful once
  /// [calculationHasRun] is true.
  bool _calculationHadNoRuleSet = false;

  /// True when the draft has changed since the last [calculate] run, so
  /// the recorded outcome no longer necessarily reflects the current
  /// draft. Recalculation stays manual (the user presses Calculer) rather
  /// than automatic -- deliberately, so an edit never triggers a
  /// calculation pass on its own; today's `genericPlaceholderRuleSet` is
  /// cheap, but a real per-manufacturer rule set is not guaranteed to be,
  /// and several mutators (e.g. section width fields) fire on every
  /// keystroke. Instead of silently clearing the last result on every
  /// edit, the stale result/error is kept and shown with a "stale"
  /// indicator so going out of date is visible rather than invisible.
  bool _calculationIsStale = false;

  /// Fingerprint of the calculator-relevant DRAFT inputs (overall
  /// dimensions, selected system, profile usages) as they were when
  /// [calculate] last ran. Paired with [_catalogInputFingerprint], this is
  /// what decides whether the recorded outcome is stale after an undo/redo
  /// jump or a catalog replacement -- see
  /// [_reconcileCalculationStaleness]. Null until the first run.
  String? _calculationInputFingerprint;

  /// Fingerprint of the calculator-relevant CATALOG state (resolved rule
  /// set identity + referenced profiles' type/weight/resolution -- see
  /// `catalogCalculationFingerprint`) as it was when [calculate] last ran.
  /// The catalog lives OUTSIDE undo/redo history and outside the draft, so
  /// without this snapshot a profile edited/deleted via the picker
  /// mid-session would leave a result looking fresh although its inputs no
  /// longer match. Null until the first run.
  String? _catalogInputFingerprint;

  /// Creates a controller editing [construction], against an empty
  /// catalog -- the screen replaces it via [setCatalog] once the persisted
  /// catalog has loaded from disk.
  ConstructionEditorController({required Construction construction})
    : _draft = construction,
      _lastSaved = construction;

  // ---- Read-only state ----

  Construction get draft => _draft;

  EditorStage get stage => _stage;

  String? get selectedSectionId => _selectedSectionId;

  Catalog get catalog => _catalog;

  /// True whenever the draft differs from the saved baseline. `Construction`
  /// and `Section` are plain classes without `==` overrides, so this
  /// compares their JSON representations -- already exactly what
  /// `ProjectStore` persists, so "differs" here means exactly "differs in
  /// whatever would actually be written to disk".
  bool get isDirty {
    return _draft.toJson().toString() != _lastSaved.toJson().toString();
  }

  /// The currently selected [Section], or `null` when the construction
  /// root is selected (or the selected id went stale, e.g. after removal).
  Section? get selectedSection {
    final id = _selectedSectionId;
    if (id == null) return null;
    for (final s in _draft.sections) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// The [ProfileSystem] the draft's `systemId` currently resolves to in
  /// the catalog, or `null` if no system is selected, or if it was
  /// selected but has since been deleted from the catalog (unresolved --
  /// callers that need to tell those two cases apart check
  /// `draft.systemId` directly alongside this getter).
  ProfileSystem? get resolvedSystem => _catalog.systemById(_draft.systemId);

  /// Whether [calculate] has been run at least once, ever -- true once any
  /// of the three outcome fields has been set, and stays true across edits
  /// (edits only mark the outcome stale, they don't clear it).
  bool get calculationHasRun =>
      _calculationResult != null ||
      _calculationError != null ||
      _calculationHadNoRuleSet;

  /// Result of the last [calculate] run, or `null` if calculation hasn't
  /// been run yet or found no rule set. See [_calculationResult].
  CalculationOutcome? get calculationResult => _calculationResult;

  /// Skip diagnostics from the last [calculate] run -- which profile
  /// usages produced no cut and why. Empty when calculation hasn't run,
  /// found no rule set, or every usage produced a cut.
  List<ProfileUsageIssue> get calculationIssues =>
      _calculationResult?.issues ?? const [];

  Object? get calculationError => _calculationError;

  bool get calculationHadNoRuleSet => _calculationHadNoRuleSet;

  bool get calculationIsStale => _calculationIsStale;

  // ---- Undo / redo ----

  /// Whether at least one past construction state exists to undo to.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether at least one undone state exists to redo to.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Restores the most recent past draft. Selection reconciles (a
  /// selection whose section no longer exists falls back to the root);
  /// stage, catalog, and viewport state are untouched -- history covers
  /// the Construction only.
  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_draft);
    _lastMutationTag = null;
    _draft = _undoStack.removeLast();
    _afterHistoryJump();
  }

  /// Re-applies the most recently undone mutation. Cleared by any new
  /// accepted mutation.
  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_draft);
    _lastMutationTag = null;
    _draft = _redoStack.removeLast();
    _afterHistoryJump();
  }

  /// Shared post-jump bookkeeping for [undo]/[redo].
  void _afterHistoryJump() {
    // Selection is presentation state, not history: keep it when the
    // restored draft still contains the section, fall back to the root
    // when it does not.
    final selectedId = _selectedSectionId;
    if (selectedId != null && !_draft.sections.any((s) => s.id == selectedId)) {
      _selectedSectionId = null;
    }
    _reconcileCalculationStaleness();
    notifyListeners();
  }

  /// Recomputes staleness precisely against what [calculate] actually ran
  /// against: the recorded outcome is stale exactly when the calculator-
  /// relevant DRAFT inputs of the current draft differ from the stored run,
  /// OR the calculator-relevant CATALOG state changed since (referenced
  /// profile deleted/retyped/reweighted, rule-set identity swapped, system
  /// unresolved).
  ///
  /// Undoing back to the calculated-for draft therefore legitimately
  /// un-stales the result again, while jumping anywhere else re-stales it.
  /// The catalog term is constant across undo/redo jumps (the catalog is
  /// not part of history) but is what makes a picker-side edit invalidate;
  /// see [setCatalog], the single mid-session catalog entry point. This
  /// complements (does not replace) the per-mutator
  /// [_markCalculationStale] calls used on live edits.
  void _reconcileCalculationStaleness() {
    if (!calculationHasRun) return;
    _calculationIsStale =
        _calculatorInputFingerprint(_draft) != _calculationInputFingerprint ||
        catalogCalculationFingerprint(_catalog, _draft) !=
            _catalogInputFingerprint;
  }

  /// The single integration point for every draft mutation. Records the
  /// previous draft onto the undo stack (with tag-based coalescing),
  /// clears the redo stack, applies [next], marks the calculation stale
  /// when the caller says the change affects calculator inputs, and
  /// notifies listeners.
  ///
  /// No-op mutations (next equals current by persisted-JSON content) do
  /// NOT create history; they still notify, matching the pre-history
  /// behaviour where every mutator call notified.
  ///
  /// Coalescing: when [tag] equals the previous accepted mutation's tag,
  /// the run continues -- the anchor already sitting on the undo stack
  /// represents "before this whole run", so no new entry is pushed. Any
  /// different/absent tag starts a new entry.
  void _updateDraft(
    Construction next, {
    required String? tag,
    required bool invalidatesCalculation,
  }) {
    final unchanged = _persistedJson(next) == _persistedJson(_draft);

    if (!unchanged) {
      final coalesce = tag != null && tag == _lastMutationTag;
      if (!coalesce) {
        _undoStack.add(_draft);
        if (_undoStack.length > kUndoHistoryLimit) _undoStack.removeAt(0);
        _redoStack.clear();
      }
      _lastMutationTag = tag;
      _draft = next;
      if (invalidatesCalculation) _markCalculationStale();
    }

    notifyListeners();
  }

  /// The exact JSON representation `ProjectStore` persists -- the basis
  /// for both no-op detection here and dirty-state comparison.
  static String _persistedJson(Construction c) => c.toJson().toString();

  /// Fingerprint of the DRAFT-side inputs `ConstructionCalculator` reads:
  /// overall dimensions, the authoritative system id, and the profile
  /// usages with their placements/quantities. The catalog-side counterpart
  /// is `catalogCalculationFingerprint` in `calculation_staleness.dart`.
  static String _calculatorInputFingerprint(Construction c) =>
      '${c.width}|${c.height}|${c.systemId}'
      '|${c.profileUsages.map((u) => u.toJson().toString()).join(';')}';

  // ---- Selection / stage navigation ----

  /// Selects a section from the tree or canvas. Selecting a section (a
  /// non-null id) switches to the Sections stage, since section selection
  /// only makes sense to look at alongside the Sections stage's
  /// properties. Selecting the construction root (null) does NOT force a
  /// stage change: General/Geometry both operate on the construction root
  /// already, so there's no mismatch to correct there.
  void selectSection(String? id) {
    _selectedSectionId = id;
    if (id != null) {
      _stage = EditorStage.sections;
    }
    notifyListeners();
  }

  /// Left-nav / bottom-bar direct stage change. Never touches the draft or
  /// the selected section -- stages are a pure UI concept over one draft.
  void goToStage(EditorStage stage) {
    _stage = stage;
    notifyListeners();
  }

  /// Advances one stage along the canonical General -> Geometry ->
  /// Sections order. Does nothing on the last stage (the bottom bar shows
  /// Finish instead of Next there), matching the previous behaviour where
  /// no `setState` happened on that path.
  void goNext() {
    switch (_stage) {
      case EditorStage.general:
        _stage = EditorStage.geometry;
        notifyListeners();
        break;
      case EditorStage.geometry:
        _stage = EditorStage.sections;
        notifyListeners();
        break;
      case EditorStage.sections:
        break;
    }
  }

  /// Goes back one stage. Does nothing before the first stage.
  void goBack() {
    switch (_stage) {
      case EditorStage.general:
        break;
      case EditorStage.geometry:
        _stage = EditorStage.general;
        notifyListeners();
        break;
      case EditorStage.sections:
        _stage = EditorStage.geometry;
        notifyListeners();
        break;
    }
  }

  // ---- Construction-level property edits ----

  void setName(String value) {
    // Renaming does not invalidate a calculation outcome: the cut list
    // depends on dimensions/usages, never on the display name.
    _updateDraft(
      _draft.copyWith(name: value),
      tag: kUndoTagName,
      invalidatesCalculation: false,
    );
  }

  void setType(ConstructionType type) {
    _updateDraft(
      _draft.copyWith(type: type),
      tag: kUndoTagType,
      invalidatesCalculation: true,
    );
  }

  /// Parses a typed dimension in millimetres.
  ///
  /// Accepts the app's French decimal COMMA as well as the dot
  /// ('750,5' == '750.5') and tolerates surrounding whitespace -- users
  /// must not have their exact input silently discarded over separator
  /// habit. No thousands separators are supported ('1,500' reads as 1.5).
  ///
  /// Returns null for empty/unparseable input; callers decide whether that
  /// means "clear the dimension" (construction W/H) or "ignore the edit"
  /// (section dimensions).
  static double? _parseDimensionMm(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  /// Applies a typed width. An empty/unparseable field means "not set yet"
  /// (`copyWith` cannot express clearing `width` back to `null` -- its null
  /// means "leave unchanged" -- so the draft is rebuilt directly here
  /// instead of via copyWith).
  ///
  /// A parsed value <= 0 is ignored (no draft rebuild, no undo entry) so
  /// a typed negative or zero cannot silently propagate into the
  /// calculator -- mirrors the validation the section dialog already
  /// applies on `applySectionWidth`. The state's `width` stays at its
  /// previous value; the field's text re-syncs on the next render.
  ///
  /// Every other field, including the authoritative `manufacturerId`/
  /// `systemId`, is carried over unchanged: dimension edits must never
  /// detach the construction from its selected manufacturer/system.
  void setWidth(String value) {
    final parsed = _parseDimensionMm(value);
    if (parsed != null && parsed <= 0) return;
    _updateDraft(
      Construction(
        id: _draft.id,
        name: _draft.name,
        type: _draft.type,
        width: parsed,
        height: _draft.height,
        manufacturer: _draft.manufacturer,
        system: _draft.system,
        manufacturerId: _draft.manufacturerId,
        systemId: _draft.systemId,
        sections: _draft.sections,
        layoutDirection: _draft.layoutDirection,
        profiles: _draft.profiles,
        profileUsages: _draft.profileUsages,
      ),
      tag: kUndoTagWidth,
      invalidatesCalculation: true,
    );
  }

  /// Applies a typed height. See [setWidth] for why this rebuilds the draft
  /// directly and carries every non-dimension field over unchanged. The
  /// `<= 0` guard mirrors the section dialog's existing validation -- a
  /// non-positive value is ignored, the draft keeps its previous height.
  void setHeight(String value) {
    final parsed = _parseDimensionMm(value);
    if (parsed != null && parsed <= 0) return;
    _updateDraft(
      Construction(
        id: _draft.id,
        name: _draft.name,
        type: _draft.type,
        width: _draft.width,
        height: parsed,
        manufacturer: _draft.manufacturer,
        system: _draft.system,
        manufacturerId: _draft.manufacturerId,
        systemId: _draft.systemId,
        sections: _draft.sections,
        layoutDirection: _draft.layoutDirection,
        profiles: _draft.profiles,
        profileUsages: _draft.profileUsages,
      ),
      tag: kUndoTagHeight,
      invalidatesCalculation: true,
    );
  }

  void setLayoutDirection(SectionLayoutDirection direction) {
    // Layout direction affects rendering and validation, not the rule-set
    // inputs the calculator reads, so the calculation outcome is not
    // marked stale here -- matching the original mutator.
    _updateDraft(
      _draft.copyWith(layoutDirection: direction),
      tag: kUndoTagLayoutDirection,
      invalidatesCalculation: false,
    );
  }

  /// Which of the draft's profile usages would become incompatible with
  /// the system identified by [systemId] (or ALL of them, for a null /
  /// unresolvable system). The screen calls this first to decide whether
  /// the user must confirm the switch; [applyManufacturerSystem] then
  /// performs the actual removal + selection.
  List<ProfileUsage> incompatibleUsagesFor(String? systemId) {
    final newSystem = systemId == null ? null : _catalog.systemById(systemId);
    return incompatibleUsages(_draft.profileUsages, newSystem);
  }

  /// Applies a manufacturer/system selection made in the picker.
  ///
  /// [manufacturerId]/[systemId] are the new authoritative ids (may be
  /// `null`). [manufacturerName]/[systemName] are the display-name
  /// fallbacks stored alongside them. Usages incompatible with the new
  /// system (see [incompatibleUsagesFor], which the screen uses to ask for
  /// confirmation BEFORE calling this) are removed as part of the same
  /// atomic change.
  void applyManufacturerSystem({
    required String manufacturerName,
    required String systemName,
    String? manufacturerId,
    String? systemId,
  }) {
    final newSystem = systemId == null ? null : _catalog.systemById(systemId);
    final incompatible = incompatibleUsages(_draft.profileUsages, newSystem);

    _updateDraft(
      _draft.copyWith(
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
      ),
      tag: kUndoTagSystem,
      invalidatesCalculation: true,
    );
  }

  /// Replaces the catalog snapshot (after the screen loads it from disk,
  /// or after the picker created/deleted entries and persisted them).
  ///
  /// The catalog can change calculation inputs WITHOUT touching the draft
  /// -- e.g. a referenced profile edited or deleted in the profiles panel.
  /// Staleness is therefore reconciled here exactly as after an undo/redo
  /// jump: a recorded outcome whose catalog fingerprint no longer matches
  /// is flagged stale (and one whose state was restored to equivalence is
  /// legitimately un-staled). Before the first [calculate] this is inert --
  /// there is no recorded outcome to reconcile.
  void setCatalog(Catalog catalog) {
    _catalog = catalog;
    _reconcileCalculationStaleness();
    notifyListeners();
  }

  // ---- Section-level property edits ----

  void applySectionWidth(Section section, String value) {
    final parsed = _parseDimensionMm(value);
    if (parsed == null || parsed <= 0) return;
    _replaceSection(
      _withSectionFields(section, width: parsed),
      tag: 'section.width:${section.id}',
    );
  }

  void applySectionHeight(Section section, String value) {
    final parsed = _parseDimensionMm(value);
    if (parsed == null || parsed <= 0) return;
    _replaceSection(
      _withSectionFields(section, height: parsed),
      tag: 'section.height:${section.id}',
    );
  }

  void applySectionKind(Section section, SectionKind kind) {
    if (kind == SectionKind.fixed) {
      _replaceSection(
        Section(
          id: section.id,
          order: section.order,
          kind: SectionKind.fixed,
          width: section.width,
          height: section.height,
        ),
        tag: 'section.kind:${section.id}',
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
        tag: 'section.kind:${section.id}',
      );
    }
  }

  void applySectionOpeningType(Section section, OpeningType type) {
    _replaceSection(
      _withSectionFields(section, openingType: type),
      tag: 'section.openingType:${section.id}',
    );
  }

  void applySectionVantauxCount(Section section, int count) {
    if (count < 1) return;
    _replaceSection(
      _withSectionFields(section, vantauxCount: count),
      tag: 'section.vantauxCount:${section.id}',
    );
  }

  /// Replaces exactly the section with [updated]'s id, keeping every other
  /// section untouched. [tag] scopes undo coalescing to this
  /// section+field pair so consecutive edits of the same field on the same
  /// section merge into one history entry.
  void _replaceSection(Section updated, {required String tag}) {
    _updateDraft(
      _draft.copyWith(
        sections: [
          for (final s in _draft.sections)
            if (s.id == updated.id) updated else s,
        ],
      ),
      tag: tag,
      invalidatesCalculation: true,
    );
  }

  /// Builds a new [Section] carrying [section]'s identity/order/kind with
  /// the given fields overridden, keeping the fixed-vs-ouvrant field
  /// invariants enforced (fixed sections carry no opening type and zero
  /// vantaux regardless of what was passed in).
  Section _withSectionFields(
    Section section, {
    double? width,
    double? height,
    OpeningType? openingType,
    int? vantauxCount,
  }) {
    return Section(
      id: section.id,
      order: section.order,
      kind: section.kind,
      width: width ?? section.width,
      height: height ?? section.height,
      openingType: section.kind == SectionKind.ouvrant
          ? (openingType ?? section.openingType)
          : null,
      vantauxCount: section.kind == SectionKind.ouvrant
          ? (vantauxCount ?? section.vantauxCount)
          : 0,
    );
  }

  // ---- Profile assignment (ProfileUsage) ----

  /// Adds a new [ProfileUsage] for [profileId] on [sectionId] with [role],
  /// quantity defaulting to `1`. [profileId] is expected to already belong
  /// to the currently resolved system -- callers (the assignment UI) only
  /// ever offer profiles from `resolvedSystem.profiles`, so this does not
  /// re-check compatibility itself.
  void addProfileUsage({
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
    _updateDraft(
      _draft.copyWith(profileUsages: [..._draft.profileUsages, usage]),
      // Unique per usage: consecutive adds must stay individually
      // undoable, never coalesce.
      tag: 'usage.add:${usage.id}',
      invalidatesCalculation: true,
    );
  }

  void updateProfileUsageQuantity(ProfileUsage usage, int quantity) {
    if (quantity < 1) return;
    _updateDraft(
      _draft.copyWith(
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
      ),
      // Same usage+field: the +/- spinner clicks coalesce into one entry.
      tag: 'usage.quantity:${usage.id}',
      invalidatesCalculation: true,
    );
  }

  void removeProfileUsage(ProfileUsage usage) {
    _updateDraft(
      _draft.copyWith(
        profileUsages: _draft.profileUsages
            .where((u) => u.id != usage.id)
            .toList(),
      ),
      tag: 'usage.remove:${usage.id}',
      invalidatesCalculation: true,
    );
  }

  // ---- Section add/remove ----

  /// Appends a dialog-created [section] to the draft, selects it, jumps to
  /// the Sections stage, and marks any calculation outcome stale -- a newly
  /// added section is only useful to look at alongside the Sections
  /// stage's properties.
  void addSection(Section section) {
    _updateDraft(
      _draft.copyWith(sections: [..._draft.sections, section]),
      // Unique per section: each add is individually undoable.
      tag: 'section.add:${section.id}',
      invalidatesCalculation: true,
    );
    _selectedSectionId = section.id;
    _stage = EditorStage.sections;
  }

  /// Removes the currently selected section and renumbers the remaining
  /// sections' orders 0..n-1 so no gap is left behind. Clearing the
  /// selection keeps the current stage -- with nothing selected, the
  /// Sections panel prompts the user to pick or add a section rather than
  /// silently jumping back to General. Does nothing (and notifies nobody)
  /// when the construction root is selected.
  void removeSelectedSection() {
    final target = selectedSection;
    if (target == null) return; // Cannot delete the construction root here.

    final remaining = _draft.sections.where((s) => s.id != target.id).toList();
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

    _updateDraft(
      _draft.copyWith(sections: reordered),
      tag: 'section.remove:${target.id}',
      invalidatesCalculation: true,
    );
    _selectedSectionId = null;
  }

  /// Moves the interior boundary after [boundaryIndex] (ordered-section
  /// convention, 1..sectionCount-1) to [positionMm] along the layout axis,
  /// redistributing exactly the two adjacent sections. See
  /// `withBoundaryMoved` for the geometry invariants: total preserved,
  /// neighbors floored at [kMinSectionSizeMm], all other fields untouched.
  ///
  /// Called ONCE per completed drag gesture -- never per pointer-move
  /// event -- so one drag produces exactly one undo entry. The tag is
  /// deliberately null: consecutive drags of the same boundary are
  /// distinct user operations and must stay individually undoable rather
  /// than coalesce.
  void moveBoundary({required int boundaryIndex, required double positionMm}) {
    _updateDraft(
      withBoundaryMoved(_draft, boundaryIndex, positionMm),
      tag: null,
      invalidatesCalculation: true,
    );
  }

  // ---- Calculation ----

  /// Runs `calculateConstructionCuts(draft, catalog)` and records the
  /// outcome.
  ///
  /// A `null` result from `calculateConstructionCuts` (unresolved
  /// system/rule set) is recorded via [calculationHadNoRuleSet] rather than
  /// folded into an empty result list, so callers can tell "no rule set
  /// available for this system yet" apart from "rule set resolved, zero
  /// cuts produced". `StateError` (missing construction dimensions) and
  /// `AmbiguousRuleMatchException` (genuine rule ambiguity) are both caught
  /// here rather than crashing; either becomes [calculationError]. No other
  /// exception type is caught -- anything else is a real bug and should
  /// still surface as one.
  void calculate() {
    // Snapshot the calculator-relevant inputs -- draft AND catalog -- so
    // undo/redo jumps and catalog replacements can decide precisely
    // whether this outcome still applies (see
    // _reconcileCalculationStaleness).
    _calculationInputFingerprint = _calculatorInputFingerprint(_draft);
    _catalogInputFingerprint = catalogCalculationFingerprint(_catalog, _draft);
    try {
      final outcome = calculateConstructionCuts(_draft, _catalog);
      _calculationResult = outcome;
      _calculationError = null;
      _calculationHadNoRuleSet = outcome == null;
      _calculationIsStale = false;
    } on AmbiguousRuleMatchException catch (e) {
      _calculationResult = null;
      _calculationError = e;
      _calculationHadNoRuleSet = false;
      _calculationIsStale = false;
    } on StateError catch (e) {
      _calculationResult = null;
      _calculationError = e;
      _calculationHadNoRuleSet = false;
      _calculationIsStale = false;
    }
    notifyListeners();
  }

  /// Marks the current calculation outcome as stale. Deliberately does NOT
  /// clear the recorded result/error/no-rule-set flags -- the last outcome
  /// is kept and flagged rather than discarded, so going out of date is
  /// visible. Called from inside mutating methods, which perform the
  /// notification themselves.
  void _markCalculationStale() {
    _calculationIsStale = true;
  }

  // ---- Save hand-off ----

  /// Records the current draft as the new saved baseline. This is the only
  /// method that advances the baseline -- ordinary field edits never touch
  /// it. Actually handing the draft to the caller (and through that, to
  /// disk) remains the screen's job via `ConstructionEditorResult.saved`.
  void commitSave() {
    _lastSaved = _draft;
    notifyListeners();
  }
}
