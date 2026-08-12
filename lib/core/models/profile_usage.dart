/// Where within a [Section]'s geometry a [ProfileUsage] sits.
///
/// This is deliberately separate from `ProfileType` (montant, traverse,
/// ouvrant, dormant, mullion, other), which describes what *kind* of
/// profile a piece is, not *where* in a section it goes. A single section
/// commonly needs two montants -- one left, one right -- which share the
/// same `ProfileType.montant` but are different usages; `ProfileType` alone
/// cannot distinguish them, so this enum exists to carry that distinction.
///
/// Kept as a small closed enum rather than free-form position data (e.g.
/// x/y coordinates) because at this stage we only need enough structure
/// for the calculation engine to eventually pick the right rule and for a
/// cutting list/3D viewer to label a piece -- not real geometry.
/// `intermediate` covers positions that don't fit the edge-relative
/// categories, such as a mullion between two ouvrants in the same section.
enum ProfileUsageRole { left, right, top, bottom, intermediate }

/// One concrete placement of a [Profile] definition within a
/// [Construction] -- e.g. "ADM-123 is used as the left montant of section
/// 2, quantity 1".
///
/// A [Profile] is catalogue data: it describes a profile reference that
/// exists in a system, independent of any particular construction.
/// `ProfileUsage` is instance data: it says a specific construction places
/// a specific profile definition at a specific spot. The two are kept as
/// separate models -- linked by [profileId] rather than by embedding a
/// `Profile` object -- so the catalogue definition stays single-sourced and
/// shared, while placement (section, role, quantity, and later
/// orientation) can vary freely per construction without risk of the
/// embedded copy drifting from the catalogue definition it came from.
///
/// This model does not compute anything -- no lengths, no angles, no
/// deductions. It only records *what is placed where*. The calculation
/// engine (unchanged by this file) will eventually consume `ProfileUsage`
/// the same way it consumes `Section`, to build a `CalculationContext` that
/// knows both the section and the role a piece plays within it.
class ProfileUsage {
  /// Stable identifier for this usage record, independent of its position
  /// in any list -- needed so a specific usage can be referenced from a
  /// future cut, 3D-viewer element, or edit operation without relying on
  /// list index.
  final String id;

  /// Id of the [Profile] definition being used. A reference rather than an
  /// embedded `Profile` -- see class doc for why.
  final String profileId;

  /// Id of the [Section] this usage belongs to.
  final String sectionId;

  /// Where within that section's geometry this usage sits.
  final ProfileUsageRole role;

  /// How many identical pieces this usage represents (e.g. `2` if the same
  /// profile/role/section combination naturally produces two identical
  /// cut pieces). This is about how many physical pieces this placement
  /// yields, not a calculated cut quantity -- the calculation engine may
  /// still adjust actual cut quantity based on rules; this is the
  /// usage-level count feeding into that, not the final answer.
  final int quantity;

  const ProfileUsage({
    required this.id,
    required this.profileId,
    required this.sectionId,
    required this.role,
    this.quantity = 1,
  });
}
