import 'cut.dart';
import 'glass_item.dart';

/// Why a single [ProfileUsage] produced no cut during a calculation run.
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

/// Why a single [Section] produced no glass item during a calculation run.
///
/// Glass is evaluated once per section (not per usage); a "no glass"
/// diagnostic therefore carries the section id, not a usage id. Same
/// diagnostic pattern as [ProfileUsageIssue] so the workshop view
/// can render all three domains (profiles, glass, hardware) with one
/// shared list -- the only differences are the identifier kind and the
/// reason vocabulary.
enum SectionGlassIssueReason {
  /// The section's dominant ouvrant [Profile] did not resolve to a
  /// catalogue entry -- mirrors [ProfileUsageIssueReason.profileUnresolved]
  /// at the section level.
  dominantOuvrantUnresolved,

  /// The section's dominant ouvrant resolved, but no glass rule in the
  /// evaluated rule set matched the section's context.
  noRuleMatched,
}

/// One [Section] that produced no glass item, with the reason why.
class SectionGlassIssue {
  /// Id of the [Section] that produced no glass.
  final String sectionId;

  final SectionGlassIssueReason reason;

  const SectionGlassIssue({required this.sectionId, required this.reason});
}

/// Everything one run of `ConstructionCalculator.calculate` decided.
///
/// This is the calculation result envelope: today it holds the profile
/// cuts plus per-usage skip diagnostics, plus (since P1) the glass
/// items produced for each opening section and the per-section glass
/// skip diagnostics. The envelope is designed to grow with further
/// component domains (hardware/accessories arrive in P1 commit 2)
/// instead of widening the calculator's return type again -- cuts stay
/// exactly as they are, so existing consumers of individual cuts are
/// unaffected.
///
/// Issues are informational, not errors: a skipped usage or section
/// is often a legitimate mid-editing state (no rules assigned yet for
/// this profile type or this opening). Hard failures keep throwing
/// (`StateError` for missing overall dimensions,
/// `AmbiguousRuleMatchException` for genuine rule ties) -- they never
/// silently become issues here.
class CalculationOutcome {
  /// Cuts produced by matched usages, in usage iteration order.
  final List<ProfileCut> cuts;

  /// Glass panes produced by matched opening sections, in section
  /// iteration order. Empty when no opening section produced a glass
  /// item (e.g. no glass rule for the system yet, or every glass rule
  /// skipped with a visible [glassIssues] reason).
  final List<GlassItem> glass;

  /// Usages that produced no cut, each with the reason. Empty when every
  /// usage produced a cut -- or when there were no usages at all.
  final List<ProfileUsageIssue> issues;

  /// Sections that produced no glass item, each with the reason. Empty
  /// when every opening section produced a glass item.
  final List<SectionGlassIssue> glassIssues;

  const CalculationOutcome({
    required this.cuts,
    this.glass = const [],
    this.issues = const [],
    this.glassIssues = const [],
  });

  /// True when the run produced neither cuts nor glass -- i.e. there was
  /// nothing to calculate from (no usages assigned, no opening sections)
  /// or nothing matched.
  bool get isEmpty =>
      cuts.isEmpty && glass.isEmpty && issues.isEmpty && glassIssues.isEmpty;
}
