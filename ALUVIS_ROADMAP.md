# ALUVIS Roadmap

Conventional commits pushed to `origin/main`, one validated milestone at a
time. Every milestone gate: `flutter analyze` clean, focused tests, full
suite green, diff inspected, then commit + push + this file updated.

## Completed milestones

| Milestone | Commit | Validation |
|---|---|---|
| Repo audit → editor architecture refactor | bfca089 | analyze clean, suite green at the time |
| Construction width/height ID fix | 9f8a38a | analyze clean, suite green |
| Hermetic editor tests (DI `_StubCatalogStore`, rename to `construction_editor_screen_test.dart`) | a7a05e6, 525f6be, c8c23af | suite unblocked standalone |
| EditorViewport foundation (single uniform transform) | 26a9b67 | viewport unit tests |
| Canvas integration of live viewport | 360edde | screen tests |
| Undo / redo | 8551576 | controller + widget tests |
| Model-space snapping foundation | c67eafc | snap engine tests |
| Narrow-section paint crash fix | 25a6cbe | painter regression tests |
| Boundary-move geometry/controller | 9cc683c | boundary_manipulation tests |
| Boundary drag interaction | 13af9c3 | integration tests |
| Canvas containment fix + dark palette (superseded visually by workshop grid milestone; clip/repaint fixes retained) | e913633 | pixel-verified containment, 244 tests |
| **M1 Workshop drafting: pure drafting-grid math** (`selectMinorGridInterval` 1-2-5 adaptive selection, `gridLinesForRange` origin-aligned visible-line enumeration) | b224512 | analyze clean; drafting_grid_test 15/15; full suite 259/259 |
| **M2 Calculation honesty C1a: quantity composition** (`ProfileUsage.quantity × rule.fixedCount` reaches cut output; placeholder rules rebased fixed(2)→fixed(1) per-usage semantics) | 4e4359f | analyze clean; full suite 302/302 |
| **C1b `feat(calc): structured calculation outcome`** (`CalculationOutcome{cuts, issues}`, `ProfileUsageIssue{profileUsageId, reason ∈ profileUnresolved/noRuleMatched}`; controller exposes `calculationIssues`; envelope is the future multi-domain result seed) | 1e47c5f | analyze clean; full suite 304/304 |
| **C1c `feat(editor): cut provenance + skip diagnostics in banner`** (`ProfileCut.ruleDescription` dim second line; issues block listing every skipped usage with its reason; end-to-end Calculer test via catalog stub) | eb29c8a | analyze clean; full suite 307/307 |
| **C2a `feat(calc): pure per-profile cut aggregation`** (`aggregateProfileTotals`/`sumProfileTotals`: pieces = Σcut.quantity, metres = Σ length×quantity, weight only from positive user-entered weightPerMeter; first-encounter order; the BOM derivation seed) | 2326a0c | analyze clean; full suite 318/318 |
| **C2b `feat(editor): totals block in results banner + piece-count badges`** (Récapitulatif per-profile lines + grand total between groups and issues; weight suffix omitted when unknown; structure badges now count physical pieces not cut rows) | 51d7d93 | analyze clean; full suite 319/319 |
| **C3a `feat(calc): catalog-aware calculation fingerprint`** (`catalogCalculationFingerprint`: resolved ruleSetId + referenced profiles' id/type/weightPerMeter, lexically sorted; `'no-system'` sentinel; display-only fields and unreferenced profiles excluded) | 7d086b3 | analyze clean; full suite 328/328 |
| **C3b `feat(editor): reconcile calculation staleness on catalog changes`** (dual-fingerprint snapshot at calculate(); shared reconciler for undo/redo jumps AND setCatalog; picker-side profile edits/deletes now correctly stale results) | 8c5bbd9 | analyze clean; full suite 336/336 |

Suite size history: 119 → 242 (through boundary drag) → 244 (containment fix)
→ 259 (after M1) → 275 → 279 → 283 → 289 → 295 → 299 (through label editing)
→ 307 (after calculation C1) → 319 (after calculation C2) → **336** (after
calculation C3).

## In progress

Workshop Drafting Grid + Configurable Snapping + Precision Dimensions:

- [x] M1 `feat(editor): add pure drafting-grid math` — b224512
- [x] M2 `feat(snap): configurable snap sources and priority` — f7a22da
      (SnapTargetKind.grid, SnapConfig, snapToGrid, resolveSnapPosition;
      legacy geometry-only behavior preserved; suite 275)
- [x] M3 `feat(editor): per-editor drafting settings with toolbar controls` —
      6d134e8 (EditorDraftingSettings ChangeNotifier, screen-owned; 'Aimanter'
      + 'Afficher la grille' toolbar toggles; settings listener wiring caught
      by tests; suite 279. Increment picker DEFERRED to M5 per no-inert-UI
      rule.)
- [x] M4 `feat(editor): workshop grid rendering and light canvas palette` —
      bc3bc9d (painter showGrid layer via M1 math under geometry; off-white
      ground 0xFFFAFBFC; light-tuned palette; pixel-sampled verification
      harness run then deleted; suite 283).
- [x] M5 `feat(editor): grid-aware boundary snapping` — 9352f6c (drag
      consumes resolveSnapPosition with session settings; dashed-vs-solid
      ActiveSnap; geometry-beats-grid tie proven end-to-end at 1500 mm;
      increment picker shipped functional + disabled while snap off;
      suite 289).
- [x] M6 `feat(editor): precision dimension editing hardening` — 2b1fe21
      (French decimal-comma parsing across all four dimension mutators;
      exact-decimal/comma/whitespace tests; non-positive section edits
      create no mutation/no undo entry; screen-level exact-750 workflow
      with undo-chain proof; suite 295).

- [x] `feat(editor): direct dimension-label editing from the canvas` —
      c71981f (overall width/height labels are click-to-edit: pure
      dimensionLabelTargets math mirroring paint anchors; canvas callback;
      Geometry-stage focus + scroll-to-field via screen-owned FocusNodes;
      per-section labels deliberately left as selection gestures; suite
      299).

FUTURE (documented, not scheduled): dedicated exterior per-section
dimension chips (click-to-edit section widths without stealing the
selection gesture); grid/snap settings persistence if a preferences
architecture ever lands.

## Decisions on record

- Grid/snap-increment are interaction aids, NOT fabrication rules; never fed
  into calculator inputs or persisted Construction JSON.
- Drafting settings are editor-session state (no persistence architecture
  exists; smallest sensible scope).
- Snap priority: nearest model distance wins; exact tie geometry > grid;
  two-way geometry tie -> lower position (existing convention).
- Major grid line = every 5th minor across the whole 1-2-5 series.
- Tolerance stays screen-perceived (`kSnapTolerancePx / scale`); increment is
  pure model-space mm.
- Cut quantity composition: `usage.quantity × rule.quantity.fixedCount`.
  Rules are per-placement ("one matched usage yields N pieces");
  placeholder rules are fixed(1) per usage -- rebased from legacy
  whole-construction fixed(2), which double-counted once role-scoped
  usages became the iteration source. Still explicitly placeholder, no
  manufacturer numbers claimed.
- Calculation result envelope is `CalculationOutcome{cuts, issues}`: a
  skipped usage is a diagnostic (`ProfileUsageIssue`, reason
  profileUnresolved/noRuleMatched), never silent and never an exception;
  hard failures (missing dimensions, ambiguous rules) keep throwing.
  Glass/hardware/accessory domains later add component lists to this
  envelope rather than widening the calculator's return type again.
- Cut provenance: `ProfileCut.ruleDescription` copies the producing rule's
  description verbatim when present; never invented.
- BOM summaries are derived from `CalculationOutcome` by pure aggregation
  (`cut_aggregation.dart`), never hand-maintained UI state. Weight is
  shown only when derivable from the user-entered `weightPerMeter`
  (positive value); unknown weight stays absent, never estimated.
- Calculation staleness is dual-fingerprint: draft inputs (dimensions,
  systemId, usages) plus catalog state consumed by the engine
  (`catalogCalculationFingerprint`: resolved ruleSetId + referenced
  profiles' id/type/weightPerMeter). Display-only catalog fields
  (name/reference/width/depth) and unreferenced profiles NEVER invalidate
  -- same rationale as the draft-rename precedent. If user-authored rule
  sets ever land, their content hash joins this fingerprint.

## Current next milestone

Calculation series C1 (honesty), C2 (derived totals récapitulatif), and C3
(catalog-aware staleness) are COMPLETE. Documented candidates, not
scheduled: real `SystemRuleSet` per manufacturer (EXTERNAL VERIFICATION
GATE: needs verified fabrication data before any numbers exist);
`ProfileSystem` metadata field for already-verified-but-unrepresentable
Cuzco 713 OM specs; glass/hardware/accessory architecture and ProfileCut →
component generalization (both deferred until a second component domain /
verified data exists).
