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

    test('dormants outside any documented débitage row stay unmatched',
        () {
      // Frappé dormants and mono-rail/coulisse dormants are not named by
      // any p. 24 row.
      for (final reference in ['14 818', '14 820', '14 640', '14 637']) {
        expect(
          meSerie14600RuleSet.select(_context(reference, role: ProfileUsageRole.top)),
          isNull,
          reason: '$reference has no encoded débitage row',
        );
      }
    });
  });

  group(
    'routing: dormant 14 618/14 628/14 626 — 2+2 × (L+46 ; H+46) [p. 24]',
    () {
      test('top and bottom placements cut to L+46 (2046 mm), one piece each',
          () {
        for (final role in [ProfileUsageRole.top, ProfileUsageRole.bottom]) {
          for (final reference in ['14 618', '14 628', '14 626']) {
            final rule = meSerie14600RuleSet.select(
              _context(reference, role: role),
            );
            expect(rule, isNotNull, reason: '$reference $role must match');
            expect(
              rule!.lengthExpression.evaluate(_variables),
              2046.0,
              reason: '$reference $role cuts at L+46',
            );
            expect(rule.quantity.fixedCount, 1);
          }
        }
      });

      test('left and right placements cut to H+46 (1546 mm), one piece each',
          () {
        for (final role in [ProfileUsageRole.left, ProfileUsageRole.right]) {
          for (final reference in ['14 618', '14 628', '14 626']) {
            final rule = meSerie14600RuleSet.select(
              _context(reference, role: role),
            );
            expect(rule, isNotNull, reason: '$reference $role must match');
            expect(
              rule!.lengthExpression.evaluate(_variables),
              1546.0,
              reason: '$reference $role cuts at H+46',
            );
            expect(rule.quantity.fixedCount, 1);
          }
        }
      });

      test('intermediate role stays unmatched for +46 dormants (no '
          'documented position between the leaves)', () {
        expect(
          meSerie14600RuleSet.select(
            _context('14 618', role: ProfileUsageRole.intermediate),
          ),
          isNull,
        );
      });
    },
  );

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

      test('intermediate role stays unmatched for lateral montants '
          '(central members are ProfileType.mullion, routed separately)',
          () {
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

    test('traverse 14 631 routes to its own rule, not the 14 621 rule '
        '(different deductions)', () {
      final context = _context('14 631', role: ProfileUsageRole.top);
      final rule = meSerie14600RuleSet.select(context);
      expect(rule, isNotNull);
      expect(rule!.description, contains('14 631'));
      expect(rule.description, isNot(contains('14 621')));
    });
  });

  group('routing: traverse 14 631 — 4 × (L−85)/2 [p. 24]', () {
    test('top/bottom placements yield two (L−85)/2 pieces each (957.5 mm)',
        () {
      for (final role in [ProfileUsageRole.top, ProfileUsageRole.bottom]) {
        final rule = meSerie14600RuleSet.select(
          _context('14 631', role: role),
        );
        expect(rule, isNotNull, reason: 'traverse $role must match');
        expect(
          rule!.lengthExpression.evaluate(_variables),
          957.5,
          reason: '(2000−85)/2 = 957.5',
        );
        // Same placement mapping as 14 621: one placement spans both
        // leaves' track halves.
        expect(rule.quantity.fixedCount, 2);
      }
    });

    test('description records the documented pairing (69.2-face montants)',
        () {
      final rule = meSerie14600RuleSet.select(
        _context('14 631', role: ProfileUsageRole.top),
      )!;
      expect(rule.description, contains('face 69.2'));
    });

    test('traverse at edge roles stays unmatched (no documented vertical '
        'traverse position)', () {
      for (final role in [
        ProfileUsageRole.left,
        ProfileUsageRole.right,
      ]) {
        for (final reference in ['14 621', '14 631']) {
          expect(
            meSerie14600RuleSet.select(_context(reference, role: role)),
            isNull,
            reason: '$reference $role has no documented débitage entry',
          );
        }
      }
    });
  });

  group(
    'routing: montant central 14 619/620/630 — 2 × (H−74), intermediate '
    '[p. 24]',
    () {
      test('intermediate placement yields two H−74 pieces (1426 mm)', () {
        for (final reference in ['14 619', '14 620', '14 630']) {
          final rule = meSerie14600RuleSet.select(
            _context(reference, role: ProfileUsageRole.intermediate),
          );
          expect(rule, isNotNull, reason: '$reference must match');
          expect(
            rule!.lengthExpression.evaluate(_variables),
            1426.0,
            reason: '$reference cuts at H−74',
          );
          // One intermediate placement covers BOTH leaves' meeting
          // stile -- the documented pair.
          expect(rule.quantity.fixedCount, 2);
        }
      });

      test('mullions at edge roles stay unmatched (only intermediate '
          'fits members between the leaves)', () {
        for (final role in [
          ProfileUsageRole.left,
          ProfileUsageRole.right,
          ProfileUsageRole.top,
          ProfileUsageRole.bottom,
        ]) {
          expect(
            meSerie14600RuleSet.select(
              _context('14 619', role: role),
            ),
            isNull,
            reason: 'mullion $role has no documented position',
          );
        }
      });

      test('mullions not named by the débitage row stay unmatched '
          '(14 650 / 14 643)', () {
        for (final reference in ['14 650', '14 643']) {
          expect(
            meSerie14600RuleSet.select(
              _context(reference, role: ProfileUsageRole.intermediate),
            ),
            isNull,
            reason: '$reference is not part of the p. 24 central-mullion '
                'row',
          );
        }
      });
    },
  );

  group(
    'routing: 3 vantaux (avec fixe) column — traverses 6 × (L−25)/3 and '
    '6 × (L−47)/3 [p. 24]',
    () {
      test('traverse 14 621 top/bottom yield three (L−25)/3 pieces each',
          () {
        for (final role in [ProfileUsageRole.top, ProfileUsageRole.bottom]) {
          final rule = meSerie14600RuleSet.select(
            _context('14 621', vantauxCount: 3, role: role),
          );
          expect(rule, isNotNull, reason: 'traverse $role must match');
          // (2000−25)/3 -- repeating decimal; assert via identical
          // computation so the IEEE-754 value matches exactly.
          expect(
            rule!.lengthExpression.evaluate(_variables),
            (2000 - 25) / 3,
            reason: '(2000−25)/3 = 658.333… at three panels per track',
          );
          // One placement spans ALL THREE panels' track thirds.
          expect(rule.quantity.fixedCount, 3);
          // Column provenance: the description names the 3-vantaux row.
          expect(rule.description, contains('3 vantaux'));
        }
      });

      test('traverse 14 631 top/bottom yield three (L−47)/3 pieces each '
          '(exactly 651 mm)', () {
        for (final role in [ProfileUsageRole.top, ProfileUsageRole.bottom]) {
          final rule = meSerie14600RuleSet.select(
            _context('14 631', vantauxCount: 3, role: role),
          );
          expect(rule, isNotNull, reason: 'traverse $role must match');
          expect(
            rule!.lengthExpression.evaluate(_variables),
            651.0,
            reason: '(2000−47)/3 = 651 exactly',
          );
          expect(rule.quantity.fixedCount, 3);
        }
      });

      test('2v traverse rules never fire at 3 vantaux (and vice versa)',
          () {
        final top = meSerie14600RuleSet.select(
          _context('14 621', vantauxCount: 3, role: ProfileUsageRole.top),
        )!;
        expect(top.description, contains('(L−25)/3'));
        expect(top.description, isNot(contains('(L−64)/2')));
      });
    },
  );

  group(
    'routing: 3 vantaux — dormant / montant / mullion rows duplicate the '
    '2v formulas under exact-column gating [p. 24]',
    () {
      test('dormants cut to L and H, one piece per placement', () {
        for (final reference in ['14 617', '14 627']) {
          final topRule = meSerie14600RuleSet.select(
            _context(reference, vantauxCount: 3, role: ProfileUsageRole.top),
          );
          expect(
            topRule!.lengthExpression.evaluate(_variables),
            2000.0,
            reason: '$reference top cuts at L',
          );
          final leftRule = meSerie14600RuleSet.select(
            _context(reference, vantauxCount: 3, role: ProfileUsageRole.left),
          );
          expect(
            leftRule!.lengthExpression.evaluate(_variables),
            1500.0,
            reason: '$reference left cuts at H',
          );
          expect(leftRule.quantity.fixedCount, 1);
          expect(leftRule.description, contains('3 vantaux'));
        }
      });

      test('+46 dormants cut to L+46 and H+46', () {
        for (final reference in ['14 618', '14 628', '14 626']) {
          final topRule = meSerie14600RuleSet.select(
            _context(reference, vantauxCount: 3, role: ProfileUsageRole.top),
          );
          expect(
            topRule!.lengthExpression.evaluate(_variables),
            2046.0,
            reason: '$reference top cuts at L+46',
          );
          final rightRule = meSerie14600RuleSet.select(
            _context(reference, vantauxCount: 3, role: ProfileUsageRole.right),
          );
          expect(
            rightRule!.lengthExpression.evaluate(_variables),
            1546.0,
            reason: '$reference right cuts at H+46',
          );
          expect(rightRule.description, contains('double équerre'));
        }
      });

      test('montants latéraux left/right cut to H−74 (1426), fixed(1)',
          () {
        for (final role in [ProfileUsageRole.left, ProfileUsageRole.right]) {
          for (final reference in ['14 622', '14 623', '14 632', '14 633']) {
            final rule = meSerie14600RuleSet.select(
              _context(reference, vantauxCount: 3, role: role),
            );
            expect(rule, isNotNull, reason: '$reference $role must match');
            expect(
              rule!.lengthExpression.evaluate(_variables),
              1426.0,
            );
            expect(rule.quantity.fixedCount, 1);
          }
        }
      });

      test('central mullion intermediate placement yields two H−74 pieces',
          () {
        for (final reference in ['14 619', '14 620', '14 630']) {
          final rule = meSerie14600RuleSet.select(
            _context(reference, vantauxCount: 3, role: ProfileUsageRole.intermediate),
          );
          expect(rule, isNotNull, reason: '$reference must match');
          expect(rule!.lengthExpression.evaluate(_variables), 1426.0);
          expect(rule.quantity.fixedCount, 2);
        }
      });

      test('roles without a documented position stay unmatched at 3 '
          'vantaux', () {
        // Mullions at edge/track roles; latéral intermediate; dormant
        // intermediate; traverse edge roles.
        expect(
          meSerie14600RuleSet.select(
            _context('14 619', vantauxCount: 3, role: ProfileUsageRole.left),
          ),
          isNull,
        );
        expect(
          meSerie14600RuleSet.select(
            _context('14 622', vantauxCount: 3, role: ProfileUsageRole.intermediate),
          ),
          isNull,
        );
        expect(
          meSerie14600RuleSet.select(
            _context('14 617', vantauxCount: 3, role: ProfileUsageRole.intermediate),
          ),
          isNull,
        );
        expect(
          meSerie14600RuleSet.select(
            _context('14 631', vantauxCount: 3, role: ProfileUsageRole.left),
          ),
          isNull,
        );
      });

      test('profiles outside any documented row stay unmatched at 3 '
          'vantaux', () {
        for (final entry in [
          ('14 818', ProfileUsageRole.top),
          ('14 650', ProfileUsageRole.intermediate),
          ('14 643', ProfileUsageRole.intermediate),
        ]) {
          expect(
            meSerie14600RuleSet.select(
              _context(entry.$1, vantauxCount: 3, role: entry.$2),
            ),
            isNull,
            reason: '${entry.$1} has no p. 24 débitage row',
          );
        }
      });
    },
  );

  group('routing safety: uncovered configurations never match', () {
    test('vantauxCount outside the encoded columns (1 and 4) matches '
        'nothing', () {
      for (final vantauxCount in [1, 4]) {
        for (final reference in ['14 617', '14 622', '14 621', '14 631', '14 619']) {
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

    test('a non-coulissante section matches nothing at either encoded '
        'vantaux count -- the source is a coulissant-only descriptif', () {
      for (final vantauxCount in [2, 3]) {
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
              vantauxCount: vantauxCount,
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
                '$openingType at $vantauxCount vantaux is covered by no '
                'page of the document; it must not receive real cuts',
          );
        }
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
          for (final vantauxCount in [0, 1, 2, 3]) {
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
