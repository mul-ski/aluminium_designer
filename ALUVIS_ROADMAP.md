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
| **C4a `feat(catalog): ProfileSystemMetadata + DimensionLimit models`** (typed advisory fiche: depth options, glazing range, tri-state thermalBreak, notes, source citation, dimension envelopes; `metadata` on ProfileSystem, key omitted when null in JSON; round-trip tested) | 306d53b | analyze clean; full suite 338/338 |
| **C4b `feat(catalog): seed verified Maghreb Extrusion Série 14600 from official PDF`** (clean-slate: all name-only placeholders removed from seed; 38 profiles transcribed from the client PDF's PROFILOSCOPE sheets with per-page citations in docs/VERIFIED_SOURCES.md; 0 = not labeled, thermalBreak null = not stated; débitage formulas documented but NOT encoded — engine can't route 14 621 vs 14 631 by reference; merge stays add-only) | c6989d4 | analyze clean; full suite 340/340 |
| **C4c `feat(catalog): 'Fiche système' metadata + dimension-limits editor`** (ProfileSystemMetadataPanel via picker's new Fiche système button; tri-state thermal break; limit rows with optional opening type; incomplete rows dropped on save; empty form clears metadata to null) | db0f520 | analyze clean; full suite 345/345 |
| **C4d `feat(editor): advisory dimension-limit warnings from the fiche système`** (`checkDimensionLimits`: envelopes are alternatives — warn only when EVERY applicable envelope is exceeded; opening-type-scoped limits; banner under geometry width/height in calculation-banner styling; never blocks editing/calculation) | 7f3d9b2 | analyze clean; full suite 354/354 |
| fix `fix(project): add construction deletion workflow` (per-construction delete on workspace cards with confirmation, id-keyed removal, immediate persist; ProjectWorkspaceScreen gains the editor's store-DI seam for hermetic widget tests) | 105fa47 | analyze clean; full suite 361/361 |
| **C5a `feat(calc): ProfileReferenceCondition`** (reference-keyed rule routing; set form mirrors débitage rows that group references sharing a formula; removes the C4b blocker -- 14 621 vs 14 631 now distinguishable) | 89abea1 | analyze clean; full suite 365/365 |
| **C5b `feat(calc): first real manufacturer rule set`** (meSerie14600RuleSet = p. 24 débitage "2 vantaux" column as 8 role-scoped rules: dormants 14 617/627 2+2×(L;H), montants 14 622/623/632/633 2×(H−74), traverse 14 621 4×(L−64)/2 with fixed(2)/placement mapping; registered + seed ruleSetId switched; ledger encoding-status updated in-commit) | b833c77 | analyze clean; full suite 377/377 |
| **C5c `test(calc): end-to-end débitage proof`** (2000×1500 coulissant unit through calculateConstructionCuts reproduces p. 24 exactly: 8 cuts, 10 pieces, provenance cites p. 24; negatives: 14 631 → issue, vantauxCount 3 → zero cuts) | ad6090d | analyze clean; full suite 380/380 |
| **fix(calc): coulissante gating + qa-review fixes** (qa-review verdict CHANGES REQUIRED → all items addressed: OpeningTypeCondition(coulissante) on all rules -- non-coulissant 2-vantaux sections can no longer receive real cuts; angle-derivation note reaches ruleDescription; negative-dimension pin without invented clamping; quantity composition test; migrated-install divergence recorded in ledger). Re-review verdict: APPROVE | 5901e41 | analyze clean; full suite 383/383 |
| `test(calc)` pin derived-angle provenance on every me-14600 rule (qa-review optional hardening) | b15a08f | full suite 384/384 |

Suite size history: 119 → 242 (through boundary drag) → 244 (containment fix)
→ 259 (after M1) → 275 → 279 → 283 → 289 → 295 → 299 (through label editing)
→ 307 (after calculation C1) → 319 (after calculation C2) → 336 (after
calculation C3) → 338 (C4a) → 340 (C4b) → 345 (C4c) → 354 (after
calculation C4) → 361 (deletion fix) → 365 (C5a) → 377 (C5b) → 380 (C5c)
→ **384** (after C5 fixes).

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
- Seeded fabrication data must trace to an identified source document,
  cited in `docs/VERIFIED_SOURCES.md`. Absence means unknown: `0` in
  `Profile.width/depth/weightPerMeter` = not stated on the sheet (never a
  measured zero); `thermalBreak: null` = never stated (≠ false); profile
  types follow the source sheet's own headings, never inferred roles.
- The Série 14600 débitage formulas (p. 24 of the source PDF) were
  deliberately NOT encoded as a `SystemRuleSet` through C4b–C4e: the rule
  engine selected by ProfileType + section conditions only and could not
  distinguish 14 621 from 14 631 nor gate on configuration. **Superseded
  in C5** for the "2 vantaux" coulissante column: `meSerie14600RuleSet`
  encodes dormants 14 617/627, montants latéraux and traverse 14 621 via
  ProfileReferenceCondition + VantauxCountCondition +
  OpeningTypeCondition + role conditions. STILL unencoded (honest
  noRuleMatched): +46 dormant variants, traverse 14 631, montants
  centraux (mullion row), chicane 14 624, and the 3/4-vantaux columns --
  each needs its own quantity-semantics analysis before encoding.
- Débitage quantities follow the per-placement law: the table counts
  pieces per unit, AluVis rules count pieces per matched placement.
  Role-scoped one-piece positions get fixed(1) (unit totals emerge from
  placements); a top/bottom traverse placement spans both leaves' track
  halves so it yields fixed(2). Never encode whole-unit counts into
  fixedCount -- that double-counts once role-scoped usages iterate.
- Real rules carry NO SystemCondition: rule-set resolution already
  scopes by systemId; matching on Construction's display-name strings
  would silently break cuts when those fallback fields drift. Scope is
  enforced by what the rules DO require (vantaux count, opening type,
  exact references, roles).
- Cut angles for the me-14600 set are DERIVED from the descriptif's
  onglet assembly statement (pp. 1-3, which names dormants) extended to
  sash members -- every rule description says so, keeping p. 24 (lengths
  only) un-overstated at cut level. No minimum-dimension clamping is
  invented: sub-deduction dimensions evaluate arithmetically; the p. 27
  certified envelopes remain the advisory guardrail.
- Add-only seed merging means installs that persisted me-14600 with
  `ruleSetId: 'generic-placeholder'` keep placeholder behaviour until
  the system is re-selected/updated via the catalog UI; fresh installs
  get the real rule set (recorded in docs/VERIFIED_SOURCES.md).
- Dimension limits are advisory envelopes, never calculator inputs.
  Multiple envelopes are alternatives (a construction fitting ANY one is
  inside the documented range); the editor warns only when EVERY
  applicable envelope is exceeded. Unknown limits never read as
  "within limits".

## OpenCode project environment (permanent)

Configured under `.opencode/` (see `AGENTS.md` for when to load what):

- `skills/aluminium-domain/` — domain rules: verified data, unknown markers,
  traceability, architecture boundaries.
- `skills/calculation-verification/` — mandatory procedure for
  calculation-engine changes.
- `skills/source-verification/` — procedure for adopting external
  manufacturer/technical facts (feeds `docs/VERIFIED_SOURCES.md`).
- `skills/flutter-qa/` — validation gate incl. editor/canvas/rendering
  specifics.
- `agents/qa-review.md` — read-only review SUBAGENT for independent
  pre-commit review; cannot edit, commit, or push.

## Current next milestone

Calculation series C1–C3, verified-catalog series C4, and **C5 (first real
manufacturer-backed calculation) are COMPLETE**: `meSerie14600RuleSet`
computes the Série 14600 "2 vantaux" débitage column end-to-end from the
seeded catalog, qa-review APPROVED. Documented candidates, not scheduled:

- extend me-14600 rules to the 3/4-vantaux columns and remaining rows
  (traverse 14 631, +46 dormants, mullions, chicane) -- formulas all
  verified in docs/VERIFIED_SOURCES.md; each column needs its own
  quantity-mapping analysis;
- editor affordance so an existing construction can adopt a newly
  registered rule set (migrated-install divergence);
- inertia (IXX/IYY) fields for profiles (values transcribed in
  docs/VERIFIED_SOURCES.md, no model field yet);
- glass/hardware/accessory architecture and ProfileCut → component
  generalization (deferred until a second component domain / verified
  data exists).
