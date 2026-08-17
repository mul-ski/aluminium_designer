library;

import '../models/profile_system.dart';
import '../models/profile_usage.dart';

/// Pure logic for deciding which [Profile] ids belong to a given
/// [ProfileSystem], and which [ProfileUsage] records stop being valid when
/// a construction's selected system changes (or was never resolved).
///
/// Kept free of any Flutter/widget/storage dependency on purpose: this is
/// exactly the kind of integrity check that must be testable on its own,
/// not only indirectly through widget interaction -- see
/// `test/system_compatibility_test.dart`. `ManufacturerSystemPicker` and
/// `ConstructionEditorScreen` both call into this rather than
/// reimplementing the same "is this usage still valid" check twice.

/// The set of profile ids that belong to [system]. `null` (no system
/// resolved -- either none selected yet, or the previously selected one
/// no longer exists in the catalog) yields an empty set: with no system
/// to check against, nothing can be considered compatible.
Set<String> compatibleProfileIds(ProfileSystem? system) {
  if (system == null) return const {};
  return system.profiles.map((p) => p.id).toSet();
}

/// Whether [profileId] belongs to [system]. Convenience wrapper around
/// [compatibleProfileIds] for a single lookup (e.g. deciding whether one
/// profile can be offered/kept for assignment) rather than building a set
/// just to check one id.
bool isProfileCompatible(String profileId, ProfileSystem? system) {
  if (system == null) return false;
  return system.profiles.any((p) => p.id == profileId);
}

/// The subset of [usages] whose `profileId` does NOT belong to
/// [replacementSystem].
///
/// This is deliberately evaluated against ALL of [usages], not just the
/// ones created under a previously-known-good system -- a construction
/// can already be carrying stale usages before this check ever runs (its
/// previously selected system may have been deleted from the catalog
/// entirely, leaving `Construction.systemId` unresolved and every one of
/// its usages already orphaned). Passing `replacementSystem: null` -- e.g.
/// checking against an unresolved system -- correctly reports every usage
/// as incompatible, since [compatibleProfileIds] returns an empty set for
/// `null`, matching "there is nothing valid to keep them compatible with".
List<ProfileUsage> incompatibleUsages(
  List<ProfileUsage> usages,
  ProfileSystem? replacementSystem,
) {
  final compatibleIds = compatibleProfileIds(replacementSystem);
  return usages
      .where((usage) => !compatibleIds.contains(usage.profileId))
      .toList();
}
