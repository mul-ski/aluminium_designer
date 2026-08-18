import '../models/construction.dart';
import '../models/cut.dart';
import '../models/profile.dart';
import '../models/profile_usage.dart';
import '../models/rules/dimension_expression.dart';
import '../models/rules/generic_placeholder_rules.dart';
import '../models/rules/rule_condition.dart';
import '../models/rules/system_rule_set.dart';
import '../models/section.dart';

/// Computes the list of [ProfileCut]s for a [Construction] by evaluating a
/// data-driven [SystemRuleSet] against that construction's dimensions.
///
/// This replaces the old hardcoded switch-statement logic. Behaviour is now
/// entirely determined by which `SystemRuleSet` is supplied -- pass
/// [genericPlaceholderRuleSet] (the default) to get the same placeholder
/// behaviour as before, or a real manufacturer rule set once one exists.
class ConstructionCalculator {
  /// The rule set this calculator evaluates against. Defaults to the
  /// built-in generic placeholder rules if none is supplied.
  final SystemRuleSet ruleSet;

  const ConstructionCalculator({this.ruleSet = genericPlaceholderRuleSet});

  /// Produces cut pieces for every [ProfileUsage] in [construction], via
  /// the current profile path: `Construction.profileUsages` -> resolved
  /// `Profile` (via [profilesById]) -> role-aware [CalculationContext] ->
  /// [SystemRuleSet.select]. See `Construction`'s "PROFILE PATH" doc
  /// comment for why `profileUsages` (not the legacy flat
  /// `Construction.profiles` list) is the correct source to iterate now
  /// that usages carry section + role.
  ///
  /// [profilesById] resolves a [ProfileUsage.profileId] to its catalogue
  /// [Profile] definition (e.g. built from the selected `ProfileSystem`'s
  /// `profiles` list). This calculator stays catalog-agnostic -- it takes
  /// already-resolved profiles as input rather than depending on
  /// `Catalog`/`ProfileSystem` directly, consistent with the rule engine
  /// already being pure, data-driven, and independent of storage.
  ///
  /// A usage whose `profileId` is not found in [profilesById] is skipped
  /// explicitly rather than throwing or inventing data -- e.g. the
  /// profile was deleted from the catalog after the usage was created
  /// (see `incompatibleUsages` in `system_compatibility.dart`, which
  /// tracks this same "usage without a valid Profile" state elsewhere).
  /// Likewise a usage whose `sectionId` doesn't resolve to a current
  /// `Section` still gets a context (with `section: null`) rather than
  /// being skipped -- section-scoped conditions simply won't match, same
  /// as any other missing-section context.
  ///
  /// For each resolved usage, builds a [CalculationContext] carrying both
  /// the owning [Section] (if resolvable) and the [ProfileUsage] itself,
  /// and asks [ruleSet] to [SystemRuleSet.select] the single applicable
  /// rule. If no rule matches, the usage is skipped -- same no-op
  /// behaviour as the previous profile-list-based version (previously
  /// `default: break;`, now "no rule matched"). If more than one rule
  /// matches with equal specificity, [AmbiguousRuleMatchException]
  /// propagates out of this call rather than being silently resolved --
  /// see `SystemRuleSet.select` for the selection/tie-breaking rules.
  ///
  /// Throws [StateError] if [construction] doesn't have both overall
  /// dimensions set yet. `Construction.width`/`height` are nullable to
  /// represent a construction the editor is still building (see
  /// `Construction`'s doc comment) -- calculation is a later stage than
  /// editing and has no meaningful way to compute cut lengths without both
  /// dimensions, so this fails loudly rather than silently treating a
  /// missing dimension as zero.
  ///
  /// `DimensionVariable.openingWidth`/`openingHeight` (available to a
  /// rule's `lengthExpression`) are sourced from the usage's resolved
  /// `Section.width`/`height` -- the section is the real per-piece
  /// geometry owner (see `Section`'s doc comment); the standalone
  /// `Opening` model is unused elsewhere in the codebase and is not read
  /// here. These two variables are only populated when the usage's
  /// `sectionId` resolves to a current `Section`; if it doesn't (e.g. a
  /// stale/deleted section) and a rule still references one of them,
  /// `DimensionExpression.evaluate` throws `StateError` for the missing
  /// variable -- same behaviour as referencing any other unavailable
  /// variable, not a silent fallback to 0 or to the construction's
  /// overall dimensions.
  List<ProfileCut> calculate(
    Construction construction, {
    Map<String, Profile> profilesById = const {},
  }) {
    final width = construction.width;
    final height = construction.height;
    if (width == null || height == null) {
      throw StateError(
        'Cannot calculate cuts for construction ${construction.id}: '
        'width/height not set yet.',
      );
    }

    final sectionsById = <String, Section>{
      for (final section in construction.sections) section.id: section,
    };

    final cuts = <ProfileCut>[];

    for (final usage in construction.profileUsages) {
      final profile = profilesById[usage.profileId];
      if (profile == null) {
        // Usage references a profile that isn't resolvable from the
        // current catalog (e.g. deleted) -- skip rather than guess.
        continue;
      }

      final section = sectionsById[usage.sectionId];
      final context = CalculationContext(
        construction: construction,
        profile: profile,
        section: section,
        usage: usage,
      );

      final rule = ruleSet.select(context);
      if (rule == null) {
        continue;
      }

      // Per-usage variables: construction-level width/height are always
      // known (checked above), but openingWidth/openingHeight are only
      // meaningful when this usage's section actually resolved -- a
      // Section is the real geometry owner for an individual piece (see
      // `Section.width`/`height`; the standalone `Opening` class is
      // unused dead model and intentionally not read here). If a rule
      // references openingWidth/openingHeight and the section didn't
      // resolve, DimensionExpression.evaluate throws StateError for the
      // missing variable -- same fail-loudly behaviour as any other
      // missing variable, not a silent 0.
      final variables = <DimensionVariable, double>{
        DimensionVariable.constructionWidth: width,
        DimensionVariable.constructionHeight: height,
        if (section != null) ...{
          DimensionVariable.openingWidth: section.width,
          DimensionVariable.openingHeight: section.height,
        },
      };

      final length = rule.lengthExpression.evaluate(variables);

      cuts.add(
        ProfileCut(
          profile: profile,
          length: length,
          quantity: rule.quantity.fixedCount,
          angleStart: rule.angles.start,
          angleEnd: rule.angles.end,
        ),
      );
    }

    return cuts;
  }
}
