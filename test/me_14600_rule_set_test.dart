import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/data/builtin_catalog_seed.dart';
import 'package:aluminium_designer/core/data/me_14600_rule_set.dart';
import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/layout_direction.dart';
import 'package:aluminium_designer/core/models/opening.dart';
import 'package:aluminium_designer/core/models/profile_usage.dart';
import 'package:aluminium_designer/core/models/rules/dimension_expression.dart';
import 'package:aluminium_designer/core/models/rules/rule_condition.dart';
import 'package:aluminium_designer/core/models/section.dart';

/// Contexts are built from the REAL seeded profiles so the tests also pin
/// the rule set's reference strings to the seed's actual `Profile.reference`
/// values ('14 617', not '14617' etc.) -- a typo in either would fail here.
Construction _construction() => Construction(
  id: 'c1',
  name: 'Test',
  type: ConstructionType.window,
  width: 2000,
  height: 1500,
  manufacturer: 'Maghreb Extrusion (ME)',
  system: 'Série 14600 Coulissant',
  sections: const [],
  layoutDirection: SectionLayoutDirection.horizontal,
  profiles: const [],
);

Section _section({required int vantauxCount}) => Section(
  id: 's1',
  order: 0,
  kind: SectionKind.ouvrant,
  width: 2000,
  height: 1500,
  openingType: OpeningType.coulissante,
  vantauxCount: vantauxCount,
);

