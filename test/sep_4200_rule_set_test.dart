import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/data/builtin_catalog_seed.dart';
import 'package:aluminium_designer/core/data/sep_4200_rule_set.dart';
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
/// values ('4220', '2656', ...) in both directions.
Construction _construction() => Construction(
  id: 'c1',
  name: 'Test',
  type: ConstructionType.window,
  width: 2000,
  height: 1500,
  manufacturer: 'Sepalumic',
  system: 'Série 4200',
  sections: const [],
  layoutDirection: SectionLayoutDirection.horizontal,
  profiles: const [],
);

Section _section({
  SectionKind kind = SectionKind.ouvrant,
  OpeningType? openingType = OpeningType.francaise,
  int vantauxCount = 1,
}) {
  // Constructor invariants: fixed sections carry no opening type and
  // zero vantaux.
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
  final profile = sepSerie4200.profilesById.values
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
  group('sepSerie4200RuleSet metadata', () {
    test('is the real (non-placeholder) rule set of the seeded system', () {
      expect(sepSerie4200RuleSet.systemId, sepSerie4200Id);
      expect(sepSerie4200RuleSet.isPlaceholder, isFalse);
      expect(sepSerie4200RuleSet.rules, isNotEmpty);
    });
  });

  group('routing: châssis fixe (E030/E050)', () {
    test('dormant 4220 cuts at L (2000) and H (1500), one piece each',
        () {
      final top = sepSerie4200RuleSet.select(
        _context('4220', kind: SectionKind.fixed, role: ProfileUsageRole.top),
      );
      expect(top!.lengthExpression.evaluate(_variables), 2000.0);
      final left = sepSerie4200RuleSet.select(
        _context('4220', kind: SectionKind.fixed, role: ProfileUsageRole.left),
      );
      expect(left!.lengthExpression.evaluate(_variables), 1500.0);
      expect(left.quantity.fixedCount, 1);
    });

    test('dormant 4221 cuts at L+50 (2050) and H+50 (1550)', () {
      final top = sepSerie4200RuleSet.select(
        _context('4221', kind: SectionKind.fixed, role: ProfileUsageRole.top),
      );
      expect(top!.lengthExpression.evaluate(_variables), 2050.0);
      final right = sepSerie4200RuleSet.select(
        _context('4221', kind: SectionKind.fixed, role: ProfileUsageRole.right),
      );
      expect(right!.lengthExpression.evaluate(_variables), 1550.0);
    });

    test('traverse option 4405/4413 intermediate cuts at L−54.5 '
        '(1945.5), square cut', () {
      for (final reference in ['4405', '4413']) {
        final rule = sepSerie4200RuleSet.select(
          _context(
            reference,
            kind: SectionKind.fixed,
            role: ProfileUsageRole.intermediate,
          ),
        );
        expect(rule, isNotNull, reason: reference);
        expect(rule!.lengthExpression.evaluate(_variables), 1945.5);
        expect(rule.angles.start, 90);
        expect(rule.angles.end, 90);
        expect(rule.quantity.fixedCount, 1);
      }
    });

    test('2656 is NOT the fixe traverse (L−54.5 row names 4405/4413)',
        () {
      expect(
        sepSerie4200RuleSet.select(
          _context(
            '2656',
            kind: SectionKind.fixed,
            role: ProfileUsageRole.intermediate,
          ),
        ),
        isNull,
      );
    });
  });

  group('routing: OF 1 vantail (E070/E090/E110/E130)', () {
    test('dormants duplicate the fixe formulas under the française gate',
        () {
      final top = sepSerie4200RuleSet.select(
        _context('4220', vantauxCount: 1, role: ProfileUsageRole.top),
      )!;
      expect(top.lengthExpression.evaluate(_variables), 2000.0);
      final left = sepSerie4200RuleSet.select(
        _context('4221', vantauxCount: 1, role: ProfileUsageRole.left),
      )!;
      expect(left.lengthExpression.evaluate(_variables), 1550.0);
    });

    test('all four ouvrant refs cut at L−43.5 (1956.5) and H−43.5 '
        '(1456.5), one piece per placement', () {
      for (final reference in ['4211', '4219', '4244', '4254']) {
        final top = sepSerie4200RuleSet.select(
          _context(reference, vantauxCount: 1, role: ProfileUsageRole.top),
        );
        expect(top, isNotNull, reason: '$reference top');
        expect(top!.lengthExpression.evaluate(_variables), 1956.5);
        final left = sepSerie4200RuleSet.select(
          _context(reference, vantauxCount: 1, role: ProfileUsageRole.left),
        );
        expect(left, isNotNull, reason: '$reference left');
        expect(left!.lengthExpression.evaluate(_variables), 1456.5);
        expect(left.quantity.fixedCount, 1);
      }
    });

    test('battue centrale 4206 stays unmatched at 1 vantail (its row '
        'exists only in the 2-vantaux tables)', () {
      expect(
        sepSerie4200RuleSet.select(
          _context('4206', vantauxCount: 1, role: ProfileUsageRole.intermediate),
        ),
        isNull,
      );
    });
  });

  group('routing: OF 2 vantaux (E150/E170/E190/E210)', () {
    test('ouvrant TRAVERSES yield TWO L/2−24 pieces per track placement '
        '(976 mm) -- each leaf is ~half the width', () {
      for (final role in [ProfileUsageRole.top, ProfileUsageRole.bottom]) {
        final rule = sepSerie4200RuleSet.select(
          _context('4211', vantauxCount: 2, role: role),
        );
        expect(rule, isNotNull, reason: role.toString());
        // (2000/2)−24 = 976 exactly.
        expect(rule!.lengthExpression.evaluate(_variables), 976.0);
        expect(rule.quantity.fixedCount, 2);
      }
    });

    test('ouvrant MONTANTS yield TWO H−43.5 pieces per side placement '
        '(1456.5 mm)', () {
      for (final role in [ProfileUsageRole.left, ProfileUsageRole.right]) {
        final rule = sepSerie4200RuleSet.select(
          _context('4219', vantauxCount: 2, role: role),
        );
        expect(rule, isNotNull, reason: role.toString());
        expect(rule!.lengthExpression.evaluate(_variables), 1456.5);
        expect(rule.quantity.fixedCount, 2);
      }
    });

    test('battue centrale 4206 intermediate placement cuts at H−102 '
        '(1398), square cut, one piece', () {
      final rule = sepSerie4200RuleSet.select(
        _context('4206', vantauxCount: 2, role: ProfileUsageRole.intermediate),
      );
      expect(rule, isNotNull);
      expect(rule!.lengthExpression.evaluate(_variables), 1398.0);
      expect(rule.angles.start, 90);
      expect(rule.quantity.fixedCount, 1);
    });

    test('4206 at edge roles stays unmatched (battue centrale sits '
        'between the leaves)', () {
      for (final role in [
        ProfileUsageRole.left,
        ProfileUsageRole.right,
        ProfileUsageRole.top,
        ProfileUsageRole.bottom,
      ]) {
        expect(
          sepSerie4200RuleSet.select(
            _context('4206', vantauxCount: 2, role: role),
          ),
          isNull,
        );
      }
    });

    test('traverse intermédiaire options are NOT encoded (cross-usage '
        'dependency on the sibling ouvrant -- ledger blocker)', () {
      for (final reference in ['2656', '4405', '4413']) {
        expect(
          sepSerie4200RuleSet.select(
            _context(reference, vantauxCount: 2, role: ProfileUsageRole.intermediate),
          ),
          isNull,
          reason: '$reference has no encodable OF traverse rule',
        );
      }
    });
  });

  group('routing safety: uncovered configurations never match', () {
    test('non-française opening types match nothing -- OB/Soufflet/'
        'Projeté tables are deliberately unencoded', () {
      for (final openingType in [
        OpeningType.oscilloBattant,
        OpeningType.anglaise,
        OpeningType.coulissante,
      ]) {
        for (final vantauxCount in [1, 2]) {
          expect(
            sepSerie4200RuleSet.select(
              _context(
                '4220',
                openingType: openingType,
                vantauxCount: vantauxCount,
                role: ProfileUsageRole.top,
              ),
            ),
            isNull,
            reason: '$openingType at $vantauxCount vantaux has no encoded '
                'débitage family',
          );
        }
      }
    });

    test('vantauxCount outside the encoded columns matches nothing', () {
      for (final vantauxCount in [3, 4]) {
        expect(
          sepSerie4200RuleSet.select(
            _context(
              '4220',
              vantauxCount: vantauxCount,
              role: ProfileUsageRole.top,
            ),
          ),
          isNull,
        );
      }
    });

    test('profiles without débitage rows stay unmatched (parcloses, '
        'complémentaires, renforcées)', () {
      for (final entry in [
        ('4464', ProfileUsageRole.intermediate),
        ('4251', ProfileUsageRole.intermediate),
        ('4243', ProfileUsageRole.intermediate),
        ('412', ProfileUsageRole.left),
      ]) {
        expect(
          sepSerie4200RuleSet.select(
            _context(entry.$1, vantauxCount: 2, role: entry.$2),
          ),
          isNull,
          reason: '${entry.$1} has no encoded débitage row',
        );
      }
    });

    test('missing section fails closed', () {
      final context = CalculationContext(
        construction: _construction(),
        profile: sepSerie4200.profilesById.values
            .firstWhere((p) => p.reference == '4220'),
        section: null,
        usage: ProfileUsage(
          id: 'u1',
          profileId: 'builtin-sepalumic-4200-4220',
          sectionId: 'gone',
          role: ProfileUsageRole.top,
        ),
      );
      expect(sepSerie4200RuleSet.select(context), isNull);
    });

    test('exhaustive sweep: no context ever selects ambiguously', () {
      for (final profile in sepSerie4200.profiles) {
        for (final role in ProfileUsageRole.values) {
          for (final kind in SectionKind.values) {
            for (final openingType in OpeningType.values) {
              for (final vantauxCount in [1, 2, 3]) {
                final isOuvrant = kind == SectionKind.ouvrant;
                expect(
                  () => sepSerie4200RuleSet.select(
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
    test('every rule cites the catalogue series + edition', () {
      for (final rule in sepSerie4200RuleSet.rules) {
        expect(rule.description, isNotNull);
        expect(rule.description, contains('4200'));
        expect(rule.description, contains('éd. 05'));
      }
    });
  });
}
