library;

import '../models/profile_system.dart';
import '../models/rules/generic_placeholder_rules.dart';
import '../models/rules/system_rule_set.dart';

/// The registered [SystemRuleSet]s, keyed by the id a [ProfileSystem]
/// references via `ProfileSystem.ruleSetId`.
///
/// This is the missing bridge documented on `ProfileSystem.ruleSetId`:
/// "linked by this id so `ConstructionCalculator` can find the right
/// rules for a given system". Before this file, that link was written
/// everywhere (every built-in seeded `ProfileSystem` sets
/// `ruleSetId: 'generic-placeholder'`) but never read anywhere --
/// `ConstructionCalculator` was only ever constructed directly in tests,
/// with an explicit `ruleSet:` argument, never resolved from a
/// `ProfileSystem`.
///
/// Deliberately just one entry today: `genericPlaceholderRuleSet` is the
/// only `SystemRuleSet` that exists in the codebase (confirmed by
/// inspection -- grep for `SystemRuleSet(` finds exactly one concrete
/// instance). Every built-in `ProfileSystem` seeded so far points at it,
/// which is an honest "no real per-manufacturer calculation rules exist
/// yet" state, not a bug -- see `builtin_catalog_seed.dart`'s comments on
/// `ruleSetId`. Add a new entry here only when a real `SystemRuleSet` is
/// built for a specific manufacturer/system; do not add placeholder
/// entries speculatively.
///
/// A `Map` rather than a class with fields, matching how
/// `genericPlaceholderRuleSet` itself is a plain top-level `const` rather
/// than something wrapped in a registry class -- no state, nothing to
/// instantiate, just a lookup table.
const Map<String, SystemRuleSet> builtInRuleSets = {
  'generic-placeholder': genericPlaceholderRuleSet,
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
