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

  group('snapToGrid (grid source)', () {
    test('spec table: 748 rounds per increment', () {
      double? snap(double position, double increment) => snapToGrid(
            positionMm: position,
            incrementMm: increment,
            toleranceMm: 1000, // generous; distance rules are tested below
          )?.snappedPositionMm;

      expect(snap(748.0, 1), 748);
      expect(snap(748.2, 5), 750);
      expect(snap(748.0, 10), 750);
      expect(snap(748.0, 50), 750);
    });

    test('rounds DOWN when nearer the lower multiple', () {
      final result = snapToGrid(
        positionMm: 747.4,
        incrementMm: 5,
        toleranceMm: 100,
      );
      expect(result!.snappedPositionMm, 745);
    });

    test('produces grid-kind targets at the snapped position', () {
      final result = snapToGrid(
        positionMm: 748.2,
        incrementMm: 5,
        toleranceMm: 100,
      );
      expect(result!.target.kind, SnapTargetKind.grid);
      expect(result.target.positionMm, 750);
      expect(result.snappedPositionMm, 750);
      expect(result.distanceMm, closeTo(1.8, 1e-9));
    });

    test('tolerance gates the candidate inclusively', () {
      // Distance to 750 is exactly 3.
      expect(
        snapToGrid(positionMm: 753, incrementMm: 10, toleranceMm: 3),
        isNotNull,
      );
      expect(
        snapToGrid(positionMm: 753.01, incrementMm: 10, toleranceMm: 3),
        isNull,
      );
    });

    test('negative and fractional positions land on correct multiples', () {
      expect(
        snapToGrid(positionMm: -12.4, incrementMm: 10, toleranceMm: 100)!
            .snappedPositionMm,
        -10,
      );
      expect(
        snapToGrid(positionMm: 12.6, incrementMm: 0.5, toleranceMm: 100)
            !.snappedPositionMm,
        12.5,
      );
    });

    test('invalid increments produce no grid source', () {
      for (final bad in const [0.0, -5.0, double.nan, double.infinity]) {
        expect(
          snapToGrid(
            positionMm: 100,
            incrementMm: bad,
            toleranceMm: 50,
          ),
          isNull,
          reason: 'increment $bad must disable the grid source',
        );
      }
    });

    test('negative/non-finite tolerance produces no snap', () {
      expect(
        snapToGrid(positionMm: 100, incrementMm: 10, toleranceMm: -1),
        isNull,
      );
      expect(
        snapToGrid(positionMm: 100, incrementMm: 10, toleranceMm: double.nan),
        isNull,
      );
    });
  });

  group('resolveSnapPosition (geometry + grid merge)', () {
    final geometryTargets = [
      const SnapTarget1D(
        positionMm: 500,
        kind: SnapTargetKind.sectionBoundary,
      ),
      const SnapTarget1D(positionMm: 1000, kind: SnapTargetKind.sectionBoundary),
    ];

    test('disabled config short-circuits to null even with targets present',
        () {
      expect(
        resolveSnapPosition(
          positionMm: 500.0000001,
          targets: geometryTargets,
          config: const SnapConfig.disabled(),
          toleranceMm: 50,
        ),
        isNull,
      );
      // Also with a grid configured -- OFF means OFF.
      expect(
        resolveSnapPosition(
          positionMm: 500.0000001,
          targets: geometryTargets,
          config: const SnapConfig(enabled: false, gridIncrementMm: 5),
          toleranceMm: 50,
        ),
        isNull,
      );
    });

    test('enabled without increment reproduces legacy geometry-only behavior',
        () {
      expect(
        resolveSnapPosition(
          positionMm: 996,
          targets: geometryTargets,
          config: const SnapConfig(),
          toleranceMm: 5,
        )!.snappedPositionMm,
        1000,
      );
      expect(
        resolveSnapPosition(
          positionMm: 970, // outside tolerance of both targets
          targets: geometryTargets,
          config: const SnapConfig(),
          toleranceMm: 5,
        ),
        isNull,
      );
    });

    test('grid wins when strictly closer than any geometry target', () {
      // 498 -> 2 mm to geometry(500), 2 mm... use clearer numbers:
      // 997 is 3 from geometry(1000) but 2 from grid(995 @ 5mm).
      final result = resolveSnapPosition(
        positionMm: 997,
        targets: geometryTargets,
        config: const SnapConfig(gridIncrementMm: 5),
        toleranceMm: 20,
      );
      expect(result!.target.kind, SnapTargetKind.grid);
      expect(result.snappedPositionMm, 995);
    });

    test('geometry wins when strictly closer', () {
      // 999 is 1 from geometry(1000) vs 4 from grid(995).
      final result = resolveSnapPosition(
        positionMm: 999,
        targets: geometryTargets,
        config: const SnapConfig(gridIncrementMm: 5),
        toleranceMm: 20,
      );
      expect(result!.target.kind, SnapTargetKind.sectionBoundary);
      expect(result.snappedPositionMm, 1000);
    });

    test('EXACT tie resolves to GEOMETRY (deterministic priority)', () {
      // 750 is equidistant (250) from 500 and 1000... make an exact
      // geometry-vs-grid tie instead: 997.5 with increment 5 -> 997.5 is
      // 2.5 from grid(995)/grid(1000); use 1002.5 with geometry 1000:
      // distance 2.5 == distance to grid 1000 (multiple of 5). Geometry
      // must win despite being evaluated first.
      final result = resolveSnapPosition(
        positionMm: 1002.5,
        targets: geometryTargets,
        config: const SnapConfig(gridIncrementMm: 5),
        toleranceMm: 50,
      );
      expect(result!.target.kind, SnapTargetKind.sectionBoundary);
      expect(result.snappedPositionMm, 1000);
    });

    test('outcome is independent of target list order', () {
      final positions = [997.0, 999.0, 1002.5];
      final orders = [
        geometryTargets,
        geometryTargets.reversed.toList(),
      ];
      for (final order in orders) {
        for (final position in positions) {
          final result = resolveSnapPosition(
            positionMm: position,
            targets: order,
            config: const SnapConfig(gridIncrementMm: 5),
            toleranceMm: 50,
          )!;
          final expected = position == 997
              ? SnapTargetKind.grid
              : SnapTargetKind.sectionBoundary;
          expect(result.target.kind, expected,
              reason: 'position $position flipped with reordered targets');
        }
      }
    });

    test('grid-only context still snaps when no geometry qualifies', () {
      final result = resolveSnapPosition(
        positionMm: 748.2,
        targets: const [],
        config: const SnapConfig(gridIncrementMm: 5),
        toleranceMm: 10,
      );
      expect(result!.snappedPositionMm, 750);
      expect(result.target.kind, SnapTargetKind.grid);
    });

    test('geometry-only context ignores invalid grid increments entirely', () {
      final result = resolveSnapPosition(
        positionMm: 997,
        targets: geometryTargets,
        config: const SnapConfig(gridIncrementMm: -5),
        toleranceMm: 20,
      );
      // No grid source -> nearest geometry target within tolerance.
      expect(result!.target.kind, SnapTargetKind.sectionBoundary);
      expect(result.snappedPositionMm, 1000); // 3 mm away, inside tolerance
    });

    test('grid candidate itself respects tolerance (not just rounding)', () {
      // At high zoom the model-space tolerance can shrink below half the
      // increment: 12 px / scale 6 == 2 mm; half of 10 mm increment is 5.
      // Position 996.5 is 3.5 from grid 1000 -> OUTSIDE a 2 mm window even
      // though it would round there.
      expect(
        resolveSnapPosition(
          positionMm: 996.5,
          targets: geometryTargets,
          config: const SnapConfig(gridIncrementMm: 10),
          toleranceMm: kSnapTolerancePx / 6,
        ),
        isNull,
      );
    });
  });
}
