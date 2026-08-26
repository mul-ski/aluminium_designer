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

/// C7 end-to-end proof: a real Sepalumic Série 4200 construction
/// calculated through the FULL application pipeline --
/// Construction + seeded Catalog -> calculateConstructionCuts -> cuts
/// reproducing the Catalogue Technique Éd. 05 débitage tables
/// (docs/VERIFIED_SOURCES.md, M-2).
///
/// Worked example: L = 2000 mm, H = 1500 mm.
const double _l = 2000;
const double _h = 1500;

Catalog _catalog() => withBuiltInCatalogSeed(const Catalog());

Construction _construction({
  required List<ProfileUsage> profileUsages,
  SectionKind kind = SectionKind.ouvrant,
  int vantauxCount = 1,
}) => Construction(
  id: 'c-sep-4200',
  name: 'Série 4200',
  type: ConstructionType.window,
  width: _l,
  height: _h,
  manufacturer: 'Sepalumic',
  system: 'Série 4200',
  systemId: sepSerie4200Id,
  sections: [
    Section(
      id: 's-unit',
      order: 0,
      kind: kind,
      width: _l,
      height: _h,
      openingType: kind == SectionKind.ouvrant
          ? OpeningType.francaise
          : null,
      vantauxCount: kind == SectionKind.ouvrant ? vantauxCount : 0,
    ),
  ],
  layoutDirection: SectionLayoutDirection.horizontal,
  profiles: const [],
  profileUsages: profileUsages,
);

ProfileUsage _usage(String id, String reference, ProfileUsageRole role) {
  final profile = sepSerie4200.profilesById.values
      .firstWhere((p) => p.reference == reference);
  return ProfileUsage(
    id: id,
    profileId: profile.id,
    sectionId: 's-unit',
    role: role,
  );
}

