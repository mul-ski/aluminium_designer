import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/engine/construction_calculator.dart';
import 'package:aluminium_designer/core/models/calculation_outcome.dart';
import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/layout_direction.dart';
import 'package:aluminium_designer/core/models/opening.dart';
import 'package:aluminium_designer/core/models/profile.dart';
import 'package:aluminium_designer/core/models/profile_usage.dart';
import 'package:aluminium_designer/core/models/rules/calculation_rule.dart';
import 'package:aluminium_designer/core/models/rules/dimension_expression.dart';
import 'package:aluminium_designer/core/models/rules/rule_condition.dart';
import 'package:aluminium_designer/core/models/rules/system_rule_set.dart';
import 'package:aluminium_designer/core/models/section.dart';

/// Companion-profile dependency engine capability (C8 commit A): unit
/// semantics of [CompanionProfileReferenceCondition], its interplay with
/// `SystemRuleSet.select`, and the sibling derivation performed by
/// `ConstructionCalculator.calculate`.
///
/// Source requirement on record: Sepalumic 4200 OF traverse-option
/// débitage keyed by the sibling ouvrant reference (E070/E090/E110/E130,
/// docs/VERIFIED_SOURCES.md M-2); ME 14800 frappe parclose rows keyed by
/// the sibling ouvrant ref (Catalogue Général p. 65).
Profile _profile(
  String reference, {
  ProfileType type = ProfileType.ouvrant,
  String? id,
}) =>
    Profile(
      id: id ?? 'p-$reference',
      manufacturer: 'Test Manufacturer',
      system: 'Test System',
      reference: reference,
      name: 'Profile $reference',
      type: type,
      width: 40,
      depth: 60,
      weightPerMeter: 1.2,
    );

Section _section(
  String id, {
  SectionKind kind = SectionKind.ouvrant,
  OpeningType? openingType = OpeningType.francaise,
  int vantauxCount = 1,
}) =>
    Section(
      id: id,
      order: 0,
      kind: kind,
      width: 2000,
      height: 1500,
      openingType: openingType,
      vantauxCount: vantauxCount,
    );

ProfileUsage _usage(
  String id,
  String profileId, {
  String sectionId = 's1',
  ProfileUsageRole role = ProfileUsageRole.left,
}) =>
    ProfileUsage(
      id: id,
      profileId: profileId,
      sectionId: sectionId,
      role: role,
    );

Construction _construction({
  required List<Section> sections,
  required List<ProfileUsage> profileUsages,
}) =>
    Construction(
      id: 'c-companion',
      name: 'Companion test',
      type: ConstructionType.window,
      width: 2000,
      height: 1500,
      manufacturer: 'Test Manufacturer',
      system: 'Test System',
      sections: sections,
      layoutDirection: SectionLayoutDirection.horizontal,
      profiles: const [],
      profileUsages: profileUsages,
    );

/// Context for the evaluated traverse usage in section s1, with [siblings]
/// as its derived section siblings (what the calculator would pass).
CalculationContext _context({
  List<SectionSibling> siblings = const [],
  ProfileUsageRole role = ProfileUsageRole.intermediate,
  Section? section,
}) {
  final evaluated = _usage(
    'eval',
    'p-2656',
    role: role,
  );
  return CalculationContext(
    construction: _construction(
      sections: [section ?? _section('s1')],
      profileUsages: [evaluated],
    ),
    profile: _profile('2656', type: ProfileType.traverse),
    section: section ?? _section('s1'),
    usage: evaluated,
    siblings: siblings,
  );
}

SectionSibling _sibling(
  String reference, {
  ProfileType type = ProfileType.ouvrant,
  ProfileUsageRole role = ProfileUsageRole.left,
  String? id,
}) =>
    SectionSibling(
      usage: _usage(id ?? 'sib-$reference-$role', 'p-$reference', role: role),
      profile: _profile(reference, type: type),
    );

