import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/logic/boundary_manipulation.dart';
import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/layout_direction.dart';
import 'package:aluminium_designer/core/models/opening.dart';
import 'package:aluminium_designer/core/models/section.dart';
import 'package:aluminium_designer/features/constructions/editor/construction_editor_controller.dart';

Section _fixed(String id, int order, double size, {double cross = 1200}) {
  return Section(
    id: id,
    order: order,
    kind: SectionKind.fixed,
    width: LayoutDirectionForTest.isHorizontal ? size : cross,
    height: LayoutDirectionForTest.isHorizontal ? cross : size,
  );
}

/// Test-only direction switch so every geometry test below runs against a
/// horizontal fixture; the vertical variants flip it explicitly.
class LayoutDirectionForTest {
  static bool isHorizontal = true;
}

Construction _threeSection() => Construction(
  id: 'c1',
  name: 'Facade',
  type: ConstructionType.window,
  width: LayoutDirectionForTest.isHorizontal ? 2400 : 1000,
  height: LayoutDirectionForTest.isHorizontal ? 1000 : 2400,
  manufacturer: '',
  system: '',
  // Cross size is 1000 in BOTH directions: full height when horizontal,
  // full width when vertical -- matching the 1D model invariant that all
  // sections span the entire cross axis.
  sections: [
    _fixed('a', 0, 1000, cross: 1000),
    _fixed('b', 1, 600, cross: 1000),
    _fixed('c', 2, 800, cross: 1000),
  ],
  layoutDirection: LayoutDirectionForTest.isHorizontal
      ? SectionLayoutDirection.horizontal
      : SectionLayoutDirection.vertical,
  profiles: const [],
);

double _axisSize(Section s) =>
    LayoutDirectionForTest.isHorizontal ? s.width : s.height;

