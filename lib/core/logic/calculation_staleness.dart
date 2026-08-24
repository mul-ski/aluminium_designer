import '../models/catalog.dart';
import '../models/construction.dart';
import '../models/profile_system.dart';

/// Fingerprint of the catalog state `ConstructionCalculator` consumes for
/// [construction] -- the catalog-side counterpart of the controller's
/// draft-input fingerprint, so a recorded calculation outcome can be
/// recognised as stale when CATALOG data changes mid-session (e.g. a
/// referenced profile is edited or deleted through the manufacturer/system
/// picker while the editor holds a fresh-looking result).
///
/// Covered -- exactly what the calculator reads from the catalog:
///   - the resolved system's `ruleSetId` (which rule set evaluates);
///   - which referenced profiles RESOLVE (`id` present in the system);
///   - each referenced profile's `type` (drives rule matching via
///     `ProfileCalculationRule.appliesTo`) and `weightPerMeter`
///     (drives the derived weight in calculation totals).
///
/// Deliberately NOT covered:
///   - profile `name`/`reference`: display-only labels copied onto cuts;
///     renaming never changes a computed number. This mirrors the
///     draft-side precedent that renaming the construction does not
///     invalidate its cut list.
///   - profile `width`/`depth`/`inertiaIxxCm4`/`inertiaIyyCm4`: not
///     consumed by any calculation or aggregation path today (no
///     DimensionVariable/NumericField reads them); inertia is display/
///     analysis data. If a verified rule ever starts consuming one of
///     these fields, that field must join the fingerprint at the same
///     time as the rule lands.
///   - unreferenced profiles: other systems' data cannot affect this
///     construction's cuts; scoping keeps unrelated catalog edits from
///     churning results.
///   - manufacturers list, `supportedOpenings`, `isBuiltIn`, system names.
///
/// Determinism: referenced-profile entries are sorted lexically, so
/// reordering a system's profile list (not semantically meaningful to the
/// engine) produces the same fingerprint. An unresolved system -- none
/// selected, deleted from the catalog -- yields the stable sentinel
/// `'no-system'` rather than depending on how the lookup fails.
///
/// Rule-set CONTENT is compile-time constant today (the built-in registry
/// has no user-authored entries and `ruleSetId` is not user-editable), so
/// identity suffices. If user-authored rule sets ever land, this function
/// is where their content hash joins the fingerprint.
String catalogCalculationFingerprint(
  Catalog catalog,
  Construction construction,
) {
  final ProfileSystem? system = catalog.systemById(construction.systemId);
  if (system == null) return 'no-system';

  final referencedIds = construction.profileUsages
      .map((usage) => usage.profileId)
      .toSet();
  final entries = <String>[
    for (final profile in system.profiles)
      if (referencedIds.contains(profile.id))
        '${profile.id}:${profile.type}:${profile.weightPerMeter}',
  ]..sort();

  return '${system.ruleSetId}|${entries.join(';')}';
}
