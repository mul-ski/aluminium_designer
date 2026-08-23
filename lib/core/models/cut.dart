import 'profile.dart';

class ProfileCut {
  final Profile profile;
  final double length;
  final int quantity;
  final double angleStart;
  final double angleEnd;

  /// Id of the [ProfileUsage] (see `profile_usage.dart`) this cut was
  /// produced for. Every cut `ConstructionCalculator.calculate` emits
  /// comes from evaluating exactly one `ProfileUsage`, so this is always
  /// set -- never null, never invented -- it's the same id already
  /// present on that usage.
  final String profileUsageId;

  /// The `sectionId` of the [ProfileUsage] this cut was produced for --
  /// i.e. `ProfileUsage.sectionId`, copied through rather than requiring
  /// callers to re-look-up the usage to find out which section a cut
  /// belongs to. This is the id as recorded on the usage, not a
  /// guarantee that a `Section` with this id still exists in
  /// `Construction.sections` -- `ConstructionCalculator.calculate`
  /// already produces a cut even when a usage's section doesn't resolve
  /// (see that method's doc comment on `CalculationContext.section`
  /// being nullable); this field preserves that same behaviour instead
  /// of silently dropping traceability whenever a section goes stale.
  final String sectionId;

  /// Human-readable description of the [ProfileCalculationRule] that
  /// produced this cut -- copied through from `rule.description` so a cut
  /// list can show WHY each piece has its length/quantity/angles without
  /// re-running the calculation. Null when the producing rule has no
  /// description; never invented here.
  final String? ruleDescription;

  const ProfileCut({
    required this.profile,
    required this.length,
    required this.quantity,
    required this.angleStart,
    required this.angleEnd,
    required this.profileUsageId,
    required this.sectionId,
    this.ruleDescription,
  });
}
