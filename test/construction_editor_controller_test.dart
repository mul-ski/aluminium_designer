import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/models/catalog.dart';
import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/layout_direction.dart';
import 'package:aluminium_designer/core/models/profile_usage.dart';
import 'package:aluminium_designer/core/models/project_json.dart'
    show ConstructionJson;
import 'package:aluminium_designer/core/models/section.dart';
import 'package:aluminium_designer/features/constructions/editor/construction_editor_controller.dart';
import 'package:aluminium_designer/features/constructions/editor/editor_stage.dart';

Construction _construction({String? manufacturerId, String? systemId}) =>
    Construction(
      id: 'c1',
      name: 'Test Window',
      type: ConstructionType.window,
      width: 1800,
      height: 1200,
      manufacturer: manufacturerId == null ? '' : 'Some Manufacturer',
      system: systemId == null ? '' : 'Some System',
      manufacturerId: manufacturerId,
      systemId: systemId,
      sections: const [],
      profiles: const [],
    );

Section _fixedSection({
  String id = 's1',
  int order = 0,
  double width = 1000,
}) => Section(
  id: id,
  order: order,
  kind: SectionKind.fixed,
  width: width,
  height: 1200,
);

/// A controller over a dimensioned construction containing one fixed
/// section -- the common base for history tests.
ConstructionEditorController _controllerWithSection() {
  final construction = _construction().copyWith(
    sections: [_fixedSection()],
  );
  return ConstructionEditorController(construction: construction);
}

