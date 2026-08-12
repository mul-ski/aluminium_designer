/// A manufacturer/company that owns one or more [ProfileSystem]s.
///
/// Previously "manufacturer" only existed as a bare `String` field on
/// `Profile`/`Construction`/`ProfileSystem`. That's enough to *label* a
/// system, but not enough to let a user create their own manufacturer as a
/// first-class, editable thing ("My Workshop" in the brief's example)
/// alongside built-in ones (Aluminium du Maroc, Maghreb Extrusion,
/// Sepalumic, Madilak, GPRAL). This model gives a manufacturer a stable
/// [id] separate from its display [name], so renaming a manufacturer later
/// doesn't break every `Profile.manufacturer` / `Construction.manufacturer`
/// string reference the way renaming a bare string would.
///
/// [isBuiltIn] is the only thing distinguishing a shipped manufacturer from
/// a user-created one, and it affects nothing about how the manufacturer is
/// read or used elsewhere -- `ProfileSystem`, `SystemRuleSet`,
/// `ConstructionCalculator`, and every `RuleCondition` treat built-in and
/// user-created manufacturers identically. It exists purely so a future UI
/// can decide things like "don't allow deleting this one" without the
/// domain model needing two different manufacturer types.
class Manufacturer {
  final String id;
  final String name;

  /// True for manufacturers shipped with the app (e.g. as Dart constants
  /// today, or seeded data later). False for ones a user creates. This
  /// flag is metadata only -- it does not gate which fields can be set or
  /// how the manufacturer participates in calculation.
  final bool isBuiltIn;

  const Manufacturer({
    required this.id,
    required this.name,
    required this.isBuiltIn,
  });
}
