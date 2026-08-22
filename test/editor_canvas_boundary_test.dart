import 'dart:ui' show PointerDeviceKind, Size;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/geometry/section_layout.dart';
import 'package:aluminium_designer/core/geometry/snap.dart';
import 'package:aluminium_designer/core/logic/boundary_manipulation.dart';
import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/layout_direction.dart';
import 'package:aluminium_designer/core/models/section.dart';
import 'package:aluminium_designer/features/constructions/editor/editor_viewport.dart';
import 'package:aluminium_designer/features/constructions/editor/widgets/editor_canvas.dart';
import 'package:aluminium_designer/features/constructions/widgets/construction_painter.dart';

/// Gesture-driven tests for direct section-boundary manipulation:
/// corridor grabbing, snapping + ActiveSnap lifecycle, preview-vs-commit,
/// one-drag-one-undo-entry semantics, pan/pinch priority outside the
/// corridor, and horizontal/vertical parity.

const double _w = 2400;
const double _h = 1200;

Construction _horizontal() => Construction(
  id: 'c1',
  name: 'Facade',
  type: ConstructionType.window,
  width: _w,
  height: _h,
  manufacturer: '',
  system: '',
  sections: [
    Section(id: 'a', order: 0, kind: SectionKind.fixed, width: 900, height: _h),
    Section(id: 'b', order: 1, kind: SectionKind.fixed, width: 600, height: _h),
    Section(id: 'c', order: 2, kind: SectionKind.fixed, width: 900, height: _h),
  ],
  profiles: const [],
);

// Boundaries of [_horizontal]: index 1 at 900 mm (between a|b), index 2 at
// 1500 mm (between b|c).

class _Harness extends StatefulWidget {
  const _Harness({super.key, required this.initial});

  final Construction initial;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late Construction construction = widget.initial;
  final EditorViewport viewport = EditorViewport();
  String? selectedSectionId;
  final List<(int, double)> commits = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 900,
          height: 700,
          child: EditorCanvas(
            construction: construction,
            selectedSectionId: selectedSectionId,
            viewport: viewport,
            onSectionTap: (id) => setState(() => selectedSectionId = id),
            onBoundaryDragCompleted: (index, position) {
              commits.add((index, position));
              setState(() {
                construction = withBoundaryMoved(construction, index, position);
              });
            },
          ),
        ),
      ),
    );
  }
}

Future<_HarnessState> _pumpHarness(
  WidgetTester tester,
  Construction initial,
) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final key = GlobalKey<_HarnessState>();
  await tester.pumpWidget(
    MaterialApp(
      home: _Harness(key: key, initial: initial),
    ),
  );
  await tester.pumpAndSettle();

  // Mirror the screen's one-time initial fit so the transform is
  // deterministic; the canvas has already reported its size post-frame.
  final state = key.currentState!;
  state.viewport.fitToContent(
    contentWidth: state.construction.width!,
    contentHeight: state.construction.height!,
  );
  await tester.pumpAndSettle();
  return state;
}

Offset _pointFor(WidgetTester tester, double mmX, double mmY) =>
    _pointForIn(tester, contentW: _w, contentH: _h, mmX: mmX, mmY: mmY);

Offset _pointForIn(
  WidgetTester tester, {
  required double contentW,
  required double contentH,
  required double mmX,
  required double mmY,
}) {
  final topLeft = tester.getTopLeft(find.byType(EditorCanvas));
  final size = tester.getSize(find.byType(EditorCanvas));
  final fit = fitConstructionToCanvas(
    contentWidth: contentW,
    contentHeight: contentH,
    canvasWidth: size.width,
    canvasHeight: size.height,
    padding: kViewportFitPadding,
  );
  return topLeft +
      Offset(fit.offsetX + mmX * fit.scale, fit.offsetY + mmY * fit.scale);
}

ConstructionPainter _painter(WidgetTester tester) {
  final customPaint = tester.widget<CustomPaint>(
    find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && widget.painter is ConstructionPainter,
    ),
  );
  return customPaint.painter as ConstructionPainter;
}

