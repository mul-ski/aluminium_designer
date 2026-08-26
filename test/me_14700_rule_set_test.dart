import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/data/builtin_catalog_seed.dart';
import 'package:aluminium_designer/core/data/me_14700_rule_set.dart';
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
/// values ('14.700', '14.705', ...) in both directions.
Construction _construction() => Construction(
  id: 'c1',
  name: 'Test',
  type: ConstructionType.door,
  width: 2000,
  height: 1500,
  manufacturer: 'Maghreb Extrusion (ME)',
  system: 'Série 14700 Portes Lourdes',
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
}) {
  final profile = meSerie14700.profilesById.values
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
  );
}

const _variables = <DimensionVariable, double>{
  DimensionVariable.constructionWidth: 2000,
  DimensionVariable.constructionHeight: 1500,
};

void main() {
  group('meSerie14700RuleSet metadata', () {
    test('is the real (non-placeholder) rule set of the seeded system', () {
      expect(meSerie14700RuleSet.systemId, meSerie14700Id);
      expect(meSerie14700RuleSet.isPlaceholder, isFalse);
      // C10a unambiguous subset: 6 dormant + 4 14.705 (1v x3 + 2v top)
      // + 2 traverse-basse + 8 parclose + 1 tige = 21.
      expect(meSerie14700RuleSet.rules, hasLength(21));
    });
  });

  group('routing: dormant 14.700 (p. 94, 45° / 45°/90° imprimé)', () {
    test('1v: top L (45°), left/right H (45°/90°)', () {
      final top = meSerie14700RuleSet.select(
        _context('14.700', vantauxCount: 1, role: ProfileUsageRole.top),
      );
      expect(top!.lengthExpression.evaluate(_variables), 2000.0);
      expect(top.angles.start, 45);
      expect(top.angles.end, 45);
      final left = meSerie14700RuleSet.select(
        _context('14.700', vantauxCount: 1, role: ProfileUsageRole.left),
      );
      expect(left!.lengthExpression.evaluate(_variables), 1500.0);
      expect(left.angles.start, 45);
      expect(left.angles.end, 90);
      expect(left.quantity.fixedCount, 1);
    });

    test('2v: same formulas, gated VantauxCountCondition(2)', () {
      final top = meSerie14700RuleSet.select(
        _context('14.700', vantauxCount: 2, role: ProfileUsageRole.top),
      );
      expect(top!.lengthExpression.evaluate(_variables), 2000.0);
      final right = meSerie14700RuleSet.select(
        _context('14.700', vantauxCount: 2, role: ProfileUsageRole.right),
      );
      expect(right!.lengthExpression.evaluate(_variables), 1500.0);
      expect(right.angles.start, 45);
      expect(right.angles.end, 90);
    });

    test('no bottom role -- 14.700 has no bottom piece (replaced by '
        'traverse-basse assembly)', () {
      expect(
        meSerie14700RuleSet.select(
          _context('14.700', vantauxCount: 1,
              role: ProfileUsageRole.bottom),
        ),
        isNull,
      );
    });
  });

  group('routing: ouvrant intérieur 14.705 (p. 94, 45° / 45°/90° imprimé)',
      () {
    test('1v: top L−118 (45°), left/right H−65 (45°/90°)', () {
      final top = meSerie14700RuleSet.select(
        _context('14.705', vantauxCount: 1, role: ProfileUsageRole.top),
      );
      expect(top!.lengthExpression.evaluate(_variables), 1882.0);
      expect(top.angles.start, 45);
      expect(top.angles.end, 45);
      final left = meSerie14700RuleSet.select(
        _context('14.705', vantauxCount: 1, role: ProfileUsageRole.left),
      );
      expect(left!.lengthExpression.evaluate(_variables), 1435.0);
      expect(left.angles.start, 45);
      expect(left.angles.end, 90);
    });

    test('2v: top (L−104,9)/2 (45°) is the only encoded 2v row', () {
      final top = meSerie14700RuleSet.select(
        _context('14.705', vantauxCount: 2, role: ProfileUsageRole.top),
      );
      expect(top, isNotNull);
      // (2000/2) − 104.9 = 895.1.
      expect(top!.lengthExpression.evaluate(_variables), 895.1);
    });

    test('2v stile formulas (H−65) stay noRuleMatched -- the 3+1 split '
        'is a documented source tension (C10a locked decision)', () {
      for (final role in [
        ProfileUsageRole.left,
        ProfileUsageRole.right,
        ProfileUsageRole.bottom,
        ProfileUsageRole.intermediate,
      ]) {
        expect(
          meSerie14700RuleSet.select(
            _context('14.705', vantauxCount: 2, role: role),
          ),
          isNull,
          reason: '14.705 2v $role: stile formula blocked per C10a',
        );
      }
    });
  });

  group('routing: ouvrant extérieur 14.706 (p. 94, BLOCKED at 2v)', () {
    test('14.706 has no encoded rule for ANY role at 1v or 2v '
        '(C10a locked decision -- 2v Qté 1 tension)', () {
      for (final vantauxCount in [1, 2]) {
        for (final role in ProfileUsageRole.values) {
          expect(
            meSerie14700RuleSet.select(
              _context('14.706', vantauxCount: vantauxCount, role: role),
            ),
            isNull,
            reason: '14.706 at $vantauxCount/$role: no rule encoded',
          );
        }
      }
    });
  });

  group('routing: traverse basse {14.813, 14.807} (p. 94, 90° imprimé)', () {
    test('1v: bottom L−261.6, 90°/90°, fixed(1)', () {
      final rule = meSerie14700RuleSet.select(
        _context('14.813', vantauxCount: 1,
            role: ProfileUsageRole.bottom),
      );
      expect(rule, isNotNull);
      expect(rule!.lengthExpression.evaluate(_variables), 1738.4);
      expect(rule.angles.start, 90);
      expect(rule.angles.end, 90);
      expect(rule.quantity.fixedCount, 1);
    });

    test('14.807 (complément) shares the rule with 14.813 (outcome-'
        'identical row, multi-ref set)', () {
      final rule807 = meSerie14700RuleSet.select(
        _context('14.807', vantauxCount: 1,
            role: ProfileUsageRole.bottom),
      );
      final rule813 = meSerie14700RuleSet.select(
        _context('14.813', vantauxCount: 1,
            role: ProfileUsageRole.bottom),
      );
      expect(rule807, isNotNull);
      expect(rule813, isNotNull);
      expect(
        rule807!.lengthExpression.evaluate(_variables),
        rule813!.lengthExpression.evaluate(_variables),
      );
    });

    test('2v: bottom (L−392,1)/2 per vantail, 90°/90°, fixed(2)', () {
      final rule = meSerie14700RuleSet.select(
        _context('14.813', vantauxCount: 2,
            role: ProfileUsageRole.bottom),
      );
      expect(rule, isNotNull);
      // (2000/2) − 392.1 = 607.9.
      expect(rule!.lengthExpression.evaluate(_variables), 607.9);
      expect(rule.quantity.fixedCount, 2);
    });
  });

  group('routing: parclose {14.809, 14.810} (p. 94, 90° imprimé)', () {
    test('1v horizontals: L−261.6 (top + bottom)', () {
      for (final role in [ProfileUsageRole.top, ProfileUsageRole.bottom]) {
        final rule = meSerie14700RuleSet.select(
          _context('14.809', vantauxCount: 1, role: role),
        );
        expect(rule, isNotNull, reason: role.toString());
        expect(rule!.lengthExpression.evaluate(_variables), 1738.4,
            reason: role.toString());
        expect(rule.angles.start, 90, reason: role.toString());
      }
    });

    test('1v verticals: H−296.8 (left + right), fixed(1)', () {
      for (final role in [ProfileUsageRole.left, ProfileUsageRole.right]) {
        final rule = meSerie14700RuleSet.select(
          _context('14.810', vantauxCount: 1, role: role),
        );
        expect(rule, isNotNull, reason: role.toString());
        expect(rule!.lengthExpression.evaluate(_variables), 1203.2,
            reason: role.toString());
        expect(rule.quantity.fixedCount, 1, reason: role.toString());
      }
    });

    test('14.809 and 14.810 share the same rule (outcome-identical row, '
        'multi-ref set)', () {
      for (final role in ProfileUsageRole.values) {
        final simple = meSerie14700RuleSet.select(
          _context('14.809', vantauxCount: 1, role: role),
        );
        final double_ = meSerie14700RuleSet.select(
          _context('14.810', vantauxCount: 1, role: role),
        );
        expect(
          simple,
          double_,
          reason: '$role: 14.809 and 14.810 share the same parclose rule',
        );
      }
    });

    test('2v horizontals: (L−392,1)/2 per vantail, fixed(2)', () {
      for (final role in [ProfileUsageRole.top, ProfileUsageRole.bottom]) {
        final rule = meSerie14700RuleSet.select(
          _context('14.809', vantauxCount: 2, role: role),
        );
        expect(rule, isNotNull, reason: role.toString());
        expect(rule!.lengthExpression.evaluate(_variables), 607.9,
            reason: role.toString());
        expect(rule.quantity.fixedCount, 2, reason: role.toString());
      }
    });

    test('2v verticals: H−296.8 per vantail, fixed(2)', () {
      for (final role in [ProfileUsageRole.left, ProfileUsageRole.right]) {
        final rule = meSerie14700RuleSet.select(
          _context('14.810', vantauxCount: 2, role: role),
        );
        expect(rule, isNotNull, reason: role.toString());
        expect(rule!.lengthExpression.evaluate(_variables), 1203.2,
            reason: role.toString());
        expect(rule.quantity.fixedCount, 2, reason: role.toString());
      }
    });
  });

  group('routing: tige de crémone 14.811 (1v only, no role condition)',
      () {
    test('cuts at H−90 (1410), 90°, one piece, at any role', () {
      for (final role in ProfileUsageRole.values) {
        final rule = meSerie14700RuleSet.select(
          _context('14.811', vantauxCount: 1, role: role),
        );
        expect(rule, isNotNull, reason: role.toString());
        expect(rule!.lengthExpression.evaluate(_variables), 1410.0,
            reason: role.toString());
        expect(rule.angles.start, 90);
        expect(rule.quantity.fixedCount, 1);
      }
    });

    test('2v has no encoded 14.811 rule -- the p.94 table only lists the '
        'tige in the 1v column', () {
      for (final role in ProfileUsageRole.values) {
        expect(
          meSerie14700RuleSet.select(
            _context('14.811', vantauxCount: 2, role: role),
          ),
          isNull,
          reason: '14.811 2v $role: not in the p.94 table',
        );
      }
    });
  });

  group('routing safety: uncovered configurations never match', () {
    test('14.819 parclose stays noRuleMatched (C10a locked decision -- '
        'p.94 has no row; p.92 maps 22-27mm glazing but no cut formula)',
        () {
      for (final role in ProfileUsageRole.values) {
        for (final vantauxCount in [1, 2]) {
          expect(
            meSerie14700RuleSet.select(
              _context('14.819', vantauxCount: vantauxCount, role: role),
            ),
            isNull,
            reason: '14.819 at $vantauxCount/$role: no débitage row',
          );
        }
      }
    });

    test('non-française opening types match nothing', () {
      for (final openingType in [
        OpeningType.coulissante,
        OpeningType.oscilloBattant,
        OpeningType.anglaise,
      ]) {
        expect(
          meSerie14700RuleSet.select(
            _context('14.700', openingType: openingType,
                role: ProfileUsageRole.top),
          ),
          isNull,
          reason: '$openingType has no encoded 14700 débitage',
        );
      }
    });

    test('profiles without débitage rows stay unmatched', () {
      for (final entry in [
        ('14.701', ProfileUsageRole.top),   // imposte fixe
        ('14.704', ProfileUsageRole.intermediate),
        ('14.712', ProfileUsageRole.bottom), // traverse basse cap
        ('14.718', ProfileUsageRole.top),
        ('14.803', ProfileUsageRole.left),
        ('14.812', ProfileUsageRole.left),
        ('14.711', ProfileUsageRole.top),
      ]) {
        expect(
          meSerie14700RuleSet.select(
            _context(entry.$1, role: entry.$2),
          ),
          isNull,
          reason: '${entry.$1} has no encoded débitage row',
        );
      }
    });

    test('3 vantaux française matches nothing (no 3v table exists)', () {
      for (final reference in ['14.700', '14.705', '14.813', '14.811']) {
        expect(
          meSerie14700RuleSet.select(
            _context(reference, vantauxCount: 3,
                role: ProfileUsageRole.top),
          ),
          isNull,
          reason: '$reference at 3vantaux: undocumented',
        );
      }
    });

    test('missing section fails closed', () {
      final context = CalculationContext(
        construction: _construction(),
        profile: meSerie14700.profilesById.values
            .firstWhere((p) => p.reference == '14.700'),
        section: null,
        usage: ProfileUsage(
          id: 'u1',
          profileId: 'builtin-me-14700-14700',
          sectionId: 'gone',
          role: ProfileUsageRole.top,
        ),
      );
      expect(meSerie14700RuleSet.select(context), isNull);
    });

    test('exhaustive sweep: no context ever selects ambiguously', () {
      for (final profile in meSerie14700.profiles) {
        for (final role in ProfileUsageRole.values) {
          for (final kind in SectionKind.values) {
            for (final openingType in OpeningType.values) {
              for (final vantauxCount in [1, 2, 3]) {
                final isOuvrant = kind == SectionKind.ouvrant;
                expect(
                  () => meSerie14700RuleSet.select(
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
                    ),
                  ),
                  returnsNormally,
                  reason:
                      '${profile.reference} $role $kind $openingType '
                      '$vantauxCount must resolve to zero-or-one rules '
                      'without ambiguity',
                );
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
      for (final rule in meSerie14700RuleSet.rules) {
        expect(rule.description, isNotNull);
        expect(rule.description, contains('14700'));
        expect(rule.description, contains('p. 94'));
        expect(
          rule.description!.contains('45° imprimé') ||
              rule.description!.contains('45°/90° imprimé') ||
              rule.description!.contains('90° imprimé'),
          isTrue,
          reason: rule.description,
        );
      }
    });
  });
}
