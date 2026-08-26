/// The fourth REAL manufacturer-backed `SystemRuleSet` in AluVis:
/// the Maghreb Extrusion Série 14700 portes Lourdes débitage table
/// "(1 ET 2 VANTAUX AVEC TRAVERSE BASSE)" from the Catalogue Général
/// p. 94 -- the UNAMBIGUOUS subset only, per the C10a locked decision.
///
///   ME "Catalogue Général" (146-page client-supplied PDF), Série 14700
///   section: titre p. 72, fiche technique pp. 73-75, PROFILOSCOPE pp.
///   76-80, coupes pp. 81-93, débitage "DÉBITAGE PORTE À FRAPPE SÉRIE
///   14.700 (1 ET 2 VANTAUX AVEC TRAVERSE BASSE)" p. 94 (text layer
///   + hi-dpi visual verification of every cell). Full transcription and
///   per-value citations: docs/VERIFIED_SOURCES.md, section S-4.
///
/// WHAT IS ENCODED — the unambiguous subset of p. 94, nothing else:
///
///   Dormant 14.700 ........... 1×L + 2×H        (45° / 45°/90°)
///   Ouvrant intérieur 14.705  1v: L−118 + 2×H−65 (45° / 45°/90°)
///                             2v: (L−104,9)/2  (45°)
///   Traverse basse {14.813, 14.807}
///                             1v: L−261.6    (90°/90°)
///                             2v: 2×(L−392,1)/2 (90°/90°)
///   Parclose {14.809, 14.810}
///                             1v: 2×(L−261.6) + 2×(H−296,8) (90°)
///                             2v: 2×(L−392,1)/2 ×2 + 2×(H−296,8) ×2 (90°)
///   Tige de crémone 14.811 ... 1×(H−90)          (90°, 1v only)
///
/// MIXED 45°/90° ANGLES: the H-piece rows print "45°/90°" -- a mitred
/// 45° end and a square 90° end on the SAME cut. Stored as
/// `CutAngles(45, 90)` matching the print order; the ledger records
/// that the source does not specify which end is 45° (top join) and
/// which is 90° (bottom join at the traverse-basse). Fabrication reads
/// it the same way.
///
/// MEMBER MAPPING: L = whole dormant-frame width, H = whole height
/// (p. 94's own variables). Dormant placements are role-scoped
/// one-piece positions EXCEPT the bottom, which is replaced by the
/// traverse-basse assembly (14.813 + 14.807) at the bottom position
/// -- the dormant 14.700 has NO bottom piece in p. 94 (Qté 1 for the
/// L-piece = top only). At 1v, the dormant bottom slots hold the
/// traverse-basse assembly; at 2v, each leaf has its own half of the
/// traverse-basse assembly. The 14.705 (intérieur) leaf has no
/// bottom horizontal of its own at 1v either -- it sits on the
/// traverse-basse. Parclose placements follow the standard top/
/// bottom (L) + left/right (H) mapping.
///
/// QUANTITY MAPPING (per-placement law): every role-scoped rule here
/// is fixed(1) at 1v. At 2v, parclose rules are fixed(2) per role
/// (one per leaf), matching the printed 2/2 top+bottom and 2/2
/// left+right decomposition. The traverse-basse assembly is
/// fixed(1) at 1v and fixed(2) at 2v. The 14.705 (intérieur)
/// 2v top rule is fixed(1) (one top traverse per construction -- the
/// 2v top is shared across both leaves, per the spanning doctrine).
///
/// ROUTING SAFETY: every rule carries exact VantauxCountCondition(1|2)
/// + OpeningTypeCondition(francaise) -- the fiche (p. 73) and the
/// coupes (pp. 81-84) pin these rows to the "PORTE À FRAPPE" 1- and
/// 2-vantail configurations. The 14.811 tige rule is the one
/// no-role-condition rule (chicane 14 624 precedent: source states no
/// position), and the only appliesTo-other rule without role. The
/// traverse-basse rule uses a multi-reference set
/// {'14.813','14.807'} per the outcome-identical-row discipline (both
/// refs share one formula per column). Same for the parclose rule
/// set {'14.809','14.810'}.
///
/// DELIBERATELY NOT ENCODED (C10a locked decision -- honest noRuleMatched,
/// blockers in docs/VERIFIED_SOURCES.md S-4):
///   1. 2v 14.705 stile formula (H−65, Qté 3): the "3" stiles across the
///      two leaves is a documented source tension. Coupes p. 87 labels
///      14.705 as "OUVRANT A L'INTERIEUR"; p. 88 labels 14.706 as
///      "OUVRANT A L'EXTERIEUR". The 2v is interpreted as a "porte +
///      tierce" (main interior door + narrower exterior service leaf)
///      but NO coupe labels the per-stile positional distribution of
///      the 3+1 split, so the role mapping (left/right/intermediate
///      of which leaf) is not directly evidenced. 2v 14.705 stiles
///      stay noRuleMatched; 1v 14.705 stiles are encoded (2 outer
///      stiles left/right, unambiguous).
///   2. 2v 14.706 stile formula (H−65, Qté 1): same tension. The single
///      14.706 stile is the service-leaf's outer stile per the tierce
///      interpretation, but the role evidence is indirect. Stays
///      noRuleMatched.
///   3. 14.819 parclose cuts: the p. 92 parclose/vitrage mapping
///      names 14.819 for 22-27mm glazing, but the p. 94 débitage table
///      does not print a cut row for it. Glass-dependent selection is
///      also a domain gap; 14.819 stays ruleless.
///   4. Va-et-vient sur pivot, châssis fixe, 1v+imposte fixe variants:
///      the fiche (p. 73) lists these product variants but no débitage
///      tables exist for them in the section.
library;

