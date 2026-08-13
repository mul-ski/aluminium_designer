import 'manufacturer.dart';
import 'profile_system.dart';

/// The global, app-level catalog of user-created [Manufacturer]s and
/// [ProfileSystem]s.
///
/// This is deliberately separate from [Project] -- a manufacturer or
/// system is not owned by any one project, so it is not stored inside
/// `Project.constructions` or duplicated per project. Any project's
/// `Construction.manufacturer`/`Construction.system` fields hold the
/// *name* of an entry here at the time it was selected (see
/// `Construction`'s doc comment for why those fields stay plain strings
/// for now), not a live reference -- so this catalog can be extended,
/// pruned, or edited independently of any project without corrupting
/// already-saved constructions.
///
/// Starts empty. Nothing here is seeded, hardcoded, or fictional --
/// entries only exist once a user creates them via the construction
/// editor's manufacturer/system picker.
class Catalog {
  final List<Manufacturer> manufacturers;
  final List<ProfileSystem> profileSystems;

  const Catalog({
    this.manufacturers = const [],
    this.profileSystems = const [],
  });

  /// Returns a copy of this catalog with [manufacturers]/[profileSystems]
  /// replaced.
  Catalog copyWith({
    List<Manufacturer>? manufacturers,
    List<ProfileSystem>? profileSystems,
  }) {
    return Catalog(
      manufacturers: manufacturers ?? this.manufacturers,
      profileSystems: profileSystems ?? this.profileSystems,
    );
  }

  /// The [ProfileSystem]s belonging to [manufacturerId], in catalog order.
  ///
  /// Used by the manufacturer/system picker to show only the systems
  /// compatible with the manufacturer the user has already selected --
  /// this is the "don't dump every profile system into one dropdown"
  /// requirement, scoped one level up from profiles to systems.
  List<ProfileSystem> systemsFor(String manufacturerId) {
    return profileSystems
        .where((system) => system.manufacturerId == manufacturerId)
        .toList();
  }
}
