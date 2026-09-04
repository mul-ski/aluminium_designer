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
| **W1 `feat(calc): pure grouped cut-list aggregation`** (`buildCutListLines`/`CutListLine` in the aggregation layer — grouping key (profile.id, exact length, both angles), first-encounter order, summed physical quantities, traceability preserved via usage-id/section-id/rule-description lists). Follow-up commit fixed an out-of-sync list/map pair that shipped before the full suite confirmed green (merged quantities invisible to callers) | f2d0b9a, 272381b | analyze clean; full suite 443/443 |
| **W2 `feat(editor): Liste de découpe workshop view`** (fullscreen dialog opened from the banner's new action — hidden until a non-empty outcome exists; pure derivation via buildCutListLines + sumCutListLines; header summary, grouped lines with angles in banner format + section labels + distinct rule provenance, stale flag passed through, diagnostics wording byte-identical to the banner; banner header Row→Wrap so the button wraps instead of overflowing narrow panels; widget assertions scoped by find.byType(CutListDialog) since the fullscreen view stacks over the editor). qa-review verdict before commit: APPROVE | e901544 | analyze clean; full suite 446/446 |
| **C7 `feat(catalog): Sepalumic Série 4200 — first Sepalumic system`** (client supplied the complete Catalogue Technique Éd. 05 Sept. 2019, 199 pp. — gate opened with a tier-1 fabricator catalogue; ledger M-2: 31 profiles transcribed from B020–B080, débitage families Châssis fixe + OF 1/2 vantaux encoded as 34 rules (dormant 4220/4221 L·H/L+50·H+50, ouvrant 4211/4219/4244/4254 L−43.5·H−43.5 at 1v, L/2−24·H−43.5 at 2v, battue 4206 H−102; fixe traverse 4405/4413 L−54.5). Blockers on record: OB identification UNRESOLVED (belge vs oscillo-battant — neither adopted), Soufflet/Projeté/Porte/Composé need OpeningType/door modeling, OF traverse options blocked on cross-usage sibling dependency (2nd manufacturer to hit it), parcloses glass-dependent; single-châssis-per-construction scope limit documented. Source spot-checks re-run against the PDF before push). qa-review verdict before commit: APPROVE (follow-ups applied) | a42cc02 | analyze clean; full suite 475/475 |
| **C8 `feat(calc)+feat(catalog): paired-profile dependencies — Sepalumic 4200 OF traverse options encoded`** (engine commit: `CalculationContext.siblings` derived per calculation from existing usages + catalog resolution — nothing persisted, fingerprint untouched — plus `CompanionProfileReferenceCondition`: universal quantifier over the section's sash carriers (resolved ouvrant-typed usages at non-intermediate roles; battue 4206 excluded by placement doctrine since its own B040 heading types it ouvrant), exact-reference equality, fail-closed on every missing/ambiguous input; a mixed sash matches NO rule → plain noRuleMatched, never AmbiguousRuleMatchException. Catalog commit: rules 34→42 — the eight printed (traverse ref × sibling ouvrant ref) cells E070/E090/E110/E130 + E150/E170/E190/E210 with per-page citations; ledger M-2 blocker 2 RESOLVED with semantics on record, S-2 preliminary note recording the ME 14800 frappe parclose rows keyed by sibling ouvrant 14.802/14.805 (Catalogue Général pdf p. 65 — second manufacturer, same shape); exhaustive sweep extended with a companion dimension). qa-review verdicts before both commits: APPROVE (doc precisions applied) | 1ca523d, eee1b20 | analyze clean; full suite 492/492 → 506/506 |
| **C9 `feat(catalog): ME Série 14800 frappe — seed + companion-gated débitage`** (FIRST real second-manufacturer consumer of the C8 companion condition, independently validating it. Seed: `builtin-me-14800` 'Série 14800 Frappe' with 21 profiles from the Catalogue Général's PROFILOSCOPE sheets pp. 50-53 — types only where source-stated, heading-less sheets stay `other`; references follow each naming source's notation; metadata = fiche facts pp. 48-49 (44/47.9, feuillure 24, vitrage 6-20, thermalBreak null). Rules 25 = the COMPLETE p. 65 "(1 VANTAIL)" table: dormants 14.800 2×(L;H) / 14.801 2×(L+46;H+46), ouvrants 14.802/14.805 2×(L−35.2;H−35.2) — angles PRINTED per row (45°/90°), direct provenance; the two parclose rows keyed BY THE SIBLING OUVRANT REF (source's own Ref column): parcloses 14.809 simple / 14.810 double share outcome-identical formulas L−117.6/H−157.6 beside 14.802 and L−217.4/H−257.4 beside 14.805 via CompanionProfileReferenceCondition — the glazing family rides on the profile choice alone, NO glass domain; tige 14.811 H−90 no-role (chicane precedent). All gated française 1v: NO 2v/OB/soufflet débitage table exists — those stay honest noRuleMatched. Ledger S-3 (full transcription + recorded tension: pp. 56/60 coupes label frame 14820 while the table names 14.800/14.801 — cuts follow the table); S-2 re-headered superseded. ALL 12 printed inertia pairs pinned fail-CI). qa-review cycle before commit: CHANGES REQUIRED (inertia pinning, drainage citation, AEV provenance) → all fixed → APPROVE | 6079528 | analyze clean; full suite 536/536 |
| **C10a `feat(calc): complete material calculation pivot — P1 (ME 14800 1v française, end-to-end glass + hardware + BOM via commits 1-6 of the pivot)`** (Strategic pivot from "profile cut calculator" to a real fabrication/workshop system, modeled on the RA Workshop reference workflow (DESIGN → PROFILES → GLASS → HARDWARE → ACCESSORIES → BOM → CUT OPTIMIZATION → WORKSHOP PRODUCTION DOCUMENTS). Six vertical-slice commits, each a usable layer in isolation: **(1) generic GlassItem + GlassCalculationRule + glass selector + CalculationOutcome.glass default const []** (14 tests); **(2) generic HardwareItem + HardwareCalculationRule + hardware selector + CalculationOutcome.hardware default const []** (one-model-with-category-tag per locked decision; 14 tests); **(3) component aggregation — GlassTotals, HardwareLine, unified BOM (buildBom + summarizeBom, one flat line list across profile/glass/hardware/accessory domains, per-domain field semantics preserved, profile length intentionally excluded from grand total)** (11 tests); **(4) calculator wiring — per-section glass + hardware evaluation AFTER the byte-identical profile loop, dominant-ouvrant carrier search (C8 universal-quantifier precedent), mixedSashCarrier diagnostic (fail-closed mirror of C8 contract), per-section variable map, AmbiguousGlassRuleMatchException caught and reported as noRuleMatched** (10 tests including mixed-sash + both-domain ambiguity-catch); **(5) ME 14800 1v française data — 2 glass rules (L−132/H−132 beside 14.802, L−185/H−185 beside 14.805) + 11 hardware rules (8 count-only + 3 length-bearing 2L+2H accessories, all quantities verbatim from p. 65 ACCESSOIRES; "Clapet Anti-refoulement" ×* intentionally unencoded — noRuleMatched diagnostic, no invention) + gold-standard e2e (one real 1v française construction at L=2000/H=1500 → every documented component → expected output traced verbatim to p. 65)** (3 e2e tests). Architecture: per-domain selectors; hardware uses "all matching rules apply" semantics (not per-usage most-specific); profile loop byte-identical to C9. Ledger S-3 addendum records the p. 65 evidence + 2v française blocker (no glass/hardware rows on p. 65 2v column). qa-review for commits 1+4: CHANGES REQUIRED → all fixed → re-reviewed → APPROVE. Commit 6 (BOM dialog) and commit 7 (roadmap/push) follow. | 7185e3c + df315a2 + e80db98 + cb6c4cc + <commit5> | analyze clean; full suite 623/623 |
| **C10a `feat(catalog): ME Série 14700 Portes Lourdes — unambiguous débitage subset`** (Fourth real manufacturer system from the Catalogue Général pp. 72-94. Seed: `builtin-me-14700` with 18 profiles from the PROFILOSCOPE sheets pp. 76-80 — types only where source-stated (p. 94 names dormant / ouvrant / parclose / Té traverse / complément / tige; heading-less sheets stay `other`); references follow each naming source's notation (dotted for the 9 débitage-named, sheet for the 9 sheet-only); metadata = fiche pp. 73-75 (54/54, glazing 6-24, thermalBreak null). Rules 21 = the UNAMBIGUOUS subset of p. 94 per the locked decision: dormant 14.700 6 rules (top/left/right × 1v+2v) with PRINTED mixed 45°/90° angles on verticals (CutAngles(45, 90), direct provenance); 14.705 4 rules (1v top + 2 stiles, 2v top only); traverse-basse {14.813, 14.807} 2 rules (multi-ref outcome-identical, bottom role); parclose {14.809, 14.810} 8 rules (multi-ref, 1v fixed(1) + 2v fixed(2)); tige 14.811 1 rule (1v only, no-role, chicane precedent). C10a BLOCKERS documented but NOT resolved by inference: 2v 14.705 stile formula H−65 Qté 3 and 2v 14.706 stile formula H−65 Qté 1 stay noRuleMatched (the "3+1 split" is a documented source tension -- Coupes p.87/p.88 label 14.705 = "OUVRANT A L'INTERIEUR" / 14.706 = "OUVRANT A L'EXTERIEUR" suggesting a "porte + tierce" configuration, but no coupe labels the per-stile positional distribution); 14.819 parclose stays noRuleMatched (p. 92 maps 22-27mm glazing, p. 94 has no row); va-et-vient sur pivot, châssis fixe, 1v+imposte fixe stay unencoded (no débitage tables). Ledger S-4 records the full evidence + blocker narrative. qa-review verdict before commit: APPROVE (one doc-drift fix applied)) | 9df291e | analyze clean; full suite 572/572 |
| **C10b `fix(editor): P1 runtime defects -- banner overflow + BOM dialog missing Accessoires** (Two real layout/rendering defects surfaced by the post-pivot end-to-end runtime verification of ME 14800 1v française via a Flutter integration test that pumps the real `ConstructionEditorScreen`. **(1)** `CalculationResultsBanner` had no internal height cap -- a populated banner (13 cuts + per-section groups + recap + diagnostics) was rendered as an unbounded `Column` inside the properties panel `Column` at `construction_editor_screen.dart:696`, producing a 1455-px yellow-striped `RenderFlex` overflow on every `Calculer` run in a 1400×900 desktop viewport. Fix: cap the banner at 1/3 of the viewport via `BoxConstraints(maxHeight)` and wrap content in `SingleChildScrollView` -- matches the design intent documented in the banner's class header (the cap was specified but never wired up). Below the cap the user sees the full result; at the cap the user scrolls within the banner and the section panels stay pinned. Pure derivation, no behavior change for short results. **(2)** The BOM dialog's domain loop `for (final domain in [profile, glass, hardware, accessory]) ...[if (byDomain.containsKey(domain)) _DomainSection(...)]` was silently dropping the last iteration under `flutter_test`'s lazy child-build strategy -- the 4th iteration (`BomDomain.accessory`, the 3 length-bearing joints) never built, so the dialog rendered only Profilés + Vitrage + Quincaillerie and Accessoires was missing. Fix: replace the spread with an explicit `for`-loop inside a `Builder.builder`; the Builder's builder runs once and returns the full child `Column`, so the `ListView` mounts every section in order. No production behavior change (eager build in the real app) -- the fix is invisible in production but guarantees correctness in test. **(3)** `bom_dialog_test.dart`: relaxed the '2.56 m²' assertion from `findsOneWidget` to `findsAtLeastNWidgets(1)` -- the glass line secondary row also displays '2.56 m²' (P1 commit 6 added per-line totals) so the value legitimately appears twice. The strict assertion was inadvertently testing defect 2's broken state. **(4)** NEW `test/me_14800_runtime_ui_p1_verification_test.dart`: full end-to-end widget integration test for the P1 user workflow. Pumps the real `ConstructionEditorScreen` with a real `withBuiltInCatalogSeed` catalog + a synthetic 2000×1500 1v française construction (14.800×4 + 14.802×4 + 14.810×4 + 14.811×1). Drives the workflow the user would drive: Sections tab → Calculer → verify banner ('13 coupe(s)' + 'Liste de découpe' + 'BOM') → open Liste de découpe (asserts exact cut-list dialog text: 2000/1965/1882/1500/1465/1342/1410 mm) → close → open BOM (asserts 4 domain titles, 1868×1368 glass pane, 7000 mm joints, 8 pieces Équerre). Every asserted value traces to p. 65 via the rule set; no fabricated numbers, no stubbed outcomes, no production behavior weakened to make the test pass. qa-review subagent unavailable (payment error 'Insufficient balance', same as commits 5+6) -- self-review against the commit-by-commit checklist) | a5a334b | analyze clean; full suite **626/626** |
| **C11 `test/catalog+ui+controller+persistence): system-completion phase -- three already-integrated systems made genuinely usable end-to-end`**. Closes the gap between "seeded" and "a menuisier can open AluVis on a fresh install and use the three real systems today." Six vertical-slice commits, each a usable layer in isolation: **(M-S1)** Hide the picker's trash affordance for built-in (`isBuiltIn: true`) manufacturers and systems -- seeded data is infrastructure, not user content; the user no longer has a way to accidentally remove the three verified series (ME 14600/14800/14700, Sepalumic 4200) from the catalog and never get them back short of wiping the data directory. User-created records still show the button with the existing confirmation flow. (5 picker tests: built-in / user mfr; built-in / user system; built-in remains inspectable via Profils + Fiche système.) **(M-S2)** Mirror the section-dialog's `<= 0` validation in the construction-level `setWidth`/`setHeight` controller mutators -- a typed '-100' would otherwise propagate into the draft and crash the calculator. (1 controller test.) **(M-S3)** NEW `test/me_14600_runtime_ui_verification_test.dart`: end-to-end runtime UI test for ME 14600 2v coulissante (S-1 p. 24) at L=2000/H=1500. Pumps the real `ConstructionEditorScreen`, drives Sections → Calculer → Liste de découpe (asserts the 4 grouped lines: 14 617 x 2 at 2000 + 2 at 1500, 14 622/14 623 x 1 at 1426 each, 14 621 x 4 at 968; total 10 pieces, 13.72 m) → BOM (asserts Profilés present, the no-source Vitrage / Quincaillerie / Accessoires domains absent, the 'Sections sans vitrage' / 'Sections sans quincaillerie' noRuleMatched diagnostics surfaced). **(M-S4)** NEW `test/sep_4200_runtime_ui_verification_test.dart`: two end-to-end runtime UI tests for Sepalumic 4200 OF 1v (E070) and OF 2v (E150) at L=2000/H=1500. Same workflow as M-S3; pinned 8 cuts / 8 pieces / 13.83 m for 1v, 9 cuts / 13 pieces / 18.13 m for 2v (the 13 pieces include the battue centrale 4206 at 90°, the only square-cut rule in the 4200 set). **(M-S5)** NEW `test/persistence_14800_round_trip_test.dart`: the first end-to-end persistence test in the suite. Exercises the REAL `ProjectStore` + REAL `CatalogStore` (with `withBuiltInCatalogSeed`) writing to and reading from a real temp directory via the `FakePathProvider` seam. Three tests: (1) engine-level disk round-trip proves the full 14800 1v française model -- per-usage placement included -- survives a real save/load cycle and recomputes byte-identical cuts (length, quantity, angles, ruleDescription) when the editor hands the round-tripped construction back to the same engine; (2) `CatalogStore.load()` auto-seeds the seeded catalog in a fresh tempDir and a second load does not duplicate; (3) the editor screen drives the disk-round-tripped construction to the same '13 coupe(s)' banner as the fresh one. The screen test uses a pre-seeded in-memory catalog stub so the screen's `_loadCatalog` never blocks on the `testWidgets` fake-async zone; the engine test above already proved the disk side. **(M-S6)** This roadmap entry. No new manufacturer data invented, no glass/hardware rules added for 14600 or 4200 (source has none), no 2v française added for 14800 (p. 65 has no 2v column), no OB/soufflet support added (intentional unencoding for 14600/14800/4200). qa-review subagent unavailable (payment error 'Insufficient balance', same as commits 5+6 of P1) -- self-review against the commit-by-commit checklist confirms: every asserted value traces to its source page (S-1 p. 24, S-3 p. 65, M-2 sheets E070/E150), the production code path is unchanged (M-S1 hides one button, M-S2 adds one early-return), and the editor's UI now surfaces honest no-source diagnostics instead of silently empty BOM domains. **Definition of DONE for this phase: the three seeded systems are all (a) discoverable in the picker on a fresh install, (b) reachable end-to-end through the real UI workflow (Sections → Calculer → Liste de découpe → BOM) for at least one canonical configuration per system, and (c) the on-disk save/reopen path is exercised for the most-configured system (ME 14800). All three conditions are now pinned by widget tests.** | 23c4f62 + 13fbe56 + 1131c26 + df7ac2a + 0794d60 | analyze clean; full suite **638/638** |
| **C12 `feat(export): production document export -- CSV cut list + CSV BOM from the existing CalculationOutcome`**. Make the calculation results useful OUTSIDE the editor as a file a workshop can email, print, archive, or feed to a downstream tool. Pure-Dart CSV is the smallest first format (no new dependencies, no PDF library, no XLSX library). Every value in the file is data already on a model field -- the only new value the exporter introduces is the file-metadata `Exported at` timestamp. Empty cells for `weight_kg == null`, `length_mm == null` (count-only hardware), etc. -- no invented 0. Diagnostics carry the engine's actual reason strings (noRuleMatched / dominantOuvrantUnresolved / mixedSashCarrier), no new labels. Five commits: **(1)** `feat(export)` -- new `lib/core/production_export/` directory with `production_exporter.dart` (orchestrator), `production_header.dart` (metadata block + filename slug/shortId), `cuts_csv_renderer.dart` (cut-list, reuses `buildCutListLines`/`sumCutListLines`), `bom_csv_renderer.dart` (BOM, reuses `buildBom`/`summarizeBom`), `csv_field.dart` (RFC 4180 field encoder). Filename pattern: `aluvis-{project-slug}-{construction-slug}-{6-char-id}.cuts.csv` and `.bom.csv`, with a Latin-1 diacritic-stripping table for the slug (NFD alone is not enough: Dart's `String` exposes precomposed `ç` (U+00E7) as a single rune and the combining-mark range `[\u0300-\u036f]` does not include the cedilla combining mark). Header has `# Stale: yes` + a prominent warning paragraph when the calculation is stale -- export is allowed (workshop decides what to do with a stale printout). The exporter accepts an explicit `DateTime` so tests pin a fixed timestamp; production code passes `DateTime.now()`. **(2)** `test(export)` -- 34 golden tests in `test/production_export_render_test.dart` cover `CsvField.encode` (7 cases), `ProductionHeader` (15 cases for type labels, ID handling, diacritic slug, short ID, stale flag, width/height rendering), `CutsCsvRenderer` (5 cases for the three systems + stale + RFC 4180 quoting), `BomCsvRenderer` (5 cases for 4-domain, profile-only, stale, diagnostics), and `ProductionExporter.filename` (1 case). **(3)** `test(export)` -- 6 IO round-trip tests in `test/production_export_io_test.dart` exercise the on-disk path: bytes match the in-memory render output; filename format is the documented `aluvis-{slug}-{short-id}.cuts.csv` / `.bom.csv`; target directory is created recursively when it does not exist; UTF-8 round-trip survives accented characters (and the first byte is 0x23 `#`, NOT 0xEF BOM, so Excel won't misinterpret the file as UTF-16); stale flag is reflected in BOTH files' metadata blocks; re-exporting the same construction to the same directory overwrites the previous file cleanly. **(4)** `feat(editor)` -- `Exporter la production` button in the calculation results banner (next to `Liste de découpe` and `BOM`). Tapping the button opens a small dialog (`ProductionExportDialog`) asking for a subdirectory name (default `production`); on submit the exporter writes to `<documents>/aluvis/exports/<subdir>/`, a `SnackBar` surfaces the two file paths on success or the error on failure. Path-traversal (`/`, `\`, `..`, `.`) is rejected at the dialog level. The dialog uses `path_provider` (already a dep) + `dart:io` -- no new dependencies. A native file-chooser is a follow-up; this milestone keeps the dependency graph stable. **(5)** `test(export)` -- 1 end-to-end UI integration test in `test/production_export_ui_test.dart` drives the editor with a 14800 1v française construction, runs Calculer, taps the new button, accepts the default subdirectory, and asserts the SnackBar is visible, the two CSV files exist on disk, and the cuts/BOM contents contain the documented p. 65 values. **Explicitly OUT of scope (recorded for the next phase):** PDF / XLSX export, stock-bar optimization, glass optimization, CNC export, pricing, inventory, cut optimization, a native file-chooser dialog, hardware/joints rules for 14600/4200 (not in source), 2v française for 14800 (not in source). No `VERIFIED_SOURCES.md` change -- every value is data already on a model field; no new manufacturer fact is introduced. qa-review subagent unavailable (payment error 'Insufficient balance', same as the rest of the project). Self-review against the commit-by-commit checklist confirms: every asserted value traces to its source page (S-1 p. 24, S-3 p. 65, M-2 E070/E150), no manufacturer data invented, no model changes, no new dependencies added. **Definition of DONE for this phase: the calculation result is now consumable outside the editor as two on-disk CSV files per construction, every value source-traced to the existing aggregation layer, and the user-visible export action is wired into the editor's results banner.** | 5b39287 + 0e11764 + 6c57317 | analyze clean; full suite **679/679** |

Suite size history: 119 → 242 (through boundary drag) → 244 (containment fix)
→ 259 (after M1) → 275 → 279 → 283 → 289 → 295 → 299 (through label editing)
→ 307 (after calculation C1) → 319 (after calculation C2) → 336 (after
calculation C3) → 338 (C4a) → 340 (C4b) → 345 (C4c) → 354 (after C4) →
361 (deletion fix) → 365 (C5a) → 377 (C5b) → 380 (C5c)
→ 384 (after C5 fixes) → 396 (after C6a) → 408 (after C6b) → 419
(after C6c) → 421 (A) → 428 (B) → 435 (C) → 443 (W1) → 446 (W2) →
475 (after C7) → 492 (C8 engine capability) → 506 (C8 rules) →
536 (C9 ME 14800 frappe) → 572 (C10a ME 14700 unambiguous subset) →
623 (P1 ME 14800 complete BOM, commits 1–5) → **625** (P1 commit 6, BOM dialog) →
**626** (P1 runtime defect fix: banner overflow cap + BOM dialog
for-spread dropping accessory section, plus the new end-to-end
widget integration test that drives the real ConstructionEditorScreen
through Sections → Calculer → Liste de découpe → BOM and asserts the
exact p. 65 values for the 13 cuts, the 1868×1368 glass pane, the
21.00 m of joints, and the 8 Équerre à pions) →
**638** (C11 system-completion phase: hide-delete on built-in
picker entries + reject non-positive construction width/height +
end-to-end runtime UI verification tests for ME 14600 2v
coulissante (S-1 p. 24) and Sepalumic 4200 OF 1v/2v française
(M-2 sheets E070/E150) + the first on-disk save/reopen round-trip
test for ME 14800 via the real ProjectStore + CatalogStore
through the FakePathProvider seam) →
**679** (C12 production-export phase: 34 golden tests for the
two CSV renderers + 6 IO round-trip tests for the on-disk
persistence + 1 end-to-end UI integration test that drives the
editor's new "Exporter la production" banner action end-to-end.
Zero new dependencies (path_provider + dart:io were already in
the project); the dialog picks a subdirectory name and writes
two CSV files -- a cut list and a BOM -- under
<documents>/aluvis/exports/<subdir>/. Every value in the file is
data already on a model field; the only new value the exporter
introduces is the file-metadata `Exported at` timestamp) →
**685** (C12 hardening E1–E5: real project name threaded
workspace → screen → banner → dialog → exporter → header with the
locked two-slug filename; BOM summary length_mm back to integer
millimetres with a unit-regression test; banner construction
required with the force-unwrap removed; dead renderer/header
params deleted with counts derived via fromConstruction; dialog
Future cached with 6s dismissible success SnackBar plus a
cancel-path test; non-finite dimension guard on all four
mutators. Silent overwrite on re-export is intentional v1
behaviour; a future version may add overwrite confirmation if
requested. Raw Section IDs in diagnostics remain out of scope
for C12 hardening as a follow-up item) →
**686** (G7 diagnostics section labels: BOM glass/hardware rows in
the dialog and both CSV renderers resolve `Section N` via
sectionLabelForCutGroup with the `Section supprimée` fallback).

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
- Workshop cut-list grouping doctrine (W1/W2): lines group by
  (profile.id, exact length, both angles) with EXACT double equality --
  deterministic because rule expressions over identical inputs are
  bit-identical; any float randomness would be an engine bug. Merged
  lines carry contributing usage ids, distinct section ids, and distinct
  rule descriptions, so aggregation never loses traceability and grouped
  display never replaces the per-cut records it derives from. The
  "Liste de découpe" dialog is pure derivation over CalculationOutcome
  (third consumer of the aggregation layer after banner totals and the
  future BOM); diagnostics wording is shared verbatim between banner and
  dialog so the two views cannot disagree.
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
- Companion-profile matching (C8) is UNIVERSAL over the sash-carrier
  class -- the evaluated usage's section siblings whose resolved profile
  is ouvrant-typed AND whose role is not intermediate -- never
  existential: a section mixing sash references matches no rule and the
  dependent usage skips with a visible issue, instead of tying two rules
  into AmbiguousRuleMatchException. Multi-reference companion sets are
  safe only for outcome-identical rows (4405/4413 → one length; 14800's
  {'14.809','14.810'} parclose rows likewise); each distinct deduction
  gets its own single-reference rule. Siblings are DERIVED at
  calculation time (never persisted, never a second domain
  representation); unresolvable siblings are invisible to the condition
  (their own profileUnresolved issue reports them), so a section whose
  only carriers do not resolve fails closed. The role clause is a
  placement-doctrine derivation, not a source statement -- documented as
  such in the condition's contract. C9's ME 14800 parclose rows are the
  first real second-manufacturer consumer, independently validating the
  capability; no generalization beyond what the two sources demonstrate.
- Profile references follow each naming source's own notation (C9):
  dotted "14.802" where the débitage table names a profile, sheet
  notation "14820" where only the PROFILOSCOPE sheet names it; the
  ledger records both notations per reference. Types follow source
  statements only -- sheets without family headings keep `other`
  ("famille non déclarée") rather than shape-based inference.

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

## New source documents received (transcription backlog, evidence in hand)

The client supplied three manufacturer documents (paths recorded in the
ledger; binaries stay out of the repo):

- **ME Catalogue Général** (`~/Downloads/855704418-...-compressed-3.pdf`,
  146 pp): SEVEN ME series — 14300 coulissant, 14600 (cross-check source
  for the existing seed + alloy chemistry for the 6063/6060 note),
  **14800 frappe WITH débitage**, **14700 portes lourdes WITH débitage**,
  14900 mur-rideau, 14100 cloisons, 14000 garde-corps.
- **Sepalumic CAT4200 ED05**: INTEGRATED (C7 above).
- **Sepalumic Catalogue 1100 ED5** (76 pp): mur-rideau profiles with
  inertias.

Candidates, not scheduled: **C10b ME 14700 stile blocker** (2v 14.705/14.706
"3+1 split" needs an external source documenting the per-stile
positional distribution -- tierce vs porte interpretation per Coupes
p.87/p.88, but no coupe labels the role mapping; resolves the
documented ledger S-4 tension) · C10+ ME 14700 va-et-vient sur
pivot (p. 85 coupes only; no débitage table; OpeningType extension
needed) · C10+ ME 14700 châssis fixe / 1v+imposte fixe (no débitage
tables; coupes pp. 86-88 use 14.701 / 14.712 / 14.707 etc.) · C11
ME Série 14700 portes (door-modeling decisions + visual table
verification; the 14700 table's text layer mangles numbers) · 14300
(verify visually whether a débitage table exists) · 14600 cross-check
· façade-architecture decision before ANY mur-rideau work (14900/1100
held sources) · OpeningType extensions (belge/soufflet/projeté --
identification of O.B. unresolved; the 14800 fiche documents
OB/soufflet variants with no débitage) · glass domain (unblocks
parclose rows everywhere -- Sepalumic 4200's "ou"-lists, 14800's
VITRAGE sizes, 14700's 14.819 + vitrage).
