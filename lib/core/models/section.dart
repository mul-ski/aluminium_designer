import 'opening.dart'; 



/// Whether a [Section] is a fixed (non-opening) panel or an openable
/// ("ouvrant") one.
///
/// Kept as a field on a single [Section] type rather than two separate
/// section classes (e.g. `FixedSection`/`OuvrantSection`), so the
/// calculation engine, 3D viewer, and any future UI all walk one list of
/// one type — mirroring the project's requirement that built-in and
/// user-created systems share one code path rather than forking by kind.
enum SectionKind { fixed, ouvrant }

/// One panel/division within a [Construction], positioned left-to-right
/// (or top-to-bottom, for future non-horizontal layouts) by [order].
///
/// A `Construction` is composed of an ordered list of `Section`s instead of
/// a flat, unordered `List<Opening>`. This is what lets configurations like
/// "fixe + ouvrant", "ouvrant + fixe", "fixe + ouvrant + fixe", or several
/// ouvrants side by side be represented directly: each is just a different
/// sequence of `Section`s, not a different data structure.
///
/// Each section carries its own width/height rather than inheriting the
/// full construction's dimensions, since a construction with multiple
/// sections divides its overall width (or height) between them.
class Section {
  /// Stable identifier for this section, independent of its position —
  /// needed so reordering sections, and referencing a specific section from
  /// a profile/cut/3D-viewer element, doesn't rely on list index.
  final String id;

  /// Position of this section within the construction. Sections are
  /// ordered by this value (ascending). Using an explicit field rather than
  /// relying on list order keeps position meaningful even if sections are
  /// stored or transmitted out of order.
  final int order;

  final SectionKind kind;

  /// This section's own width and height, in millimetres. For a
  /// multi-section construction these sum to (or subdivide) the overall
  /// `Construction.width`/`height` — the calculation engine, not this
  /// model, is responsible for enforcing that consistency.
  final double width;
  final double height;

  /// The opening behaviour of this section. Required when [kind] is
  /// [SectionKind.ouvrant] (an ouvrant section must specify how it opens),
  /// and must be `null` when [kind] is [SectionKind.fixed] — a fixed
  /// section has no opening type. This is enforced in the constructor
  /// rather than left to callers to get right by convention.
  final OpeningType? openingType;

  /// Number of vantaux (openable leaves) this section represents. `1` for
  /// an ordinary single-leaf ouvrant. Fixed sections always have `0`.
  final int vantauxCount;

  Section({
    required this.id,
    required this.order,
    required this.kind,
    required this.width,
    required this.height,
    this.openingType,
    this.vantauxCount = 0,
  }) {
    if (kind == SectionKind.ouvrant && openingType == null) {
      throw ArgumentError('Section $id is ouvrant but has no openingType.');
    }
    if (kind == SectionKind.fixed && openingType != null) {
      throw ArgumentError(
        'Section $id is fixed but has an openingType ($openingType); '
        'fixed sections must not specify one.',
      );
    }
    if (kind == SectionKind.ouvrant && vantauxCount < 1) {
      throw ArgumentError(
        'Section $id is ouvrant but vantauxCount is $vantauxCount; '
        'an ouvrant section needs at least 1 vantail.',
      );
    }
    if (kind == SectionKind.fixed && vantauxCount != 0) {
      throw ArgumentError(
        'Section $id is fixed but vantauxCount is $vantauxCount; '
        'fixed sections must have 0 vantaux.',
      );
    }
  }
}
