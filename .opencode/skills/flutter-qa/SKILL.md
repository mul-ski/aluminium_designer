---
name: flutter-qa
description: AluVis Flutter/Dart validation procedure - analyze, focused tests, full suite, diff inspection, rendering verification. Use after any implementation work in this repository, especially editor/canvas/painter changes.
---

# Flutter QA (AluVis)

Run after implementation, before commit. The gate is: analyze clean + full
suite green + diff inspected + no leftovers.

## Gate

1. `flutter analyze` — zero issues.
2. Focused tests for every touched area.
3. Full suite (`flutter test`) — green. Record the count when updating the
   roadmap.
4. Inspect failures honestly: a failure reveals either a bug in the change
   or an outdated test — decide which, never skip.
5. Inspect the final diff end to end.
6. Remove temporary/debug files (scratch scripts, debug prints, generated
   renders). `/tmp/opencode/` scratch is fine to leave; the repo is not.
7. Check for secrets and unrelated files in the diff.

## Editor / canvas changes — extra matrix

- horizontal AND vertical section layouts
- zoom and pan (viewport transform correctness, not just absence of crash)
- viewport transforms under resize/constraints
- hit-testing (dimension labels, sections, boundary handles)
- undo/redo around every new mutation (controller-level, not just smoke)
- interaction behavior (drag vs tap, snap on/off, focus handoff)
- when widget-level assertions cannot see what matters, test the painter
  directly (see `construction_painter_test.dart` for the harness pattern)

## Rendering changes

A green widget test does NOT prove visual correctness. For rendering work,
verify pixels: PictureRecorder/painter-level tests, or pixel-sampled
verification, matching the existing precedent in the painter tests.

## Test-writing traps learned in this repo

- Real `dart:io` I/O cannot complete inside `testWidgets` (fake async) —
  use the store-DI seam (`ConstructionEditorScreen.catalogStore`,
  `ProjectWorkspaceScreen.store`) with a recording stub, or plain `test()`
  for store-level I/O.
- `ListView` children are built lazily: scroll before find/tap.
- `find.text` matches `EditableText` too — a value appearing in several
  fields needs `findsNWidgets` or `.first`.
- Dialogs: assert the cancel path changes nothing, not just the confirm path.
- Never weaken production behavior to make a test pass. Fix the test or the
  code — decide which is wrong and say so.
