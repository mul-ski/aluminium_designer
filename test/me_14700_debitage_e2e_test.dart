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

/// C10a end-to-end proof: a real Maghreb Extrusion Série 14700 portes
/// Lourdes construction calculated through the FULL application pipeline
/// -- Construction + seeded Catalog -> calculateConstructionCuts -> cuts
/// reproducing the unambiguous subset of the Catalogue Général p. 94
/// débitage table (docs/VERIFIED_SOURCES.md, S-4).
///
/// Worked dimensions: L = 2000 mm, H = 1500 mm.
const double _l = 2000;
const double _h = 1500;

Catalog _catalog() => withBuiltInCatalogSeed(const Catalog());

Construction _construction({
  required List<ProfileUsage> profileUsages,
  OpeningType openingType = OpeningType.francaise,
  int vantauxCount = 1,
}) =>
    Construction(
      id: 'c-me-14700',
      name: 'Série 14700 Portes Lourdes',
      type: ConstructionType.door,
      width: _l,
      height: _h,
      manufacturer: 'Maghreb Extrusion (ME)',
      system: 'Série 14700 Portes Lourdes',
      systemId: meSerie14700Id,
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
  final profile = meSerie14700.profilesById.values
      .firstWhere((p) => p.reference == reference);
  return ProfileUsage(
    id: id,
    profileId: profile.id,
    sectionId: 's-unit',
    role: role,
  );
}

