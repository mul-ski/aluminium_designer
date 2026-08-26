import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/data/builtin_catalog_seed.dart';
import 'package:aluminium_designer/core/data/me_14800_rule_set.dart';
import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/layout_direction.dart';
import 'package:aluminium_designer/core/models/opening.dart';
import 'package:aluminium_designer/core/models/profile_usage.dart';
import 'package:aluminium_designer/core/models/rules/dimension_expression.dart';
import 'package:aluminium_designer/core/models/rules/rule_condition.dart';
import 'package:aluminium_designer/core/models/section.dart';

/// Contexts built from the REAL seeded profiles: the tests pin the rule
/// set's reference strings to the seed's actual `Profile.reference`
/// values ('14.800', '14.809', ...) in both directions.
Construction _construction() => Construction(
  id: 'c1',
  name: 'Test',
  type: ConstructionType.window,
  width: 2000,
  height: 1500,
  manufacturer: 'Maghreb Extrusion (ME)',
  system: 'Série 14800 Frappe',
  sections: const [],
  layoutDirection: SectionLayoutDirection.horizontal,
  profiles: const [],
);

Section _section({
  SectionKind kind = SectionKind.ouvrant,
  OpeningType? openingType = OpeningType.francaise,
  int vantauxCount = 1,
}) {
  final isFixed = kind == SectionKind.fixed;
  return Section(
    id: 's1',
    order: 0,
    kind: kind,
    width: 2000,
    height: 1500,
    openingType: isFixed ? null : openingType,
    vantauxCount: isFixed ? 0 : vantauxCount,
  );
}

CalculationContext _context(
  String reference, {
  SectionKind kind = SectionKind.ouvrant,
  OpeningType? openingType = OpeningType.francaise,
  int vantauxCount = 1,
  ProfileUsageRole? role,
  List<SectionSibling> siblings = const [],
}) {
  final profile = meSerie14800.profilesById.values
      .firstWhere((p) => p.reference == reference);
  return CalculationContext(
    construction: _construction(),
    profile: profile,
    section: _section(
      kind: kind,
      openingType: openingType,
      vantauxCount: vantauxCount,
    ),
    usage: role == null
        ? null
        : ProfileUsage(
            id: 'u1',
            profileId: profile.id,
            sectionId: 's1',
            role: role,
          ),
    siblings: siblings,
  );
}

SectionSibling _sibling(
  String reference, {
  ProfileUsageRole role = ProfileUsageRole.left,
}) {
  final profile = meSerie14800.profilesById.values
      .firstWhere((p) => p.reference == reference);
  return SectionSibling(
    usage: ProfileUsage(
      id: 'sib-$reference-$role',
      profileId: profile.id,
      sectionId: 's1',
      role: role,
    ),
    profile: profile,
  );
}

const _variables = <DimensionVariable, double>{
  DimensionVariable.constructionWidth: 2000,
  DimensionVariable.constructionHeight: 1500,
};

