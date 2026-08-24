import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/data/builtin_catalog_seed.dart';
import 'package:aluminium_designer/core/logic/rule_set_resolution.dart';
import 'package:aluminium_designer/core/models/calculation_outcome.dart';
import 'package:aluminium_designer/core/models/catalog.dart';
import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/layout_direction.dart';
import 'package:aluminium_designer/core/models/opening.dart';
import 'package:aluminium_designer/core/models/profile_usage.dart';
import 'package:aluminium_designer/core/models/section.dart';

/// C5 end-to-end proof: a real Série 14600 construction calculated through
/// the FULL application pipeline -- Construction + seeded Catalog ->
/// resolveRuleSetForConstruction -> ConstructionCalculator -> cuts whose
/// lengths reproduce the source document's débitage table (p. 24,
/// "2 vantaux" column; citations in docs/VERIFIED_SOURCES.md).
///
/// Source inputs for the worked example (L = 2000 mm, H = 1500 mm):
///   Dormant 14 617 ............ 2+2 × (L ; H)
///   Montant latéral 14 622 .... 2 × (H−74)
///   Traverse 14 621 ........... 4 × (L−64)/2
const double _l = 2000;
const double _h = 1500;

Catalog _catalog() => withBuiltInCatalogSeed(const Catalog());

Construction _construction({
  required List<ProfileUsage> profileUsages,
  int vantauxCount = 2,
}) => Construction(
  id: 'c-me-14600',
  name: 'Coulissant $vantauxCount vantaux',
  type: ConstructionType.window,
  width: _l,
  height: _h,
  manufacturer: 'Maghreb Extrusion (ME)',
  system: 'Série 14600 Coulissant',
  systemId: meSerie14600Id,
  sections: [
    Section(
      id: 's-unit',
      order: 0,
      kind: SectionKind.ouvrant,
      width: _l,
      height: _h,
      openingType: OpeningType.coulissante,
      vantauxCount: vantauxCount,
    ),
  ],
  layoutDirection: SectionLayoutDirection.horizontal,
  profiles: const [],
  profileUsages: profileUsages,
);

ProfileUsage _usage(String id, String profileReference, ProfileUsageRole role) {
  final profile = meSerie14600.profilesById.values
      .firstWhere((p) => p.reference == profileReference);
  return ProfileUsage(
    id: id,
    profileId: profile.id,
    sectionId: 's-unit',
    role: role,
  );
}

/// The documented 2-vantaux unit: frame + sash stiles + leaf tracks.
List<ProfileUsage> _unitUsages() => [
  _usage('d-top', '14 617', ProfileUsageRole.top),
  _usage('d-bottom', '14 617', ProfileUsageRole.bottom),
  _usage('d-left', '14 617', ProfileUsageRole.left),
  _usage('d-right', '14 617', ProfileUsageRole.right),
  _usage('m-left', '14 622', ProfileUsageRole.left),
  _usage('m-right', '14 623', ProfileUsageRole.right),
  _usage('t-top', '14 621', ProfileUsageRole.top),
  _usage('t-bottom', '14 621', ProfileUsageRole.bottom),
];

