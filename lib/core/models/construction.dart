import 'construction_type.dart';
import 'profile.dart';
import 'profile_usage.dart';
import 'section.dart';

/// A complete window, door, or curtain-wall design.
///
/// `openings: List<Opening>` has been replaced by `sections:
/// List<Section>`. A flat, unordered opening list could not represent
/// which parts of a construction are fixed vs openable, how many sections
/// there are, their individual dimensions, or their left-to-right order --
/// all of which are required to tell "fixe + ouvrant" apart from "ouvrant +
/// fixe", or a single wide ouvrant apart from two narrower ones.
///
/// `profiles` is the flat list of `Profile` *definitions* assigned to/
/// available in this construction (catalogue data) and is preserved as-is.
/// `profileUsages` is new: it records where each profile definition is
/// actually placed (which section, which role, what quantity) -- see
/// [ProfileUsage] for why this is a separate model from `Profile` rather
/// than embedding profiles directly inside `Section`.
class Construction {
  final String id;
  final String name;

  final ConstructionType type;

  final double width;
  final double height;

  final String manufacturer;
  final String system;

  /// Ordered sections making up this construction. See [Section] for how
  /// order, fixed/ouvrant kind, and per-section dimensions are represented.
  final List<Section> sections;

  final List<Profile> profiles;

  /// Concrete placements of profile definitions within this construction's
  /// sections. See [ProfileUsage] for the definition/usage distinction.
  /// Not yet consumed by `ConstructionCalculator` -- this only records
  /// placement, it doesn't change how cuts are computed.
  final List<ProfileUsage> profileUsages;

  const Construction({
    required this.id,
    required this.name,
    required this.type,
    required this.width,
    required this.height,
    required this.manufacturer,
    required this.system,
    required this.sections,
    required this.profiles,
    this.profileUsages = const [],
  });
}