void main() {
  group('meSerie14800RuleSet metadata', () {
    test('is the real (non-placeholder) rule set of the seeded system', () {
      expect(meSerie14800RuleSet.systemId, meSerie14800Id);
      expect(meSerie14800RuleSet.isPlaceholder, isFalse);
      // 8 dormant/ouvrant role rules ×2 refs... exact printed-row count:
      // 4 (14.800) + 4 (14.801) + 4 (14.802) + 4 (14.805) + 8 parcloses
      // + 1 tige = 25.
      expect(meSerie14800RuleSet.rules, hasLength(25));
    });
  });

  group('routing: dormants (p. 65, 45° imprimé)', () {
    test('14.800 cuts at L (2000) and H (1500), one piece per placement',
        () {
      final top = meSerie14800RuleSet.select(
        _context('14.800', role: ProfileUsageRole.top),
      );
      expect(top!.lengthExpression.evaluate(_variables), 2000.0);
      expect(top.angles.start, 45);
      final left = meSerie14800RuleSet.select(
        _context('14.800', role: ProfileUsageRole.left),
      );
      expect(left!.lengthExpression.evaluate(_variables), 1500.0);
      expect(left.quantity.fixedCount, 1);
    });

    test('14.801 cuts at L+46 (2046) and H+46 (1546)', () {
      final top = meSerie14800RuleSet.select(
        _context('14.801', role: ProfileUsageRole.top),
      );
      expect(top!.lengthExpression.evaluate(_variables), 2046.0);
      final right = meSerie14800RuleSet.select(
        _context('14.801', role: ProfileUsageRole.right),
      );
      expect(right!.lengthExpression.evaluate(_variables), 1546.0);
    });
  });

  group('routing: ouvrants (p. 65, 45° imprimé)', () {
    test('14.802 and 14.805 both cut at L−35.2 (1964.8) and H−35.2 '
        '(1464.8)', () {
      for (final reference in ['14.802', '14.805']) {
        final top = meSerie14800RuleSet.select(
          _context(reference, role: ProfileUsageRole.top),
        );
        expect(top, isNotNull, reason: reference);
        expect(top!.lengthExpression.evaluate(_variables), 1964.8,
            reason: reference);
        final left = meSerie14800RuleSet.select(
          _context(reference, role: ProfileUsageRole.left),
        );
        expect(left, isNotNull, reason: reference);
        expect(left!.lengthExpression.evaluate(_variables), 1464.8,
            reason: reference);
        expect(left.quantity.fixedCount, 1, reason: reference);
      }
    });
  });

  group('routing: parcloses (companion-gated, p. 65)', () {
    test('beside 14.802: L−117.6 (1882.4) and H−157.6 (1342.4), square '
        'cut', () {
      for (final role in [
        MapEntry(ProfileUsageRole.top, 2000.0 - 117.6),
        MapEntry(ProfileUsageRole.bottom, 2000.0 - 117.6),
        MapEntry(ProfileUsageRole.left, 1500.0 - 157.6),
        MapEntry(ProfileUsageRole.right, 1500.0 - 157.6),
      ]) {
        final rule = meSerie14800RuleSet.select(
          _context(
            '14.809',
            role: role.key,
            siblings: [_sibling('14.802')],
          ),
        );
        expect(rule, isNotNull, reason: role.key.toString());
        expect(rule!.lengthExpression.evaluate(_variables), role.value,
            reason: role.key.toString());
        expect(rule.angles.start, 90);
        expect(rule.quantity.fixedCount, 1);
      }
    });

    test('beside 14.805: L−217.4 (1782.6) and H−257.4 (1242.6)', () {
      final top = meSerie14800RuleSet.select(
        _context('14.810', role: ProfileUsageRole.top,
            siblings: [_sibling('14.805')]),
      );
      expect(top!.lengthExpression.evaluate(_variables), 1782.6);
      final right = meSerie14800RuleSet.select(
        _context('14.810', role: ProfileUsageRole.right,
            siblings: [_sibling('14.805')]),
      );
      expect(right!.lengthExpression.evaluate(_variables), 1242.6);
    });

    test('simple (14.809) and double (14.810) produce identical cuts -- '
        'outcome-identical printed row', () {
      for (final role in [ProfileUsageRole.top, ProfileUsageRole.left]) {
        final simple = meSerie14800RuleSet.select(
          _context('14.809', role: role,
              siblings: [_sibling('14.802')]),
        );
        final double_ = meSerie14800RuleSet.select(
          _context('14.810', role: role,
              siblings: [_sibling('14.802')]),
        );
        expect(simple, isNotNull, reason: role.toString());
        expect(double_, isNotNull, reason: role.toString());
        expect(
          simple!.lengthExpression.evaluate(_variables),
          double_!.lengthExpression.evaluate(_variables),
          reason: role.toString(),
        );
      }
    });

    test('each parclose ref routes to its section\'s carrier cell; a '
        'carrier-less section matches nothing', () {
      // 14.809 beside 14.805 lands on the 14.805 cell (the row covers
      // both parclose refs).
      expect(
        meSerie14800RuleSet.select(
          _context('14.809', role: ProfileUsageRole.top,
              siblings: [_sibling('14.805')]),
        )!.lengthExpression.evaluate(_variables),
        1782.6,
      );
      // A parclose in a section with NO sash carrier matches nothing:
      expect(
        meSerie14800RuleSet.select(
          _context('14.809', role: ProfileUsageRole.top),
        ),
        isNull,
      );
    });

    test('mixed sash (14.802 + 14.805) matches nothing, without throwing',
        () {
      expect(
        meSerie14800RuleSet.select(
          _context('14.809', role: ProfileUsageRole.top, siblings: [
            _sibling('14.802', role: ProfileUsageRole.left),
            _sibling('14.805', role: ProfileUsageRole.right),
          ]),
        ),
        isNull,
      );
    });

    test('a parclose at the intermediate role is not a sash carrier and '
        'matches nothing', () {
      expect(
        meSerie14800RuleSet.select(
          _context('14.809', role: ProfileUsageRole.intermediate, siblings: [
            _sibling('14.809', role: ProfileUsageRole.intermediate),
          ]),
        ),
        isNull,
      );
    });
  });

  group('routing: tige de crémone 14.811 (no role condition)', () {
    test('cuts at H−90 (1410), square, one piece, at any role', () {
      for (final role in ProfileUsageRole.values) {
        final rule = meSerie14800RuleSet.select(
          _context('14.811', role: role),
        );
        expect(rule, isNotNull, reason: role.toString());
        expect(rule!.lengthExpression.evaluate(_variables), 1410.0,
            reason: role.toString());
        expect(rule.angles.start, 90);
        expect(rule.quantity.fixedCount, 1);
      }
    });
  });

  group('routing safety: uncovered configurations never match', () {
    test('no 2-vantaux table exists for this series -- 2v française '
        'matches nothing', () {
      for (final entry in [
        ('14.800', ProfileUsageRole.top, const <SectionSibling>[]),
        ('14.802', ProfileUsageRole.top, const <SectionSibling>[]),
        (
          '14.809',
          ProfileUsageRole.top,
          <SectionSibling>[_sibling('14.802', role: ProfileUsageRole.left)],
        ),
        ('14.811', ProfileUsageRole.top, const <SectionSibling>[]),
      ]) {
        expect(
          meSerie14800RuleSet.select(
            _context(
              entry.$1,
              vantauxCount: 2,
              role: entry.$2,
              siblings: entry.$3,
            ),
          ),
          isNull,
          reason: '${entry.$1} at 2 vantaux is undocumented',
        );
      }
    });

    test('non-française opening types match nothing', () {
      for (final openingType in [
        OpeningType.coulissante,
        OpeningType.oscilloBattant,
        OpeningType.anglaise,
      ]) {
        expect(
          meSerie14800RuleSet.select(
            _context('14.800', openingType: openingType,
                role: ProfileUsageRole.top),
          ),
          isNull,
          reason: '$openingType has no encoded 14800 débitage',
        );
      }
    });

    test('profiles without débitage rows stay unmatched', () {
      for (final entry in [
        ('14803', ProfileUsageRole.left),
        ('14812', ProfileUsageRole.intermediate),
        ('14820', ProfileUsageRole.top),
      ]) {
        expect(
          meSerie14800RuleSet.select(
            _context(entry.$1, role: entry.$2),
          ),
          isNull,
          reason: '${entry.$1} has no encoded débitage row',
        );
      }
    });

    test('missing section fails closed', () {
      final context = CalculationContext(
        construction: _construction(),
        profile: meSerie14800.profilesById.values
            .firstWhere((p) => p.reference == '14.800'),
        section: null,
        usage: ProfileUsage(
          id: 'u1',
          profileId: 'builtin-me-14800-14800',
          sectionId: 'gone',
          role: ProfileUsageRole.top,
        ),
      );
      expect(meSerie14800RuleSet.select(context), isNull);
    });

    test('exhaustive sweep: no context ever selects ambiguously', () {
      final companionSets = <List<SectionSibling>>[
        const [],
        [_sibling('14.802')],
        [_sibling('14.805')],
        [
          _sibling('14.802', role: ProfileUsageRole.left),
          _sibling('14.805', role: ProfileUsageRole.right),
        ],
        [_sibling('14.809', role: ProfileUsageRole.intermediate)],
        [_sibling('14820')],
      ];
      for (final profile in meSerie14800.profiles) {
        for (final role in ProfileUsageRole.values) {
          for (final kind in SectionKind.values) {
            for (final openingType in OpeningType.values) {
              for (final vantauxCount in [1, 2, 3]) {
                for (final siblings in companionSets) {
                  final isOuvrant = kind == SectionKind.ouvrant;
                  expect(
                    () => meSerie14800RuleSet.select(
                      CalculationContext(
                        construction: _construction(),
                        profile: profile,
                        section: Section(
                          id: 's',
                          order: 0,
                          kind: kind,
                          width: 2000,
                          height: 1500,
                          openingType: isOuvrant ? openingType : null,
                          vantauxCount: isOuvrant ? vantauxCount : 0,
                        ),
                        usage: ProfileUsage(
                          id: 'u',
                          profileId: profile.id,
                          sectionId: 's',
                          role: role,
                        ),
                        siblings: siblings,
                      ),
                    ),
                    returnsNormally,
                    reason:
                        '${profile.reference} $role $kind $openingType '
                        '$vantauxCount siblings='
                        '${siblings.map((s) => s.profile.reference).join('+')} '
                        'must resolve to zero-or-one rules without '
                        'ambiguity',
                  );
                }
              }
            }
          }
        }
      }
    });
  });

  group('rule provenance descriptions', () {
    test('every rule cites the catalogue + page and the printed angles',
        () {
      for (final rule in meSerie14800RuleSet.rules) {
        expect(rule.description, isNotNull);
        expect(rule.description, contains('14800'));
        expect(rule.description, contains('p. 65'));
        expect(
          rule.description!.contains('45° imprimé') ||
              rule.description!.contains('90° imprimé'),
          isTrue,
          reason: rule.description,
        );
      }
    });
  });
}