import '../models/opening.dart';
import '../models/profile.dart';
import '../models/profile_usage.dart';
import '../models/rules/calculation_rule.dart';
import '../models/rules/dimension_expression.dart';
import '../models/rules/rule_condition.dart';
import '../models/rules/system_rule_set.dart';
import 'builtin_catalog_seed.dart';

const SystemRuleSet meSerie14700RuleSet = SystemRuleSet(
  systemId: meSerie14700Id,
  name: 'ME Série 14700 portes Lourdes — débitage 1/2 vantaux '
      '(sous-ensemble sans ambiguïté, éd. Catalogue Général)',
  isPlaceholder: false,
  rules: [
    // --- Dormant 14.700 (p. 94, 45° / 45°/90° imprimé) ---
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.700'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionWidth,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 14.700 — L traverse haute '
          '[débitage 14700 portes 1 vantail, Catalogue Général p. 94 · '
          '45° imprimé]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.700'}),
        ProfileUsageRoleCondition(ProfileUsageRole.left),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionHeight,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles(start: 45, end: 90),
      isPlaceholder: false,
      description:
          'Dormant 14.700 — H montant gauche '
          '[débitage 14700 portes 1 vantail, Catalogue Général p. 94 · '
          '45°/90° imprimé]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.700'}),
        ProfileUsageRoleCondition(ProfileUsageRole.right),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionHeight,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles(start: 45, end: 90),
      isPlaceholder: false,
      description:
          'Dormant 14.700 — H montant droit '
          '[débitage 14700 portes 1 vantail, Catalogue Général p. 94 · '
          '45°/90° imprimé]',
    ),
    // --- Dormant 14.700 (p. 94, 2 vantaux) ---
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.700'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionWidth,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 14.700 — L traverse haute '
          '[débitage 14700 portes 2 vantaux, Catalogue Général p. 94 · '
          '45° imprimé]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.700'}),
        ProfileUsageRoleCondition(ProfileUsageRole.left),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionHeight,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles(start: 45, end: 90),
      isPlaceholder: false,
      description:
          'Dormant 14.700 — H montant gauche '
          '[débitage 14700 portes 2 vantaux, Catalogue Général p. 94 · '
          '45°/90° imprimé]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.700'}),
        ProfileUsageRoleCondition(ProfileUsageRole.right),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionHeight,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles(start: 45, end: 90),
      isPlaceholder: false,
      description:
          'Dormant 14.700 — H montant droit '
          '[débitage 14700 portes 2 vantaux, Catalogue Général p. 94 · '
          '45°/90° imprimé]',
    ),
    // --- Ouvrant intérieur 14.705 (p. 94, 1 vantail: top + 2 stiles) ---
    ProfileCalculationRule(
      appliesTo: ProfileType.ouvrant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.705'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionWidth),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(118.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Ouvrant intérieur 14.705 — L−118 traverse haute '
          '[débitage 14700 portes 1 vantail, Catalogue Général p. 94 · '
          '45° imprimé]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.ouvrant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.705'}),
        ProfileUsageRoleCondition(ProfileUsageRole.left),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(65.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles(start: 45, end: 90),
      isPlaceholder: false,
      description:
          'Ouvrant intérieur 14.705 — H−65 montant gauche '
          '[débitage 14700 portes 1 vantail, Catalogue Général p. 94 · '
          '45°/90° imprimé]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.ouvrant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.705'}),
        ProfileUsageRoleCondition(ProfileUsageRole.right),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(65.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles(start: 45, end: 90),
      isPlaceholder: false,
      description:
          'Ouvrant intérieur 14.705 — H−65 montant droit '
          '[débitage 14700 portes 1 vantail, Catalogue Général p. 94 · '
          '45°/90° imprimé]',
    ),
    // --- Ouvrant intérieur 14.705 (p. 94, 2 vantaux: top formula
    // ONLY; the 2v stile formula is blocked per the C10a locked
    // decision -- the 3+1 split tension stays noRuleMatched) ---
    ProfileCalculationRule(
      appliesTo: ProfileType.ouvrant,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.705'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
      ],
      lengthExpression: BinaryExpression(
        left: BinaryExpression(
          left: DimensionExpression.variable(
            DimensionVariable.constructionWidth,
          ),
          operator: BinaryOperator.divide,
          right: DimensionExpression.constant(2.0),
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(104.9),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Ouvrant intérieur 14.705 — (L−104,9)/2 traverse haute '
          '[débitage 14700 portes 2 vantaux, Catalogue Général p. 94 · '
          '45° imprimé; stile formula H−65 Qté 3 non encodée — '
          'tension de source documentée ledger S-4]',
    ),
    // --- Traverse basse {14.813, 14.807} (p. 94, 90°/90° imprimé;
    // --- outcome-identical row, multi-ref set) ---
    ProfileCalculationRule(
      appliesTo: ProfileType.traverse,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.813', '14.807'}),
        ProfileUsageRoleCondition(ProfileUsageRole.bottom),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionWidth),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(261.6),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.square(),
      isPlaceholder: false,
      description:
          'Traverse basse 14.813/14.807 — L−261.6 '
          '[débitage 14700 portes 1 vantail, Catalogue Général p. 94 · '
          '90° imprimé; assemble le seuil (pas de dormant bottom)]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.traverse,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.813', '14.807'}),
        ProfileUsageRoleCondition(ProfileUsageRole.bottom),
      ],
      lengthExpression: BinaryExpression(
        left: BinaryExpression(
          left: DimensionExpression.variable(
            DimensionVariable.constructionWidth,
          ),
          operator: BinaryOperator.divide,
          right: DimensionExpression.constant(2.0),
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(392.1),
      ),
      quantity: CutQuantity.fixed(2),
      angles: CutAngles.square(),
      isPlaceholder: false,
      description:
          'Traverse basse 14.813/14.807 — (L−392,1)/2 par vantail '
          '[débitage 14700 portes 2 vantaux, Catalogue Général p. 94 · '
          '90° imprimé; une demi-pièce par vantail]',
    ),
    // --- Parclose {14.809, 14.810} (p. 94, 90° imprimé; outcome-
    // --- identical row, multi-ref set; p. 94 prints BOTH the
    // --- 14.809-ou-14.810 "Double vitrage" row AND the 14.810-ou-14.809
    // --- "Simple vitrage" row with the SAME formulas) ---
    ProfileCalculationRule(
      appliesTo: ProfileType.other,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.809', '14.810'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionWidth),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(261.6),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.square(),
      isPlaceholder: false,
      description:
          'Parclose 14.809/14.810 — L−261.6 traverse haute '
          '[débitage 14700 portes 1 vantail, Catalogue Général p. 94 · '
          '90° imprimé]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.other,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.809', '14.810'}),
        ProfileUsageRoleCondition(ProfileUsageRole.bottom),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionWidth),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(261.6),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.square(),
      isPlaceholder: false,
      description:
          'Parclose 14.809/14.810 — L−261.6 traverse basse '
          '[débitage 14700 portes 1 vantail, Catalogue Général p. 94 · '
          '90° imprimé]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.other,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.809', '14.810'}),
        ProfileUsageRoleCondition(ProfileUsageRole.left),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(296.8),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.square(),
      isPlaceholder: false,
      description:
          'Parclose 14.809/14.810 — H−296.8 montant gauche '
          '[débitage 14700 portes 1 vantail, Catalogue Général p. 94 · '
          '90° imprimé]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.other,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.809', '14.810'}),
        ProfileUsageRoleCondition(ProfileUsageRole.right),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(296.8),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.square(),
      isPlaceholder: false,
      description:
          'Parclose 14.809/14.810 — H−296.8 montant droit '
          '[débitage 14700 portes 1 vantail, Catalogue Général p. 94 · '
          '90° imprimé]',
    ),
    // --- Parclose {14.809, 14.810} (2 vantaux: 2 L-pieces per role
    // --- + 2 H-pieces per role; per-placement fixed(2)) ---
    ProfileCalculationRule(
      appliesTo: ProfileType.other,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.809', '14.810'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
      ],
      lengthExpression: BinaryExpression(
        left: BinaryExpression(
          left: DimensionExpression.variable(
            DimensionVariable.constructionWidth,
          ),
          operator: BinaryOperator.divide,
          right: DimensionExpression.constant(2.0),
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(392.1),
      ),
      quantity: CutQuantity.fixed(2),
      angles: CutAngles.square(),
      isPlaceholder: false,
      description:
          'Parclose 14.809/14.810 — (L−392,1)/2 par vantail ×2 par position '
          '[débitage 14700 portes 2 vantaux, Catalogue Général p. 94 · '
          '90° imprimé]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.other,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.809', '14.810'}),
        ProfileUsageRoleCondition(ProfileUsageRole.bottom),
      ],
      lengthExpression: BinaryExpression(
        left: BinaryExpression(
          left: DimensionExpression.variable(
            DimensionVariable.constructionWidth,
          ),
          operator: BinaryOperator.divide,
          right: DimensionExpression.constant(2.0),
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(392.1),
      ),
      quantity: CutQuantity.fixed(2),
      angles: CutAngles.square(),
      isPlaceholder: false,
      description:
          'Parclose 14.809/14.810 — (L−392,1)/2 par vantail ×2 par position '
          '[débitage 14700 portes 2 vantaux, Catalogue Général p. 94 · '
          '90° imprimé]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.other,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.809', '14.810'}),
        ProfileUsageRoleCondition(ProfileUsageRole.left),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(296.8),
      ),
      quantity: CutQuantity.fixed(2),
      angles: CutAngles.square(),
      isPlaceholder: false,
      description:
          'Parclose 14.809/14.810 — H−296.8 par vantail ×2 par côté '
          '[débitage 14700 portes 2 vantaux, Catalogue Général p. 94 · '
          '90° imprimé]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.other,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.809', '14.810'}),
        ProfileUsageRoleCondition(ProfileUsageRole.right),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(296.8),
      ),
      quantity: CutQuantity.fixed(2),
      angles: CutAngles.square(),
      isPlaceholder: false,
      description:
          'Parclose 14.809/14.810 — H−296.8 par vantail ×2 par côté '
          '[débitage 14700 portes 2 vantaux, Catalogue Général p. 94 · '
          '90° imprimé]',
    ),
    // --- Tige de crémone 14.811 (p. 94, 1v only; no role condition,
    // --- chicane 14 624 precedent: source states no position) ---
    ProfileCalculationRule(
      appliesTo: ProfileType.other,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.811'}),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(90.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.square(),
      isPlaceholder: false,
      description:
          'Tige de crémone 14.811 — H−90 '
          '[débitage 14700 portes 1 vantail, Catalogue Général p. 94 · '
          '90° imprimé; position non déclarée par la source]',
    ),
  ],
);
