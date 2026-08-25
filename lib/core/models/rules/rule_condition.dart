import '../construction.dart';
import '../construction_type.dart';
import '../opening.dart';
import '../profile.dart';
import '../profile_usage.dart';
import '../section.dart';

/// Everything a [RuleCondition] might need to decide whether a rule applies.
///
/// This bundles the construction being calculated, the specific profile
/// being processed, and (optionally) the section it belongs to. It exists
/// so conditions have one typed thing to inspect instead of the calculator
/// passing around loose parameters -- and so adding a new condition type
/// later just means reading an existing/new field here, not changing every
/// call site.
class CalculationContext {
  final Construction construction;
  final Profile profile;

  /// The section this profile belongs to, if applicable. Some profiles
  /// (e.g. a dormant shared across the whole frame) may not be tied to a
  /// single section, so this is nullable. Conditions that need
  /// section-specific data (opening type, vantaux count, fixed vs ouvrant)
  /// simply don't match when this is `null` -- see e.g.
  /// [OpeningTypeCondition].
  final Section? section;

  /// The specific placement (section, role, quantity) that [profile] is
  /// being evaluated for, if known. Distinct from [section]: `section`
  /// says *which section*, `usage` additionally says *which role within
  /// that section* -- e.g. left montant vs right montant, both of which
  /// share the same profile and section. Nullable because not every
  /// calculation context is tied to a specific `ProfileUsage` record (the
  /// legacy `Construction.profiles` path has no usages at all -- see
  /// `Construction`'s "PROFILE PATH" doc comment). Conditions that need
  /// role-specific data simply don't match when this is `null` -- see
  /// [ProfileUsageRoleCondition].
  final ProfileUsage? usage;

  /// The other successfully-resolved [ProfileUsage]s sharing the evaluated
  /// usage's section, excluding the evaluated usage itself -- the derived
  /// "who else is placed in this châssis" view that companion-profile
  /// conditions read (see [CompanionProfileReferenceCondition]). Populated
  /// by `ConstructionCalculator.calculate` from data already in hand (the
  /// construction's usages plus the resolved profile map); never persisted
  /// and never read from storage. Empty by default. Conditions reading it
  /// fail closed whenever the evaluated context has no usage or no
  /// section, exactly like every other missing-context case -- note the
  /// list itself is keyed by the usage's raw `sectionId`, so it can be
  /// non-empty even when the section record no longer resolves; the guard
  /// in [CompanionProfileReferenceCondition] is what makes that state
  /// safe. Usages whose profile does not resolve are invisible here (they
  /// carry no identity to check); their own skip surfaces separately as a
  /// `profileUnresolved` issue on the same outcome.
  final List<SectionSibling> siblings;

  const CalculationContext({
    required this.construction,
    required this.profile,
    this.section,
    this.usage,
    this.siblings = const [],
  });
}

/// One entry in [CalculationContext.siblings]: a [ProfileUsage] sharing the
/// evaluated usage's section together with its resolved catalogue
/// [Profile]. A plain pair -- no behaviour -- so conditions can quantify
/// over "the other placed members of this section" without reaching back
/// into the construction or the profile map themselves.
class SectionSibling {
  final ProfileUsage usage;
  final Profile profile;

  const SectionSibling({required this.usage, required this.profile});
}

/// Base type for rule-matching conditions.
///
/// Deliberately a small closed set of condition types (like
/// `DimensionExpression`'s node types) rather than a generic predicate
/// callback -- keeps rules strongly typed, inspectable, and eventually
/// serializable (e.g. loaded from JSON or a user-editable config store),
/// instead of opaque closures.
///
/// New condition kinds are added as new subclasses. Existing rules and
/// matching logic don't need to change when a new condition kind is added
/// -- see `ProfileCalculationRule.conditions` and `SystemRuleSet.select`.
///
/// [NumericComparisonCondition] is the one condition kind here that is
/// itself parameterised by data (which field, which operator, which
/// value) rather than being a fixed check. That's what lets a user
/// eventually configure something like "Width > 1500" from external data
/// without adding a new Dart class for every possible threshold -- the
/// class already exists, only the field/operator/value need to come from
/// configuration.
abstract class RuleCondition {
  const RuleCondition();

