/// The stages of the construction editor's design workflow: General ->
/// Geometry -> Sections.
///
/// Purely a UI concept layered on top of the editor's single draft
/// [Construction] -- the stage never gates what data exists or what Save
/// persists; it only decides which subset of the *same* draft's fields the
/// properties panel currently shows, and which item is highlighted in the
/// left nav. Order in this enum is the canonical Back/Next order used by
/// `ConstructionEditorController.goNext`/`goBack`.
enum EditorStage { general, geometry, sections }