void main() {
  setUp(() {
    LayoutDirectionForTest.isHorizontal = true;
  });

  group('withBoundaryMoved - horizontal', () {
    test('moving boundary 1 redistributes exactly the two neighbors', () {
      // Boundaries: after a (1000), after b (1600). Move boundary 1 to 1200.
      final result = withBoundaryMoved(_threeSection(), 1, 1200);

      expect(_axisSize(result.sections[0]), 1200);
      expect(_axisSize(result.sections[1]), 400); // 600 - 200
      expect(_axisSize(result.sections[2]), 800); // untouched
      expect(
        result.sections.map(_axisSize).reduce((a, b) => a + b),
        2400,
      ); // total preserved exactly
    });

    test('moving boundary 2 redistributes b and c', () {
      final result = withBoundaryMoved(_threeSection(), 2, 1900);

      expect(_axisSize(result.sections[0]), 1000);
      expect(_axisSize(result.sections[1]), 900); // b+c span [1000..2400]
      expect(_axisSize(result.sections[2]), 500);
    });

    test('clamps to the 1 mm floor on both sides', () {
      // Dragging boundary 1 far left: 'a' floors at 1 mm.
      final flooredLeft = withBoundaryMoved(_threeSection(), 1, -500);
      expect(_axisSize(flooredLeft.sections[0]), kMinSectionSizeMm);
      expect(_axisSize(flooredLeft.sections[1]), 1599); // rest goes to b

      // Dragging far right past both limits: clamped at max legal.
      final maxLegal = withBoundaryMoved(_threeSection(), 1, 99999);
      // a+b combined = 1600 -> a can grow to 1599 (b floored at 1).
      expect(_axisSize(maxLegal.sections[0]), 1599);
      expect(_axisSize(maxLegal.sections[1]), kMinSectionSizeMm);
    });

    test('edge indices are not boundaries and return the input unchanged',
        () {
      final construction = _threeSection();

      expect(identical(withBoundaryMoved(construction, 0, 1200), construction),
          isTrue);
      expect(identical(withBoundaryMoved(construction, 3, 1200), construction),
          isTrue);
      expect(identical(withBoundaryMoved(construction, -1, 1200), construction),
          isTrue);
    });

    test('non-neighbor sections keep identity and all fields', () {
      final original = _threeSection();
      final result = withBoundaryMoved(original, 1, 1300);

      // 'c' untouched entirely.
      expect(result.sections[2], same(original.sections[2]));
      // 'a' keeps its non-axis fields.
      expect(result.sections[0].id, 'a');
      expect(result.sections[0].order, 0);
      expect(result.sections[0].kind, SectionKind.fixed);
      expect(result.sections[0].height,
          original.sections[0].height); // cross axis untouched
    });

    test('ouvrant fields survive redistribution', () {
      final construction = Construction(
        id: 'c2',
        name: 'Mix',
        type: ConstructionType.window,
        width: 2000,
        height: 1200,
        manufacturer: '',
        system: '',
        sections: [
          Section(
            id: 'f',
            order: 0,
            kind: SectionKind.fixed,
            width: 1000,
            height: 1200,
          ),
          Section(
            id: 'o',
            order: 1,
            kind: SectionKind.ouvrant,
            width: 1000,
            height: 1200,
            openingType: OpeningType.oscilloBattant,
            vantauxCount: 2,
          ),
        ],
        profiles: const [],
      );

      final result = withBoundaryMoved(construction, 1, 700);

      final ouvrant = result.sections[1];
      expect(ouvrant.kind, SectionKind.ouvrant);
      expect(ouvrant.openingType, OpeningType.oscilloBattant);
      expect(ouvrant.vantauxCount, 2);
      expect(_axisSize(ouvrant), 1300);
    });
  });

  group('withBoundaryMoved - vertical', () {
    setUp(() => LayoutDirectionForTest.isHorizontal = false);

    test('mirrors onto heights preserving total height', () {
      // Heights a=1000, b=600, c=800. Boundary 2 sits after b at 1600;
      // dragging it to 1500 redistributes b+c only.
      final result = withBoundaryMoved(_threeSection(), 2, 1500);

      expect(result.layoutDirection, SectionLayoutDirection.vertical);
      expect(result.sections[0].height, 1000); // untouched neighbor
      expect(result.sections[1].height, 500); // 1500 - 1000
      expect(result.sections[2].height, 900); // 1400 combined - 500
      expect(result.sections[0].width, 1000); // cross axis untouched
      expect(
        result.sections.map((s) => s.height).reduce((a, b) => a + b),
        2400,
      );
    });
  });

  group('controller.moveBoundary', () {
    test('one move is exactly one undo entry; undo/redo restore endpoints',
        () {
      final controller = ConstructionEditorController(
        construction: _threeSection(),
      );

      controller.moveBoundary(boundaryIndex: 1, positionMm: 1200);
      expect(controller.canUndo, isTrue);
      expect(controller.canRedo, isFalse);

      controller.undo();
      expect(controller.draft.sections[0].width, 1000);
      expect(controller.draft.sections[1].width, 600);

      controller.redo();
      expect(controller.draft.sections[0].width, 1200);
      expect(controller.draft.sections[1].width, 400);
    });

    test('consecutive drags of the same boundary stay separately undoable',
        () {
      final controller = ConstructionEditorController(
        construction: _threeSection(),
      );

      controller.moveBoundary(boundaryIndex: 1, positionMm: 1100);
      controller.moveBoundary(boundaryIndex: 1, positionMm: 1400);

      controller.undo();
      expect(controller.draft.sections[0].width, 1100); // first drag state
      controller.undo();
      expect(controller.draft.sections[0].width, 1000); // pre-drag
    });

    test('a no-op move creates no history and stays clean', () {
      final controller = ConstructionEditorController(
        construction: _threeSection(),
      );

      // Boundary 1 already sits at 1000.
      controller.moveBoundary(boundaryIndex: 1, positionMm: 1000);

      expect(controller.canUndo, isFalse);
      expect(controller.isDirty, isFalse);
    });

    test('moves invalidate any recorded calculation outcome', () {
      final controller = ConstructionEditorController(
        construction: _threeSection(),
      )..calculate();

      expect(controller.calculationIsStale, isFalse);
      controller.moveBoundary(boundaryIndex: 1, positionMm: 1200);
      expect(controller.calculationIsStale, isTrue);
    });
  });
}
