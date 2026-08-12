import 'package:flutter_test/flutter_test.dart';
import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/layout_direction.dart';
import 'package:aluminium_designer/core/models/section.dart';
import 'package:aluminium_designer/core/models/section_geometry.dart';

Construction _buildConstruction({
  required List<Section> sections,
  required double width,
  required double height,
  SectionLayoutDirection layoutDirection = SectionLayoutDirection.horizontal,
  ConstructionType type = ConstructionType.window,
}) {
  return Construction(
    id: 'c1',
    name: 'Test',
    type: type,
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
  group('validateSectionGeometry - horizontal', () {
    test('valid: multiple sections, widths sum, heights match', () {
      final construction = _buildConstruction(
        width: 2000,
        height: 1200,
        layoutDirection: SectionLayoutDirection.horizontal,
        sections: [
          _fixedSection(id: 's1', order: 0, width: 800, height: 1200),
          _fixedSection(id: 's2', order: 1, width: 1200, height: 1200),
        ],
      );

      expect(validateSectionGeometry(construction), isEmpty);
    });

    test('invalid: section widths do not sum to construction width', () {
      final construction = _buildConstruction(
        width: 2000,
        height: 1200,
        layoutDirection: SectionLayoutDirection.horizontal,
        sections: [
          _fixedSection(id: 's1', order: 0, width: 800, height: 1200),
          _fixedSection(id: 's2', order: 1, width: 900, height: 1200),
        ],
      );

      expect(validateSectionGeometry(construction), isNotEmpty);
    });

    test('invalid: a section height does not match construction height', () {
      final construction = _buildConstruction(
        width: 2000,
        height: 1200,
        layoutDirection: SectionLayoutDirection.horizontal,
        sections: [
          _fixedSection(id: 's1', order: 0, width: 800, height: 1200),
          _fixedSection(id: 's2', order: 1, width: 1200, height: 1000),
        ],
      );

      expect(validateSectionGeometry(construction), isNotEmpty);
    });
  });

  group('validateSectionGeometry - vertical', () {
    test('valid: multiple sections, heights sum, widths match', () {
      final construction = _buildConstruction(
        width: 1200,
        height: 2000,
        layoutDirection: SectionLayoutDirection.vertical,
        sections: [
          _fixedSection(id: 's1', order: 0, width: 1200, height: 800),
          _fixedSection(id: 's2', order: 1, width: 1200, height: 1200),
        ],
      );

      expect(validateSectionGeometry(construction), isEmpty);
    });

    test('invalid: section heights do not sum to construction height', () {
      final construction = _buildConstruction(
        width: 1200,
        height: 2000,
        layoutDirection: SectionLayoutDirection.vertical,
        sections: [
          _fixedSection(id: 's1', order: 0, width: 1200, height: 800),
          _fixedSection(id: 's2', order: 1, width: 1200, height: 900),
        ],
      );

      expect(validateSectionGeometry(construction), isNotEmpty);
    });

    test('invalid: a section width does not match construction width', () {
      final construction = _buildConstruction(
        width: 1200,
        height: 2000,
        layoutDirection: SectionLayoutDirection.vertical,
        sections: [
          _fixedSection(id: 's1', order: 0, width: 1200, height: 800),
          _fixedSection(id: 's2', order: 1, width: 1000, height: 1200),
        ],
      );

      expect(validateSectionGeometry(construction), isNotEmpty);
    });
  });

  test('valid: single section matches full construction dimensions', () {
    final construction = _buildConstruction(
      width: 1200,
      height: 1400,
      layoutDirection: SectionLayoutDirection.horizontal,
      sections: [_fixedSection(id: 's1', order: 0, width: 1200, height: 1400)],
    );

    expect(validateSectionGeometry(construction), isEmpty);
  });

  test('curtain wall is not rejected by the linear validator', () {
    final construction = _buildConstruction(
      width: 3000,
      height: 3000,
      type: ConstructionType.curtainWall,
      layoutDirection: SectionLayoutDirection.horizontal,
      sections: [_fixedSection(id: 's1', order: 0, width: 500, height: 500)],
    );

    expect(validateSectionGeometry(construction), isEmpty);
  });
}
