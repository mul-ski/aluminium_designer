import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/features/constructions/editor/construction_editor_controller.dart';

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

void main() {
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
}