  /// Whether this condition holds for the given [context].
  bool matches(CalculationContext context);
}

/// Matches when the section being evaluated is an ouvrant section with the
/// given [OpeningType].
///
/// Unlike the previous version of this condition (which scanned
/// `Construction.openings` for *any* matching opening), this now checks the
/// specific [CalculationContext.section] -- a construction with "fixe +
/// oscillo-battant + fixe" should let a rule target the oscillo-battant
/// section specifically, not match every profile in the construction just
/// because one of its sections happens to be oscillo-battant.
class OpeningTypeCondition extends RuleCondition {
  final OpeningType openingType;

  const OpeningTypeCondition(this.openingType);

  @override
  bool matches(CalculationContext context) {
    final section = context.section;
    if (section == null || section.kind != SectionKind.ouvrant) {
      return false;
    }
    return section.openingType == openingType;
  }
}

/// Matches when the section being evaluated has exactly [count] vantaux.
///
/// Reads `Section.vantauxCount` for the specific section in context, rather
/// than counting entries in a flat construction-wide list -- consistent
/// with [OpeningTypeCondition] now being section-scoped.
class VantauxCountCondition extends RuleCondition {
  final int count;

  const VantauxCountCondition(this.count);

  @override
  bool matches(CalculationContext context) {
    return context.section?.vantauxCount == count;
  }
}

/// Matches when the section being evaluated is fixed or ouvrant, per
/// [kind]. Covers the "fixed vs ouvrant" condition category explicitly.
class SectionKindCondition extends RuleCondition {
  final SectionKind kind;

  const SectionKindCondition(this.kind);

  @override
  bool matches(CalculationContext context) {
    return context.section?.kind == kind;
  }
}

/// Matches when the [CalculationContext.usage] being evaluated has the
/// given [ProfileUsageRole] (left/right/top/bottom/intermediate).
///
/// This is what lets a rule distinguish "left montant" from "right
/// montant" -- both share the same `ProfileType.montant` and may share
/// the same `Section`, so `SectionKindCondition`/`OpeningTypeCondition`
/// alone cannot tell them apart. Fails safely (does not match) when
/// `context.usage` is `null`, consistent with every other section/usage
/// -scoped condition in this file.
class ProfileUsageRoleCondition extends RuleCondition {
  final ProfileUsageRole role;

  const ProfileUsageRoleCondition(this.role);

  @override
  bool matches(CalculationContext context) {
    return context.usage?.role == role;
  }
}

/// Matches when the construction's overall type (window/door/curtain wall)
/// equals [constructionType]. Covers the "construction type" condition
/// category explicitly.
class ConstructionTypeCondition extends RuleCondition {
  final ConstructionType constructionType;

  const ConstructionTypeCondition(this.constructionType);

  @override
  bool matches(CalculationContext context) {
    return context.construction.type == constructionType;
  }
}

/// Matches when the construction's `manufacturer`/`system` fields equal the
/// given values. Covers system-specific conditions without needing a
/// separate condition subclass per manufacturer -- including
/// user-created manufacturers/systems, since those are just strings, not
/// special-cased types.
class SystemCondition extends RuleCondition {
  final String manufacturer;
  final String system;

  const SystemCondition({required this.manufacturer, required this.system});

  @override
  bool matches(CalculationContext context) {
    return context.construction.manufacturer == manufacturer &&
        context.construction.system == system;
  }
}

