/// How a [Construction]'s [Section]s are arranged relative to each other.
///
/// Section order alone (see `Section.order`) is enough to sequence sections
/// but not enough to say which of the construction's two dimensions they
/// subdivide -- "fixe + ouvrant" could mean two sections side by side
/// (widths sum, heights match) or stacked top to bottom (heights sum,
/// widths match). This field makes that explicit rather than assuming one
/// direction silently.
///
/// Deliberately not paired with x/y coordinates yet -- ordered sections
/// plus a single layout direction are enough to derive positions for
/// simple linear (1D) layouts. A 2D grid (e.g. for curtain walls) is a
/// separate, larger model change and is out of scope here.
enum SectionLayoutDirection { horizontal, vertical }
