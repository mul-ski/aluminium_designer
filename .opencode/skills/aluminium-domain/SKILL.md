---
name: aluminium-domain
description: AluVis aluminium joinery domain rules - verified data, traceability, and architecture boundaries. Use when implementing any domain/calculation/catalog feature, handling manufacturer data (profiles, débitage, deductions, glass, hardware), or when tempted to fill a missing engineering value.
---

# Aluminium domain rules (AluVis)

AluVis designs aluminium windows/doors/curtain walls and computes cut lists.
A wrong number here becomes a wrongly fabricated bar of aluminium. These rules
are law, not style.

## Never invent

Do not fabricate, estimate, interpolate, or "complete from experience":

- manufacturer data (names, series, certifications)
- profile dimensions (width/depth/weightPerMeter)
- deduction formulas / cut lengths (débitage)
- glass deductions and rebate fits
- hardware quantities or compatibility
- tolerances or fabrication constraints

Absence means **unknown**. The codebase encodes this explicitly:

- `Profile.width/depth/weightPerMeter == 0` → not stated by the source (never a measured zero)
- `ProfileSystemMetadata.thermalBreak == null` → not stated (≠ `false`)
- `ruleSetId: 'generic-placeholder'` → no real rules exist yet (never encode one row of a real table unconditionally)
- empty `supportedOpenings` / `dimensionLimits` → nothing verified, not "everything fits"

## Classify every number

Before writing a value into code or a test, state which it is:

1. **Verified fact** — traces to an identified source document; record the
   citation in `docs/VERIFIED_SOURCES.md`.
2. **Placeholder** — clearly marked as such (`isPlaceholder: true`,
   `generic-placeholder`, "non vérifié" naming). Never mix placeholders into
   verified data.
3. **Assumption** — allowed only in throwaway analysis, never in `lib/` or
   persisted models.
4. **Unknown** — leave the field at its unknown marker; say so in the doc comment.

## Traceability

Every calculation output must stay explainable back to its inputs:
`Construction` → `Section` → `ProfileUsage` → `Profile` (+ `SystemRuleSet`
rule via `ProfileCut.ruleDescription`). Do not break this chain with
untracked derived state; derive displays by pure aggregation
(`cut_aggregation.dart`), never hand-maintained UI copies.

## Architecture boundaries

- Domain/calculation logic lives in `lib/core/` (models, engine, logic) —
  never in Flutter widgets. Widgets render and forward intents.
- `Construction`/domain models are authoritative. UI state is a draft view,
  not a second source of truth.
- The calculation engine is data-driven (`SystemRuleSet` + conditions +
  `DimensionExpression`). Extend the engine only when a REAL, sourced rule
  cannot be represented — see the débitage precedent in
  `docs/VERIFIED_SOURCES.md` (formulas documented but NOT encoded because
  the engine cannot route them correctly). No speculative abstractions.

## External-verification gate

When required engineering data is missing, STOP and say so. The correct
output is "cannot proceed without source X", not a plausible guess. This
gate has priority over shipping, deadlines, and completeness.