void main() {
  group('precision dimension parsing', () {
    test('construction dimensions accept exact decimals', () {
      final controller = ConstructionEditorController(
        construction: _construction(),
      );

      controller.setWidth('750.5');
      expect(controller.draft.width, 750.5);

      controller.setHeight('1200.25');
      expect(controller.draft.height, 1200.25);
    });

    test('the French decimal COMMA parses like the dot -- typed input is '
        'never silently discarded over separator habit', () {
      final controller = ConstructionEditorController(
        construction: _construction(),
      );

      controller.setWidth('750,5');
      expect(controller.draft.width, 750.5);

      controller.setHeight('1200,25');
      expect(controller.draft.height, 1200.25);
      // Whitespace around the number is tolerated too.
      controller.setWidth(' 800 ');
      expect(controller.draft.width, 800);
    });

    test('section dimensions accept exact decimals and commas', () {
      final controller = _controllerWithSection();
      final section = controller.draft.sections.single;

      controller.applySectionWidth(section, '750.5');
      expect(controller.draft.sections.single.width, 750.5);

      controller.applySectionHeight(section, '1200,5');
      expect(controller.draft.sections.single.height, 1200.5);
    });

    test('non-positive or unparseable section dimensions are IGNORED: no '
        'mutation, no undo entry, model untouched', () {
      final controller = _controllerWithSection();
      final section = controller.draft.sections.single;

      for (final bad in const ['-5', '0', 'abc', '']) {
        controller.applySectionWidth(section, bad);
        controller.applySectionHeight(section, bad);
        expect(controller.canUndo, isFalse,
            reason: "'$bad' must not create history");
        expect(controller.draft.sections.single.width, 1000);
        expect(controller.draft.sections.single.height, 1200);
      }
    });

    test('typing the exact value lands exactly in the model and undoes '
        'cleanly (750 workflow)', () {
      final controller = _controllerWithSection();
      final section = controller.draft.sections.single;
      expect(controller.canUndo, isFalse);

      controller.setWidth('2000'); // rough pass
      controller.applySectionWidth(section, '750'); // precise pass
      expect(controller.draft.width, 2000);
      expect(controller.draft.sections.single.width, 750.0);

      controller.undo(); // undoes the section width only
      expect(controller.draft.sections.single.width, 1000);
      expect(controller.canUndo, isTrue);
      controller.undo(); // undoes the construction width
      expect(controller.draft.width, 1800);
      expect(controller.canUndo, isFalse);
    });
  });
  group('ConstructionEditorController width/height edits', () {
    test(
      'setWidth preserves authoritative manufacturerId/systemId',
      () {
        final controller = ConstructionEditorController(
          construction: _construction(
            manufacturerId: 'mfr-1',
            systemId: 'sys-1',
          ),
        );

        controller.setWidth('2000');

        expect(controller.draft.width, 2000);
        expect(controller.draft.manufacturerId, 'mfr-1');
        expect(controller.draft.systemId, 'sys-1');
        // Display-name fallbacks are preserved alongside the ids too.
        expect(controller.draft.manufacturer, 'Some Manufacturer');
        expect(controller.draft.system, 'Some System');
      },
    );

    test(
      'setHeight preserves authoritative manufacturerId/systemId',
      () {
        final controller = ConstructionEditorController(
          construction: _construction(
            manufacturerId: 'mfr-1',
            systemId: 'sys-1',
          ),
        );

        controller.setHeight('1500');

        expect(controller.draft.height, 1500);
        expect(controller.draft.manufacturerId, 'mfr-1');
        expect(controller.draft.systemId, 'sys-1');
        expect(controller.draft.manufacturer, 'Some Manufacturer');
        expect(controller.draft.system, 'Some System');
      },
    );

    test(
      'null ids stay null through width/height edits '
      '(no system ever selected)',
      () {
        final controller = ConstructionEditorController(
          construction: _construction(),
        );
        expect(controller.draft.manufacturerId, isNull);
        expect(controller.draft.systemId, isNull);

        controller.setWidth('2000');
        controller.setHeight('1500');

        expect(controller.draft.manufacturerId, isNull);
        expect(controller.draft.systemId, isNull);
        expect(controller.draft.width, 2000);
        expect(controller.draft.height, 1500);
      },
    );

    test(
      'clearing a dimension back to null (empty field) still preserves ids',
      () {
        // copyWith cannot express setting width back to null -- these
        // mutators rebuild the draft directly, so this pins both halves of
        // their contract: nullable dimensions AND preserved identities.
        final controller = ConstructionEditorController(
          construction: _construction(
            manufacturerId: 'mfr-1',
            systemId: 'sys-1',
          ),
        );

        controller.setWidth('');
        expect(controller.draft.width, isNull);

        controller.setHeight('');
        expect(controller.draft.height, isNull);

        expect(controller.draft.manufacturerId, 'mfr-1');
        expect(controller.draft.systemId, 'sys-1');
      },
    );

    test(
      'dimension edits leave every other construction field untouched',
      () {
        final original = _construction(
          manufacturerId: 'mfr-1',
          systemId: 'sys-1',
        );
        final controller = ConstructionEditorController(
          construction: original,
        );

        controller.setWidth('2000');
        controller.setHeight('1500');

        expect(controller.draft.id, original.id);
        expect(controller.draft.name, original.name);
        expect(controller.draft.type, original.type);
        expect(controller.draft.sections, same(original.sections));
        expect(controller.draft.layoutDirection, original.layoutDirection);
        expect(controller.draft.profiles, same(original.profiles));
        expect(controller.draft.profileUsages, same(original.profileUsages));
      },
    );
  });

  group('undo/redo basics', () {
    test('a fresh controller starts with clean history', () {
      final controller = _controllerWithSection();

      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);
    });

    test('basic undo restores the previous draft', () {
      final controller = _controllerWithSection();

      controller.setType(ConstructionType.door);
      expect(controller.draft.type, ConstructionType.door);

      controller.undo();
      expect(controller.draft.type, ConstructionType.window);
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isTrue);
    });

    test('basic redo re-applies the undone mutation', () {
      final controller = _controllerWithSection()..setType(ConstructionType.door)..undo();

      controller.redo();
      expect(controller.draft.type, ConstructionType.door);
      expect(controller.canRedo, isFalse);
    });

    test('undo then redo round-trips to identical content', () {
      final controller = _controllerWithSection();
      controller.setWidth('2000');
      final mutated = controller.draft.toJson().toString();

      controller.undo();
      expect(controller.draft.toJson().toString(),
          isNot(mutated));

      controller.redo();
      expect(controller.draft.toJson().toString(), mutated);
    });

    test('a new mutation after undo clears the redo stack', () {
      final controller = _controllerWithSection()
        ..setName('A')
        ..setName('B')
        ..undo();

      expect(controller.canRedo, isTrue);

      // A differently-tagged mutation (name -> type) must invalidate all
      // redoable future states.
      controller.setType(ConstructionType.door);
      expect(controller.canRedo, isFalse);

      final afterFailedRedo = controller.draft;
      controller.redo(); // no-op
      expect(controller.draft, same(afterFailedRedo));
    });

    test('multiple distinct mutations undo step by step', () {
      final controller = _controllerWithSection()
        ..setName('First')
        ..setType(ConstructionType.door)
        ..setHeight('900');

      controller.undo();
      expect(controller.draft.height, 1200);
      expect(controller.draft.type, ConstructionType.door);

      controller.undo();
      expect(controller.draft.type, ConstructionType.window);

      controller.undo();
      expect(controller.draft.name, 'Test Window');
      expect(controller.canUndo, isFalse);
    });

    test('multiple redos restore forward in order', () {
      final controller = _controllerWithSection()
        ..setName('First')
        ..setType(ConstructionType.door)
        ..setHeight('900')
        ..undo()
        ..undo()
        ..undo();

      controller.redo();
      expect(controller.draft.name, 'First');
      controller.redo();
      expect(controller.draft.type, ConstructionType.door);
      controller.redo();
      expect(controller.draft.height, 900);
    });
  });

  group('no-op mutations and history', () {
    test('setting an identical value creates no history entry', () {
      final controller = _controllerWithSection();

      controller.setName('Test Window'); // unchanged
      expect(controller.canUndo, isFalse);

      controller.setWidth('');
      controller.setWidth(''); // width already null -- unchanged
      expect(controller.canUndo, isTrue); // only ONE entry from first clear
      controller.undo();
      expect(controller.canUndo, isFalse);
    });

    test('unparseable section edits create no history', () {
      final controller = _controllerWithSection();
      final section = controller.draft.sections.single;

      controller.applySectionWidth(section, 'abc');
      controller.applySectionHeight(section, '-5');
      controller.applySectionVantauxCount(section, 0);

      expect(controller.canUndo, isFalse);
    });

    test(
      'consecutive edits of one field coalesce into a single entry',
      () {
        final controller = _controllerWithSection();

        // Simulates typing "1500" digit by digit into the width field.
        controller
          ..setWidth('1')
          ..setWidth('15')
          ..setWidth('150')
          ..setWidth('1500');

        expect(controller.draft.width, 1500);
        controller.undo();
        expect(controller.draft.width, 1800); // back BEFORE the whole run
        expect(controller.canUndo, isFalse);
      },
    );

    test('switching fields breaks the coalescing run', () {
      final controller = _controllerWithSection();

      controller
        ..setWidth('1500') // run: width
        ..setHeight('1300') // new entry: height
        ..setWidth('1600'); // new entry: width again

      controller.undo();
      expect(controller.draft.width, 1500);
      controller.undo();
      expect(controller.draft.height, 1200);
      controller.undo();
      expect(controller.draft.width, 1800);
      expect(controller.canUndo, isFalse);
    });

    test('same field on different sections does NOT coalesce', () {
      final controller = ConstructionEditorController(
        construction: _construction().copyWith(
          sections: [
            _fixedSection(id: 's1', order: 0),
            _fixedSection(id: 's2', order: 1, width: 800),
          ],
        ),
      );
      final s1 = controller.draft.sections[0];
      final s2 = controller.draft.sections[1];

      controller
        ..applySectionWidth(s1, '500')
        ..applySectionWidth(s1, '505') // coalesces with previous
        ..applySectionWidth(s2, '700'); // different tag -> own entry

      controller.undo();
      expect(controller.draft.sections[1].width, 800);
      expect(controller.draft.sections[0].width, 505); // s1 run survived

      controller.undo();
      expect(controller.draft.sections[0].width, 1000); // before s1 run
    });

    test('usage quantity spinner clicks coalesce per usage', () {
      final controller = _controllerWithSection();
      controller.addProfileUsage(
        profileId: 'p1',
        sectionId: 's1',
        role: ProfileUsageRole.left,
      );
      final usage = controller.draft.profileUsages.single;

      controller.updateProfileUsageQuantity(usage, 2);
      controller.updateProfileUsageQuantity(usage, 3);

      controller.undo();
      // One undo steps back to BEFORE quantity editing began (qty == 1),
      // not just one click.
      expect(controller.draft.profileUsages.single.quantity, 1);
    });

    test('each section add stays individually undoable', () {
      final controller = _controllerWithSection();

      controller.addSection(_fixedSection(id: 's2', order: 1, width: 800));
      controller.addSection(_fixedSection(id: 's3', order: 2, width: 300));

      controller.undo();
      expect(controller.draft.sections.length, 2);
      controller.undo();
      expect(controller.draft.sections.length, 1);
    });
  });

  group('dirty state across undo/redo/save', () {
    test('undoing back to the saved baseline makes the editor clean', () {
      final controller = _controllerWithSection();

      controller.setType(ConstructionType.door);
      expect(controller.isDirty, isTrue);

      controller.undo();
      expect(controller.isDirty, isFalse);

      controller.redo();
      expect(controller.isDirty, isTrue);
    });

    test('saving creates no history entry and keeps semantics intact', () {
      final controller = _controllerWithSection()
        ..setType(ConstructionType.door);

      expect(controller.canUndo, isTrue);
      controller.commitSave();
      expect(controller.isDirty, isFalse);
      expect(controller.canUndo, isTrue); // save added nothing

      controller.setName('Renamed'); // dirty again
      expect(controller.isDirty, isTrue);
      controller.undo();
      expect(controller.draft.type, ConstructionType.door);
      expect(controller.isDirty, isFalse); // exactly the saved content
    });
  });

  group('history bounds and lifecycle', () {
    test('history depth is capped at kUndoHistoryLimit entries', () {
      final controller = _controllerWithSection();

      // Rotate through three distinct tags with changing values so no two
      // consecutive mutations coalesce.
      for (var i = 0; i < kUndoHistoryLimit + 5; i++) {
        switch (i % 3) {
          case 0:
            controller.setName('Name $i');
          case 1:
            controller.setWidth('${1801 + i}');
          default:
            controller.setHeight('${1201 + i}');
        }
      }

      var undos = 0;
      while (controller.canUndo) {
        controller.undo();
        undos++;
      }
      expect(undos, kUndoHistoryLimit);
    });
  });

  group('calculation staleness across undo/redo', () {
    test(
      'undoing back to the calculated-for state un-stales the outcome',
      () {
        final controller = _controllerWithSection();

        controller.calculate();
        expect(controller.calculationHasRun, isTrue);
        expect(controller.calculationIsStale, isFalse);

        controller.setWidth('2000'); // calculator input -> live stale
        expect(controller.calculationIsStale, isTrue);

        controller.undo(); // back to the calculated inputs
        expect(controller.calculationIsStale, isFalse);

        controller.redo(); // away from them again
        expect(controller.calculationIsStale, isTrue);
      },
    );

    test('type-only jumps keep the outcome fresh across undo/redo', () {
      // ConstructionType is NOT part of the calculator-input fingerprint
      // (the engine reads dimensions/system/usages). Jump reconciliation
      // therefore keeps the outcome fresh across type-only edits -- a
      // deliberate, documented divergence from the live mutator's
      // conservative over-marking on setType.
      final controller = _controllerWithSection()
        ..calculate()
        ..setType(ConstructionType.door)
        ..undo()
        ..redo();

      expect(controller.calculationIsStale, isFalse);
    });

    test('display-name changes never stale the outcome across jumps', () {
      final controller = _controllerWithSection()
        ..calculate()
        // setName does not live-mark staleness...
        ..setName('New Name');
      expect(controller.calculationIsStale, isFalse);

      // ...and a jump over it reconciles to the same verdict.
      controller.undo();
      expect(controller.calculationIsStale, isFalse);
      controller.redo();
      expect(controller.calculationIsStale, isFalse);
    });

    test('layout-direction jumps keep the outcome fresh, like live edits',
        () {
      final controller = _controllerWithSection()..calculate();

      controller.setLayoutDirection(SectionLayoutDirection.vertical);
      expect(controller.calculationIsStale, isFalse);

      controller.undo();
      expect(controller.calculationIsStale, isFalse);
    });

    test('live stale mark persists when there is no outcome to reconcile',
        () {
      // Legacy behaviour preserved: every content edit live-marks the
      // (possibly nonexistent) outcome stale, and jump reconciliation only
      // runs when an outcome actually exists.
      final controller = _controllerWithSection()
        ..setType(ConstructionType.door)
        ..undo();

      expect(controller.calculationHasRun, isFalse);
      expect(controller.calculationIsStale, isTrue);
    });
  });

  group('state that must stay OUTSIDE history', () {
    test('editor stage survives undo/redo jumps untouched', () {
      final controller = _controllerWithSection()
        ..selectSection('s1')
        ..goToStage(EditorStage.geometry);

      controller.setName('X');
      controller.undo();

      expect(controller.stage, EditorStage.geometry);
      expect(controller.selectedSectionId, 's1'); // still exists -> kept
    });

    test('catalog snapshot survives undo/redo jumps untouched', () {
      const customCatalog = Catalog();
      final controller =
          _controllerWithSection()..setCatalog(customCatalog);

      controller.setName('X');
      controller.undo();

      expect(identical(controller.catalog, customCatalog), isTrue);
    });

    test('selection falls back to root when its section is undone away',
        () {
      final controller = _controllerWithSection()
        ..selectSection('s1')
        ..removeSelectedSection(); // clears selection by contract

      controller.undo(); // s1 comes back -- but selection is NOT restored
      expect(controller.selectedSectionId, isNull);
    });

    test('selection is preserved when the restored draft still has it', () {
      final controller = _controllerWithSection()..selectSection('s1');

      controller.setName('X'); // unrelated to sections
      controller.undo();

      expect(controller.selectedSectionId, 's1');
    });
  });
}