void main() {
  group('end-to-end: ME 14700 portes Lourdes (1v, unambiguous subset)',
      () {
    test('1v with dormant + 14.705 leaf + traverse-basse + parcloses '
        '+ tige reproduces p. 94 exactly', () {
      final outcome = calculateConstructionCuts(
        _construction(profileUsages: [
          _usage('d-top', '14.700', ProfileUsageRole.top),
          _usage('d-left', '14.700', ProfileUsageRole.left),
          _usage('d-right', '14.700', ProfileUsageRole.right),
          _usage('o-top', '14.705', ProfileUsageRole.top),
          _usage('o-left', '14.705', ProfileUsageRole.left),
          _usage('o-right', '14.705', ProfileUsageRole.right),
          _usage('tb', '14.813', ProfileUsageRole.bottom),
          _usage('p-top', '14.810', ProfileUsageRole.top),
          _usage('p-bottom', '14.810', ProfileUsageRole.bottom),
          _usage('p-left', '14.810', ProfileUsageRole.left),
          _usage('p-right', '14.810', ProfileUsageRole.right),
          _usage('tige', '14.811', ProfileUsageRole.intermediate),
        ]),
        _catalog(),
      )!;

      expect(outcome.issues, isEmpty);
      final byUsageId = {
        for (final cut in outcome.cuts) cut.profileUsageId: cut,
      };
      expect(byUsageId, hasLength(12));

      // Dormant 14.700: 1×L + 2×H.
      expect(byUsageId['d-top']!.length, _l);
      expect(byUsageId['d-top']!.angleStart, 45);
      expect(byUsageId['d-top']!.angleEnd, 45);
      expect(byUsageId['d-left']!.length, _h);
      expect(byUsageId['d-left']!.angleStart, 45);
      expect(byUsageId['d-left']!.angleEnd, 90);
      // Ouvrant intérieur 14.705: 1×(L−118) + 2×(H−65), mitred/stile angles.
      expect(byUsageId['o-top']!.length, _l - 118);
      expect(byUsageId['o-left']!.length, _h - 65);
      expect(byUsageId['o-left']!.angleStart, 45);
      expect(byUsageId['o-left']!.angleEnd, 90);
      // Traverse basse 14.813: 1×(L−261.6), 90°/90°.
      expect(byUsageId['tb']!.length, _l - 261.6);
      expect(byUsageId['tb']!.angleStart, 90);
      expect(byUsageId['tb']!.angleEnd, 90);
      expect(byUsageId['tb']!.quantity, 1);
      // Parclose 14.810: 2×(L−261.6) + 2×(H−296.8), all 90°/90°.
      expect(byUsageId['p-top']!.length, _l - 261.6);
      expect(byUsageId['p-bottom']!.length, _l - 261.6);
      expect(byUsageId['p-left']!.length, _h - 296.8);
      expect(byUsageId['p-right']!.length, _h - 296.8);
      // Tige de crémone 14.811: 1×(H−90), 90°/90°.
      expect(byUsageId['tige']!.length, _h - 90);
      expect(byUsageId['tige']!.quantity, 1);
      expect(byUsageId['tige']!.angleStart, 90);

      // Provenance cites the source.
      for (final cut in outcome.cuts) {
        expect(cut.ruleDescription, contains('14700'));
        expect(cut.ruleDescription, contains('p. 94'));
      }
      // Unit total: 3 dormant + 3 sash + 1 traverse-basse + 4 parclose
      // + 1 tige = 12 pieces.
      expect(
        outcome.cuts.fold<int>(0, (sum, c) => sum + c.quantity),
        12,
      );
    });

    test('complément traverse basse 14.807 (multi-ref set) produces '
        'the same length as 14.813', () {
      final outcome = calculateConstructionCuts(
        _construction(profileUsages: [
          _usage('d-top', '14.700', ProfileUsageRole.top),
          _usage('tb807', '14.807', ProfileUsageRole.bottom),
        ]),
        _catalog(),
      )!;
      final byUsageId = {
        for (final cut in outcome.cuts) cut.profileUsageId: cut,
      };
      expect(byUsageId['tb807']!.length, _l - 261.6);
    });
  });

  group('end-to-end: ME 14700 (2v, C10a unambiguous subset)', () {
    test('2v: dormant + 14.705 top + traverse-basse (×2 per leaf) + '
        'parclose horizontals and verticals produce the 2v column of '
        'p. 94', () {
      final outcome = calculateConstructionCuts(
        _construction(
          vantauxCount: 2,
          profileUsages: [
            _usage('d-top', '14.700', ProfileUsageRole.top),
            _usage('d-left', '14.700', ProfileUsageRole.left),
            _usage('d-right', '14.700', ProfileUsageRole.right),
            _usage('o-top', '14.705', ProfileUsageRole.top),
            _usage('tb', '14.813', ProfileUsageRole.bottom),
            _usage('p-top', '14.809', ProfileUsageRole.top),
            _usage('p-bottom', '14.809', ProfileUsageRole.bottom),
            _usage('p-left', '14.809', ProfileUsageRole.left),
            _usage('p-right', '14.809', ProfileUsageRole.right),
          ],
        ),
        _catalog(),
      )!;

      expect(outcome.issues, isEmpty);
      final byUsageId = {
        for (final cut in outcome.cuts) cut.profileUsageId: cut,
      };
      expect(byUsageId, hasLength(9));

      // Dormant 14.700 2v: same formulas.
      expect(byUsageId['d-top']!.length, _l);
      // Ouvrant 14.705 2v top: (L−104,9)/2.
      expect(byUsageId['o-top']!.length, (_l / 2) - 104.9);
      // Traverse basse 14.813 2v: 2×(L−392,1)/2 per vantail.
      expect(byUsageId['tb']!.length, (_l / 2) - 392.1);
      expect(byUsageId['tb']!.quantity, 2);
      // Parcloses 14.809 2v: 2×(L−392,1)/2 top+bottom, 2×(H−296.8) left+right.
      expect(byUsageId['p-top']!.length, (_l / 2) - 392.1);
      expect(byUsageId['p-top']!.quantity, 2);
      expect(byUsageId['p-left']!.length, _h - 296.8);
      expect(byUsageId['p-left']!.quantity, 2);

      // Unit total: 3 dormant + 1 sash top + 2 traverse-basse + 8
      // parclose = 14 pieces.
      expect(
        outcome.cuts.fold<int>(0, (sum, c) => sum + c.quantity),
        14,
      );
    });
  });

  group('C10a locked decision: 2v stile / 14.706 / 14.819 stay noRuleMatched',
      () {
    test('2v 14.705 stile usage is a noRuleMatched skip with a visible '
        'issue and no throw', () {
      final outcome = calculateConstructionCuts(
        _construction(
          vantauxCount: 2,
          profileUsages: [
            _usage('d-top', '14.700', ProfileUsageRole.top),
            _usage('stile-left', '14.705', ProfileUsageRole.left),
          ],
        ),
        _catalog(),
      )!;
      // Dormant top still cuts...
      expect(outcome.cuts, hasLength(1));
      // ...and the 14.705 stile is loudly skipped.
      expect(outcome.issues.single.profileUsageId, 'stile-left');
      expect(
        outcome.issues.single.reason,
        ProfileUsageIssueReason.noRuleMatched,
      );
    });

    test('2v 14.706 usage is a noRuleMatched skip (C10a blocker)', () {
      final outcome = calculateConstructionCuts(
        _construction(
          vantauxCount: 2,
          profileUsages: [
            _usage('d-top', '14.700', ProfileUsageRole.top),
            _usage('ext-left', '14.706', ProfileUsageRole.left),
          ],
        ),
        _catalog(),
      )!;
      expect(outcome.cuts, hasLength(1));
      expect(outcome.issues.single.profileUsageId, 'ext-left');
      expect(
        outcome.issues.single.reason,
        ProfileUsageIssueReason.noRuleMatched,
      );
    });

    test('14.819 parclose usage is a noRuleMatched skip (C10a blocker)', () {
      final outcome = calculateConstructionCuts(
        _construction(
          profileUsages: [
            _usage('d-top', '14.700', ProfileUsageRole.top),
            _usage('p-top', '14.819', ProfileUsageRole.top),
          ],
        ),
        _catalog(),
      )!;
      expect(outcome.cuts, hasLength(1));
      expect(outcome.issues.single.profileUsageId, 'p-top');
      expect(
        outcome.issues.single.reason,
        ProfileUsageIssueReason.noRuleMatched,
      );
    });
  });
}
