import 'package:aluminium_designer/core/logic/dimension_limit_check.dart';
import 'package:aluminium_designer/core/models/opening.dart';
import 'package:aluminium_designer/core/models/profile_system_metadata.dart';
import 'package:aluminium_designer/features/constructions/editor/widgets/dimension_limit_warning_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('checkDimensionLimits (pure logic)', () {
    // The Série 14600's two certified envelopes, as seeded.
    final limits = [
      const DimensionLimit(maxWidthMm: 1600, maxHeightMm: 1800),
      const DimensionLimit(maxWidthMm: 2500, maxHeightMm: 2500),
    ];

    test('unset dimensions produce no warning -- mid-edit state, not "ok"',
        () {
      expect(
        checkDimensionLimits(widthMm: null, heightMm: 1000, limits: limits),
        isEmpty,
      );
      expect(
        checkDimensionLimits(widthMm: 1000, heightMm: null, limits: limits),
        isEmpty,
      );
    });

    test('no limits documented produces no warning -- unknown is not "ok" '
        'or "not ok", it is unknown', () {
      expect(
        checkDimensionLimits(
          widthMm: 9999,
          heightMm: 9999,
          limits: const [],
        ),
        isEmpty,
      );
    });

    test('dimensions inside any single envelope produce no warning '
        '(envelopes are alternatives, not a min/max range)', () {
      // Exceeds the 1600x1800 envelope but fits 2500x2500.
      expect(
        checkDimensionLimits(widthMm: 2000, heightMm: 2000, limits: limits),
        isEmpty,
      );
      expect(
        checkDimensionLimits(widthMm: 1600, heightMm: 1800, limits: limits),
        isEmpty,
      );
      expect(
        checkDimensionLimits(widthMm: 2500, heightMm: 2500, limits: limits),
        isEmpty,
      );
    });

    test('exceeding every envelope warns and returns all exceeded envelopes',
        () {
      final warnings = checkDimensionLimits(
        widthMm: 3000,
        heightMm: 1000,
        limits: limits,
      );

      expect(warnings, hasLength(2));
      // Width 3000 exceeds both envelopes' max width; the returned list
      // carries the envelopes themselves so the UI can show what was
      // left behind.
      expect(warnings[0].limit.maxWidthMm, 1600);
      expect(warnings[1].limit.maxWidthMm, 2500);
    });

    test('exceeding in height only also warns (either axis leaves the '
        'envelope)', () {
      final warnings = checkDimensionLimits(
        widthMm: 1000,
        heightMm: 2600,
        limits: limits,
      );

      expect(warnings, hasLength(2));
    });

    test('a limit scoped to an opening type only applies to constructions '
        'having a section of that type', () {
      final coulissanteOnly = [
        const DimensionLimit(
          openingType: OpeningType.coulissante,
          maxWidthMm: 2000,
          maxHeightMm: 2000,
        ),
      ];

      // No coulissante section -> the limit does not apply at all.
      expect(
        checkDimensionLimits(
          widthMm: 5000,
          heightMm: 5000,
          limits: coulissanteOnly,
          sectionOpeningTypes: {OpeningType.francaise},
        ),
        isEmpty,
      );

      // A coulissante section exists -> the limit applies and is exceeded.
      final warnings = checkDimensionLimits(
        widthMm: 5000,
        heightMm: 5000,
        limits: coulissanteOnly,
        sectionOpeningTypes: {OpeningType.coulissante},
      );
      expect(warnings, hasLength(1));
      expect(warnings.single.limit.maxWidthMm, 2000);
    });

    test('a scoped limit that does not apply cannot be "the one that '
        'still fits" -- mixed applicability warns only on the applicable '
        'envelope', () {
      final mixed = [
        const DimensionLimit(maxWidthMm: 1000, maxHeightMm: 1000),
        const DimensionLimit(
          openingType: OpeningType.oscilloBattant,
          maxWidthMm: 9000,
          maxHeightMm: 9000,
        ),
      ];

      // The 9000 envelope is scoped to oscillo-battant and the
      // construction has none, so only the 1000 envelope applies -- and
      // it is exceeded.
      final warnings = checkDimensionLimits(
        widthMm: 2000,
        heightMm: 2000,
        limits: mixed,
      );
      expect(warnings, hasLength(1));
      expect(warnings.single.limit.maxWidthMm, 1000);
    });
  });

  group('DimensionLimitWarningBanner (widget)', () {
    Future<void> pumpBanner(
      WidgetTester tester,
      List<DimensionLimitExceeded> exceeded,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Text('Hauteur'),
                DimensionLimitWarningBanner(exceeded: exceeded),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders nothing when no envelope is exceeded', (
      tester,
    ) async {
      await pumpBanner(tester, const []);

      expect(find.byType(DimensionLimitWarningBanner), findsOneWidget);
      expect(find.textContaining('hors limites'), findsNothing);
    });

    testWidgets('lists the exceeded envelopes in advisory tone', (
      tester,
    ) async {
      const limits = [
        DimensionLimit(maxWidthMm: 1600, maxHeightMm: 1800),
        DimensionLimit(maxWidthMm: 2500, maxHeightMm: 2500),
      ];

      await pumpBanner(
        tester,
        [for (final limit in limits) DimensionLimitExceeded(limit)],
      );

      expect(find.textContaining('hors limites'), findsOneWidget);
      expect(find.textContaining('1600 × 1800'), findsOneWidget);
      expect(find.textContaining('2500 × 2500'), findsOneWidget);
    });
  });
}