/// Matches when the evaluated profile's catalogue reference
/// ([Profile.reference]) is one of [references].
///
/// This exists because real manufacturer débitage tables are keyed by the
/// exact profile reference, not just by [ProfileType]: Série 14600's
/// traverses 14 621 and 14 631 share `ProfileType.traverse` but carry
/// different deductions ((L−64)/2 vs (L−85)/2 in the source document's
/// débitage table -- see docs/VERIFIED_SOURCES.md), so no type-based or
/// section-based condition can tell them apart. The set form mirrors how
/// such tables group rows: one débitage row often covers several
/// references that share a formula (e.g. montants latéraux 14 622/623/632/633
/// all cut to H−74), and one condition listing that row's references keeps
/// one rule per table row instead of one rule per reference.
///
/// An empty set matches nothing -- consistent with every other condition's
/// fail-closed behaviour, and it can never be meaningful ("reference is
/// one of none").
class ProfileReferenceCondition extends RuleCondition {
  final Set<String> references;

  const ProfileReferenceCondition(this.references);

  @override
  bool matches(CalculationContext context) {
    return references.contains(context.profile.reference);
  }
}

/// Matches when the evaluated usage's section siblings establish the
/// required companion-profile identity: at least one *sash-carrier*
/// sibling exists and every sash-carrier sibling's catalogue reference is
/// one of [references].
///
/// "Sash carrier" = a sibling whose resolved [Profile.type] is
/// [ProfileType.ouvrant] and whose role is NOT
/// [ProfileUsageRole.intermediate] -- i.e. the leaf-frame members AluVis
/// places at left/right/top/bottom. The intermediate slot is excluded
/// because real systems place members there that their sheets still type
/// as ouvrant profiles: Sepalumic Série 4200's battue centrale 4206 is
/// seeded `ProfileType.ouvrant` from its own B040 sheet heading yet
/// coexists with the traverse options at 2 vantaux
/// (docs/VERIFIED_SOURCES.md, M-2). The clause is a derivation from AluVis
/// placement doctrine, not a source statement.
///
/// WHY THIS EXISTS (real source requirement; second manufacturer to hit
/// it): Sepalumic 4200's OF traverse-option débitage is keyed by the
/// châssis's OUVRANT reference, not by the traverse's own -- traverse 2656
/// cuts L−117 / L−141 / L−177 beside ouvrant 4211/4219/4244, and
/// 4405/4413 cut L−187 beside 4254 (E070/E090/E110/E130, éd. 05; per-page
/// citations in docs/VERIFIED_SOURCES.md M-2). The same shape appears in
/// ME Série 14800 frappe, whose parclose rows are keyed by the sibling
/// ouvrant ref 14.802 vs 14.805 (Catalogue Général, pdf p. 65). No
/// single-usage condition can express "the OTHER member of this section
/// is ref X", which is exactly why those rows stayed unencoded while
/// blocked (blockers on record in docs/VERIFIED_SOURCES.md).
///
/// Semantics are UNIVERSAL over the carrier class, not existential ("first
/// match wins"): a section mixing two sash references (e.g. left stile
/// 4211 with right stile 4219) matches NO rule here and surfaces as a
/// plain `noRuleMatched` skip on the dependent usage, instead of two rules
/// tying at equal specificity in `SystemRuleSet.select` and throwing
/// `AmbiguousRuleMatchException` out of otherwise-calculating
/// constructions. Each E-sheet documents exactly one sash reference per
/// châssis; a mixed-sash section lies outside every documented cell.
///
/// Fail-closed everywhere: no usage or section in context, an empty
/// [references] set, no sash-carrier siblings at all, or any carrier
/// outside [references] all yield `false`. Unresolvable sibling placements
/// are invisible here (no identity to check -- their own
/// `profileUnresolved` issue reports them on the same outcome), so a
/// section whose only carriers do not resolve also fails closed. Matching
/// is exact string equality on [Profile.reference] -- never display names,
/// never iteration-order-dependent.
///
/// Encoding discipline for rule authors: a multi-reference [references]
/// set is safe only when every reference it names shares the SAME outcome
/// (the same débitage row, e.g. Sepalumic 4405/4413 → L−187). A set
/// spanning different-deduction references would re-admit wrong matches
/// under the universal quantifier -- give each deduction its own rule
/// with a single-reference set instead.
class CompanionProfileReferenceCondition extends RuleCondition {
  final Set<String> references;