void main() {
  group('boundary drag - horizontal', () {
    testWidgets('snaps to another boundary, previews clamped result, '
        'commits once and clears ActiveSnap', (tester) async {
      final state = await _pumpHarness(tester, _horizontal());
      final scale = state.viewport.scale;

      // Grab boundary 1 (at 900 mm) and move it right onto the other
      // interior boundary at 1500 mm.
      final gesture = await tester.startGesture(_pointFor(tester, 900, 600));
      await tester.pump();
      await gesture.moveBy(Offset((1500 - 900) * scale, 0));
      await tester.pump();

      // Mid-drag: the snap target is indicated...
      final painter = _painter(tester);
      expect(painter.activeSnap, isNotNull);
      expect(painter.activeSnap!.positionMm, 1500);
      expect(painter.activeSnap!.kind, SnapTargetKind.sectionBoundary);
      // ...and the PREVIEW shows the clamped result ('b' floored at
      // kMinSectionSizeMm because it cannot vanish).
      expect(painter.construction.sections[0].width, 1499);
      expect(painter.construction.sections[1].width, kMinSectionSizeMm);
      expect(painter.construction.sections[2].width, 900); // untouched

      await gesture.up();
      await tester.pumpAndSettle();

      // Exactly one commit; indicator cleared; model updated.
      expect(state.commits.length, 1);
      expect(state.commits.single.$1, 1);
      expect(state.commits.single.$2, closeTo(1499, 1e-9));
      expect(state.construction.sections[0].width, 1499);
      expect(_painter(tester).activeSnap, isNull);
    });

    testWidgets('movement away from targets commits unsnapped raw position', (
      tester,
    ) async {
      final state = await _pumpHarness(tester, _horizontal());
      final scale = state.viewport.scale;

      final gesture = await tester.startGesture(_pointFor(tester, 900, 600));
      await tester.pump();
      await gesture.moveBy(Offset(60, 0));
      await tester.pump();

      // Raw ≈ 900 + 60/scale -- far from every remaining target.
      final expectedPosition = 900 + 60 / scale;
      expect(_painter(tester).activeSnap, isNull);
      expect(
        _painter(tester).construction.sections[0].width,
        closeTo(expectedPosition, 0.01),
      );

      await gesture.up();
      await tester.pumpAndSettle();

      expect(state.commits.length, 1);
      expect(state.commits.single.$2, closeTo(expectedPosition, 0.01));
    });

    testWidgets('a tap inside the corridor is a no-op', (tester) async {
      final state = await _pumpHarness(tester, _horizontal());

      // Select section b first so we can prove the corridor tap does not
      // clear or change selection.
      await tester.tapAt(_pointFor(tester, 1200, 600));
      await tester.pumpAndSettle();
      expect(state.selectedSectionId, 'b');

      await tester.tapAt(_pointFor(tester, 900, 600)); // corridor
      await tester.pumpAndSettle();

      expect(state.selectedSectionId, 'b'); // preserved, not reset to root
      expect(state.commits, isEmpty);
    });

    testWidgets('selection still works right beside the corridor', (
      tester,
    ) async {
      final state = await _pumpHarness(tester, _horizontal());

      await tester.tapAt(_pointFor(tester, 1950, 600)); // centre of c
      await tester.pumpAndSettle();

      expect(state.selectedSectionId, 'c');
    });
  });

  group('pan/pinch priority', () {
    testWidgets('single-pointer drag away from corridors pans instead of '
        'mutating the construction', (tester) async {
      final state = await _pumpHarness(tester, _horizontal());
      final constructionBefore = state.construction;
      final txBefore = state.viewport.matrix[12];
      final tyBefore = state.viewport.matrix[13];

      // Centre of section a: far (>100 px) from any boundary corridor.
      final gesture = await tester.startGesture(_pointFor(tester, 450, 600));
      await tester.pump();
      await gesture.moveBy(const Offset(150, 40));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(state.viewport.matrix[12], closeTo(txBefore + 150, 1e-6));
      expect(state.viewport.matrix[13], closeTo(tyBefore + 40, 1e-6));
      expect(state.commits, isEmpty);
      expect(identical(state.construction, constructionBefore), isTrue);
    });

    testWidgets('two-finger gestures starting on a corridor stay in '
        'pan/pinch mode', (tester) async {
      final state = await _pumpHarness(tester, _horizontal());
      final matrixBefore = state.viewport.matrix.clone();

      final g1 = await tester.startGesture(_pointFor(tester, 900, 580));
      final g2 = await tester.startGesture(_pointFor(tester, 900, 620));
      await tester.pump();
      await g1.moveBy(const Offset(-50, -30));
      await g2.moveBy(const Offset(50, 30));
      await tester.pump();
      await g1.up();
      await g2.up();
      await tester.pumpAndSettle();

      // Boundary mode requires a SINGLE pointer at start; with two, the
      // gesture stays pan/pinch and nothing is committed -- but the
      // viewport DID respond.
      expect(state.commits, isEmpty);
      expect(
        listEquals(matrixBefore.storage, state.viewport.matrix.storage),
        isFalse,
      );
    });
  });

  group('boundary drag - vertical', () {
    testWidgets('mirrors onto heights preserving widths', (tester) async {
      final vertical = Construction(
        id: 'v',
        name: 'Vertical',
        type: ConstructionType.window,
        width: 1200,
        height: 2400,
        manufacturer: '',
        system: '',
        sections: [
          Section(
            id: 'a',
            order: 0,
            kind: SectionKind.fixed,
            width: 1200,
            height: 900,
          ),
          Section(
            id: 'b',
            order: 1,
            kind: SectionKind.fixed,
            width: 1200,
            height: 600,
          ),
          Section(
            id: 'c',
            order: 2,
            kind: SectionKind.fixed,
            width: 1200,
            height: 900,
          ),
        ],
        layoutDirection: SectionLayoutDirection.vertical,
        profiles: [],
      );

      final state = await _pumpHarness(tester, vertical);
      final scale = state.viewport.scale;

      // Boundary 1 sits at y=900; drag downward onto the next interior
      // boundary at y=1500 (snap wall applies as in the horizontal case).
      final gesture = await tester.startGesture(
        _pointForIn(tester, contentW: 1200, contentH: 2400, mmX: 600, mmY: 900),
      );
      await tester.pump();
      await gesture.moveBy(Offset(0, (1500 - 900) * scale));
      await tester.pump();

      final painter = _painter(tester);
      expect(painter.activeSnap?.positionMm, 1500);
      expect(painter.construction.sections[0].height, 1499);
      expect(painter.construction.sections[1].height, kMinSectionSizeMm);
      expect(painter.construction.sections[0].width, 1200); // cross untouched

      await gesture.up();
      await tester.pumpAndSettle();

      expect(state.commits.single.$1, 1);
      expect(state.construction.sections[1].height, kMinSectionSizeMm);
    });
  });

  testWidgets('zoomed viewport produces correct model-space movement', (
    tester,
  ) async {
    final state = await _pumpHarness(tester, _horizontal());

    // Zoom in substantially -- ANCHORED ON THE BOUNDARY itself, so it
    // remains visible and grabbable afterwards.
    final boundaryOnScreen =
        tester.getTopLeft(find.byType(EditorCanvas)) +
        state.viewport.modelToScreen(const Offset(900, 600));
    state.viewport.zoomAt(
      boundaryOnScreen - tester.getTopLeft(find.byType(EditorCanvas)),
      4,
    );
    await tester.pumpAndSettle();
    final scale = state.viewport.scale;

    // Where does the boundary live NOW?
    final grabPoint =
        tester.getTopLeft(find.byType(EditorCanvas)) +
        state.viewport.modelToScreen(const Offset(900, 600));

    const screenDeltaPx = 48.0;
    final gesture = await tester.startGesture(grabPoint);
    await tester.pump();
    await gesture.moveBy(const Offset(screenDeltaPx, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final expectedPosition = 900 + screenDeltaPx / scale;
    expect(state.commits.single.$2, closeTo(expectedPosition, 0.01));
  });

  testWidgets('hovering a corridor switches the cursor affordance', (
    tester,
  ) async {
    await _pumpHarness(tester, _horizontal());

    MouseRegion region() => tester.widget<MouseRegion>(
      find.descendant(
        of: find.byType(EditorCanvas),
        matching: find.byType(MouseRegion),
      ),
    );
    // A button-less mouse pointer produces real hover events.
    final hover = TestPointer(7, PointerDeviceKind.mouse);

    void hoverAt(double mmX, double mmY) {
      tester.binding.handlePointerEvent(
        hover.hover(_pointFor(tester, mmX, mmY)),
      );
    }

    // Above the construction's cross extent: no affordance.
    tester.binding.handlePointerEvent(hover.hover(const Offset(400, 20)));
    await tester.pump();
    expect(region().cursor, MouseCursor.defer);

    // Over the boundary corridor: resize affordance.
    hoverAt(900, 600);
    await tester.pump();
    expect(region().cursor, SystemMouseCursors.resizeLeftRight);

    // Away from any corridor again.
    hoverAt(450, 600);
    await tester.pump();
    expect(region().cursor, MouseCursor.defer);
  });
}
