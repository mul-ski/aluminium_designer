/// One computed hardware item for a [Construction] run -- the kind of
/// information a workshop needs to order and assemble: a reference
/// (e.g. "AC-600"), a name, a quantity, an optional cut-length formula
/// (for gaskets / brushes / weatherstripping that comes in a cut length
/// per frame), a category (metal hardware vs gasket/accessory), and
/// section/usage provenance.
///
/// HARDWARE VS ACCESSORY -- why one model with a category tag, not two:
/// the source material (e.g. ME 14800 p. 65 ACCESSOIRES) does not
/// distinguish the two categories itself -- the same row lists paumelles
/// next to joints. Splitting into two models would create two
/// near-identical data shapes that the model layer has to keep in
/// lockstep. A single model with a [HardwareCategory] tag gives the
/// downstream consumers (aggregation, UI) a clean way to group or
/// label without duplicating shape. P1 commit 3 (aggregation) and
/// commit 6 (BOM dialog) read this tag.
///
/// PROVENANCE: a hardware item is keyed to a [Section] (where the item
/// is installed) -- not to a single [ProfileUsage], since the same
/// hardware attaches to the section's whole frame or sash, not to one
/// profile usage. The section id is therefore the natural granularity;
/// `usageIds` records the specific profile usages that contributed to
/// the rule (e.g. both stile usages of a section contribute to the
/// joint rule that covers the stile-to-dormant seam), when the rule
/// matches on a per-usage basis.
///
/// LENGTH: `lengthMm` is the cut length in mm, populated when the rule
/// has a length expression (joints, weatherstripping -- "2L+2H", "L",
/// etc.). `null` when the item is a count-only hardware (paumelles,
/// gaches, equerres) -- the absence is data, never an invented zero.
class HardwareItem {
  /// Reference as stated by the source -- direct string equality with
  /// the catalogue `Profile` / accessory reference, never display names.
  /// For pure accessories (e.g. "JO-826"), this is the accessory's own
  /// reference; the model makes no distinction at the type level.
  final String reference;

  /// Display name (e.g. "Équerre à pions", "Joint de battue"). The
  /// source's own wording when available, otherwise the reference itself.
  final String name;

  /// Whether this item is a metal hardware piece (paumelles, gaches,
  /// cremone, equerres, etc.) or a gasket/accessory (joints, weather
  /// strips, etc.). Downstream grouping reads this; P1 commit 3 and 6
  /// use it to build the BOM's hardware vs accessories split.
  final HardwareCategory category;

  /// Physical number of pieces. Plain int -- no `CutQuantity`-style
  /// wrapper needed (hardware rules don't compose across roles; one
  /// matched section yields `quantity` items).
  final int quantity;

  /// Cut length in mm when the item is length-bearing (joints, weather
  /// strips); `null` when the item is count-only (paumelles, equerres,
  /// gaches). The cut length is the result of evaluating the rule's
  /// length expression against the construction dimensions; `null`
  /// means the rule did not produce a length (or produced 0 -- but 0
  /// would mean "nothing to cut", which is itself a length state and
  /// would be reported as `lengthMm: 0`, not `null`).
  final double? lengthMm;

  /// Id of the [Section] this item belongs to.
  final String sectionId;

  /// Distinct `ProfileUsage.id`s that contributed to this item's rule
  /// match. Empty when the rule matched on a per-section basis (no
  /// specific usages to attribute). First-encounter order.
  final List<String> usageIds;

  /// Human-readable description of the [HardwareCalculationRule] that
  /// produced this item -- same convention as [ProfileCut.ruleDescription]
  /// / [GlassItem.ruleDescription]: copied through, null when the rule
  /// has no description, never invented.
  final String? ruleDescription;

  const HardwareItem({
    required this.reference,
    required this.name,
    required this.category,
    required this.quantity,
    this.lengthMm,
    required this.sectionId,
    this.usageIds = const [],
    this.ruleDescription,
  });
}

/// Whether a [HardwareItem] is a structural metal piece or a sealing
/// gasket/accessory. The split mirrors the natural workshop ordering
/// (paumelles + cremone + equerres on one side of the bench, joints and
/// weather strips on the other) and lets the BOM dialog render the two
/// as distinct sections without two parallel item models.
///
/// `hardware` covers structural pieces: paumelles, cremone, equerres,
/// gaches, equerre a pion, verificateurs, etc.
/// `accessory` covers gaskets and similar: joints de battue, joints de
/// vitrage, joints brosse, weatherstripping, etc.
enum HardwareCategory { hardware, accessory }
