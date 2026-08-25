library;

import '../data/builtin_catalog_seed.dart';
import '../data/me_14600_rule_set.dart';
import '../data/sep_4200_rule_set.dart';
import '../engine/construction_calculator.dart';
import '../models/calculation_outcome.dart';
import '../models/catalog.dart';
import '../models/construction.dart';
import '../models/profile.dart';
import '../models/profile_system.dart';
import '../models/rules/generic_placeholder_rules.dart';
import '../models/rules/system_rule_set.dart';

/// The registered [SystemRuleSet]s, keyed by the id a [ProfileSystem]
/// references via `ProfileSystem.ruleSetId`.
///
/// This is the missing bridge documented on `ProfileSystem.ruleSetId`:
/// "linked by this id so `ConstructionCalculator` can find the right
/// rules for a given system".
///
/// Three entries today:
///
/// - `generic-placeholder` -- the honest "no real per-manufacturer
///   calculation data" fallback, still referenced by any system without
///   verified rules.
/// - `builtin-me-14600` -- Maghreb Extrusion Série 14600: the COMPLETE
///   débitage table (all three configuration columns; see
///   docs/VERIFIED_SOURCES.md S-1).
/// - `builtin-sepalumic-4200` -- Sepalumic Série 4200: the Châssis fixe
///   + OF (à la française) 1/2 vantaux débitage families (éd. 05;
///   docs/VERIFIED_SOURCES.md M-2). OB/Soufflet/Projeté/Porte/Composé
///   families stay unencoded with documented blockers.
///
/// A `Map` rather than a class with fields, matching how all rule sets
/// are plain top-level `const`s rather than something wrapped in a
/// registry class -- no state, nothing to instantiate, just a lookup
/// table. Add an entry only for a real, sourced `SystemRuleSet`; do not
/// add placeholder entries speculatively.
const Map<String, SystemRuleSet> builtInRuleSets = {
  'generic-placeholder': genericPlaceholderRuleSet,
  meSerie14600Id: meSerie14600RuleSet,
  sepSerie4200Id: sepSerie4200RuleSet,
};

/// Resolves [ruleSetId] to its [SystemRuleSet], or `null` if it doesn't
/// match any registered rule set.
///
/// `null` covers both "no id" (an empty/blank `ruleSetId`, which should
/// not happen given the field is required, but this function does not
/// assume the caller validated that) and "id doesn't match anything
/// registered" (e.g. a `ProfileSystem` saved before a since-removed rule
/// set existed, or a typo). Returning `null` rather than throwing or
/// silently substituting [genericPlaceholderRuleSet] matches the existing
/// "unresolved -> nothing usable, not a guess" precedent in
/// `system_compatibility.dart`'s `compatibleProfileIds` -- a caller (e.g.
/// `ConstructionCalculator`, once wired to call this) must decide for
/// itself what "no rule set found" means for calculation, rather than this
/// function silently picking a default on its behalf.
SystemRuleSet? resolveRuleSetById(String ruleSetId) {
  return builtInRuleSets[ruleSetId];
}

/// Resolves the [SystemRuleSet] for [system]'s `ruleSetId`, or `null` if
/// [system] itself is unresolved (mirrors `compatibleProfileIds`'
/// `ProfileSystem?` handling) or its `ruleSetId` doesn't match anything
/// registered.
///
/// Convenience wrapper over [resolveRuleSetById] for the common case of
/// already having a `ProfileSystem?` in hand (e.g. resolved from
/// `Catalog.profileSystems` via a `Construction.systemId`) rather than a
/// bare id string.
SystemRuleSet? resolveRuleSetForSystem(ProfileSystem? system) {
  if (system == null) return null;
  return resolveRuleSetById(system.ruleSetId);
}

/// Resolves the full chain from [construction] to its [SystemRuleSet]:
/// `Construction.systemId` -> `Catalog.systemById` -> `ProfileSystem` ->
/// `ProfileSystem.ruleSetId` -> [resolveRuleSetById] -> `SystemRuleSet`.
///
/// Returns `null` if any link in that chain doesn't resolve -- no system
/// selected yet, the selected system was deleted from [catalog], or the
/// system's `ruleSetId` doesn't match anything in [builtInRuleSets]. Every
/// one of those is a distinct real-world state, but all of them mean the
/// same thing to a caller trying to calculate: there is no usable rule
/// set right now. This function does not throw and does not fall back to
/// [genericPlaceholderRuleSet] -- per the same "unresolved -> nothing
/// usable, not a guess" precedent as [resolveRuleSetForSystem] and
/// `system_compatibility.dart`'s `compatibleProfileIds`. A caller that
/// wants to actually calculate must check for `null` and decide what to
/// show the user (e.g. "no calculation rules available for this system
/// yet") rather than silently producing placeholder cuts for a
/// construction the user never chose the placeholder system for.
///
/// This is the one place `Construction`/`Catalog` (application-layer
/// models) meet the rule engine's resolution logic -- `Catalog` is
/// intentionally not imported by `rule_set_resolution.dart`'s other
/// functions, and `ConstructionCalculator` itself still takes a
/// `SystemRuleSet` directly and knows nothing about `Catalog` at all; see
/// `construction_calculator.dart`'s class doc for why it stays
/// catalog-agnostic.
SystemRuleSet? resolveRuleSetForConstruction(
  Construction construction,
  Catalog catalog,
) {
  final system = catalog.systemById(construction.systemId);
  return resolveRuleSetForSystem(system);
}

/// Calculates [construction]'s [CalculationOutcome] by resolving its
/// `SystemRuleSet` and profile catalogue from [catalog] and running
/// `ConstructionCalculator.calculate` -- the full application-layer
/// pipeline described in this file's module doc, made directly callable
/// with just a `Construction` and a `Catalog` rather than requiring the
/// caller to manually resolve the system, rule set, and profile map
/// itself first.
///
/// Returns `null` if [resolveRuleSetForConstruction] can't resolve a rule
/// set (no system selected, system deleted from the catalog, or its
/// `ruleSetId` doesn't match anything registered) -- same "unresolved ->
/// nothing usable, not a guess" behaviour as the rest of this file. This
/// does NOT fall back to [genericPlaceholderRuleSet]; a caller wanting
/// that behaviour must ask for it explicitly by resolving the rule set
/// itself and constructing a `ConstructionCalculator` directly, the same
/// way `ConstructionCalculator`'s own default constructor argument
/// already allows.
///
/// `ConstructionCalculator` itself is still constructed fresh here with
/// no stored state and no `Catalog` reference of its own -- this function
/// is where `Catalog`/`Construction` (application-layer concerns) meet
/// the calculator, not a change to the calculator's own catalog-agnostic
/// design (see `construction_calculator.dart`'s class doc).
///
/// `ConstructionCalculator.calculate` can still throw `StateError` if
/// [construction] doesn't have both overall dimensions set, or propagate
/// `AmbiguousRuleMatchException` from rule selection -- this function
/// does not catch either; see `ConstructionCalculator.calculate`'s doc
/// for both. A non-null outcome carries cuts plus per-usage skip issues;
/// per-usage skips are diagnostics on the outcome, distinct from this
/// null "no rule set at all" case.
CalculationOutcome? calculateConstructionCuts(
  Construction construction,
  Catalog catalog,
) {
  final ruleSet = resolveRuleSetForConstruction(construction, catalog);
  if (ruleSet == null) return null;

  final system = catalog.systemById(construction.systemId);
  final profilesById = system?.profilesById ?? const <String, Profile>{};

  return ConstructionCalculator(
    ruleSet: ruleSet,
  ).calculate(construction, profilesById: profilesById);
}
