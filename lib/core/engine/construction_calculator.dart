import '../models/calculation_outcome.dart';
import '../models/construction.dart';
import '../models/cut.dart';
import '../models/profile.dart';
import '../models/profile_usage.dart';
import '../models/rules/dimension_expression.dart';
import '../models/rules/generic_placeholder_rules.dart';
import '../models/rules/rule_condition.dart';
import '../models/rules/system_rule_set.dart';
import '../models/section.dart';

/// Computes the [CalculationOutcome] -- matched cuts plus per-usage skip
/// diagnostics -- for a [Construction] by evaluating a data-driven
/// [SystemRuleSet] against that construction's dimensions.
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

  /// Produces a [CalculationOutcome] covering every [ProfileUsage] in
  /// [construction], via
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
  /// A usage whose `profileId` is not found in [profilesById] produces no
  /// cut and a `ProfileUsageIssueReason.profileUnresolved` issue, instead
  /// of throwing or inventing data -- e.g. the profile was deleted from
  /// the catalog after the usage was created (see `incompatibleUsages`
  /// in `system_compatibility.dart`, which tracks this same "usage without
  /// a valid Profile" state elsewhere). Likewise a usage whose `sectionId`
  /// doesn't resolve to a current `Section` still gets a context (with
  /// `section: null`) rather than being skipped -- section-scoped
  /// conditions simply won't match, same as any other missing-section
  /// context. Issues are diagnostics, not failures: every skipped usage is
  /// reported through the outcome so "fewer cuts than usages" is always
  /// explainable.
  ///
  /// For each resolved usage, builds a [CalculationContext] carrying both
  /// the owning [Section] (if resolvable) and the [ProfileUsage] itself,
  /// and asks [ruleSet] to [SystemRuleSet.select] the single applicable
  /// rule. If no rule matches, the usage produces no cut and a
  /// `ProfileUsageIssueReason.noRuleMatched` issue -- same no-op-for-the-
  /// cut-list behaviour as before, now visible instead of silent. If more
  /// than one rule matches with equal specificity,
  /// [AmbiguousRuleMatchException] propagates out of this call rather
  /// than being silently resolved or downgraded to an issue --
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
  ///
  /// Every emitted [ProfileCut] carries `profileUsageId`/`sectionId`
  /// copied directly from the [ProfileUsage] it was produced for -- see
  /// `ProfileCut`'s doc comment. This is a straight pass-through of ids
  /// already available in this loop, not a lookup or inference; a
  /// caller that needs to group cuts by section does so itself (e.g. by
  /// `sectionId`) rather than this method returning a pre-grouped
  /// structure -- grouping is a display concern, not something the
  /// calculator needs an opinion about.
  ///
  /// Cut quantity composition: `ProfileUsage.quantity × rule.quantity`
  /// (`CutQuantity.fixedCount`). The usage says how many identical pieces
  /// the user placed at that spot; the rule says how many pieces one
  /// matched placement yields; the product is the physical piece count on
  /// the cut. Both factors are user/rule data already present -- nothing
  /// here invents a count.
  CalculationOutcome calculate(
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
    final issues = <ProfileUsageIssue>[];

    for (final usage in construction.profileUsages) {
      final profile = profilesById[usage.profileId];
      if (profile == null) {
        // Usage references a profile that isn't resolvable from the
        // current catalog (e.g. deleted) -- no cut, and the skip is
        // reported rather than silent.
        issues.add(
          ProfileUsageIssue(
            profileUsageId: usage.id,
            reason: ProfileUsageIssueReason.profileUnresolved,
          ),
        );
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
        // No rule in the set matches this context -- no cut, and the
        // skip is reported rather than silent.
        issues.add(
          ProfileUsageIssue(
            profileUsageId: usage.id,
            reason: ProfileUsageIssueReason.noRuleMatched,
          ),
        );
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
          // The placement's own count times what the matched rule yields
          // per placement -- see the quantity-composition note in this
          // method's doc comment. This is what makes the assignment UI's
          // quantity spinner actually reach the calculation output.
          quantity: rule.quantity.fixedCount * usage.quantity,
          angleStart: rule.angles.start,
          angleEnd: rule.angles.end,
          profileUsageId: usage.id,
          sectionId: usage.sectionId,
          // Cut-level provenance: which rule produced this piece (null
          // when the rule has no description -- never invented).
          ruleDescription: rule.description,
        ),
      );
    }

    return CalculationOutcome(cuts: cuts, issues: issues);
  }
}
