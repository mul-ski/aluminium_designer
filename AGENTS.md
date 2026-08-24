# AGENTS.md — AluVis engineering law

AluVis: Flutter desktop app for designing aluminium joinery (windows, doors,
curtain walls) and computing fabrication cut lists. Domain truth lives in
`lib/core/`; the calculation engine is data-driven (`SystemRuleSet`).

## Workflow

- Conventional commits to `origin/main`, one validated milestone at a time.
- Gate per commit: `flutter analyze` clean → focused tests → full suite
  green → diff inspected → commit. Push after the docs/roadmap commit.
- `ALUVIS_ROADMAP.md` is the persistent roadmap: milestone rows, suite-size
  history, decisions on record. Update it per milestone; don't rewrite
  history.
- `docs/VERIFIED_SOURCES.md` is the technical evidence ledger: every seeded
  or adopted engineering fact cites its source document, page, and
  extraction method there.

## Domain law (short form)

- NEVER invent manufacturer data, profile dimensions, deduction formulas,
  glass deductions, hardware quantities, or tolerances. Absence = unknown
  (`0` = not stated, `thermalBreak: null` = not stated, `generic-placeholder`
  = no real rules yet).
- Verified fact / placeholder / assumption / unknown must be distinguishable
  in the code. Placeholders are always clearly marked.
- Missing required engineering data = external-verification gate: stop and
  say what source is needed instead of guessing.
- Domain logic stays in `lib/core/`, never in widgets. The domain models are
  authoritative; no speculative abstractions without a real requirement.

The long form lives in the project skills (below) — load them; don't rely on
memory.

## OpenCode project environment

- Project skills live under `.opencode/skills/` and are picked up
  automatically:
  - `aluminium-domain` — domain rules: verified data, unknown markers,
    traceability, architecture boundaries. Load for ANY domain/catalog/
    calculation work.
  - `calculation-verification` — mandatory procedure for calculation-engine
    changes. Load before touching rules, cuts, quantities, or BOM inputs.
  - `source-verification` — procedure for researching/validating external
    manufacturer data. Load before adopting any external technical fact.
  - `flutter-qa` — validation gate incl. editor/canvas/rendering specifics.
    Load after implementation, before committing.
- `qa-review` (`.opencode/agents/qa-review.md`) is a read-only reviewer
  SUBAGENT — invoke it explicitly for an independent pre-commit review. It
  cannot edit files and never commits or pushes.
