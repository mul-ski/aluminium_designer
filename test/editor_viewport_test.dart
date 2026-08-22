import 'package:flutter/material.dart' show Matrix4, Offset, Size;
import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/geometry/section_layout.dart';
import 'package:aluminium_designer/features/constructions/editor/editor_viewport.dart';

const _canvas = Size(800, 600);

EditorViewport _viewport({Size canvas = _canvas}) {
  final viewport = EditorViewport();
  viewport.setCanvasSize(canvas);
  return viewport;
}

/// The uniform scale of a viewport transform (translate·scale matrices
/// keep m00 == m11 == scale).
double _scaleOf(EditorViewport viewport) => viewport.matrix[0];

Offset _offsetOf(EditorViewport viewport) =>
    Offset(viewport.matrix[12], viewport.matrix[13]);

void main() {
  group('EditorViewport.fitToContent', () {
    test('produces exactly the shared fitConstructionToCanvas result', () {
      final viewport = _viewport();

      expect(
        viewport.fitToContent(contentWidth: 1800, contentHeight: 1200),
        isTrue,
      );

      final fit = fitConstructionToCanvas(
        contentWidth: 1800,
        contentHeight: 1200,
        canvasWidth: _canvas.width,
        canvasHeight: _canvas.height,
        padding: kViewportFitPadding,
      );

      expect(_scaleOf(viewport), fit.scale);
      expect(_offsetOf(viewport), Offset(fit.offsetX, fit.offsetY));
    });

    test('is a no-op before a canvas size is reported', () {
      final viewport = EditorViewport();

      expect(
        viewport.fitToContent(contentWidth: 1000, contentHeight: 500),
        isFalse,
      );
      expect(viewport.matrix, Matrix4.identity());
    });

    test('is a no-op for degenerate content', () {
      expect(
        _viewport().fitToContent(contentWidth: 0, contentHeight: 500),
        isFalse,
      );
      expect(
        _viewport().fitToContent(contentWidth: 1000, contentHeight: -1),
        isFalse,
      );
    });

    test('notifies listeners only when the fit actually applied', () {
      var notifications = 0;
      final viewport = _viewport()..addListener(() => notifications++);

      viewport.fitToContent(contentWidth: 0, contentHeight: 0);
      expect(notifications, 0);

      viewport.fitToContent(contentWidth: 1000, contentHeight: 500);
      expect(notifications, 1);
    });
  });

  group('coordinate conversion', () {
    test('modelToScreen applies offset + scale semantics', () {
      final viewport = _viewport()
        ..fitToContent(contentWidth: 2000, contentHeight: 800);
      final s = _scaleOf(viewport);
      final o = _offsetOf(viewport);

      expect(
        viewport.modelToScreen(const Offset(300, 125)),
        Offset(o.dx + 300 * s, o.dy + 125 * s),
      );
    });

    test('screenToModel inverts modelToScreen across scales and offsets', () {
      const modelPoint = Offset(1234.5, -77.25);

      for (final factor in <double>[0.2, 1.0, 3.7]) {
        final viewport = _viewport()..zoomAt(const Offset(400, 300), factor);

        final roundTripped = viewport.screenToModel(
          viewport.modelToScreen(modelPoint),
        );

        // Exact equality is not guaranteed across multiply/divide in
        // binary floating point; sub-nanometre agreement is.
        expect(
          roundTripped.dx,
          closeTo(modelPoint.dx, 1e-6),
          reason: 'x round-trip failed at scale factor $factor',
        );
        expect(
          roundTripped.dy,
          closeTo(modelPoint.dy, 1e-6),
          reason: 'y round-trip failed at scale factor $factor',
        );
      }
    });

    test('fitting oversized content clamps to the minimum zoom scale', () {
      final viewport = _viewport();

      expect(
        viewport.fitToContent(contentWidth: 100000, contentHeight: 50000),
        isTrue,
      );

      expect(_scaleOf(viewport), kViewportMinScale);
    });
  });

  group('zoom anchoring', () {
    test('zoomBy keeps the viewport-center model point fixed on screen', () {
      final viewport = _viewport()
        ..fitToContent(contentWidth: 1600, contentHeight: 900);

      final center = Offset(_canvas.width / 2, _canvas.height / 2);
      final centerBefore = viewport.modelToScreen(
        viewport.screenToModel(center),
      );

      viewport.zoomBy(1.5);

      final centerAfter = viewport.modelToScreen(
        viewport.screenToModel(center),
      );
      expect(centerAfter, centerBefore);
    });

    test('zoomAt keeps the exact anchor point stable under the cursor', () {
      final viewport = _viewport()
        ..fitToContent(contentWidth: 2400, contentHeight: 1400);
      const cursor = Offset(613, 247);

      final modelUnderCursor = viewport.screenToModel(cursor);
      viewport.zoomAt(cursor, 2.0);

      // The same model point must still project to the same screen point.
      expect(viewport.modelToScreen(modelUnderCursor), cursor);
    });

    test('clamps runaway zooming to the configured bounds', () {
      final viewport = _viewport();

      for (var i = 0; i < 30; i++) {
        viewport.zoomBy(10);
      }
      expect(_scaleOf(viewport), kViewportMaxScale);

      for (var i = 0; i < 40; i++) {
        viewport.zoomBy(0.000001);
      }
      expect(_scaleOf(viewport), kViewportMinScale);
    });

    test('zoomAt is a no-op once already clamped at a bound', () {
      var notifications = 0;
      final viewport = _viewport()..addListener(() => notifications++);

      // Drive the scale down onto the minimum bound.
      for (var i = 0; i < 40; i++) {
        viewport.zoomBy(0.000001);
      }
      expect(_scaleOf(viewport), kViewportMinScale);
      final before = viewport.matrix;
      final notificationsBefore = notifications;

      viewport.zoomAt(const Offset(100, 100), 0.5); // would clamp again

      expect(notifications, notificationsBefore);
      expect(viewport.matrix, before);
    });
  });

  group('panning', () {
    test('panBy translates without changing scale', () {
      final viewport = _viewport()
        ..fitToContent(contentWidth: 1200, contentHeight: 900);
      final scaleBefore = _scaleOf(viewport);

      viewport.panBy(const Offset(-40, 15));

      expect(_scaleOf(viewport), scaleBefore);
    });

    test('panBy moves the model origin on screen by exactly the delta', () {
      final viewport = _viewport()
        ..fitToContent(contentWidth: 1200, contentHeight: 900);
      final originBefore = viewport.modelToScreen(Offset.zero);

      const delta = Offset(-64.5, 33.25);
      viewport.panBy(delta);

      expect(viewport.modelToScreen(Offset.zero), originBefore + delta);
    });
  });

  group('canvas size tracking', () {
    test('setCanvasSize notifies only on change', () {
      var notifications = 0;
      final viewport = EditorViewport()..addListener(() => notifications++);

      viewport.setCanvasSize(_canvas);
      expect(notifications, 1);
      expect(viewport.canvasSize, _canvas);

      viewport.setCanvasSize(_canvas);
      expect(notifications, 1);
    });
  });

  group('scale accessor', () {
    test('reflects the uniform transform scale through fit and zoom', () {
      final viewport = _viewport()
        ..fitToContent(contentWidth: 2000, contentHeight: 1000);

      expect(viewport.scale, viewport.matrix[0]);

      final scaleBefore = viewport.scale;
      viewport.zoomBy(2);
      expect(viewport.scale, closeTo(scaleBefore * 2, 1e-9));
      expect(viewport.matrix[0], closeTo(scaleBefore * 2, 1e-9));
    });

    test('starts at identity scale', () {
      expect(_viewport().scale, 1.0);
    });
  });
}
