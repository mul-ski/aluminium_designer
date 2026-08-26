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

/// C9 end-to-end proof: a real Maghreb Extrusion Série 14800 frappe
/// construction calculated through the FULL application pipeline --
/// Construction + seeded Catalog -> calculateConstructionCuts -> cuts
/// reproducing the Catalogue Général p. 65 débitage table "(1 VANTAIL)"
/// (docs/VERIFIED_SOURCES.md, S-3).
///
/// Worked dimensions: L = 2000 mm, H = 1500 mm (the source prints no
/// numeric example; every expected length below is the printed formula
/// evaluated exactly).
const double _l = 2000;
const double _h = 1500;

Catalog _catalog() => withBuiltInCatalogSeed(const Catalog());

Construction _construction({
  required List<ProfileUsage> profileUsages,
  OpeningType openingType = OpeningType.francaise,
  int vantauxCount = 1,
}) =>
    Construction(
      id: 'c-me-14800',
      name: 'Série 14800 Frappe',
      type: ConstructionType.window,
      width: _l,
      height: _h,
      manufacturer: 'Maghreb Extrusion (ME)',
      system: 'Série 14800 Frappe',
      systemId: meSerie14800Id,
      sections: [
        Section(
          id: 's-unit',
          order: 0,
          kind: SectionKind.ouvrant,
          width: _l,
          height: _h,
          openingType: openingType,
          vantauxCount: vantauxCount,
        ),
      ],
      layoutDirection: SectionLayoutDirection.horizontal,
      profiles: const [],
      profileUsages: profileUsages,
    );

ProfileUsage _usage(String id, String reference, ProfileUsageRole role) {
  final profile = meSerie14800.profilesById.values
      .firstWhere((p) => p.reference == reference);
  return ProfileUsage(
    id: id,
    profileId: profile.id,
    sectionId: 's-unit',
    role: role,
  );
}

