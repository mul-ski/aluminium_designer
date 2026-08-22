import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/geometry/snap.dart';
import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/section.dart';
import 'package:aluminium_designer/features/constructions/editor/editor_viewport.dart';
import 'package:aluminium_designer/features/constructions/editor/widgets/editor_canvas.dart';
import 'package:aluminium_designer/features/constructions/widgets/construction_painter.dart';

/// Plumbing tests for the dormant snap-indicator path: EditorCanvas must
/// forward its [ActiveSnap] into the painter it builds, and painting with
/// an active snap must never crash -- including on incomplete constructions
/// where the layout is null.
///
/// Pixel-level verification of the indicator drawing is deferred to the
/// drag-manipulation task, where a live producer makes real assertions (or
/// goldens) meaningful. Today nothing can produce an ActiveSnap, so these
/// tests pin only the dormant wiring.

Construction _completeConstruction() => Construction(
  id: 'c1',
  name: 'Test',
  type: ConstructionType.window,
  width: 1800,
  height: 1200,
  manufacturer: '',
  system: '',
  sections: [
    Section(
      id: 's1',
      order: 0,
      kind: SectionKind.fixed,
      width: 1000,
      height: 1200,
    ),
    Section(
      id: 's2',
      order: 1,
      kind: SectionKind.fixed,
      width: 800,
      height: 1200,
    ),
  ],
  profiles: const [],
);

Construction _incompleteConstruction() => Construction(
  id: 'c2',
  name: 'Incomplete',
  type: ConstructionType.window,
  manufacturer: '',
  system: '',
  sections: const [],
  profiles: const [],
);

Future<void> _pumpCanvas(
  WidgetTester tester, {
  required Construction construction,
  ActiveSnap? activeSnap,
}) async {
  tester.view.physicalSize = const Size(1000, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          child: SizedBox(
            width: 600,
            height: 400,
            child: EditorCanvas(
              construction: construction,
              selectedSectionId: null,
              viewport: EditorViewport(),
              onSectionTap: (_) {},
              activeSnap: activeSnap,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ConstructionPainter _painterOf(WidgetTester tester) {
  final customPaint = tester.widget<CustomPaint>(
    find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is ConstructionPainter,
    ),
  );
  return customPaint.painter as ConstructionPainter;
}

void main() {
  testWidgets('canvas forwards a null activeSnap by default', (tester) async {
    await _pumpCanvas(tester, construction: _completeConstruction());

    expect(_painterOf(tester).activeSnap, isNull);
  });

  testWidgets('canvas forwards the provided activeSnap to its painter', (
    tester,
  ) async {
    const snap = ActiveSnap(
      positionMm: 1000,
      kind: SnapTargetKind.sectionBoundary,
    );

    await _pumpCanvas(
      tester,
      construction: _completeConstruction(),
      activeSnap: snap,
    );

    expect(_painterOf(tester).activeSnap, same(snap));
  });

  testWidgets(
    'painting an active snap over a complete construction does not crash',
    (tester) async {
      await _pumpCanvas(
        tester,
        construction: _completeConstruction(),
        activeSnap: const ActiveSnap(
          positionMm: 500,
          kind: SnapTargetKind.sectionBoundary,
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('painting an active snap over an incomplete construction (null '
      'layout) does not crash -- the indicator is simply skipped', (
    tester,
  ) async {
    await _pumpCanvas(
      tester,
      construction: _incompleteConstruction(),
      activeSnap: const ActiveSnap(
        positionMm: 500,
        kind: SnapTargetKind.sectionBoundary,
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
