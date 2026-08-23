import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/logic/cut_aggregation.dart';
import 'package:aluminium_designer/core/models/cut.dart';
import 'package:aluminium_designer/core/models/profile.dart';

Profile _profile(
  String id, {
  String name = 'Profile A',
  String? reference,
  double weightPerMeter = 1.5,
  ProfileType type = ProfileType.montant,
}) => Profile(
  id: id,
  manufacturer: 'Test Manufacturer',
  system: 'Test System',
  reference: reference ?? id,
  name: name,
  type: type,
  width: 40,
  depth: 60,
  weightPerMeter: weightPerMeter,
);

ProfileCut _cut(
  Profile profile, {
  double length = 1200,
  int quantity = 1,
  String profileUsageId = 'u1',
  String sectionId = 's1',
}) => ProfileCut(
  profile: profile,
  length: length,
  quantity: quantity,
  angleStart: 45,
  angleEnd: 45,
  profileUsageId: profileUsageId,
  sectionId: sectionId,
);

void main() {
  group('aggregateProfileTotals', () {
    test('aggregates a single cut into pieces and linear metres', () {
      final profile = _profile('M1');
      final totals = aggregateProfileTotals([_cut(profile)]);

      expect(totals, hasLength(1));
      expect(totals.single.profileId, 'M1');
      expect(totals.single.profileName, 'Profile A');
      expect(totals.single.reference, 'M1');
      expect(totals.single.cutCount, 1);
      expect(totals.single.pieces, 1);
      expect(totals.single.totalLengthMm, closeTo(1200, 1e-9));
      // 1200 mm at 1.5 kg/m -> 1.2 m * 1.5 = 1.8 kg.
      expect(totals.single.weightKg, closeTo(1.8, 1e-9));
    });

    test(
      'quantity multiplies into both pieces and metres (C1a composition)',
      () {
        final profile = _profile('M1');
        final totals = aggregateProfileTotals([_cut(profile, quantity: 3)]);

        expect(totals.single.cutCount, 1);
        expect(totals.single.pieces, 3);
        expect(totals.single.totalLengthMm, closeTo(3600, 1e-9));
        expect(totals.single.weightKg, closeTo(5.4, 1e-9));
      },
    );

    test('cuts for the same profile from different usages merge into one '
        'totals line', () {
      final profile = _profile('M1');
      final totals = aggregateProfileTotals([
        _cut(profile, profileUsageId: 'u-left', sectionId: 'sA'),
        _cut(profile, length: 1000, profileUsageId: 'u-right', sectionId: 'sB'),
      ]);

      expect(totals, hasLength(1));
      expect(totals.single.cutCount, 2);
      expect(totals.single.pieces, 2);
      expect(totals.single.totalLengthMm, closeTo(2200, 1e-9));
    });

    test('profiles stay in first-encounter order, not sorted by id', () {
      final m = _profile('M1', name: 'Montant');
      final t = _profile('T1', name: 'Traverse', type: ProfileType.traverse);
      final totals = aggregateProfileTotals([
        _cut(m),
        _cut(t, length: 800),
        _cut(m, profileUsageId: 'u2'),
      ]);

      expect(totals.map((t) => t.profileId), ['M1', 'T1']);
      // M1 merged across its two cuts.
      expect(totals[0].pieces, 2);
      expect(totals[0].totalLengthMm, closeTo(2400, 1e-9));
      expect(totals[1].pieces, 1);
    });

    test('zero weightPerMeter means unknown weight, never estimated zero', () {
      final profile = _profile('M1', weightPerMeter: 0);
      final totals = aggregateProfileTotals([_cut(profile)]);

      expect(totals.single.weightKg, isNull);
    });

    test('empty input yields no totals', () {
      expect(aggregateProfileTotals(const []), isEmpty);
    });
  });

  group('sumProfileTotals', () {
    test('sums pieces and metres across profiles', () {
      final m = _profile('M1', weightPerMeter: 1.5);
      final t = _profile('T1', weightPerMeter: 2.0);
      final totals = aggregateProfileTotals([_cut(m), _cut(t, length: 800)]);

      final grand = sumProfileTotals(totals);

      expect(grand.pieces, 2);
      expect(grand.totalLengthMm, closeTo(2000, 1e-9));
      // 1.8 kg + 1.6 kg.
      expect(grand.weightKg, closeTo(3.4, 1e-9));
    });

    test('grand total stays numeric when only some weights are known', () {
      final known = _profile('M1', weightPerMeter: 1.5);
      final unknown = _profile('T1', weightPerMeter: 0);
      final totals = aggregateProfileTotals([
        _cut(known),
        _cut(unknown, length: 800),
      ]);

      final grand = sumProfileTotals(totals);

      expect(grand.weightKg, isNotNull);
      expect(grand.weightKg, closeTo(1.8, 1e-9)); // only the known part
    });

    test('grand total weight is null when every weight is unknown', () {
      final a = _profile('M1', weightPerMeter: 0);
      final b = _profile('T1', weightPerMeter: 0);
      final totals = aggregateProfileTotals([_cut(a), _cut(b, length: 800)]);

      expect(sumProfileTotals(totals).weightKg, isNull);
    });

    test('empty totals produce an empty grand total', () {
      final grand = sumProfileTotals(const []);

      expect(grand.pieces, 0);
      expect(grand.totalLengthMm, 0);
      expect(grand.weightKg, isNull);
    });
  });

  test('end-to-end shape: aggregation over a realistic mixed run', () {
    // Mirrors what C2b renders: two montant cuts (one with usage qty 2)
    // plus one traverse cut.
    final montant = _profile('M1', name: 'Montant', reference: 'ADM-123');
    final traverse = _profile(
      'T1',
      name: 'Traverse',
      reference: 'ADM-200',
      type: ProfileType.traverse,
      weightPerMeter: 1.0,
    );
    final totals = aggregateProfileTotals([
      _cut(montant, profileUsageId: 'u1'),
      _cut(montant, quantity: 2, length: 1100, profileUsageId: 'u2'),
      _cut(traverse, length: 900, profileUsageId: 'u3'),
    ]);

    expect(totals[0].profileName, 'Montant');
    expect(totals[0].reference, 'ADM-123');
    expect(totals[0].pieces, 3); // 1 + 2
    expect(totals[0].totalLengthMm, closeTo(3400, 1e-9)); // 1200 + 2200
    expect(totals[1].pieces, 1);
    expect(totals[1].totalLengthMm, closeTo(900, 1e-9));

    final grand = sumProfileTotals(totals);
    expect(grand.pieces, 4);
    expect(grand.totalLengthMm, closeTo(4300, 1e-9));
  });
}
