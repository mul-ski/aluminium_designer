import 'package:flutter_test/flutter_test.dart';
import 'package:aluminium_designer/core/geometry/section_layout.dart';
import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/layout_direction.dart';
import 'package:aluminium_designer/core/models/section.dart';

Construction _buildConstruction({
  required List<Section> sections,
  double? width,
  double? height,
  SectionLayoutDirection layoutDirection = SectionLayoutDirection.horizontal,
}) {
  return Construction(
    id: 'c1',
    name: 'Test',
    type: ConstructionType.window,
    width: width,
    height: height,
    manufacturer: '',
    system: '',
    sections: sections,
    layoutDirection: layoutDirection,
    profiles: const [],
  );
}

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
  group('layoutConstruction - horizontal', () {
    test('places sections left to right in order', () {
      final construction = _buildConstruction(
        width: 2000,
        height: 1200,
        layoutDirection: SectionLayoutDirection.horizontal,
        sections: [
          _fixedSection(id: 's1', order: 0, width: 800, height: 1200),
          _fixedSection(id: 's2', order: 1, width: 1200, height: 1200),
        ],
      );

      final layout = layoutConstruction(construction)!;

      expect(layout.sections, hasLength(2));

      expect(layout.sections[0].x, 0);
      expect(layout.sections[0].y, 0);
      expect(layout.sections[0].width, 800);
      expect(layout.sections[0].height, 1200);

      expect(layout.sections[1].x, 800);
      expect(layout.sections[1].y, 0);
      expect(layout.sections[1].width, 1200);
      expect(layout.sections[1].height, 1200);
    });

    test('uses Section.order rather than list order', () {
      final construction = _buildConstruction(
        width: 2000,
        height: 1200,
        layoutDirection: SectionLayoutDirection.horizontal,
        sections: [
          // Deliberately supplied out of order.
          _fixedSection(id: 's2', order: 1, width: 1200, height: 1200),
          _fixedSection(id: 's1', order: 0, width: 800, height: 1200),
        ],
      );

      final layout = layoutConstruction(construction)!;

      expect(layout.sections[0].section.id, 's1');
      expect(layout.sections[0].x, 0);
      expect(layout.sections[1].section.id, 's2');
      expect(layout.sections[1].x, 800);
    });
  });

  group('layoutConstruction - vertical', () {
    test('places sections top to bottom in order', () {
      final construction = _buildConstruction(
        width: 1200,
        height: 2000,
        layoutDirection: SectionLayoutDirection.vertical,
        sections: [
          _fixedSection(id: 's1', order: 0, width: 1200, height: 800),
          _fixedSection(id: 's2', order: 1, width: 1200, height: 1200),
        ],
      );

      final layout = layoutConstruction(construction)!;

      expect(layout.sections[0].x, 0);
      expect(layout.sections[0].y, 0);
      expect(layout.sections[0].height, 800);

      expect(layout.sections[1].x, 0);
      expect(layout.sections[1].y, 800);
      expect(layout.sections[1].height, 1200);
    });
  });

  test('single section spans the whole construction', () {
    final construction = _buildConstruction(
      width: 1200,
      height: 1400,
      sections: [_fixedSection(id: 's1', order: 0, width: 1200, height: 1400)],
    );

    final layout = layoutConstruction(construction)!;

    expect(layout.width, 1200);
    expect(layout.height, 1400);
    expect(layout.sections, hasLength(1));
    expect(layout.sections.single.x, 0);
    expect(layout.sections.single.y, 0);
  });

  group('layoutConstruction - incomplete construction', () {
    test('returns null when width is not set yet', () {
      final construction = _buildConstruction(
        width: null,
        height: 1200,
        sections: [_fixedSection(id: 's1', order: 0, width: 800, height: 1200)],
      );

      expect(layoutConstruction(construction), isNull);
    });

    test('returns null when height is not set yet', () {
      final construction = _buildConstruction(
        width: 2000,
        height: null,
        sections: [_fixedSection(id: 's1', order: 0, width: 800, height: 1200)],
      );

      expect(layoutConstruction(construction), isNull);
    });

    test('returns null when neither dimension is set yet', () {
      final construction = _buildConstruction(
        width: null,
        height: null,
        sections: [],
      );

      expect(layoutConstruction(construction), isNull);
    });
  });

  group('fitConstructionToCanvas', () {
    test('scales down a wide construction to fit, preserving aspect ratio', () {
      final transform = fitConstructionToCanvas(
        contentWidth: 2000,
        contentHeight: 1000,
        canvasWidth: 1000,
        canvasHeight: 1000,
        padding: 0,
      );

      // Width is the binding constraint: 1000 / 2000 = 0.5 px/mm.
      expect(transform.scale, closeTo(0.5, 1e-9));

      // Scaled content is 1000x500 inside a 1000x1000 canvas -- centered
      // vertically, flush horizontally.
      expect(transform.offsetX, closeTo(0, 1e-9));
      expect(transform.offsetY, closeTo(250, 1e-9));
    });

    test('scales down a tall construction to fit, preserving aspect ratio', () {
      final transform = fitConstructionToCanvas(
        contentWidth: 1000,
        contentHeight: 2000,
        canvasWidth: 1000,
        canvasHeight: 1000,
        padding: 0,
      );

      expect(transform.scale, closeTo(0.5, 1e-9));
      expect(transform.offsetX, closeTo(250, 1e-9));
      expect(transform.offsetY, closeTo(0, 1e-9));
    });

    test('accounts for padding when fitting', () {
      final transform = fitConstructionToCanvas(
        contentWidth: 100,
        contentHeight: 100,
        canvasWidth: 200,
        canvasHeight: 200,
        padding: 50,
      );

      // Available area is 100x100 after padding -- exact fit, scale 1.
      expect(transform.scale, closeTo(1, 1e-9));
      expect(transform.offsetX, closeTo(50, 1e-9));
      expect(transform.offsetY, closeTo(50, 1e-9));
    });

    test('maps millimetre coordinates to pixel coordinates correctly', () {
      final transform = fitConstructionToCanvas(
        contentWidth: 1000,
        contentHeight: 1000,
        canvasWidth: 500,
        canvasHeight: 500,
        padding: 0,
      );

      expect(transform.scale, closeTo(0.5, 1e-9));
      expect(transform.toPixelX(0), closeTo(0, 1e-9));
      expect(transform.toPixelX(1000), closeTo(500, 1e-9));
      expect(transform.toPixelLength(200), closeTo(100, 1e-9));
    });

    test('returns a degenerate scale-0 transform for zero-area content', () {
      final transform = fitConstructionToCanvas(
        contentWidth: 0,
        contentHeight: 1000,
        canvasWidth: 500,
        canvasHeight: 500,
      );

      expect(transform.scale, 0);
    });

    test('returns a degenerate scale-0 transform for zero-area canvas', () {
      final transform = fitConstructionToCanvas(
        contentWidth: 1000,
        contentHeight: 1000,
        canvasWidth: 0,
        canvasHeight: 500,
      );

      expect(transform.scale, 0);
    });
  });

  group('sectionAtPoint', () {
    test('finds the section containing the point (horizontal layout)', () {
      final construction = _buildConstruction(
        width: 1800,
        height: 1200,
        sections: [
          _fixedSection(id: 's1', order: 0, width: 1000, height: 1200),
          _fixedSection(id: 's2', order: 1, width: 800, height: 1200),
        ],
      );
      final layout = layoutConstruction(construction)!;

      expect(sectionAtPoint(layout, const Offset(500, 600))!.section.id, 's1');
      expect(sectionAtPoint(layout, const Offset(1500, 600))!.section.id, 's2');
    });

    test('finds the section containing the point (vertical layout)', () {
      final construction = _buildConstruction(
        width: 1000,
        height: 2000,
        layoutDirection: SectionLayoutDirection.vertical,
        sections: [
          _fixedSection(id: 'top', order: 0, width: 1000, height: 700),
          _fixedSection(id: 'bottom', order: 1, width: 1000, height: 1300),
        ],
      );
      final layout = layoutConstruction(construction)!;

      expect(sectionAtPoint(layout, const Offset(500, 350))!.section.id, 'top');
      expect(
        sectionAtPoint(layout, const Offset(500, 1500))!.section.id,
        'bottom',
      );
    });

    test('returns null outside every section', () {
      final construction = _buildConstruction(
        width: 1000,
        height: 1000,
        sections: [
          _fixedSection(id: 's1', order: 0, width: 1000, height: 1000),
        ],
      );
      final layout = layoutConstruction(construction)!;

      expect(sectionAtPoint(layout, const Offset(-1, 500)), isNull);
      expect(sectionAtPoint(layout, const Offset(1001, 500)), isNull);
      expect(sectionAtPoint(layout, const Offset(500, -0.5)), isNull);
    });

    test('counts boundary points as contained', () {
      final construction = _buildConstruction(
        width: 1000,
        height: 1000,
        sections: [
          _fixedSection(id: 's1', order: 0, width: 1000, height: 1000),
        ],
      );
      final layout = layoutConstruction(construction)!;

      expect(sectionAtPoint(layout, Offset.zero), isNotNull);
      expect(sectionAtPoint(layout, const Offset(1000, 1000)), isNotNull);
    });
  });
}
