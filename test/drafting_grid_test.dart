import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/geometry/drafting_grid.dart';

void main() {
  group('selectMinorGridInterval', () {
    test('picks intervals from the 1-2-5 series at representative scales', () {
      // Table computed by hand from interval * scale >= 20 px:
      expect(selectMinorGridInterval(scale: 0.2), 100); // viewport minimum
      expect(selectMinorGridInterval(scale: 0.31), 100); // typical fit zoom
      expect(selectMinorGridInterval(scale: 0.4), 50);
      expect(selectMinorGridInterval(scale: 1.0), 20);
      expect(selectMinorGridInterval(scale: 3.0), 10);
      expect(selectMinorGridInterval(scale: 6.0), 5); // viewport maximum
    });

    test('inclusive floor: an interval rendering EXACTLY minSpacing qualifies',
        () {
      // 100 mm * 0.2 px/mm == 20.0 px == kMinGridLineSpacingPx.
      expect(
        selectMinorGridInterval(
          scale: 0.2,
          minSpacingPx: kMinGridLineSpacingPx,
        ),
        100,
      );
    });

    test('interval never renders denser than the perceptual floor', () {
      for (final scale in const [
        0.2, 0.25, 0.31, 0.5, 0.75, 1.0, 1.7, 2.0, 4.0, 6.0,
      ]) {
        final interval = selectMinorGridInterval(scale: scale);
        expect(interval * scale, greaterThanOrEqualTo(kMinGridLineSpacingPx),
            reason: 'scale $scale picked $interval mm');
      }
    });

    test('denser zoom never picks a LARGER interval (monotonic refinement)',
        () {
      double? previous;
      for (var scale = 0.2; scale <= 6.0001; scale += 0.1) {
        final interval = selectMinorGridInterval(scale: scale);
        if (previous != null) {
          expect(interval, lessThanOrEqualTo(previous),
              reason: 'zooming in at scale $scale coarsened the grid');
        }
        previous = interval;
      }
    });

    test('custom perceptual floors are honored', () {
      // A denser preference (10 px floor): 50 mm * 0.31 == 15.5 -> still
      // needs 100; a sparser one (40 px floor) pushes to 200 mm.
      expect(selectMinorGridInterval(scale: 0.31, minSpacingPx: 10), 50);
      expect(selectMinorGridInterval(scale: 0.31, minSpacingPx: 40), 200);
    });

    test('degenerate inputs yield 0 ("draw nothing"), never throw', () {
      expect(selectMinorGridInterval(scale: 0), 0);
      expect(selectMinorGridInterval(scale: -1), 0);
      expect(selectMinorGridInterval(scale: double.nan), 0);
      expect(selectMinorGridInterval(scale: double.infinity), 0);
      expect(
        selectMinorGridInterval(scale: 1, minSpacingPx: 0),
        0,
      );
      expect(
        selectMinorGridInterval(scale: 1, minSpacingPx: -5),
        0,
      );
      expect(
        selectMinorGridInterval(scale: 1, minSpacingPx: double.nan),
        0,
      );
    });
  });

  group('gridLinesForRange', () {
    test('covers a full construction extent with origin-aligned multiples', () {
      final lines =
          gridLinesForRange(minMm: 0, maxMm: 2400, minorIntervalMm: 100);

      expect(lines.length, 25); // 0..2400 inclusive.
      expect(lines.first.positionMm, 0);
      expect(lines.last.positionMm, 2400);
      for (var i = 0; i < lines.length; i++) {
        expect(lines[i].positionMm, closeTo(i * 100.0, 1e-9),
            reason: 'line $i drifted off its multiple');
      }
    });

    test('majors land every 5th line and nowhere else', () {
      final lines =
          gridLinesForRange(minMm: 0, maxMm: 2400, minorIntervalMm: 100);

      final majors = lines.where((l) => l.isMajor).map((l) => l.positionMm);
      expect(majors, [0, 500, 1000, 1500, 2000]);

      // Default constant agreement.
      expect(kGridMajorEvery, 5);
    });

    test('panning past the origin produces correct NEGATIVE multiples', () {
      final lines =
          gridLinesForRange(minMm: -350, maxMm: 250, minorIntervalMm: 100);

      expect(
        lines.map((l) => l.positionMm).toList(),
        [-300, -200, -100, 0, 100, 200],
      );
      // Negative majors classify correctly with Dart's non-negative %.
      expect(
        lines.where((l) => l.isMajor).map((l) => l.positionMm).toList(),
        [0], // -500 would be major but lies outside this range.
      );

      final wider =
          gridLinesForRange(minMm: -2600, maxMm: 0, minorIntervalMm: 100);
      expect(
        wider.where((l) => l.isMajor).map((l) => l.positionMm).toList(),
        [-2500, -2000, -1500, -1000, -500, 0],
      );
    });

    test('lines stay pinned to ABSOLUTE model coordinates across pans', () {
      // Shifting the visible window by a non-multiple must NOT shift the
      // set of produced positions -- only which of them are included.
      final before =
          gridLinesForRange(minMm: 0, maxMm: 1000, minorIntervalMm: 100)
              .map((l) => l.positionMm)
              .toSet();
      final after =
          gridLinesForRange(minMm: 30, maxMm: 1130, minorIntervalMm: 100)
              .map((l) => l.positionMm)
              .toSet();

      expect(after.difference(before), {1100});
      expect(before.difference(after), {0});
    });

    test('integer-index arithmetic avoids cumulative drift on long ranges',
        () {
      final lines = gridLinesForRange(
        minMm: 0,
        maxMm: 1_000_000,
        minorIntervalMm: 0.1,
      ).toList(growable: false);

      expect(lines.length, lessThanOrEqualTo(kMaxGridLinesPerAxis));
      for (final line in lines.take(100)) {
        // Every position must be within fp-noise of a true multiple.
        final quotient = line.positionMm / 0.1;
        expect((quotient - quotient.roundToDouble()).abs(), lessThan(1e-6));
      }
    });

    test('degenerate inputs return empty lists, never throw', () {
      expect(gridLinesForRange(minMm: 0, maxMm: 100, minorIntervalMm: 0),
          isEmpty);
      expect(gridLinesForRange(minMm: 0, maxMm: 100, minorIntervalMm: -10),
          isEmpty);
      expect(
          gridLinesForRange(
              minMm: 0, maxMm: 100, minorIntervalMm: double.nan),
          isEmpty);
      expect(gridLinesForRange(minMm: 500, maxMm: 100, minorIntervalMm: 100),
          isEmpty); // inverted range
      expect(gridLinesForRange(minMm: double.nan, maxMm: 100, minorIntervalMm: 100),
          isEmpty);
    });

    test('point range includes a boundary multiple exactly once', () {
      expect(
        gridLinesForRange(minMm: 500, maxMm: 500, minorIntervalMm: 100)
            .map((l) => l.positionMm),
        [500],
      );
      // Non-multiple point ranges are simply empty.
      expect(
        gridLinesForRange(minMm: 550, maxMm: 550, minorIntervalMm: 100),
        isEmpty,
      );
    });

    test('allocation cap bounds pathological requests', () {
      final lines = gridLinesForRange(
        minMm: 0,
        maxMm: 10_000_000,
        minorIntervalMm: 1,
        maxLines: 64,
      );
      expect(lines.length, 64);
      // Cap keeps ascending order intact.
      expect(lines.first.positionMm, lessThan(lines.last.positionMm));
    });

    test('majorEvery below 1 is clamped to "every line is major"', () {
      final lines = gridLinesForRange(
        minMm: 0,
        maxMm: 300,
        minorIntervalMm: 100,
        majorEvery: 0,
      );
      expect(lines.every((l) => l.isMajor), isTrue);
    });
  });
}
