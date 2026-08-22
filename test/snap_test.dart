import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/geometry/section_layout.dart';
import 'package:aluminium_designer/core/geometry/snap.dart';
import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/layout_direction.dart';
import 'package:aluminium_designer/core/models/project_json.dart'
    show ConstructionJson;
import 'package:aluminium_designer/core/models/section.dart';
import 'package:aluminium_designer/features/constructions/editor/editor_viewport.dart';

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
  String id = 's1',
  int order = 0,
  double width = 1000,
  double height = 1200,
}) {
  return Section(
    id: id,
    order: order,
    kind: SectionKind.fixed,
    width: width,
    height: height,
  );
}

/// Two-section horizontal construction: s1 (1000 wide) + s2 (800 wide),
/// total 1800 -- the canonical fixture for boundary positions
/// [0, 1000, 1800].
ConstructionLayout _twoSectionHorizontal() => layoutConstruction(
  _buildConstruction(
    width: 1800,
    height: 1200,
    sections: [
      _fixedSection(id: 's1', order: 0, width: 1000),
      _fixedSection(id: 's2', order: 1, width: 800),
    ],
  ),
)!;

void main() {
  group('collectSnapTargets - horizontal', () {
    test('yields edges and interior boundaries with correct kinds', () {
      final targets = collectSnapTargets(
        _twoSectionHorizontal(),
        SectionLayoutDirection.horizontal,
      );

      expect(targets.map((t) => t.positionMm).toList(), [0, 1000, 1800]);
      expect(targets[0].kind, SnapTargetKind.constructionEdge);
      expect(targets[1].kind, SnapTargetKind.sectionBoundary);
      expect(targets[2].kind, SnapTargetKind.constructionEdge);
    });

    test('is independent of section list order (uses Section.order)', () {
      final construction = _buildConstruction(
        width: 1800,
        height: 1200,
        sections: [
          _fixedSection(id: 's2', order: 1, width: 800),
          _fixedSection(id: 's1', order: 0, width: 1000),
        ],
      );

      final targets = collectSnapTargets(
        layoutConstruction(construction)!,
        SectionLayoutDirection.horizontal,
      );

      expect(targets.map((t) => t.positionMm).toList(), [0, 1000, 1800]);
    });

    test('a single section yields only the two construction edges', () {
      final layout = layoutConstruction(
        _buildConstruction(
          width: 1200,
          height: 900,
          sections: [_fixedSection(id: 'only', order: 0, width: 1200)],
        ),
      )!;

      final targets = collectSnapTargets(
        layout,
        SectionLayoutDirection.horizontal,
      );

      expect(targets.length, 2);
      for (final t in targets) {
        expect(t.kind, SnapTargetKind.constructionEdge);
      }
      expect(targets.map((t) => t.positionMm), [0, 1200]);
    });

    test('an empty-sections layout yields just the two edges', () {
      final layout = layoutConstruction(
        _buildConstruction(width: 1800, height: 1200, sections: []),
      )!;

      final targets = collectSnapTargets(
        layout,
        SectionLayoutDirection.horizontal,
      );

      expect(targets.map((t) => t.positionMm), [0, 1800]);
    });
  });

  group('collectSnapTargets - vertical', () {
    test('mirrors onto Y using heights and total height', () {
      final layout = layoutConstruction(
        _buildConstruction(
          width: 1000,
          height: 2000,
          layoutDirection: SectionLayoutDirection.vertical,
          sections: [
            _fixedSection(id: 'top', order: 0, width: 1000, height: 700),
            _fixedSection(id: 'bottom', order: 1, width: 1000, height: 1300),
          ],
        ),
      )!;

      final targets = collectSnapTargets(
        layout,
        SectionLayoutDirection.vertical,
      );

      expect(targets.map((t) => t.positionMm), [0, 700, 2000]);
      expect(targets[1].kind, SnapTargetKind.sectionBoundary);
      expect(targets[0].kind, SnapTargetKind.constructionEdge);
      expect(targets[2].kind, SnapTargetKind.constructionEdge);
    });
  });

  group('collector output contract', () {
    test('returns an unmodifiable list sorted ascending', () {
      final targets = collectSnapTargets(
        _twoSectionHorizontal(),
        SectionLayoutDirection.horizontal,
      );

      expect(
        () => targets.add(
          const SnapTarget1D(
            positionMm: 5,
            kind: SnapTargetKind.sectionBoundary,
          ),
        ),
        throwsUnsupportedError,
      );
      expect(
        targets.map((t) => t.positionMm),
        orderedEquals([...targets.map((t) => t.positionMm)]..sort()),
      );
    });

    test('collecting never mutates the underlying construction', () {
      final construction = _buildConstruction(
        width: 1800,
        height: 1200,
        sections: [
          _fixedSection(id: 's1', order: 0, width: 1000),
          _fixedSection(id: 's2', order: 1, width: 800),
        ],
      );
      final before = construction.toJson().toString();

      collectSnapTargets(
        layoutConstruction(construction)!,
        SectionLayoutDirection.horizontal,
      );

      expect(construction.toJson().toString(), before);
    });
  });

  group('snapPosition', () {
    final targets = [
      const SnapTarget1D(positionMm: 500, kind: SnapTargetKind.sectionBoundary),
      const SnapTarget1D(
        positionMm: 1000,
        kind: SnapTargetKind.sectionBoundary,
      ),
    ];

    test('snaps exactly onto a target with zero distance', () {
      final result = snapPosition(
        positionMm: 1000,
        targets: targets,
        toleranceMm: 5,
      );

      expect(result, isNotNull);
      expect(result!.snappedPositionMm, 1000);
      expect(result.distanceMm, 0);
      expect(result.target.positionMm, 1000);
    });

    test('snaps a nearby position within tolerance', () {
      final result = snapPosition(
        positionMm: 996,
        targets: targets,
        toleranceMm: 5,
      );

      expect(result!.snappedPositionMm, 1000);
      expect(result.distanceMm, 4);
    });

    test('returns null outside tolerance', () {
      expect(
        snapPosition(positionMm: 1010, targets: targets, toleranceMm: 5),
        isNull,
      );
    });

    test('tolerance is inclusive at the exact boundary distance', () {
      final result = snapPosition(
        positionMm: 1005,
        targets: targets,
        toleranceMm: 5,
      );

      expect(result!.distanceMm, 5);
      expect(result.snappedPositionMm, 1000);
    });

    test('picks the nearest of multiple candidates', () {
      final result = snapPosition(
        positionMm: 970,
        targets: targets,
        toleranceMm: 50,
      );

      // 30 mm to 1000 vs 470 to 500.
      expect(result!.target.positionMm, 1000);
    });

    test('exact ties resolve deterministically to the LOWER position', () {
      final result = snapPosition(
        positionMm: 750,
        targets: targets,
        toleranceMm: 260,
      );

      expect(result!.target.positionMm, 500);
    });

    test('tie-breaking is independent of target list order', () {
      final reversed = targets.reversed.toList();

      final result = snapPosition(
        positionMm: 750,
        targets: reversed,
        toleranceMm: 260,
      );

      expect(result!.target.positionMm, 500);
    });

    test('no candidates means no snap', () {
      expect(
        snapPosition(positionMm: 1000, targets: const [], toleranceMm: 50),
        isNull,
      );
    });
  });

  group('zoom-consistent tolerance conversion', () {
    test('kSnapTolerancePx / scale shrinks in model space as you zoom in', () {
      const canvas = Size(800, 600);
      final viewport = EditorViewport()..setCanvasSize(canvas);
      viewport.fitToContent(contentWidth: 2000, contentHeight: 1500);

      final scaleZoomedOut = viewport.scale;
      final toleranceZoomedOutMm = kSnapTolerancePx / scaleZoomedOut;

      viewport.zoomBy(8); // clamped well upward in scale

      final scaleZoomedIn = viewport.scale;
      final toleranceZoomedInMm = kSnapTolerancePx / scaleZoomedIn;

      expect(toleranceZoomedInMm, lessThan(toleranceZoomedOutMm));
      // The perceived window is identical: same pixels on screen.
      expect(toleranceZoomedInMm * scaleZoomedIn, kSnapTolerancePx);
      expect(toleranceZoomedOutMm * scaleZoomedOut, kSnapTolerancePx);
    });

    test('the same screen offset maps to proportionally different '
        'model distances at different scales', () {
      const canvas = Size(800, 600);
      final viewport = EditorViewport()..setCanvasSize(canvas);
      viewport.fitToContent(contentWidth: 2000, contentHeight: 1500);
      final scaleBefore = viewport.scale;

      const screenOffsetPx = 12.0;
      final mmAtScaleA = screenOffsetPx / scaleBefore;

      viewport.zoomBy(4);
      final mmAtScaleB = screenOffsetPx / viewport.scale;

      expect(mmAtScaleB, closeTo(mmAtScaleA / 4, 1e-9));
    });
  });
}
