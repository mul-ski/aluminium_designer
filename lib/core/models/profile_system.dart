import 'opening.dart';
import 'profile.dart';

/// A named collection of profiles and supported opening types belonging to
/// one manufacturer -- e.g. one product line such as "Custom Window 2026".
///
/// Nothing about this class assumes it is a hardcoded Dart constant.
/// `id`/`manufacturerId`/`ruleSetId` are plain strings precisely so a
/// `ProfileSystem` can be constructed from data loaded at runtime (a user's
/// saved system) exactly as easily as from a Dart literal (a built-in
/// system) -- the two are the same type, built the same way, consumed the
/// same way by `ConstructionCalculator`/`SystemRuleSet`. `isBuiltIn` is
/// metadata only, matching [Manufacturer]'s -- it never changes how the
/// system behaves in calculation, only how a future UI might treat it
/// (e.g. preventing deletion).
class ProfileSystem {
  final String id;

  /// Manufacturer display name, kept for backward compatibility with
  /// existing code that reads a plain string (e.g. `Construction.manufacturer`,
  /// `Profile.manufacturer`).
  final String manufacturer;

  /// Id of the owning [Manufacturer], so a system can be looked up by/
  /// grouped under its manufacturer without relying on name matching --
  /// important once manufacturer names are user-editable and no longer
  /// guaranteed unique or stable.
  final String manufacturerId;

  final String name;

  /// Id of the [SystemRuleSet] (see `rules/system_rule_set.dart`) that
  /// holds this system's calculation rules. Calculation rules are kept in
  /// their own model/collection rather than embedded here, so a rule set
  /// can be swapped, versioned, or loaded independently of the profile
  /// catalogue -- but the two are linked by this id so
  /// `ConstructionCalculator` can find the right rules for a given system.
  /// Resolve this id via `resolveRuleSetById`/`resolveRuleSetForSystem` in
  /// `lib/core/logic/rule_set_resolution.dart` -- do not look it up ad hoc
  /// elsewhere; that file is the single registry of known rule sets.
  final String ruleSetId;

  final List<Profile> profiles;
  final List<OpeningType> supportedOpenings;

  /// True for systems shipped with the app; false for user-created ones.
  /// See [Manufacturer.isBuiltIn] for why this is metadata-only.
  final bool isBuiltIn;

  const ProfileSystem({
    required this.id,
    required this.manufacturer,
    required this.manufacturerId,
    required this.name,
    required this.ruleSetId,
    required this.profiles,
    required this.supportedOpenings,
    required this.isBuiltIn,
  });
}