CalculationContext _context(
  String reference, {
  int vantauxCount = 2,
  ProfileUsageRole? role,
}) {
  final profile = meSerie14600.profilesById.values
      .firstWhere((p) => p.reference == reference);
  return CalculationContext(
    construction: _construction(),
    profile: profile,
    section: _section(vantauxCount: vantauxCount),
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
  group('meSerie14600RuleSet metadata', () {
    test('is the real (non-placeholder) rule set of the seeded system', () {
      expect(meSerie14600RuleSet.systemId, meSerie14600Id);
      expect(meSerie14600RuleSet.isPlaceholder, isFalse);
      expect(meSerie14600RuleSet.rules, isNotEmpty);
    });
  });

  group('routing: dormant 14 617 / 14 627 — 2+2 × (L ; H) [p. 24]', () {
    test('top and bottom placements cut to L (2000 mm), one piece each',
        () {
      for (final role in [ProfileUsageRole.top, ProfileUsageRole.bottom]) {
        for (final reference in ['14 617', '14 627']) {
          final rule = meSerie14600RuleSet.select(
            _context(reference, role: role),
          );
          expect(rule, isNotNull, reason: '$reference $role must match');
          expect(
            rule!.lengthExpression.evaluate(_variables),
            2000.0,
            reason: '$reference $role cuts at L',
          );
          expect(rule.quantity.fixedCount, 1);
        }
      }
    });

    test('left and right placements cut to H (1500 mm), one piece each',
        () {
      for (final role in [ProfileUsageRole.left, ProfileUsageRole.right]) {
        for (final reference in ['14 617', '14 627']) {
          final rule = meSerie14600RuleSet.select(
            _context(reference, role: role),
          );
          expect(rule, isNotNull, reason: '$reference $role must match');
          expect(
            rule!.lengthExpression.evaluate(_variables),
            1500.0,
            reason: '$reference $role cuts at H',
          );
          expect(rule.quantity.fixedCount, 1);
        }
      }
    });

    test('other dormants stay unmatched (no +46 row encoded)', () {
      for (final reference in ['14 618', '14 628', '14 626', '14 818']) {
        expect(
          meSerie14600RuleSet.select(_context(reference, role: ProfileUsageRole.top)),
          isNull,
          reason: '$reference has no encoded débitage row yet',
        );
      }
    });
  });

  group(
    'routing: montant latéral 14 622/623/632/633 — 2 × (H−74) [p. 24]',
    () {
      test('left and right placements cut to H−74 (1426 mm)', () {
        for (final role in [ProfileUsageRole.left, ProfileUsageRole.right]) {
          for (final reference in ['14 622', '14 623', '14 632', '14 633']) {
            final rule = meSerie14600RuleSet.select(
              _context(reference, role: role),
            );
            expect(rule, isNotNull, reason: '$reference $role must match');
            expect(
              rule!.lengthExpression.evaluate(_variables),
              1426.0,
              reason: '$reference $role cuts at H−74',
            );
            expect(rule.quantity.fixedCount, 1);
          }
        }
      });

      test('intermediate role stays unmatched (central montants are '
          'mullions with their own unencoded row)', () {
        expect(
          meSerie14600RuleSet.select(
            _context('14 622', role: ProfileUsageRole.intermediate),
          ),
          isNull,
        );
      });
    },
  );

  group('routing: traverse 14 621 — 4 × (L−64)/2 [p. 24]', () {
    test('top/bottom placements yield two (L−64)/2 pieces each (968 mm)',
        () {
      for (final role in [ProfileUsageRole.top, ProfileUsageRole.bottom]) {
        final rule = meSerie14600RuleSet.select(
          _context('14 621', role: role),
        );
        expect(rule, isNotNull, reason: 'traverse $role must match');
        expect(
          rule!.lengthExpression.evaluate(_variables),
          968.0,
          reason: '(2000−64)/2 = 968',
        );
        // One placement spans both leaves' track halves.
        expect(rule.quantity.fixedCount, 2);
      }
    });

    test('traverse 14 631 stays unmatched (different deductions)', () {
      expect(
        meSerie14600RuleSet.select(
          _context('14 631', role: ProfileUsageRole.top),
        ),
        isNull,
        reason: '14 631 is (L−85)/2 on p. 24 -- encoding it here would '
            'fabricate wrong cuts; its rules are future work',
      );
    });
  });

  group('routing safety: uncovered configurations never match', () {
    test('vantauxCount other than 2 matches nothing (only the 2-vantaux '
        'column is encoded)', () {
      for (final vantauxCount in [1, 3, 4]) {
        for (final reference in ['14 617', '14 622', '14 621']) {
          expect(
            meSerie14600RuleSet.select(
              _context(
                reference,
                vantauxCount: vantauxCount,
                role: ProfileUsageRole.top,
              ),
            ),
            isNull,
            reason: '$reference at $vantauxCount vantaux is not documented '
                'by this rule set',
          );
        }
      }
    });

    test('a non-coulissante 2-vantaux section matches nothing -- the '
        'source is a coulissant-only descriptif', () {
      for (final openingType in [
        OpeningType.oscilloBattant,
        OpeningType.francaise,
        OpeningType.anglaise,
      ]) {
        final context = CalculationContext(
          construction: _construction(),
          profile: meSerie14600.profilesById.values
              .firstWhere((p) => p.reference == '14 617'),
          section: Section(
            id: 's1',
            order: 0,
            kind: SectionKind.ouvrant,
            width: 2000,
            height: 1500,
            openingType: openingType,
            vantauxCount: 2,
          ),
          usage: ProfileUsage(
            id: 'u1',
            profileId: 'builtin-me-14600-14617',
            sectionId: 's1',
            role: ProfileUsageRole.top,
          ),
        );
        expect(
          meSerie14600RuleSet.select(context),
          isNull,
          reason:
              '$openingType at 2 vantaux is covered by no page of the '
              'document; it must not receive real cuts',
        );
      }
    });

    test('missing section fails closed', () {
      final context = CalculationContext(
        construction: _construction(),
        profile: meSerie14600.profilesById.values
            .firstWhere((p) => p.reference == '14 617'),
        section: null,
        usage: ProfileUsage(
          id: 'u1',
          profileId: 'builtin-me-14600-14617',
          sectionId: 'gone',
          role: ProfileUsageRole.top,
        ),
      );
      expect(meSerie14600RuleSet.select(context), isNull);
    });

    test('exhaustive sweep: no context ever selects ambiguously', () {
      // select() throws AmbiguousRuleMatchException on equal-specificity
      // ties; running every seeded profile x every role x the relevant
      // vantaux counts x opening types proves the rule conditions
      // partition contexts disjointly.
      for (final profile in meSerie14600.profiles) {
        for (final role in ProfileUsageRole.values) {
          for (final vantauxCount in [0, 1, 2]) {
            for (final openingType in OpeningType.values) {
              expect(
                () => meSerie14600RuleSet.select(
                  CalculationContext(
                    construction: _construction(),
                    profile: profile,
                    section: Section(
                      id: 's',
                      order: 0,
                      kind: vantauxCount == 0
                          ? SectionKind.fixed
                          : SectionKind.ouvrant,
                      width: 2000,
                      height: 1500,
                      openingType: vantauxCount == 0 ? null : openingType,
                      vantauxCount: vantauxCount,
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
                    '${profile.reference} $role vantaux=$vantauxCount '
                    '$openingType must resolve to zero-or-one rules '
                    'without ambiguity',
              );
            }
          }
        }
      }
    });
  });

  group('expression edge behaviour', () {
    test('dimensions below the deductions evaluate arithmetically -- '
        'no clamping is invented', () {
      // The source states no minimum dimensions and no clamping rule, so
      // the engine must not invent one here (domain law: absence =
      // unknown). A 500 mm unit still yields (500−64)/2 = 218; a 50 mm
      // unit yields a negative number, which is a nonsense-input signal
      // rather than a fabricated cut. Documented guardrails are the
      // ADVISORY p. 27 dimension envelopes in the system metadata, not a
      // calculator clamp.
      final rule = meSerie14600RuleSet.select(
        _context('14 621', role: ProfileUsageRole.top),
      )!;
      expect(
        rule.lengthExpression.evaluate({
          DimensionVariable.constructionWidth: 500,
          DimensionVariable.constructionHeight: 1500,
        }),
        218.0,
      );
      expect(
        rule.lengthExpression.evaluate({
          DimensionVariable.constructionWidth: 50,
          DimensionVariable.constructionHeight: 1500,
        }),
        -7.0,
      );
    });
  });

  group('rule provenance descriptions', () {
    test('every rule cites the source table page', () {
      for (final rule in meSerie14600RuleSet.rules) {
        expect(rule.description, isNotNull);
        expect(rule.description, contains('p. 24'));
      }
    });

    test('every rule marks its angles as derived, not stated on p. 24',
        () {
      for (final rule in meSerie14600RuleSet.rules) {
        expect(rule.description, contains('angles dérivés pp. 1-3'));
      }
    });
  });
}
