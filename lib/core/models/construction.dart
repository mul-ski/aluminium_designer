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
/// PROFILE PATH -- READ BEFORE TOUCHING `profiles`/`profileUsages`:
/// `profiles` is the OLD, disconnected flat list of `Profile` copies. It
/// predates `manufacturerId`/`systemId` and is not linked to anything in
/// `Catalog` by id. It is kept only for backward compatibility with
/// already-saved data and is NOT used by any new functionality -- new code
/// must never read or write it. The current, real profile path is:
///
///   `Construction.systemId` -> `Catalog.profileSystems[id]` ->
///   `ProfileSystem.profiles` (profile *definitions*, catalog-owned)
///   `Construction.profileUsages` (profile *assignments* -- which
///   definition, which section, which role; construction-owned)
///
/// See `ProfileUsage`'s doc comment for the definition/usage distinction,
/// and `lib/core/logic/system_compatibility.dart` for the shared logic
/// that decides which usages are compatible with a given system.
/// `ConstructionCalculator` is untouched by this and still reads the old
/// `profiles` list -- that is a separate, later milestone.
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

  /// Display names of the selected manufacturer/system, kept for backward
  /// compatibility and for display when the stable id can't be resolved
  /// (e.g. an old project saved before ids existed, or a catalog entry
  /// that was later deleted -- see `manufacturerId`/`systemId` below).
  /// These are NOT the authoritative relationship once an id is present;
  /// they may go stale (e.g. after a catalog rename) without affecting
  /// which `ProfileSystem` this construction actually resolves to.
  final String manufacturer;
  final String system;

  /// Stable ids of the selected [Manufacturer]/[ProfileSystem] in the app
  /// catalog, or `null` if none has been selected yet, or if this
  /// `Construction` was saved before these fields existed (old JSON --
  /// see `project_json.dart`'s `constructionFromJson`).
  ///
  /// These are authoritative for resolving "which system is this
  /// construction using" -- `manufacturer`/`system` (the plain name
  /// strings above) are display-only fallbacks. A non-null `systemId`
  /// that no longer matches any `ProfileSystem.id` in the current catalog
  /// (the system, or its manufacturer, was deleted) means "unresolved",
  /// not "none selected" -- callers must distinguish the two: unresolved
  /// keeps whatever `profileUsages` already exist untouched (see
  /// `system_compatibility.dart`), while selecting a new system runs the
  /// incompatibility check against them.
  final String? manufacturerId;
  final String? systemId;

  /// Ordered sections making up this construction. See [Section] for how
  /// order, fixed/ouvrant kind, and per-section dimensions are represented.
  final List<Section> sections;

  /// Direction sections are arranged in. See [SectionLayoutDirection].
  final SectionLayoutDirection layoutDirection;

  /// OLD profile path. See the class doc's "PROFILE PATH" note -- do not
  /// use this for new functionality.
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
    this.manufacturerId,
    this.systemId,
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
  ///
  /// `manufacturerId`/`systemId` use an explicit `clearManufacturerId`/
  /// `clearSystemId` flag rather than relying on `null` meaning "clear" --
  /// the usual `newValue ?? oldValue` pattern this method otherwise uses
  /// cannot distinguish "caller didn't pass this field" from "caller
  /// explicitly wants it set to null", and clearing to null is a real,
  /// needed case here (selecting a manufacturer with no system yet must
  /// clear a previously-set `systemId`, not leave a stale one behind).
  Construction copyWith({
    String? name,
    ConstructionType? type,
    double? width,
    double? height,
    String? manufacturer,
    String? system,
    String? manufacturerId,
    bool clearManufacturerId = false,
    String? systemId,
    bool clearSystemId = false,
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
      manufacturerId: clearManufacturerId
          ? null
          : (manufacturerId ?? this.manufacturerId),
      systemId: clearSystemId ? null : (systemId ?? this.systemId),
      sections: sections ?? this.sections,
      layoutDirection: layoutDirection ?? this.layoutDirection,
      profiles: profiles ?? this.profiles,
      profileUsages: profileUsages ?? this.profileUsages,
    );
  }
}
