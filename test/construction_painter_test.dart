import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/geometry/section_layout.dart';
import 'package:aluminium_designer/core/geometry/snap.dart';
import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/layout_direction.dart';
import 'package:aluminium_designer/core/models/section.dart';
import 'package:aluminium_designer/features/constructions/widgets/construction_painter.dart';

/// Regression tests for a runtime crash where _paintSectionLabel called
/// TextPainter.layout with a NEGATIVE maxWidth whenever a section rendered
/// narrower than 8 px on screen (e.g. a narrow section while zoomed out to
/// the viewport minimum scale of 0.2). Since the first-class viewport
/// rewrite, the paint-time transform is the LIVE zoom -- unlike the old
/// InteractiveViewer architecture where labels were always laid out at the
/// internal fit scale regardless of zoom -- which made this latent bug
/// reachable and crashed every painted frame.
///
/// The fix requires the legibility guard to run BEFORE layout so
/// TextPainter only ever receives valid, positive constraints.

Construction _constructionWithSliverSection() {
  // A realistic mixed facade: mostly wide panels plus one narrow 30 mm
  // sliver. At scale 0.2 the sliver renders 6 px wide -> available label
  // width was -2 px.
  Section fixed(String id, int order, double width) => Section(
    id: id,
    order: order,
    kind: SectionKind.fixed,
    width: width,
    height: 1200,
  );

  return Construction(
    id: 'c1',
    name: 'Facade',
    type: ConstructionType.window,
    width: 1830,
    height: 1200,
    manufacturer: '',
    system: '',
    sections: [
      fixed('s1', 0, 900),
      fixed('sliver', 1, 30),
      fixed('s3', 2, 900),
    ],
    layoutDirection: SectionLayoutDirection.horizontal,
    profiles: const [],
  );
}

void _paintWith(ConstructionPainter painter) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  // Must not throw; assertions inside paint propagate here synchronously.
  painter.paint(canvas, const Size(800, 600));
}

