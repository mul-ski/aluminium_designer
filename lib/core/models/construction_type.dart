/// The broad category of construction being designed.
///
/// This is a coarse classification used for display, filtering, and future
/// rule conditions (e.g. a rule that only applies to curtain walls). It is
/// deliberately small and closed — new categories are rare enough that a
/// plain enum is appropriate, unlike profile systems or opening
/// configurations which must stay data-driven.
enum ConstructionType { window, door, curtainWall }
