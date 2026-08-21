import 'package:flutter/foundation.dart';

import '../../../core/logic/rule_set_resolution.dart';
import '../../../core/logic/system_compatibility.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/construction.dart';
import '../../../core/models/construction_type.dart';
import '../../../core/models/cut.dart';
import '../../../core/models/layout_direction.dart';
import '../../../core/models/opening.dart';
import '../../../core/models/profile_system.dart';
import '../../../core/models/profile_usage.dart';
import '../../../core/models/project_json.dart' show ConstructionJson;
import '../../../core/models/rules/system_rule_set.dart'
    show AmbiguousRuleMatchException;
import '../../../core/models/section.dart';
import 'editor_stage.dart';

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

  // ---- Last calculation outcome ----

  /// Result of the last [calculate] run, or `null` if calculation hasn't
  /// been run yet, or `calculateConstructionCuts` itself returned `null`
  /// (no rule set could be resolved). An empty (but non-null) list is a
  /// meaningful, distinct result: the rule set resolved fine, there was
  /// just nothing to cut (e.g. no profile usages assigned yet). Not part
  /// of the draft -- it's a derived view, not saved data, so it must never
  /// affect [isDirty]/`toJson()` comparison or [commitSave].
  List<ProfileCut>? _calculationResult;

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

  List<ProfileCut>? get calculationResult => _calculationResult;

  Object? get calculationError => _calculationError;

  bool get calculationHadNoRuleSet => _calculationHadNoRuleSet;

  bool get calculationIsStale => _calculationIsStale;

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
    _draft = _draft.copyWith(name: value);
    notifyListeners();
  }

  void setType(ConstructionType type) {
    _draft = _draft.copyWith(type: type);
    _markCalculationStale();
    notifyListeners();
  }

  /// Applies a typed width. An empty/unparseable field means "not set yet".
  ///
  /// DEBT PRESERVED DELIBERATELY: `copyWith` cannot express clearing
  /// `width` back to `null` (its null means "leave unchanged"), which is
  /// why the draft is rebuilt directly here instead of via copyWith. The
  /// historical rebuild also omitted `manufacturerId`/`systemId`, silently
  /// resetting both ids to null while keeping the display-name strings --
  /// that quirk is reproduced verbatim here because this refactor must be
  /// behaviour-preserving; fixing it is a separate, deliberate decision.
  void setWidth(String value) {
    final parsed = double.tryParse(value);
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
    _markCalculationStale();
    notifyListeners();
  }

  /// Applies a typed height. See [setWidth] for the preserved rebuild debt.
  void setHeight(String value) {
    final parsed = double.tryParse(value);
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
    _markCalculationStale();
    notifyListeners();
  }

  void setLayoutDirection(SectionLayoutDirection direction) {
    // Layout direction affects rendering and validation, not the rule-set
    // inputs the calculator reads, so the calculation outcome is not
    // marked stale here -- matching the original mutator.
    _draft = _draft.copyWith(layoutDirection: direction);
    notifyListeners();
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
    _markCalculationStale();
    notifyListeners();
  }

  /// Replaces the catalog snapshot (after the screen loads it from disk,
  /// or after the picker created/deleted entries and persisted them).
  void setCatalog(Catalog catalog) {
    _catalog = catalog;
    notifyListeners();
  }

  // ---- Section-level property edits ----

  void applySectionWidth(Section section, String value) {
    final parsed = double.tryParse(value);
    if (parsed == null || parsed <= 0) return;
    _replaceSection(_withSectionFields(section, width: parsed));
  }

  void applySectionHeight(Section section, String value) {
    final parsed = double.tryParse(value);
    if (parsed == null || parsed <= 0) return;
    _replaceSection(_withSectionFields(section, height: parsed));
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

  void applySectionOpeningType(Section section, OpeningType type) {
    _replaceSection(_withSectionFields(section, openingType: type));
  }

  void applySectionVantauxCount(Section section, int count) {
    if (count < 1) return;
    _replaceSection(_withSectionFields(section, vantauxCount: count));
  }

  /// Replaces exactly the section with [updated]'s id, keeping every other
  /// section untouched.
  void _replaceSection(Section updated) {
    _draft = _draft.copyWith(
      sections: [
        for (final s in _draft.sections)
          if (s.id == updated.id) updated else s,
      ],
    );
    _markCalculationStale();
    notifyListeners();
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
    _draft = _draft.copyWith(profileUsages: [..._draft.profileUsages, usage]);
    _markCalculationStale();
    notifyListeners();
  }

  void updateProfileUsageQuantity(ProfileUsage usage, int quantity) {
    if (quantity < 1) return;
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
    _markCalculationStale();
    notifyListeners();
  }

  void removeProfileUsage(ProfileUsage usage) {
    _draft = _draft.copyWith(
      profileUsages: _draft.profileUsages
          .where((u) => u.id != usage.id)
          .toList(),
    );
    _markCalculationStale();
    notifyListeners();
  }

  // ---- Section add/remove ----

  /// Appends a dialog-created [section] to the draft, selects it, jumps to
  /// the Sections stage, and marks any calculation outcome stale -- a newly
  /// added section is only useful to look at alongside the Sections
  /// stage's properties.
  void addSection(Section section) {
    _draft = _draft.copyWith(sections: [..._draft.sections, section]);
    _selectedSectionId = section.id;
    _stage = EditorStage.sections;
    _markCalculationStale();
    notifyListeners();
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

    _draft = _draft.copyWith(sections: reordered);
    _selectedSectionId = null;
    _markCalculationStale();
    notifyListeners();
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
    try {
      final cuts = calculateConstructionCuts(_draft, _catalog);
      _calculationResult = cuts;
      _calculationError = null;
      _calculationHadNoRuleSet = cuts == null;
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
