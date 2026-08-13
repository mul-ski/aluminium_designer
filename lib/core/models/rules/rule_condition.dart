import '../construction.dart';
import '../construction_type.dart';
import '../opening.dart';
import '../profile.dart';
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

  const CalculationContext({
    required this.construction,
    required this.profile,
    this.section,
  });
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
