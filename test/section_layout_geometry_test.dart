import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/layout_direction.dart';
import 'package:aluminium_designer/core/models/section.dart';
import 'package:aluminium_designer/features/projects/widgets/section_layout_geometry.dart';

Section _fixedSection({
  required String id,
  required int order,
  required double width,
  required double height,
}) {
  return Section(
    id: id,
    order: order,
    kind: SectionKind.fixed,
    width: width,
    height: height,
  );
}

void main() {
  group('layoutSectionRects - horizontal', () {
    test('two sections split canvas width proportionally, full height', () {
      final construction = Construction(
        id: 'c1',
        name: 'Test',
        type: ConstructionType.window,
        width: 2000,
        height: 1000,
        manufacturer: '',
        system: '',
        sections: [
          _fixedSection(id: 's1', order: 0, width: 800, height: 1000),
          _fixedSection(id: 's2', order: 1, width: 1200, height: 1000),
        ],
        layoutDirection: SectionLayoutDirection.horizontal,
        profiles: const [],
      );

      const canvasRect = Rect.fromLTWH(0, 0, 1000, 500);
      final rects = layoutSectionRects(
        construction: construction,
        canvasRect: canvasRect,
      );

      expect(rects, hasLength(2));

      // s1: 800/2000 of width = 40% -> 400px wide, full 500px height.
      expect(rects[0].rect.left, 0);
      expect(rects[0].rect.width, closeTo(400, 0.001));
      expect(rects[0].rect.height, 500);

      // s2 continues where s1 ends.
      expect(rects[1].rect.left, closeTo(400, 0.001));
      expect(rects[1].rect.width, closeTo(600, 0.001));
      expect(rects[1].rect.height, 500);
    });

    test('sections are ordered by Section.order, not list order', () {
      final construction = Construction(
        id: 'c1',
        name: 'Test',
        type: ConstructionType.window,
        width: 2000,
        height: 1000,
        manufacturer: '',
        system: '',
        sections: [
          _fixedSection(id: 'second', order: 1, width: 1000, height: 1000),
          _fixedSection(id: 'first', order: 0, width: 1000, height: 1000),
        ],
        layoutDirection: SectionLayoutDirection.horizontal,
        profiles: const [],
      );

      const canvasRect = Rect.fromLTWH(0, 0, 1000, 500);
      final rects = layoutSectionRects(
        construction: construction,
        canvasRect: canvasRect,
      );

      expect(rects[0].section.id, 'first');
      expect(rects[1].section.id, 'second');
    });
  });

  group('layoutSectionRects - vertical', () {
    test('two sections split canvas height proportionally, full width', () {
      final construction = Construction(
        id: 'c1',
        name: 'Test',
        type: ConstructionType.door,
        width: 1000,
        height: 2000,
        manufacturer: '',
        system: '',
        sections: [
          _fixedSection(id: 's1', order: 0, width: 1000, height: 800),
          _fixedSection(id: 's2', order: 1, width: 1000, height: 1200),
        ],
        layoutDirection: SectionLayoutDirection.vertical,
        profiles: const [],
      );

      const canvasRect = Rect.fromLTWH(0, 0, 500, 1000);
      final rects = layoutSectionRects(
        construction: construction,
        canvasRect: canvasRect,
      );

      expect(rects, hasLength(2));

      expect(rects[0].rect.top, 0);
      expect(rects[0].rect.height, closeTo(400, 0.001));
      expect(rects[0].rect.width, 500);

      expect(rects[1].rect.top, closeTo(400, 0.001));
      expect(rects[1].rect.height, closeTo(600, 0.001));
      expect(rects[1].rect.width, 500);
    });
  });

  test('empty sections list returns empty rects', () {
    final construction = Construction(
      id: 'c1',
      name: 'Test',
      type: ConstructionType.window,
      width: 1000,
      height: 1000,
      manufacturer: '',
      system: '',
      sections: const [],
      profiles: const [],
    );

    const canvasRect = Rect.fromLTWH(0, 0, 500, 500);
    final rects = layoutSectionRects(
      construction: construction,
      canvasRect: canvasRect,
    );

    expect(rects, isEmpty);
  });

  test('a point inside one section rect is not inside another', () {
    final construction = Construction(
      id: 'c1',
      name: 'Test',
      type: ConstructionType.window,
      width: 2000,
      height: 1000,
      manufacturer: '',
      system: '',
      sections: [
        _fixedSection(id: 's1', order: 0, width: 1000, height: 1000),
        _fixedSection(id: 's2', order: 1, width: 1000, height: 1000),
      ],
      layoutDirection: SectionLayoutDirection.horizontal,
      profiles: const [],
    );

    const canvasRect = Rect.fromLTWH(0, 0, 1000, 500);
    final rects = layoutSectionRects(
      construction: construction,
      canvasRect: canvasRect,
    );

    const pointInFirst = Offset(100, 250);
    const pointInSecond = Offset(600, 250);

    expect(rects[0].rect.contains(pointInFirst), isTrue);
    expect(rects[1].rect.contains(pointInFirst), isFalse);

    expect(rects[1].rect.contains(pointInSecond), isTrue);
    expect(rects[0].rect.contains(pointInSecond), isFalse);
  });
}