void main() {
  group('end-to-end: ME 14800 frappe débitage vs Catalogue Général p. 65',
      () {
    test('14.802 configuration with simple-vitrage parclose and tige '
        'reproduces the table exactly', () {
      final outcome = calculateConstructionCuts(
        _construction(profileUsages: [
          _usage('d-top', '14.800', ProfileUsageRole.top),
          _usage('d-bottom', '14.800', ProfileUsageRole.bottom),
          _usage('d-left', '14.800', ProfileUsageRole.left),
          _usage('d-right', '14.800', ProfileUsageRole.right),
          _usage('o-top', '14.802', ProfileUsageRole.top),
          _usage('o-bottom', '14.802', ProfileUsageRole.bottom),
          _usage('o-left', '14.802', ProfileUsageRole.left),
          _usage('o-right', '14.802', ProfileUsageRole.right),
          _usage('p-top', '14.809', ProfileUsageRole.top),
          _usage('p-left', '14.809', ProfileUsageRole.left),
          _usage('tige', '14.811', ProfileUsageRole.intermediate),
        ]),
        _catalog(),
      )!;

      expect(outcome.issues, isEmpty);
      final byUsageId = {
        for (final cut in outcome.cuts) cut.profileUsageId: cut,
      };
      expect(byUsageId, hasLength(11));

      // Dormant 14.800: 2×L + 2×H.
      expect(byUsageId['d-top']!.length, _l);
      expect(byUsageId['d-left']!.length, _h);
      // Ouvrant 14.802: 2×(L−35.2) + 2×(H−35.2).
      expect(byUsageId['o-top']!.length, _l - 35.2);
      expect(byUsageId['o-left']!.length, _h - 35.2);
      // Parclose beside 14.802: L−117.6 / H−157.6, square cuts.
      expect(byUsageId['p-top']!.length, _l - 117.6);
      expect(byUsageId['p-top']!.quantity, 1);
      expect(byUsageId['p-top']!.angleStart, 90);
      expect(byUsageId['p-left']!.length, _h - 157.6);
      expect(byUsageId['p-left']!.angleEnd, 90);
      // Tige de crémone: H−90.
      expect(byUsageId['tige']!.length, _h - 90);
      expect(byUsageId['tige']!.quantity, 1);

      // Provenance cites the source table.
      for (final cut in outcome.cuts) {
        expect(cut.ruleDescription, contains('14800'));
        expect(cut.ruleDescription, contains('p. 65'));
      }
      // Unit total: 4 dormant + 4 sash + 2 parcloses + 1 tige = 11
      // pieces, exactly the printed Quantité column.
      expect(
        outcome.cuts.fold<int>(0, (sum, c) => sum + c.quantity),
        11,
      );
    });

    test('14.805 configuration with double-vitrage parclose: parcloses '
        'cut at L−217.4 / H−257.4', () {
      final outcome = calculateConstructionCuts(
        _construction(profileUsages: [
          _usage('d-top', '14.801', ProfileUsageRole.top),
          _usage('d-bottom', '14.801', ProfileUsageRole.bottom),
          _usage('d-left', '14.801', ProfileUsageRole.left),
          _usage('d-right', '14.801', ProfileUsageRole.right),
          _usage('o-top', '14.805', ProfileUsageRole.top),
          _usage('o-bottom', '14.805', ProfileUsageRole.bottom),
          _usage('o-left', '14.805', ProfileUsageRole.left),
          _usage('o-right', '14.805', ProfileUsageRole.right),
          _usage('p-top', '14.810', ProfileUsageRole.top),
          _usage('p-right', '14.810', ProfileUsageRole.right),
        ]),
        _catalog(),
      )!;

      expect(outcome.issues, isEmpty);
      final byUsageId = {
        for (final cut in outcome.cuts) cut.profileUsageId: cut,
      };
      expect(byUsageId, hasLength(10));

      // Dormant 14.801: L+46 / H+46.
      expect(byUsageId['d-top']!.length, _l + 46);
      expect(byUsageId['d-left']!.length, _h + 46);
      // Ouvrant 14.805: same deductions as 14.802.
      expect(byUsageId['o-top']!.length, _l - 35.2);
      // Parcloses beside 14.805.
      expect(byUsageId['p-top']!.length, _l - 217.4);
      expect(byUsageId['p-top']!.quantity, 1);
      expect(byUsageId['p-right']!.length, _h - 257.4);
      expect(byUsageId['p-right']!.quantity, 1);
      // 4 dormant + 4 sash + 2 parcloses = 10 pieces.
      expect(
        outcome.cuts.fold<int>(0, (sum, c) => sum + c.quantity),
        10,
      );
    });

    test('simple (14.809) vs double (14.810) parclose choice changes no '
        'cut -- the glazing family rides on the profile reference alone',
        () {
      final outcomes = [
        for (final reference in ['14.809', '14.810'])
          calculateConstructionCuts(
            _construction(profileUsages: [
              _usage('o-left', '14.802', ProfileUsageRole.left),
              _usage('p-left', reference, ProfileUsageRole.left),
            ]),
            _catalog(),
          )!,
      ];
      for (final outcome in outcomes) {
        expect(outcome.issues, isEmpty);
        expect(
          outcome.cuts.firstWhere((c) => c.profileUsageId == 'p-left').length,
          _h - 157.6,
        );
      }
    });

    test('a mixed sash (14.802 + 14.805) skips the parclose with a '
        'visible issue and never throws', () {
      final outcome = calculateConstructionCuts(
        _construction(profileUsages: [
          _usage('o-left', '14.802', ProfileUsageRole.left),
          _usage('o-right', '14.805', ProfileUsageRole.right),
          _usage('p-top', '14.809', ProfileUsageRole.top),
        ]),
        _catalog(),
      )!;

      final byUsageId = {
        for (final cut in outcome.cuts) cut.profileUsageId: cut,
      };
      // Both sash members still cut (documented rows)...
      expect(byUsageId['o-left'], isNotNull);
      expect(byUsageId['o-right'], isNotNull);
      // ...while the parclose is skipped loudly, not wrongly cut.
      expect(byUsageId['p-top'], isNull);
      expect(outcome.issues.single.profileUsageId, 'p-top');
      expect(
        outcome.issues.single.reason,
        ProfileUsageIssueReason.noRuleMatched,
      );
    });

    test('no 2-vantaux table exists for this series -- a 2v française '
        'unit produces no cuts at all', () {
      final outcome = calculateConstructionCuts(
        _construction(
          vantauxCount: 2,
          profileUsages: [
            _usage('d-top', '14.800', ProfileUsageRole.top),
            _usage('o-top', '14.802', ProfileUsageRole.top),
          ],
        ),
        _catalog(),
      )!;
      expect(outcome.cuts, isEmpty);
      expect(outcome.issues, hasLength(2));
      for (final issue in outcome.issues) {
        expect(issue.reason, ProfileUsageIssueReason.noRuleMatched);
      }
    });

    test('the parclose without its sash carrier stays unmatched '
        '(fail-closed)', () {
      final outcome = calculateConstructionCuts(
        _construction(profileUsages: [
          _usage('d-top', '14.800', ProfileUsageRole.top),
          _usage('p-top', '14.809', ProfileUsageRole.top),
        ]),
        _catalog(),
      )!;
      expect(outcome.cuts, hasLength(1)); // only the dormant
      expect(outcome.issues.single.profileUsageId, 'p-top');
      expect(
        outcome.issues.single.reason,
        ProfileUsageIssueReason.noRuleMatched,
      );
    });
  });
}
