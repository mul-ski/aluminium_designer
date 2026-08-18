library;

import '../models/cut.dart';
import '../models/section.dart';

/// Groups [cuts] by `ProfileCut.sectionId`, in the order each section id
/// is first encountered in [cuts] (i.e. calculation order -- the same
/// order `ConstructionCalculator.calculate` iterates `Construction
/// .profileUsages` in). Not sorted by `Section.order`, since a cut whose
/// `sectionId` doesn't resolve to any current `Section` (stale/deleted
/// section -- see `ProfileCut.sectionId`'s doc comment) has no
/// `Section.order` to sort by; keeping calculation order avoids needing a
/// special-cased position for that group.
///
/// Pure and framework-free like the rest of `lib/core/logic/` -- this is
/// display grouping, not something `ConstructionCalculator` itself has
/// an opinion about (see that method's doc comment on why grouping is a
/// caller/display concern).
Map<String, List<ProfileCut>> groupCutsBySectionId(List<ProfileCut> cuts) {
  final grouped = <String, List<ProfileCut>>{};
  for (final cut in cuts) {
    grouped.putIfAbsent(cut.sectionId, () => []).add(cut);
  }
  return grouped;
}

/// `'Section ${order + 1}'` for [sectionId] if it resolves against
/// [sections], matching the label convention already used by the
/// construction editor's structure tree -- or a distinct fallback label
/// when it doesn't resolve, so a stale reference reads as "this section
/// is gone", not silently as some other section or a blank heading.
String sectionLabelForCutGroup(String sectionId, List<Section> sections) {
  for (final section in sections) {
    if (section.id == sectionId) return 'Section ${section.order + 1}';
  }
  return 'Section supprimée';
}
