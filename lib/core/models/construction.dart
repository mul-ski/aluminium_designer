import 'construction_type.dart';
import 'layout_direction.dart';
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
///
/// `layoutDirection` says whether `sections` are arranged side by side
/// (`horizontal`) or stacked (`vertical`) -- see [SectionLayoutDirection].
/// It defaults to `horizontal`, matching every construction built before
/// this field existed. This field only has a defined geometric meaning for
/// linear (window/door) constructions; see `validateSectionGeometry` for
/// why curtain walls are excluded from that check.
class Construction {
  final String id;
  final String name;

  final ConstructionType type;

  /// Overall width/height in millimetres, or `null` if the user hasn't
  /// entered them yet.
  ///
  /// Nullable rather than defaulting to `0` (or any other placeholder
  /// number) so a freshly created construction can honestly represent
  /// "not dimensioned yet" instead of a fake dimension that would either
  /// silently pass or silently fail geometry validation for the wrong
  /// reason. See `GeometryStatus`/`constructionGeometryStatus` in
  /// `section_geometry.dart` for how this incomplete state is surfaced to
  /// the editor without being treated as an error.
  final double? width;
  final double? height;

  final String manufacturer;
  final String system;

  /// Ordered sections making up this construction. See [Section] for how
  /// order, fixed/ouvrant kind, and per-section dimensions are represented.
  final List<Section> sections;

  /// Direction sections are arranged in. See [SectionLayoutDirection].
  final SectionLayoutDirection layoutDirection;

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
    this.width,
    this.height,
    required this.manufacturer,
    required this.system,
    required this.sections,
    this.layoutDirection = SectionLayoutDirection.horizontal,
    required this.profiles,
    this.profileUsages = const [],
  });

  /// Returns a copy of this construction with the given fields replaced.
  ///
  /// Needed now that a `Construction` is built up incrementally in the
  /// editor (name/type first, then manufacturer/system, then dimensions,
  /// then sections) rather than constructed once with every field known --
  /// each editor step produces a new `Construction` via this method rather
  /// than mutating one in place, consistent with `Project.copyWith`.
  Construction copyWith({
    String? name,
    ConstructionType? type,
    double? width,
    double? height,
    String? manufacturer,
    String? system,
    List<Section>? sections,
    SectionLayoutDirection? layoutDirection,
    List<Profile>? profiles,
    List<ProfileUsage>? profileUsages,
  }) {
    return Construction(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      width: width ?? this.width,
      height: height ?? this.height,
      manufacturer: manufacturer ?? this.manufacturer,
      system: system ?? this.system,
      sections: sections ?? this.sections,
      layoutDirection: layoutDirection ?? this.layoutDirection,
      profiles: profiles ?? this.profiles,
      profileUsages: profileUsages ?? this.profileUsages,
    );
  }
}
