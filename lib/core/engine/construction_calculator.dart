import '../models/calculation_outcome.dart';
import '../models/construction.dart';
import '../models/cut.dart';
import '../models/glass_item.dart';
import '../models/hardware_item.dart';
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
  /// Each context also carries the evaluated usage's section siblings --
  /// every OTHER successfully-resolved usage sharing its `sectionId`, as
  /// [SectionSibling] pairs (see [CalculationContext.siblings]). This is
  /// derived once per calculation from the construction's usages plus
  /// [profilesById]; nothing new is read from storage and nothing
  /// persists. Companion-profile conditions
  /// ([CompanionProfileReferenceCondition]) quantify over this list; every
  /// other condition ignores it. Usages whose profile fails to resolve are
  /// omitted from sibling lists -- they carry no reference to match on,
  /// and their own `profileUnresolved` issue already reports them in this
  /// same outcome.
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

    // Companion view: resolved usages grouped by section, giving each
    // CalculationContext its section siblings (see [SectionSibling]).
    // Derived once per calculation from data already in hand -- the
    // construction's usages plus [profilesById]; nothing new is read from
    // storage and nothing persists. Unresolvable usages are omitted: they
    // carry no reference to match on, and their own `profileUnresolved`
    // issue is reported in the loop below.
    final siblingsBySectionId = <String, List<SectionSibling>>{};
    for (final u in construction.profileUsages) {
      final p = profilesById[u.profileId];
      if (p == null) continue;
      (siblingsBySectionId[u.sectionId] ??= []).add(
        SectionSibling(usage: u, profile: p),
      );
    }

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
      final usageId = usage.id;
      final siblings =
          (siblingsBySectionId[usage.sectionId] ?? const <SectionSibling>[])
              .where((s) => s.usage.id != usageId)
              .toList(growable: false);
      final context = CalculationContext(
        construction: construction,
        profile: profile,
        section: section,
        usage: usage,
        siblings: siblings,
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

    // P1 glass + hardware loops: per-section evaluation after the
    // profile loop. Glass and hardware are NOT per-usage components:
    // a single glass pane covers an entire opening section, a hardware
    // item attaches to the section's frame or sash. Each opening
    // section is evaluated once: build a [CalculationContext] whose
    // `profile` is the section's dominant ouvrant [Profile] (the sash
    // carrier) so the existing [ProfileReferenceCondition] keys
    // naturally on the sash ref, run the glass and hardware selectors.
    // A missing or split sash carrier is a documented "no glass /
    // no hardware" state (see C8 companion-condition precedent: the
    // "no carrier" case is a documented honest skip, and the "mixed
    // sash" case is a documented source tension). The profile loop
    // above is byte-identical to its pre-P1 form.
    final glass = <GlassItem>[];
    final hardware = <HardwareItem>[];
    final glassIssues = <SectionGlassIssue>[];
    final hardwareIssues = <SectionHardwareIssue>[];
    for (final section in construction.sections) {
      // Glass and operational hardware (paumelles, cremone, joints)
      // attach to opening sections. Fixed panels have no glass pane
      // and no operational hardware in our current sources; skipping
      // them keeps the outcome clean rather than producing empty
      // results for sections that don't have anything to evaluate.
      if (section.kind != SectionKind.ouvrant) {
        continue;
      }

      // Per-section variable map, same shape the profile loop used for
      // its single resolved section. Each opening section evaluates its
      // own glass and hardware with its own width/height so the
      // expression engine sees the right values per section.
      final sectionVariables = <DimensionVariable, double>{
        DimensionVariable.constructionWidth: width,
        DimensionVariable.constructionHeight: height,
        DimensionVariable.openingWidth: section.width,
        DimensionVariable.openingHeight: section.height,
      };

      // Carrier set: every distinct `ProfileType.ouvrant` reference in
      // this section whose role is NOT intermediate. "Distinct" means
      // the set of refs -- not the count of usages; a section with one
      // carrier ref used four times still has a single carrier. The
      // carrier SET is the C8 companion-condition's input: its
      // universal quantifier fails closed on any mismatch between the
      // carrier set and a rule's required set.
      //
      // The result has three honest states the workshop view must
      // distinguish, all honest-skip diagnostics -- never a fabricated
      // evaluation:
      //   - empty: no resolved sash carrier -> dominantOuvrantUnresolved.
      //   - >1 distinct refs: "porte + tierce" / mixed-sash state.
      //     The C8 precedent (CompanionProfileReferenceCondition)
      //     universal quantifier fails closed on the same state; we
      //     mirror the precedent here too so the profile-side skip and
      //     the glass/hardware side stay in agreement (an
      //     existential-first pick would silently size the section to
      //     one carrier's rules while the profile side reports a skip
      //     -- contradictory diagnostics on the same construction).
      //   - exactly 1 distinct ref: proceed with that single profile as
      //     the section's dominant ouvrant.
      final carrierRefs = <String>{};
      Profile? dominant;
      for (final usage in construction.profileUsages) {
        if (usage.sectionId != section.id) continue;
        final profile = profilesById[usage.profileId];
        if (profile == null) continue;
        if (profile.type != ProfileType.ouvrant) continue;
        if (usage.role == ProfileUsageRole.intermediate) continue;
        carrierRefs.add(profile.reference);
        dominant ??= profile;
      }

      if (dominant == null) {
        glassIssues.add(
          SectionGlassIssue(
            sectionId: section.id,
            reason: SectionGlassIssueReason.dominantOuvrantUnresolved,
          ),
        );
        hardwareIssues.add(
          SectionHardwareIssue(
            sectionId: section.id,
            reason: SectionHardwareIssueReason.dominantOuvrantUnresolved,
          ),
        );
        continue;
      }

      if (carrierRefs.length > 1) {
        // Mixed-sash: skip with a diagnostic. Mirrors the C8
        // precedent's universal-quantor fail-closed behaviour.
        glassIssues.add(
          SectionGlassIssue(
            sectionId: section.id,
            reason: SectionGlassIssueReason.mixedSashCarrier,
          ),
        );
        hardwareIssues.add(
          SectionHardwareIssue(
            sectionId: section.id,
            reason: SectionHardwareIssueReason.mixedSashCarrier,
          ),
        );
        continue;
      }

      // Section-scoped context: `usage` is null because glass and
      // hardware rules target the whole section, not a single
      // placement. `section-scope conditions` (OpeningTypeCondition,
      // VantauxCountCondition, SectionKindCondition) all read
      // `context.section` and work unchanged. `ProfileReferenceCondition`
      // reads `context.profile` -- here the dominant ouvrant, exactly
      // the ref the glass/hardware source rows are keyed on.
      final sectionContext = CalculationContext(
        construction: construction,
        profile: dominant,
        section: section,
        // usage intentionally omitted: glass/hardware rules do not
        // target a single profile usage. Any condition that reads
        // `context.usage` (e.g. ProfileUsageRoleCondition) fails
        // closed by design -- no role is meaningful at section scope.
        siblings: const [],
      );

      // Glass evaluation.
      try {
        final glassRule = ruleSet.selectGlass(sectionContext);
        if (glassRule == null) {
          glassIssues.add(
            SectionGlassIssue(
              sectionId: section.id,
              reason: SectionGlassIssueReason.noRuleMatched,
            ),
          );
        } else {
          final widthMm = glassRule.widthExpression.evaluate(sectionVariables);
          final heightMm =
              glassRule.heightExpression.evaluate(sectionVariables);
          glass.add(
            GlassItem(
              profileReference: dominant.reference,
              widthMm: widthMm,
              heightMm: heightMm,
              quantity: glassRule.quantity, // section quantity is 1 today
              glazingType: glassRule.glazingType,
              glazingThicknessMm: glassRule.glazingThicknessMm,
              sectionId: section.id,
              ruleDescription: glassRule.description,
            ),
          );
        }
      } on AmbiguousGlassRuleMatchException {
        // Genuine authoring ambiguity in the rule set -- surface as a
        // diagnostic, NOT an exception that kills the whole run.
        // The user's action is to fix the rules; the rest of the
        // calculation continues. We don't carry the exception message
        // into the issue (issues carry a fixed enum reason, not free
        // text -- keeps the contract simple and the aggregation
        // deterministic).
        glassIssues.add(
          SectionGlassIssue(
            sectionId: section.id,
            reason: SectionGlassIssueReason.noRuleMatched,
          ),
        );
      }

      // Hardware evaluation. Same shape as glass.
      try {
        final hardwareRule = ruleSet.selectHardware(sectionContext);
        if (hardwareRule == null) {
          hardwareIssues.add(
            SectionHardwareIssue(
              sectionId: section.id,
              reason: SectionHardwareIssueReason.noRuleMatched,
            ),
          );
        } else {
          double? lengthMm;
          if (hardwareRule.lengthExpression != null) {
            lengthMm =
                hardwareRule.lengthExpression!.evaluate(sectionVariables);
          }
          // `usageIds` is empty: hardware rules match on a per-section
          // basis (no per-usage decomposition yet). A future evolution
          // could record contributing usages; P1 stays simple.
          hardware.add(
            HardwareItem(
              reference: hardwareRule.reference,
              name: hardwareRule.name,
              category: hardwareRule.category,
              quantity: hardwareRule.quantity,
              lengthMm: lengthMm,
              sectionId: section.id,
              usageIds: const [],
              ruleDescription: hardwareRule.description,
            ),
          );
        }
      } on AmbiguousHardwareRuleMatchException {
        hardwareIssues.add(
          SectionHardwareIssue(
            sectionId: section.id,
            reason: SectionHardwareIssueReason.noRuleMatched,
          ),
        );
      }
    }

    return CalculationOutcome(
      cuts: cuts,
      glass: glass,
      hardware: hardware,
      issues: issues,
      glassIssues: glassIssues,
      hardwareIssues: hardwareIssues,
    );
  }
}