void main() {
  group('end-to-end: Série 14600 débitage vs source p. 24', () {
    test('every usage produces its documented cut at L=2000 / H=1500', () {
      final outcome = calculateConstructionCuts(
        _construction(profileUsages: _unitUsages()),
        _catalog(),
      );

      expect(outcome, isNotNull, reason: 'the seeded system must resolve '
          'its rule set');
      expect(outcome!.issues, isEmpty,
          reason: 'a fully-covered 2-vantaux unit has no skipped usages');

      final byUsageId = {
        for (final cut in outcome.cuts) cut.profileUsageId: cut,
      };
      expect(byUsageId, hasLength(8));

      // Dormant 14 617: horizontals at L, verticals at H.
      expect(byUsageId['d-top']!.length, _l);
      expect(byUsageId['d-bottom']!.length, _l);
      expect(byUsageId['d-left']!.length, _h);
      expect(byUsageId['d-right']!.length, _h);

      // Montants latéraux 14 622/14 623: H−74 = 1426.
      expect(byUsageId['m-left']!.length, _h - 74);
      expect(byUsageId['m-right']!.length, _h - 74);

      // Traverses 14 621: (L−64)/2 = 968, two pieces per placement.
      expect(byUsageId['t-top']!.length, (_l - 64) / 2);
      expect(byUsageId['t-bottom']!.length, (_l - 64) / 2);
      expect(byUsageId['t-top']!.quantity, 2);
      expect(byUsageId['t-bottom']!.quantity, 2);

      // Unit totals equal the débitage table's per-unit counts:
      // 2×(L ; H) dormants + 2×(H−74) montants + 4×(L−64)/2 traverses.
      final totalPieces = outcome.cuts.fold<int>(
        0,
        (sum, cut) => sum + cut.quantity,
      );
      expect(totalPieces, 10);

      for (final cut in outcome.cuts) {
        expect(cut.angleStart, 45);
        expect(cut.angleEnd, 45);
        expect(cut.sectionId, 's-unit');
        expect(cut.ruleDescription, isNotNull);
        // Provenance traces every cut to the source table page.
        expect(cut.ruleDescription, contains('p. 24'));
      }
    });

    test('usage.quantity composes with the traverse rule fixed(2)', () {
      // The riskiest semantic of this milestone: one top traverse
      // placement spans both leaves' track halves (fixedCount 2), so a
      // user quantity of 2 on that placement must yield 2 × 2 = 4 pieces
      // of 968 mm -- calculator line `rule.quantity.fixedCount *
      // usage.quantity`, exercised for the real rule set.
      final usages = [
        ProfileUsage(
          id: 't-top-x2',
          profileId: meSerie14600.profilesById.values
              .firstWhere((p) => p.reference == '14 621')
              .id,
          sectionId: 's-unit',
          role: ProfileUsageRole.top,
          quantity: 2,
        ),
      ];
      final outcome = calculateConstructionCuts(
        _construction(profileUsages: usages),
        _catalog(),
      )!;

      expect(outcome.issues, isEmpty);
      expect(outcome.cuts, hasLength(1));
      expect(outcome.cuts.single.length, (_l - 64) / 2);
      expect(outcome.cuts.single.quantity, 4);
    });

    test('a complete unit with central mullions: intermediate placement '
        'yields the documented pair', () {
      final usages = [
        ..._unitUsages(),
        _usage('mc-intermediate', '14 619', ProfileUsageRole.intermediate),
      ];
      final outcome = calculateConstructionCuts(
        _construction(profileUsages: usages),
        _catalog(),
      )!;

      expect(outcome.issues, isEmpty);
      final byUsageId = {
        for (final cut in outcome.cuts) cut.profileUsageId: cut,
      };
      expect(byUsageId, hasLength(9));

      // Montant central 14 619: (H−74) = 1426, TWO pieces from the one
      // intermediate placement (one meeting stile per leaf).
      final mullionCut = byUsageId['mc-intermediate']!;
      expect(mullionCut.length, _h - 74);
      expect(mullionCut.quantity, 2);
      expect(mullionCut.ruleDescription, contains('14 619'));

      // Unit total grows by exactly the documented 2 × (H−74).
      final totalPieces = outcome.cuts.fold<int>(
        0,
        (sum, cut) => sum + cut.quantity,
      );
      expect(totalPieces, 12);
    });

    test('the other documented frame family: +46 dormants, traverse '
        '14 631, montants 69.2, central mullion — every new row end-to-end',
        () {
      // References are spread across the documented row members purely
      // for coverage (e.g. 14 618 top/bottom with 14 628 left/right is
      // not a realistic BOM); each usage is individually routed and
      // asserted against its own débitage row.
      final usages = [
        _usage('d-top', '14 618', ProfileUsageRole.top),
        _usage('d-bottom', '14 618', ProfileUsageRole.bottom),
        _usage('d-left', '14 628', ProfileUsageRole.left),
        _usage('d-right', '14 628', ProfileUsageRole.right),
        _usage('m-left', '14 632', ProfileUsageRole.left),
        _usage('m-right', '14 633', ProfileUsageRole.right),
        _usage('t-top', '14 631', ProfileUsageRole.top),
        _usage('t-bottom', '14 631', ProfileUsageRole.bottom),
        _usage('mc-intermediate', '14 620', ProfileUsageRole.intermediate),
      ];
      final outcome = calculateConstructionCuts(
        _construction(profileUsages: usages),
        _catalog(),
      )!;

      expect(outcome.issues, isEmpty);
      final byUsageId = {
        for (final cut in outcome.cuts) cut.profileUsageId: cut,
      };
      expect(byUsageId, hasLength(9));

      // Dormants +46 row: horizontals L+46 = 2046, verticals H+46 = 1546.
      expect(byUsageId['d-top']!.length, _l + 46);
      expect(byUsageId['d-bottom']!.length, _l + 46);
      expect(byUsageId['d-left']!.length, _h + 46);
      expect(byUsageId['d-right']!.length, _h + 46);

      // Traverse 14 631: (L−85)/2 = 957.5, two pieces per placement.
      expect(byUsageId['t-top']!.length, (_l - 85) / 2);
      expect(byUsageId['t-bottom']!.length, (_l - 85) / 2);
      expect(byUsageId['t-top']!.quantity, 2);
      expect(byUsageId['t-bottom']!.quantity, 2);

      // Montants latéraux face 69.2 and montant central: H−74 = 1426;
      // the central placement carries the documented pair.
      expect(byUsageId['m-left']!.length, _h - 74);
      expect(byUsageId['m-right']!.length, _h - 74);
      expect(byUsageId['mc-intermediate']!.length, _h - 74);
      expect(byUsageId['mc-intermediate']!.quantity, 2);

      // Per-unit counts: 2×(L+46) + 2×(H+46) + 4×((L−85)/2)
      //                + 2×(H−74 latéral) + 2×(H−74 central).
      final totalPieces = outcome.cuts.fold<int>(
        0,
        (sum, cut) => sum + cut.quantity,
      );
      expect(totalPieces, 12);
    });

    test('traverses route by exact reference: 14 631 never receives the '
        '14 621 formula', () {
      final usages = [
        _usage('d-top', '14 617', ProfileUsageRole.top),
        _usage('t-621', '14 621', ProfileUsageRole.top),
        _usage('t-631', '14 631', ProfileUsageRole.top),
      ];
      final outcome = calculateConstructionCuts(
        _construction(profileUsages: usages),
        _catalog(),
      )!;

      expect(outcome.issues, isEmpty);
      final byUsageId = {
        for (final cut in outcome.cuts) cut.profileUsageId: cut,
      };
      expect(byUsageId, hasLength(3));
      expect(byUsageId['t-621']!.length, (_l - 64) / 2);
      expect(byUsageId['t-631']!.length, (_l - 85) / 2);
      // Provenance names the exact profile each formula belongs to.
      expect(byUsageId['t-621']!.ruleDescription, contains('14 621'));
      expect(byUsageId['t-631']!.ruleDescription, contains('14 631'));
    });

    test('a mullion outside the documented débitage row surfaces as an '
        'issue while the rest of the unit still calculates', () {
      final usages = [
        _usage('d-top', '14 617', ProfileUsageRole.top),
        _usage('mc-wrong', '14 650', ProfileUsageRole.intermediate),
      ];
      final outcome = calculateConstructionCuts(
        _construction(profileUsages: usages),
        _catalog(),
      )!;

      expect(outcome.cuts, hasLength(1));
      expect(outcome.cuts.single.profileUsageId, 'd-top');
      expect(outcome.issues, hasLength(1));
      expect(outcome.issues.single.profileUsageId, 'mc-wrong');
      expect(
        outcome.issues.single.reason,
        ProfileUsageIssueReason.noRuleMatched,
      );
    });

    test('a complete 3-vantaux (avec fixe) unit reproduces its p. 24 '
        'column end-to-end', () {
      // One ouvrant coulissante section, vantauxCount = 3 -- the
      // documented configuration. Which third is fixed is not stated by
      // the table, affects no cut length, and is not represented.
      final usages = [
        _usage('d-top', '14 617', ProfileUsageRole.top),
        _usage('d-bottom', '14 617', ProfileUsageRole.bottom),
        _usage('d-left', '14 617', ProfileUsageRole.left),
        _usage('d-right', '14 617', ProfileUsageRole.right),
        _usage('m-left', '14 622', ProfileUsageRole.left),
        _usage('m-right', '14 623', ProfileUsageRole.right),
        _usage('mc-intermediate', '14 619', ProfileUsageRole.intermediate),
        _usage('t-top', '14 621', ProfileUsageRole.top),
        _usage('t-bottom', '14 621', ProfileUsageRole.bottom),
      ];
      final outcome = calculateConstructionCuts(
        _construction(profileUsages: usages, vantauxCount: 3),
        _catalog(),
      )!;

      expect(outcome.issues, isEmpty);
      final byUsageId = {
        for (final cut in outcome.cuts) cut.profileUsageId: cut,
      };
      expect(byUsageId, hasLength(9));

      // Traverses 14 621: (L−25)/3 per panel, THREE pieces per placement
      // -> 6 total. Repeating decimal: assert via identical computation.
      expect(byUsageId['t-top']!.length, (_l - 25) / 3);
      expect(byUsageId['t-bottom']!.length, (_l - 25) / 3);
      expect(byUsageId['t-top']!.quantity, 3);
      expect(byUsageId['t-bottom']!.quantity, 3);

      // Dormants identical to the 2v column; montants/mullion likewise.
      expect(byUsageId['d-top']!.length, _l);
      expect(byUsageId['d-left']!.length, _h);
      expect(byUsageId['m-left']!.length, _h - 74);
      expect(byUsageId['mc-intermediate']!.length, _h - 74);
      expect(byUsageId['mc-intermediate']!.quantity, 2);

      // Per-unit counts: 2×(L ; H) + 2×(H−74 latéraux)
      //                + 2×(H−74 central) + 6×((L−25)/3).
      final totalPieces = outcome.cuts.fold<int>(
        0,
        (sum, cut) => sum + cut.quantity,
      );
      expect(totalPieces, 14);

      for (final cut in outcome.cuts) {
        expect(cut.angleStart, 45);
        expect(cut.angleEnd, 45);
        expect(cut.ruleDescription, contains('p. 24'));
        // Column provenance: every cut names the 3-vantaux row.
        expect(cut.ruleDescription, contains('3 vantaux'));
      }
    });

    test('the 3-vantaux traverse-14 631 column evaluates exactly '
        '((2000−47)/3 = 651)', () {
      final usages = [
        _usage('t-top', '14 631', ProfileUsageRole.top),
        _usage('t-bottom', '14 631', ProfileUsageRole.bottom),
      ];
      final outcome = calculateConstructionCuts(
        _construction(profileUsages: usages, vantauxCount: 3),
        _catalog(),
      )!;

      expect(outcome.issues, isEmpty);
      expect(outcome.cuts, hasLength(2));
      for (final cut in outcome.cuts) {
        expect(cut.length, 651.0);
        expect(cut.quantity, 3);
        expect(cut.ruleDescription, contains('14 631'));
      }
    });

    test('a complete 4-vantaux unit reproduces its p. 24 column '
        'end-to-end, chicane included', () {
      final usages = [
        _usage('d-top', '14 617', ProfileUsageRole.top),
        _usage('d-bottom', '14 617', ProfileUsageRole.bottom),
        _usage('d-left', '14 617', ProfileUsageRole.left),
        _usage('d-right', '14 617', ProfileUsageRole.right),
        _usage('m-left', '14 622', ProfileUsageRole.left),
        _usage('m-right', '14 623', ProfileUsageRole.right),
        _usage('mc-intermediate', '14 619', ProfileUsageRole.intermediate),
        _usage('t-top', '14 621', ProfileUsageRole.top),
        _usage('t-bottom', '14 621', ProfileUsageRole.bottom),
        _usage('ch-coulissante', '14 624', ProfileUsageRole.left),
      ];
      final outcome = calculateConstructionCuts(
        _construction(profileUsages: usages, vantauxCount: 4),
        _catalog(),
      )!;

      expect(outcome.issues, isEmpty);
      final byUsageId = {
        for (final cut in outcome.cuts) cut.profileUsageId: cut,
      };
      expect(byUsageId, hasLength(10));

      // Traverses: (L−60)/4 per panel, FOUR pieces per placement -> 8.
      expect(byUsageId['t-top']!.length, (_l - 60) / 4);
      expect(byUsageId['t-bottom']!.length, (_l - 60) / 4);
      expect(byUsageId['t-top']!.quantity, 4);
      expect(byUsageId['t-bottom']!.quantity, 4);

      // Montants double per unit: fixed(2) per side placement; central
      // mullion fixed(4) on the one intermediate placement.
      expect(byUsageId['m-left']!.length, _h - 74);
      expect(byUsageId['m-left']!.quantity, 2);
      expect(byUsageId['m-right']!.quantity, 2);
      expect(byUsageId['mc-intermediate']!.quantity, 4);

      // Chicane: H−92 = 1408, one piece from its single placement (the
      // rule has no role condition -- any placement matches).
      expect(byUsageId['ch-coulissante']!.length, _h - 92);
      expect(byUsageId['ch-coulissante']!.quantity, 1);

      // Per-unit counts: 2×(L ; H) + 4×(H−74 latéraux) + 4×(H−74 central)
      //                + 8×((L−60)/4) + 1×(H−92).
      final totalPieces = outcome.cuts.fold<int>(
        0,
        (sum, cut) => sum + cut.quantity,
      );
      expect(totalPieces, 21);

      for (final cut in outcome.cuts) {
        expect(cut.angleStart, 45);
        expect(cut.angleEnd, 45);
        expect(cut.ruleDescription, contains('p. 24'));
        expect(cut.ruleDescription, contains('4 vantaux'));
      }
    });

    test('chicane usage.quantity composes with its fixed(1) rule', () {
      final usages = [
        ProfileUsage(
          id: 'ch-x2',
          profileId: meSerie14600.profilesById.values
              .firstWhere((p) => p.reference == '14 624')
              .id,
          sectionId: 's-unit',
          role: ProfileUsageRole.intermediate,
          quantity: 2,
        ),
      ];
      final outcome = calculateConstructionCuts(
        _construction(profileUsages: usages, vantauxCount: 4),
        _catalog(),
      )!;
      expect(outcome.issues, isEmpty);
      expect(outcome.cuts.single.length, _h - 92);
      expect(outcome.cuts.single.quantity, 2);
    });

    test('the 4-vantaux traverse-14 631 column evaluates exactly '
        '((2000−106)/4 = 473.5)', () {
      final usages = [
        _usage('t-top', '14 631', ProfileUsageRole.top),
        _usage('t-bottom', '14 631', ProfileUsageRole.bottom),
      ];
      final outcome = calculateConstructionCuts(
        _construction(profileUsages: usages, vantauxCount: 4),
        _catalog(),
      )!;
      expect(outcome.issues, isEmpty);
      expect(outcome.cuts, hasLength(2));
      for (final cut in outcome.cuts) {
        expect(cut.length, 473.5);
        expect(cut.quantity, 4);
      }
    });

    test('2-vantaux units still route to the 2v rules next to their new '
        '3v siblings', () {
      final outcome = calculateConstructionCuts(
        _construction(profileUsages: _unitUsages()),
        _catalog(),
      )!;

      expect(outcome.issues, isEmpty);
      // The 2v traverse formula survives untouched: (2000−64)/2 = 968,
      // two pieces per placement -- NOT the 3v (2000−25)/3 ×3.
      final topTraverse = outcome.cuts
          .singleWhere((cut) => cut.profileUsageId == 't-top');
      expect(topTraverse.length, (_l - 64) / 2);
      expect(topTraverse.quantity, 2);
      expect(topTraverse.ruleDescription, contains('(L−64)/2'));
      expect(topTraverse.ruleDescription, contains('2 vantaux'));
    });

    test('same profiles outside the encoded columns (5 vantaux) produce '
        'no cuts at all', () {
      final outcome = calculateConstructionCuts(
        _construction(profileUsages: _unitUsages(), vantauxCount: 5),
        _catalog(),
      )!;

      expect(outcome.cuts, isEmpty);
      expect(outcome.issues, hasLength(8));
      for (final issue in outcome.issues) {
        expect(issue.reason, ProfileUsageIssueReason.noRuleMatched);
      }
    });
  });
}
