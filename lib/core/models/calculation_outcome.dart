import 'cut.dart';

/// Why a [ProfileUsage] produced no cut during a calculation run.
///
/// A closed set rather than a free-form message so callers can react per
/// reason (e.g. colour, icon) and tests can assert exactly which state the
/// engine detected -- mirroring how `RuleCondition` subclasses are typed
/// data instead of opaque predicates.
enum ProfileUsageIssueReason {
  /// The usage's `profileId` did not resolve to a catalogue [Profile] --
  /// e.g. the profile was deleted from its system after the usage was
  /// created.
  profileUnresolved,

  /// The usage resolved fine, but no rule in the evaluated
  /// `SystemRuleSet` matched its context (profile type + conditions).
  noRuleMatched,
}

/// One [ProfileUsage] that produced no cut, with the reason why.
///
/// Deliberately carries only the usage's id -- not the usage object itself
/// -- matching `ProfileCut.profileUsageId`: ids are stable references a
/// caller can resolve against the construction it already has, and the
/// engine never needs to embed instance data to explain a skip.
class ProfileUsageIssue {
  /// Id of the [ProfileUsage] that produced no cut.
  final String profileUsageId;

  final ProfileUsageIssueReason reason;

  const ProfileUsageIssue({required this.profileUsageId, required this.reason});
}

/// Everything one run of `ConstructionCalculator.calculate` decided.
///
/// This is the calculation result envelope: today it holds the profile
/// cuts plus per-usage diagnostics (which usages were skipped and why).
/// Later milestones extend the envelope with further component domains
/// (glass, hardware, accessories) and richer traceability instead of
/// widening the calculator's return type again -- cuts stay exactly as
/// they are, so existing consumers of individual cuts are unaffected.
///
/// Issues are informational, not errors: a skipped usage is often a
/// legitimate mid-editing state (no rules assigned yet for this profile
/// type). Hard failures keep throwing (`StateError` for missing overall
/// dimensions, `AmbiguousRuleMatchException` for genuine rule ties) --
/// they never silently become issues here.
class CalculationOutcome {
  /// Cuts produced by matched usages, in usage iteration order.
  final List<ProfileCut> cuts;

  /// Usages that produced no cut, each with the reason. Empty when every
  /// usage produced a cut -- or when there were no usages at all.
  final List<ProfileUsageIssue> issues;

  const CalculationOutcome({required this.cuts, this.issues = const []});

  /// True when the run produced neither cuts nor issues -- i.e. there was
  /// nothing to calculate from (no usages assigned), or nothing matched.
  bool get isEmpty => cuts.isEmpty && issues.isEmpty;
}