void main() {
  group('end-to-end: Sepalumic 4200 débitage vs catalogue Éd. 05', () {
    test('OF 1 vantail (ouvrant 4211) reproduces sheet E070 exactly', () {
      final outcome = calculateConstructionCuts(
        _construction(profileUsages: [
          _usage('d-top', '4220', ProfileUsageRole.top),
          _usage('d-bottom', '4220', ProfileUsageRole.bottom),
          _usage('d-left', '4220', ProfileUsageRole.left),
          _usage('d-right', '4220', ProfileUsageRole.right),
          _usage('o-top', '4211', ProfileUsageRole.top),
          _usage('o-bottom', '4211', ProfileUsageRole.bottom),
          _usage('o-left', '4211', ProfileUsageRole.left),
          _usage('o-right', '4211', ProfileUsageRole.right),
        ]),
        _catalog(),
      )!;

      expect(outcome.issues, isEmpty);
      final byUsageId = {
        for (final cut in outcome.cuts) cut.profileUsageId: cut,
      };
      expect(byUsageId, hasLength(8));

      // Dormant 4220: 2×L + 2×H.
      expect(byUsageId['d-top']!.length, _l);
      expect(byUsageId['d-bottom']!.length, _l);
      expect(byUsageId['d-left']!.length, _h);
      expect(byUsageId['d-right']!.length, _h);

      // Ouvrant 4211: 2×(L−43.5) traverses + 2×(H−43.5) montants.
      expect(byUsageId['o-top']!.length, _l - 43.5);
      expect(byUsageId['o-bottom']!.length, _l - 43.5);
      expect(byUsageId['o-left']!.length, _h - 43.5);
      expect(byUsageId['o-right']!.length, _h - 43.5);

      // 45° mitres everywhere; provenance cites the catalogue.
      for (final cut in outcome.cuts) {
        expect(cut.angleStart, 45);
        expect(cut.angleEnd, 45);
        expect(cut.ruleDescription, contains('4200'));
        expect(cut.ruleDescription, contains('éd. 05'));
      }
      // Unit total: 4 frame + 4 sash pieces.
      expect(
        outcome.cuts.fold<int>(0, (sum, c) => sum + c.quantity),
        8,
      );
    });

    test('OF 2 vantaux (ouvrant 4211 + battue centrale) reproduces sheet '
        'E150 exactly', () {
      final outcome = calculateConstructionCuts(
        _construction(
          vantauxCount: 2,
          profileUsages: [
            _usage('d-top', '4220', ProfileUsageRole.top),
            _usage('d-bottom', '4220', ProfileUsageRole.bottom),
            _usage('d-left', '4220', ProfileUsageRole.left),
            _usage('d-right', '4220', ProfileUsageRole.right),
            _usage('o-top', '4211', ProfileUsageRole.top),
            _usage('o-bottom', '4211', ProfileUsageRole.bottom),
            _usage('o-left', '4211', ProfileUsageRole.left),
            _usage('o-right', '4211', ProfileUsageRole.right),
            _usage('bc-intermediate', '4206', ProfileUsageRole.intermediate),
          ],
        ),
        _catalog(),
      )!;

      expect(outcome.issues, isEmpty);
      final byUsageId = {
        for (final cut in outcome.cuts) cut.profileUsageId: cut,
      };
      expect(byUsageId, hasLength(9));

      // Ouvrant traverses: (L/2−24) = 976, TWO pieces per placement.
      expect(byUsageId['o-top']!.length, (_l / 2) - 24);
      expect(byUsageId['o-top']!.quantity, 2);
      expect(byUsageId['o-bottom']!.quantity, 2);
      // Ouvrant montants: (H−43.5) = 1456.5, TWO pieces per placement.
      expect(byUsageId['o-left']!.length, _h - 43.5);
      expect(byUsageId['o-left']!.quantity, 2);
      expect(byUsageId['o-right']!.quantity, 2);
      // Battue centrale: (H−102) = 1398, ONE square-cut piece.
      expect(byUsageId['bc-intermediate']!.length, _h - 102);
      expect(byUsageId['bc-intermediate']!.quantity, 1);
      expect(byUsageId['bc-intermediate']!.angleStart, 90);

      // Unit totals: dormant 4 + ouvrant 8 + battue 1 = 13 pieces,
      // exactly the E150 table.
      expect(
        outcome.cuts.fold<int>(0, (sum, c) => sum + c.quantity),
        13,
      );
    });

    test('châssis fixe reproduces E030 including the traverse option', () {
      final outcome = calculateConstructionCuts(
        _construction(
          kind: SectionKind.fixed,
          profileUsages: [
            _usage('d-top', '4220', ProfileUsageRole.top),
            _usage('d-bottom', '4220', ProfileUsageRole.bottom),
            _usage('d-left', '4220', ProfileUsageRole.left),
            _usage('d-right', '4220', ProfileUsageRole.right),
            _usage('t-intermediate', '4405', ProfileUsageRole.intermediate),
          ],
        ),
        _catalog(),
      )!;

      expect(outcome.issues, isEmpty);
      final byUsageId = {
        for (final cut in outcome.cuts) cut.profileUsageId: cut,
      };
      expect(byUsageId, hasLength(5));
      expect(byUsageId['d-top']!.length, _l);
      expect(byUsageId['d-left']!.length, _h);
      // Traverse option: L−54.5 = 1945.5, square cut.
      expect(byUsageId['t-intermediate']!.length, _l - 54.5);
      expect(byUsageId['t-intermediate']!.angleStart, 90);
    });

    test('the dormant 4221 variant cuts at L+50 / H+50 (E050)', () {
      final outcome = calculateConstructionCuts(
        _construction(
          kind: SectionKind.fixed,
          profileUsages: [
            _usage('d-top', '4221', ProfileUsageRole.top),
            _usage('d-left', '4221', ProfileUsageRole.left),
          ],
        ),
        _catalog(),
      )!;
      final byUsageId = {
        for (final cut in outcome.cuts) cut.profileUsageId: cut,
      };
      expect(byUsageId['d-top']!.length, _l + 50);
      expect(byUsageId['d-left']!.length, _h + 50);
    });

    test('undocumented configurations stay honest: 3 vantaux française '
        'produces no cuts at all', () {
      final outcome = calculateConstructionCuts(
        _construction(
          vantauxCount: 3,
          profileUsages: [
            _usage('d-top', '4220', ProfileUsageRole.top),
            _usage('o-top', '4211', ProfileUsageRole.top),
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

    test('parcloses are seeded but produce no cuts (glass-dependent '
        'selection is a documented blocker)', () {
      final outcome = calculateConstructionCuts(
        _construction(
          profileUsages: [
            _usage('p-left', '5016', ProfileUsageRole.left),
          ],
        ),
        _catalog(),
      )!;
      expect(outcome.cuts, isEmpty);
      expect(outcome.issues.single.reason,
          ProfileUsageIssueReason.noRuleMatched);
    });
  });

  group('end-to-end: OF traverse options (companion-gated, C8)', () {
    test('OF 1 vantail, ouvrant 4244 + traverse 2656 reproduces sheet '
        'E110 exactly (L−177 beside 4244)', () {
      final outcome = calculateConstructionCuts(
        _construction(profileUsages: [
          _usage('d-top', '4220', ProfileUsageRole.top),
          _usage('d-bottom', '4220', ProfileUsageRole.bottom),
          _usage('d-left', '4220', ProfileUsageRole.left),
          _usage('d-right', '4220', ProfileUsageRole.right),
          _usage('o-top', '4244', ProfileUsageRole.top),
          _usage('o-bottom', '4244', ProfileUsageRole.bottom),
          _usage('o-left', '4244', ProfileUsageRole.left),
          _usage('o-right', '4244', ProfileUsageRole.right),
          _usage('t-intermediate', '2656', ProfileUsageRole.intermediate),
        ]),
        _catalog(),
      )!;

      expect(outcome.issues, isEmpty);
      final byUsageId = {
        for (final cut in outcome.cuts) cut.profileUsageId: cut,
      };
      expect(byUsageId, hasLength(9));

      // Traverse option: L−177 = 1823, ONE square-cut piece (E110 p. 48).
      expect(byUsageId['t-intermediate']!.length, _l - 177);
      expect(byUsageId['t-intermediate']!.quantity, 1);
      expect(byUsageId['t-intermediate']!.angleStart, 90);
      expect(byUsageId['t-intermediate']!.angleEnd, 90);
      expect(byUsageId['t-intermediate']!.ruleDescription, contains('E110'));

      // Unit total: 4 dormant + 4 sash + 1 traverse = 9 pieces.
      expect(
        outcome.cuts.fold<int>(0, (sum, c) => sum + c.quantity),
        9,
      );
    });

    test('OF 2 vantaux, ouvrant 4219 + battue + traverse 2656 reproduces '
        'sheet E170 exactly (2×(L/2−122) beside 4219)', () {
      final outcome = calculateConstructionCuts(
        _construction(
          vantauxCount: 2,
          profileUsages: [
            _usage('d-top', '4220', ProfileUsageRole.top),
            _usage('d-bottom', '4220', ProfileUsageRole.bottom),
            _usage('d-left', '4220', ProfileUsageRole.left),
            _usage('d-right', '4220', ProfileUsageRole.right),
            _usage('o-top', '4219', ProfileUsageRole.top),
            _usage('o-bottom', '4219', ProfileUsageRole.bottom),
            _usage('o-left', '4219', ProfileUsageRole.left),
            _usage('o-right', '4219', ProfileUsageRole.right),
            _usage('bc-intermediate', '4206', ProfileUsageRole.intermediate),
            _usage('t-intermediate', '2656', ProfileUsageRole.intermediate),
          ],
        ),
        _catalog(),
      )!;

      expect(outcome.issues, isEmpty);
      final byUsageId = {
        for (final cut in outcome.cuts) cut.profileUsageId: cut,
      };
      expect(byUsageId, hasLength(10));

      // Traverse option: (L/2−122) = 878, TWO pieces (E170 p. 54).
      expect(byUsageId['t-intermediate']!.length, (_l / 2) - 122);
      expect(byUsageId['t-intermediate']!.quantity, 2);
      expect(byUsageId['t-intermediate']!.angleStart, 90);
      expect(byUsageId['t-intermediate']!.ruleDescription, contains('E170'));

      // The battue coexists unchanged (H−102 = 1398, one piece).
      expect(byUsageId['bc-intermediate']!.length, _h - 102);
      expect(byUsageId['bc-intermediate']!.quantity, 1);

      // Unit total: 4 dormant + 8 sash + 1 battue + 2 traverse = 15.
      expect(
        outcome.cuts.fold<int>(0, (sum, c) => sum + c.quantity),
        15,
      );
    });

    test('OF 2 vantaux, ouvrant 4254 + traverse 4413 reproduces sheet '
        'E210 exactly (2×(L/2−168) beside 4254)', () {
      final outcome = calculateConstructionCuts(
        _construction(
          vantauxCount: 2,
          profileUsages: [
            _usage('o-top', '4254', ProfileUsageRole.top),
            _usage('o-bottom', '4254', ProfileUsageRole.bottom),
            _usage('o-left', '4254', ProfileUsageRole.left),
            _usage('o-right', '4254', ProfileUsageRole.right),
            _usage('t-intermediate', '4413', ProfileUsageRole.intermediate),
          ],
        ),
        _catalog(),
      )!;

      expect(outcome.issues, isEmpty);
      final byUsageId = {
        for (final cut in outcome.cuts) cut.profileUsageId: cut,
      };
      // Traverse option: (L/2−168) = 832, TWO pieces (E210 p. 58).
      expect(byUsageId['t-intermediate']!.length, (_l / 2) - 168);
      expect(byUsageId['t-intermediate']!.quantity, 2);
      expect(byUsageId['t-intermediate']!.ruleDescription, contains('E210'));
    });

    test('a mixed sash (4211 left + 4219 right) skips the traverse with '
        'a visible issue and never throws', () {
      final outcome = calculateConstructionCuts(
        _construction(
          vantauxCount: 2,
          profileUsages: [
            _usage('o-top', '4211', ProfileUsageRole.top),
            _usage('o-bottom', '4211', ProfileUsageRole.bottom),
            _usage('o-left', '4211', ProfileUsageRole.left),
            _usage('o-right', '4219', ProfileUsageRole.right),
            _usage('bc-intermediate', '4206', ProfileUsageRole.intermediate),
            _usage('t-intermediate', '2656', ProfileUsageRole.intermediate),
          ],
        ),
        _catalog(),
      )!;

      final byUsageId = {
        for (final cut in outcome.cuts) cut.profileUsageId: cut,
      };
      // Every documented member still cuts...
      expect(byUsageId['o-top'], isNotNull);
      expect(byUsageId['o-right'], isNotNull);
      expect(byUsageId['bc-intermediate'], isNotNull);
      // ...while the traverse is skipped loudly, not wrongly cut.
      expect(byUsageId['t-intermediate'], isNull);
      final traverseIssue = outcome.issues.single;
      expect(traverseIssue.profileUsageId, 't-intermediate');
      expect(
        traverseIssue.reason,
        ProfileUsageIssueReason.noRuleMatched,
      );
    });

    test('the traverse option without its sash carrier stays unmatched '
        '(fail-closed)', () {
      final outcome = calculateConstructionCuts(
        _construction(profileUsages: [
          _usage('d-top', '4220', ProfileUsageRole.top),
          _usage('t-intermediate', '2656', ProfileUsageRole.intermediate),
        ]),
        _catalog(),
      )!;
      expect(outcome.cuts, hasLength(1)); // only the dormant
      expect(outcome.issues.single.profileUsageId, 't-intermediate');
      expect(
        outcome.issues.single.reason,
        ProfileUsageIssueReason.noRuleMatched,
      );
    });
  });
}