  const CompanionProfileReferenceCondition(this.references);

  @override
  bool matches(CalculationContext context) {
    if (references.isEmpty) return false;
    if (context.usage == null || context.section == null) return false;

    var sawCarrier = false;
    for (final sibling in context.siblings) {
      final isSashCarrier = sibling.profile.type == ProfileType.ouvrant &&
          sibling.usage.role != ProfileUsageRole.intermediate;
      if (!isSashCarrier) continue;
      if (!references.contains(sibling.profile.reference)) {
        return false;
      }
      sawCarrier = true;
    }
    return sawCarrier;
  }
}

/// A numeric field on a [CalculationContext] that a
/// [NumericComparisonCondition] can read and compare.
///
/// This is a closed set of *readable fields*, not thresholds -- it says
/// "these are the numbers a condition is allowed to compare", not what
/// they're compared against. Adding a new comparable field (e.g. a glass
/// thickness once that's modelled) means adding one enum value plus one
/// case in `NumericComparisonCondition._valueOf`; it does not mean adding a
/// new condition subclass.
enum NumericField {
  constructionWidth,
  constructionHeight,
  sectionWidth,
  sectionHeight,
  vantauxCount,
}

/// Comparison operators available to [NumericComparisonCondition].
enum ComparisonOperator {
  equal,
  notEqual,
  greaterThan,
  greaterThanOrEqual,
  lessThan,
  lessThanOrEqual,
}

/// A user-configurable numeric comparison, e.g. "Width > 1500" or "vantaux
/// = 2".
///
/// This is intentionally the *only* condition class needed to express any
/// numeric threshold or range check (a range is just two of these combined
/// via `ProfileCalculationRule.conditions`' AND semantics, e.g. width >=
/// 1000 AND width <= 1500). [field], [operator], and [value] are all plain
/// data -- nothing here is a hardcoded threshold. A future config/database
/// loader can construct these directly from user input without touching
/// Dart source, which is the actual requirement: the architecture supports
/// configurable conditions, without this codebase inventing what any real
/// threshold should be.
class NumericComparisonCondition extends RuleCondition {
  final NumericField field;
  final ComparisonOperator operator;
  final double value;

  const NumericComparisonCondition({
    required this.field,
    required this.operator,
    required this.value,
  });

  @override
  bool matches(CalculationContext context) {
    final fieldValue = _valueOf(field, context);
    if (fieldValue == null) {
      // The field isn't applicable in this context (e.g. sectionWidth
      // when there's no section) -- treat as a non-match rather than
      // throwing, consistent with other section-scoped conditions above.
      return false;
    }
    switch (operator) {
      case ComparisonOperator.equal:
        return fieldValue == value;
      case ComparisonOperator.notEqual:
        return fieldValue != value;
      case ComparisonOperator.greaterThan:
        return fieldValue > value;
      case ComparisonOperator.greaterThanOrEqual:
        return fieldValue >= value;
      case ComparisonOperator.lessThan:
        return fieldValue < value;
      case ComparisonOperator.lessThanOrEqual:
        return fieldValue <= value;
    }
  }

  double? _valueOf(NumericField field, CalculationContext context) {
    switch (field) {
      case NumericField.constructionWidth:
        return context.construction.width;
      case NumericField.constructionHeight:
        return context.construction.height;
      // Both branches above already return double? (Construction.width/
      // height are nullable), and matches() above already treats a null
      // fieldValue as "condition does not match" rather than throwing --
      // so an incomplete construction's dimensions simply fail to match
      // any numeric condition, consistent with how a missing sectionWidth
      // is already handled below.
      case NumericField.sectionWidth:
        return context.section?.width;
      case NumericField.sectionHeight:
        return context.section?.height;
      case NumericField.vantauxCount:
        return context.section?.vantauxCount.toDouble();
    }
  }
}