void main() {
  test(
    'painting a narrow section at minimum zoom does not produce an '
    'invalid TextPainter constraint (regression)',
    () {
      final construction = _constructionWithSliverSection();
      final layout = layoutConstruction(construction)!;

      // Minimum reachable viewport scale: a 30 mm section is 6 px wide.
      const minScale = 0.2;
      final painter = ConstructionPainter(
        construction: construction,
        selectedSectionId: null,
        transform: FittedTransform(scale: minScale, offsetX: 20, offsetY: 20),
      );

      expect(layout.sections[1].width * minScale, lessThan(8)); // precondition

      _paintWith(painter);
    },
  );

  test('labels still lay out normally at ordinary scales', () {
    final construction = _constructionWithSliverSection();

    final painter = ConstructionPainter(
      construction: construction,
      selectedSectionId: null,
      transform: const FittedTransform(scale: 0.35, offsetX: 40, offsetY: 40),
    );

    _paintWith(painter);
  });

  test('painting tolerates degenerate zero-area transforms without '
      'throwing', () {
    final painter = ConstructionPainter(
      construction: _constructionWithSliverSection(),
      selectedSectionId: null,
      transform: const FittedTransform(scale: 0, offsetX: 0, offsetY: 0),
    );

    _paintWith(painter); // early-out path; nothing drawn, nothing thrown
  });

  test(
    'shouldRepaint reacts to transform and activeSnap changes (regression): '
    'the live viewport hands the painter a NEW transform on every pan, zoom '
    'and fit -- a shouldRepaint that ignores it left the canvas displaying '
    'the first, pre-fit identity-transform frame for the whole session',
    () {
      final construction = _constructionWithSliverSection();

      ConstructionPainter painterWith(FittedTransform t) =>
          ConstructionPainter(
            construction: construction,
            selectedSectionId: null,
            transform: t,
          );

      final fitted = painterWith(
        const FittedTransform(scale: 0.3, offsetX: 30, offsetY: 30),
      );
      // Same construction + selection, but the viewport has since panned
      // and zoomed -- the paint MUST be refreshed.
      expect(
        fitted.shouldRepaint(
          painterWith(const FittedTransform(scale: 1, offsetX: 0, offsetY: 0)),
        ),
        isTrue,
      );
      // A pure translation is equally repaint-worthy.
      expect(
        fitted.shouldRepaint(
          painterWith(const FittedTransform(scale: 0.3, offsetX: 45, offsetY: 30)),
        ),
        isTrue,
      );
      // Identical transforms with identical content need no repaint --
      // e.g. unrelated widget rebuilds between frames.
      expect(fitted.shouldRepaint(painterWith(fitted.transform)), isFalse);

      // A snap highlight appearing/disappearing/changing must also repaint:
      // like the transform, its visual lives inside this painter.
      final withSnap = ConstructionPainter(
        construction: construction,
        selectedSectionId: null,
        transform: fitted.transform,
        activeSnap: ActiveSnap(
          positionMm: 900,
          kind: SnapTargetKind.sectionBoundary,
        ),
      );
      expect(withSnap.shouldRepaint(fitted), isTrue);
    },
  );

  group('workshop grid rendering', () {
    test('painting with the grid on does not throw at representative scales',
        () {
      for (final scale in const [0.2, 0.31, 1.0, 6.0]) {
        _paintWith(ConstructionPainter(
          construction: _constructionWithSliverSection(),
          selectedSectionId: null,
          transform: FittedTransform(scale: scale, offsetX: 40, offsetY: 40),
          showGrid: true,
        ));
      }
    });

    test('grid on + degenerate (zero-scale) transform paints nothing, '
        'without throwing', () {
      _paintWith(ConstructionPainter(
        construction: _constructionWithSliverSection(),
        selectedSectionId: null,
        transform: const FittedTransform(scale: 0, offsetX: 0, offsetY: 0),
        showGrid: true,
      ));
    });

    test('painting an INCOMPLETE construction with the grid still draws the '
        'grid and skips geometry without throwing', () {
      // A construction missing sections yields a null layout -- the grid
      // is presentation and must not depend on drawable geometry.
      const incomplete = Construction(
        id: 'x',
        name: 'empty',
        type: ConstructionType.window,
        width: null,
        height: null,
        manufacturer: '',
        system: '',
        sections: [],
        profiles: [],
      );
      _paintWith(ConstructionPainter(
        construction: incomplete,
        selectedSectionId: null,
        transform: const FittedTransform(scale: 0.5, offsetX: 30, offsetY: 30),
        showGrid: true,
      ));
    });

    test('shouldRepaint reacts to grid visibility changes', () {
      final construction = _constructionWithSliverSection();
      final transform =
          const FittedTransform(scale: 0.3, offsetX: 20, offsetY: 20);
      final gridOn = ConstructionPainter(
        construction: construction,
        selectedSectionId: null,
        transform: transform,
        showGrid: true,
      );
      final gridOff = ConstructionPainter(
        construction: construction,
        selectedSectionId: null,
        transform: transform,
        showGrid: false,
      );

      expect(gridOn.shouldRepaint(gridOff), isTrue);
      expect(gridOff.shouldRepaint(gridOn), isTrue);
      // Identical visibility needs no repaint.
      expect(gridOn.shouldRepaint(gridOn), isFalse);
    });

    test('dimensionLabelTargets mirror the painted label anchors exactly', () {
      final layout = layoutConstruction(_constructionWithSliverSection())!;
      const t = FittedTransform(scale: 0.3, offsetX: 40, offsetY: 50);

      final targets = dimensionLabelTargets(layout: layout, transform: t);
      expect(targets, hasLength(2));

      final left = t.toPixelX(0); // 40
      final top = t.toPixelY(0); // 50
      final right = t.toPixelX(layout.width); // 40 + 1830*0.3
      final bottom = t.toPixelY(layout.height); // 50 + 1200*0.3

      final widthTarget =
          targets.firstWhere((x) => x.label == ConstructionDimensionLabel.overallWidth);
      expect(
        widthTarget.hitBounds.center,
        Offset((left + right) / 2, top - 18),
      );
      expect(widthTarget.hitBounds.contains(widthTarget.hitBounds.center),
          isTrue);

      final heightTarget =
          targets.firstWhere((x) => x.label == ConstructionDimensionLabel.overallHeight);
      expect(
        heightTarget.hitBounds.center,
        Offset(left - 34, (top + bottom) / 2),
      );

      // The two grab boxes must not overlap each other or the drawing.
      expect(
        widthTarget.hitBounds.overlaps(heightTarget.hitBounds),
        isFalse,
      );
    });
  });
}