void main() {
  group('CompanionProfileReferenceCondition semantics', () {
    test('matches when a sash-carrier sibling carries a required reference',
        () {
      final condition = CompanionProfileReferenceCondition({'4211'});
      expect(
        condition.matches(
          _context(siblings: [_sibling('4211', role: ProfileUsageRole.top)]),
        ),
        isTrue,
      );
    });

    test('does not match when the carrier reference differs', () {
      final condition = CompanionProfileReferenceCondition({'4244'});
      expect(
        condition.matches(_context(siblings: [_sibling('4211')])),
        isFalse,
      );
    });

    test('universal over the carrier class: mixed sash references match '
        'nothing', () {
      final condition = CompanionProfileReferenceCondition({'4211'});
      expect(
        condition.matches(_context(siblings: [
          _sibling('4211', role: ProfileUsageRole.left),
          _sibling('4219', role: ProfileUsageRole.right),
        ])),
        isFalse,
      );
    });

    test('a multi-reference set accepts any consistent identity from it', () {
      final condition = CompanionProfileReferenceCondition({'4405', '4413'});
      expect(
        condition.matches(_context(siblings: [
          _sibling('4413', role: ProfileUsageRole.left),
          _sibling('4413', role: ProfileUsageRole.right),
        ])),
        isTrue,
      );
      expect(
        condition.matches(_context(siblings: [
          _sibling('4413', role: ProfileUsageRole.left),
          _sibling('4405', role: ProfileUsageRole.right),
        ])),
        isTrue,
      );
    });

    test('duplicate carriers all matching are fine (2v: four stiles)', () {
      final condition = CompanionProfileReferenceCondition({'4211'});
      expect(
        condition.matches(_context(siblings: [
          _sibling('4211', role: ProfileUsageRole.top),
          _sibling('4211', role: ProfileUsageRole.bottom),
          _sibling('4211', role: ProfileUsageRole.left),
          _sibling('4211', role: ProfileUsageRole.right),
        ])),
        isTrue,
      );
    });

    test('an ouvrant-typed sibling in the intermediate slot is NOT a '
        'carrier (battue coexistence)', () {
      final condition = CompanionProfileReferenceCondition({'4206'});
      expect(
        condition.matches(
          _context(siblings: [
            _sibling('4206', role: ProfileUsageRole.intermediate),
          ]),
        ),
        isFalse,
      );
      // ...and a battue sibling does not disturb a real carrier match.
      final realCarrier = CompanionProfileReferenceCondition({'4211'});
      expect(
        realCarrier.matches(_context(siblings: [
          _sibling('4211', role: ProfileUsageRole.left),
          _sibling('4206', role: ProfileUsageRole.intermediate),
        ])),
        isTrue,
      );
    });

    test('non-ouvrant siblings are never carriers, whatever their '
        'reference', () {
      final condition =
          CompanionProfileReferenceCondition({'4220', '2656'});
      expect(
        condition.matches(_context(siblings: [
          _sibling('4220', type: ProfileType.dormant),
          _sibling('2656', type: ProfileType.traverse),
        ])),
        isFalse,
      );
    });

    test('fails closed with no usage, no section, or no siblings', () {
      final condition = CompanionProfileReferenceCondition({'4211'});
      final bare = CalculationContext(
        construction: _construction(
          sections: [_section('s1')],
          profileUsages: const [],
        ),
        profile: _profile('2656', type: ProfileType.traverse),
      );
      expect(condition.matches(bare), isFalse);

      final noSection = CalculationContext(
        construction: _construction(
          sections: [_section('s1')],
          profileUsages: const [],
        ),
        profile: _profile('2656', type: ProfileType.traverse),
        usage: _usage('eval', 'p-2656'),
        siblings: [_sibling('4211')],
      );
      expect(condition.matches(noSection), isFalse);

      expect(condition.matches(_context(siblings: const [])), isFalse);
    });

    test('an empty reference set matches nothing', () {
      expect(
        CompanionProfileReferenceCondition(const {})
            .matches(_context(siblings: [_sibling('4211')])),
        isFalse,
      );
    });

    test('exact reference equality: a longer reference is not a match',
        () {
      final condition = CompanionProfileReferenceCondition({'4211'});
      expect(
        condition.matches(_context(siblings: [
          _sibling('42119'),
        ])),
        isFalse,
      );
    });
  });

  group('companion-gated rule selection', () {
    SystemRuleSet twoCompanionRules() => SystemRuleSet(
          systemId: 'test',
          name: 'test',
          isPlaceholder: false,
          rules: [
            ProfileCalculationRule(
              appliesTo: ProfileType.traverse,
              conditions: [
                CompanionProfileReferenceCondition({'4211'}),
              ],
              lengthExpression: const ConstantExpression(117),
              quantity: const CutQuantity.fixed(1),
              angles: const CutAngles.square(),
              isPlaceholder: false,
              description: 'beside 4211',
            ),
            ProfileCalculationRule(
              appliesTo: ProfileType.traverse,
              conditions: [
                CompanionProfileReferenceCondition({'4219'}),
              ],
              lengthExpression: const ConstantExpression(141),
              quantity: const CutQuantity.fixed(1),
              angles: const CutAngles.square(),
              isPlaceholder: false,
              description: 'beside 4219',
            ),
          ],
        );

    test('selects the rule whose companion identity the section carries',
        () {
      final ruleSet = twoCompanionRules();
      final rule = ruleSet.select(
        _context(siblings: [_sibling('4219')]),
      );
      expect(rule, isNotNull);
      expect(rule!.lengthExpression.evaluate(const {}), 141);
    });

    test('a mixed-sash section matches NO rule and does not throw', () {
      final ruleSet = twoCompanionRules();
      final rule = ruleSet.select(
        _context(siblings: [
          _sibling('4211', role: ProfileUsageRole.left),
          _sibling('4219', role: ProfileUsageRole.right),
        ]),
      );
      expect(rule, isNull);
    });

    test('an undocumented companion matches no rule', () {
      expect(
        twoCompanionRules()
            .select(_context(siblings: [_sibling('4244')])),
        isNull,
      );
    });
  });

  group('ConstructionCalculator sibling derivation', () {
    ProfileCalculationRule companionRule() => ProfileCalculationRule(
          appliesTo: ProfileType.traverse,
          conditions: [
            CompanionProfileReferenceCondition({'4211'}),
          ],
          lengthExpression: const ConstantExpression(117),
          quantity: const CutQuantity.fixed(1),
          angles: const CutAngles.square(),
          isPlaceholder: false,
          description: 'traverse beside 4211',
        );

    test('siblings are scoped to the evaluated usage\'s section', () {
      final construction = _construction(
        sections: [
          _section('s1'),
          _section(
            's2',
            kind: SectionKind.fixed,
            openingType: null,
            vantauxCount: 0,
          ),
        ],
        profileUsages: [
          _usage('t', 'p-2656', sectionId: 's1',
              role: ProfileUsageRole.intermediate),
          // Carrier lives in ANOTHER section -- must stay invisible.
          _usage('far', 'p-4211', sectionId: 's2'),
        ],
      );
      final outcome = ConstructionCalculator(
        ruleSet: SystemRuleSet(
          systemId: 'test',
          name: 'test',
          isPlaceholder: false,
          rules: [companionRule()],
        ),
      ).calculate(construction, profilesById: {
        'p-2656': _profile('2656', type: ProfileType.traverse),
        'p-4211': _profile('4211'),
      });

      expect(outcome.cuts, isEmpty);
      final reasons = {
        for (final issue in outcome.issues) issue.profileUsageId: issue.reason,
      };
      expect(reasons, hasLength(2));
      expect(reasons['t'], ProfileUsageIssueReason.noRuleMatched);
      // The far-section stile has no rule of its own in this synthetic
      // set -- its skip is independent of the companion outcome.
      expect(reasons['far'], ProfileUsageIssueReason.noRuleMatched);
    });

    test('a carrier in the same section produces the companion cut', () {
      final construction = _construction(
        sections: [_section('s1')],
        profileUsages: [
          _usage('t', 'p-2656', role: ProfileUsageRole.intermediate),
          _usage('stile', 'p-4211', role: ProfileUsageRole.left),
        ],
      );
      final outcome = ConstructionCalculator(
        ruleSet: SystemRuleSet(
          systemId: 'test',
          name: 'test',
          isPlaceholder: false,
          rules: [companionRule()],
        ),
      ).calculate(construction, profilesById: {
        'p-2656': _profile('2656', type: ProfileType.traverse),
        'p-4211': _profile('4211'),
      });

      expect(outcome.cuts, hasLength(1));
      expect(outcome.cuts.single.profileUsageId, 't');
      expect(outcome.cuts.single.length, 117);
      // The stile itself has no rule in this synthetic set; its skip is
      // reported and does not affect the companion-gated cut.
      final reasons = {
        for (final issue in outcome.issues) issue.profileUsageId: issue.reason,
      };
      expect(reasons['stile'], ProfileUsageIssueReason.noRuleMatched);
      expect(reasons.containsKey('t'), isFalse);
    });

    test('a lone carrier does not satisfy its own companion gate '
        '(self-exclusion)', () {
      final loneCarrierRule = ProfileCalculationRule(
        appliesTo: ProfileType.ouvrant,
        conditions: [
          CompanionProfileReferenceCondition({'4211'}),
        ],
        lengthExpression: const ConstantExpression(1),
        quantity: const CutQuantity.fixed(1),
        angles: const CutAngles.square(),
        isPlaceholder: false,
      );
      final construction = _construction(
        sections: [_section('s1')],
        profileUsages: [
          _usage('only', 'p-4211', role: ProfileUsageRole.left),
        ],
      );
      final outcome = ConstructionCalculator(
        ruleSet: SystemRuleSet(
          systemId: 'test',
          name: 'test',
          isPlaceholder: false,
          rules: [loneCarrierRule],
        ),
      ).calculate(construction, profilesById: {
        'p-4211': _profile('4211'),
      });

      expect(outcome.cuts, isEmpty);
      expect(outcome.issues.single.reason,
          ProfileUsageIssueReason.noRuleMatched);
    });

    test('unresolved siblings stay invisible but still report their own '
        'issue (fail-closed when they were the only carrier)', () {
      final construction = _construction(
        sections: [_section('s1')],
        profileUsages: [
          _usage('t', 'p-2656', role: ProfileUsageRole.intermediate),
          _usage('broken', 'p-deleted', role: ProfileUsageRole.left),
        ],
      );
      final outcome = ConstructionCalculator(
        ruleSet: SystemRuleSet(
          systemId: 'test',
          name: 'test',
          isPlaceholder: false,
          rules: [companionRule()],
        ),
      ).calculate(construction, profilesById: {
        'p-2656': _profile('2656', type: ProfileType.traverse),
      });

      expect(outcome.cuts, isEmpty);
      final reasons = {
        for (final issue in outcome.issues) issue.profileUsageId: issue.reason,
      };
      expect(reasons['broken'], ProfileUsageIssueReason.profileUnresolved);
      expect(reasons['t'], ProfileUsageIssueReason.noRuleMatched);
    });
  });
}
