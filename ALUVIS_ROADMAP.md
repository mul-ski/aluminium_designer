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
| **C6a `feat(calc): remaining verified 2-vantaux débitage rows`** (rule set 8→15: traverse 14 631 4×(L−85)/2 fixed(2)/placement; dormants 14 618/628/626 2+2×(L+46;H+46) four roles; montant central 14 619/620/630 2×(H−74) intermediate fixed(2)/placement; mullions 14 650/14 643 + chicane + all 3/4-vantaux stay honest noRuleMatched; ledger now six of seven rows; double-équerre 14627-vs-618 note tension recorded verbatim). qa-review verdict before commit: APPROVE | 24eaffa | analyze clean; full suite 396/396 |
| **C6b `feat(calc): verified 3-vantaux (avec fixe) débitage column`** (rule set 15→30 under exact VantauxCountCondition(3): traverses 14 621 6×(L−25)/3 and 14 631 6×(L−47)/3 with fixedCount(3)/placement spanning all three panels; dormant/montant/mullion rows duplicated per column rather than relaxing verified gates; modeling decision on record: one ouvrant coulissante section vantauxCount=3, fixed-third position NOT represented — not stated by source, affects no cut length; plain-3v indistinguishable, undocumented by table. qa-review verdict before commit: APPROVE) | 494b131 | analyze clean; full suite 408/408 |
| **C6c `feat(calc): verified 4-vantaux débitage column — table complete`** (rule set 30→46: traverses 14 621 8×(L−60)/4 and 14 631 8×(L−106)/4 fixedCount(4)/placement; latéraux doubled to 4/unit via DERIVED fixed(2)-per-side mapping; central mullion fixed(4); chicane 14 624 H−92 as the one deliberate no-role-condition rule — source states no position, role gating would fabricate one; collision-free by construction. Ledger heading corrected; p. 24 table now FULLY encoded). qa-review verdict before commit: APPROVE | e5cfd99 | analyze clean; full suite 419/419 |
| **A `test(editor): pin multi-vantaux reachability for coulissante sections`** (audit verdict recorded: BOTH live steppers — Sections-stage properties panel and add-section dialog — produce any count ≥1 for every ouvrant type, so the encoded coulissante 3v/4v débitage columns are UI-reachable with zero changes; controller coalescing + widget stepping pinned by tests) | 62272c5 | analyze clean; full suite 421/421 |
| **B `feat(catalog): adopt real built-in rule sets on load`** (closes the recorded migrated-install divergence: seed merge runs once per install, so pre-C5 installs kept placeholder cuts forever; adoptBuiltInRuleSets = narrow exception refreshing ONLY ruleSetId of present built-in systems still on the placeholder, invoked from CatalogStore.load on every load with identity-based save-on-change; user-created systems/user rule choices/deleted records untouched; store test asserts persistence via raw catalog.json). qa-review cycle: CHANGES REQUIRED → fixes → APPROVE | 2803d6a | analyze clean; full suite 428/428 |
| **C `feat(catalog): verified profile inertia fields for Série 14600`** (`Profile.inertiaIxxCm4/inertiaIyyCm4` doubles, 0 = not stated, default params keep all call sites compiling; JSON always-writes/tolerant-reads for legacy compat; all 20 ledger-verified pairs seeded verbatim — full map pinned in tests; 14 650's axis-less "69.47" stays 0/0 as a recorded open verification item; p.23 assembly combinations remain excluded; fingerprint UNCHANGED with exclusion rationale documented — display-only until a rule consumes it; profiles-panel subtitle shows inertia only when stated). qa-review verdict before commit: APPROVE (follow-ups applied: all-20-pairs pinning, format) | e20a4dc | analyze clean; full suite 435/435 |

Suite size history: 119 → 242 (through boundary drag) → 244 (containment fix)
→ 259 (after M1) → 275 → 279 → 283 → 289 → 295 → 299 (through label editing)
→ 307 (after calculation C1) → 319 (after calculation C2) → 336 (after
calculation C3) → 338 (C4a) → 340 (C4b) → 345 (C4c) → 354 (after
calculation C4) → 361 (deletion fix) → 365 (C5a) → 377 (C5b) → 380 (C5c)
→ 384 (after C5 fixes) → 396 (after C6a) → 408 (after C6b) → 419
(after C6c) → 421 (A) → 428 (B) → **435** (after C).

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
  in C5+C6a+C6b+C6c**: the COMPLETE p. 24 table (all three configuration
  columns, all seven rows) is now encoded in `meSerie14600RuleSet` via
  ProfileReferenceCondition + exact VantauxCountCondition +
  OpeningTypeCondition + role conditions, with honest noRuleMatched for
  everything outside the documented cells.
- "3 vantaux (avec fixe)" modeling decision (C6b): represented as ONE
  ouvrant coulissante section with vantauxCount = 3. The source does
  not state which third of the unit is fixed, its rail arrangement, or
  the fixed panel's framing membership -- and no encoded cut length
  depends on any of that -- so fixed-third position is deliberately NOT
  represented. A hypothetical plain-3v unit is undocumented by the
  table and indistinguishable in this model; the manufacturer's column
  header defines the 3-vantail configuration as the avec-fixe one.
  Dormant/montant/mullion rules are DUPLICATED per vantaux column:
  their formulas coincide at 2 and 3 vantaux, but exact-column gating
  ties every rule to its printed row instead of relying on that
  coincidence (relaxing verified gates to >=2 was rejected).
- Débitage quantity mappings are per-unit totals decomposed into
  placements by a documented spanning doctrine: traverses fixed(n) per
  top/bottom placement where n = panel count; latéraux fixed(2) per
  side at 4 vantaux (both leaves on that side); central mullion
  fixed(2)/(4) on the single intermediate placement. These
  decompositions are DERIVED from printed totals, never presented as
  printed statements. The chicane 14 624 rule is the one deliberate
  exception to role gating: the source states no position for it
  (fabricating one would violate domain law); it is collision-free by
  construction as the only appliesTo-other rule.
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

Calculation series C1–C3, verified-catalog series C4, C5 (first real
manufacturer-backed calculation), **C6a+C6b+C6c (COMPLETE Série 14600
débitage table) are COMPLETE**: `meSerie14600RuleSet` now encodes every
documented cell of the p. 24 table across all three configuration
columns, qa-review APPROVED before each commit. Documented candidates,
not scheduled:

- C7: first verified Sepalumic system — externally gated on official
  fabrication documentation (Coulissant 8800 brochure is the candidate
  source to inspect; débitage/profile references not public otherwise);
- C8: Targa Menara — fully blocked: manufacturer identity itself
  unverified online; needs external documentation;
- editor affordance so an existing construction can adopt a newly
  registered rule set (migrated-install divergence);
- inertia (IXX/IYY) fields for profiles (values transcribed in
  docs/VERIFIED_SOURCES.md, no model field yet);
- glass/hardware/accessory architecture and ProfileCut → component
  generalization (deferred until a second component domain / verified
  data exists).
