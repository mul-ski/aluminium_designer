---
name: calculation-verification
description: Verification procedure for AluVis calculation-engine changes - cuts, quantities, rules, deductions, BOM. Use whenever modifying ConstructionCalculator, SystemRuleSet, rules/, dimension expressions, cut aggregation, or any manufacturer-backed calculation.
---

# Calculation verification (AluVis)

Run this procedure IN ORDER for any change touching formulas, quantities,
cuts, rule conditions/evaluation, BOM inputs, or manufacturer-backed
calculations. Do not skip steps to ship.

## Procedure

1. **Identify the exact source rule.** Which real-world rule/formula is this?
   If none exists, the change is a placeholder — mark it `isPlaceholder` and
   say so in its description.
2. **Identify all required inputs and conditions.** Dimensions, profile
   references, configuration (vantaux count, opening type, profile pairing),
   units.
3. **Verify AluVis can represent those conditions.** Check
   `DimensionVariable`, `RuleCondition` subclasses, and rule selection
   (specificity, ambiguity). If the engine cannot route the rule correctly
   for every configuration it matches, STOP — encoding one case
   unconditionally fabricates wrong cuts for the others (see the Série
   14600 débitage precedent in `docs/VERIFIED_SOURCES.md`). Document the
   missing engine capability instead of half-encoding.
4. **Verify the source.** Load the `source-verification` skill. Every number
   needs a document + page/section.
5. **Do not invent missing information.** Missing input → external-
   verification gate. Stop and report.
6. **Implement the smallest change required.** No speculative generic
   rule-engine extensions "while we're at it".
7. **Create deterministic regression tests.** Exact input → exact expected
   cut lengths/quantities/angles. No floats-without-purpose, no random.
8. **Test edge cases and ambiguity.** Zero/negative dimensions, missing
   section, unresolved profile, ambiguous rule match
   (`AmbiguousRuleMatchException` must stay loud), quantity composition
   (`usage.quantity × rule.fixedCount`).
9. **Verify output traceability.** Cuts still carry `profileUsageId`,
   `sectionId`, `ruleDescription`; skips still surface as
   `ProfileUsageIssue` with a reason — nothing silent.
10. `flutter analyze` — clean.
11. Focused tests (engine + rules + affected feature).
12. Full suite green.
13. Inspect the final diff yourself.
14. Record verified sources in `docs/VERIFIED_SOURCES.md` where applicable.

## Manufacturer formulas — extra requirements

- Exact system/profile/configuration identification ("14 621 with 56-face
  montants, 2-vantaux" — not "the traverse formula").
- Document + page/section reference for every constant.
- Source recorded in `docs/VERIFIED_SOURCES.md` before or with the code.
- Re-verify the transcription at high resolution if any digit is unclear
  (this project has already caught two low-dpi misreads).
- Stop if the current rule system cannot represent the required conditions
  (step 3). The honest state is a documented placeholder + a roadmap note,
  never a partially-encoded table.
