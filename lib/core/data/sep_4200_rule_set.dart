/// The second REAL manufacturer-backed `SystemRuleSet` in AluVis, and the
/// first for Sepalumic: the Série 4200 débitage families the domain model
/// can honestly represent — "Châssis fixe" and "OF 1/2 vantaux"
/// (à la française) — from the Catalogue Technique Édition 05 (Sept. 2019).
///
///   Sepalumic "Catalogue Technique Série 4200", Édition 05 — Septembre
///   2019 (199-page client-supplied PDF; AutoCAD-plotted sheets).
///   E-section débitage tables E030/E050 (fixe, pdf pp. 39-42),
///   E070/E090/E110/E130 (OF 1 vantail, pp. 43-50),
///   E150/E170/E190/E210 (OF 2 vantaux, pp. 51-58). Full transcription
///   and per-value citations: docs/VERIFIED_SOURCES.md, section M-2.
///
/// WHAT IS ENCODED — exactly three families, nothing else:
///
///   Châssis fixe (kind = fixed):
///     Dormant 4220 .......... 2×L + 2×H    (45°/45°)
///     OU Dormant 4221 ....... 2×(L+50) + 2×(H+50)
///     Traverse 4405/4413 .... 1×(L−54.5)   (90°/90°, option)
///   OF 1 vantail (française, vantauxCount = 1):
///     Dormant 4220 / 4221 ... identical to fixe
///     Ouvrant 4211/4219/4244/4254 .. 2×(L−43.5) + 2×(H−43.5) (45°/45°)
///   OF 2 vantaux (française, vantauxCount = 2):
///     Dormant 4220 / 4221 ... identical to fixe
///     Ouvrant (same refs) ... 4×(L/2−24) + 4×(H−43.5) (45°/45°)
///     Battue centrale 4206 .. 1×(H−102)    (90°/90°)
///
/// MEMBER MAPPING (from the tables' own arithmetic): the ouvrant
/// TRAVERSES span the sash width -- 1v: L−43.5 (top/bottom placements);
/// 2v: L/2−24 (each leaf is ~half the width, one placement spans both
/// leaves' rails). The ouvrant MONTANTS span the sash height -- H−43.5
/// at both columns (left/right placements; at 2v each placement covers
/// both leaves' same-side stiles). L = whole dormant-frame width, H =
/// whole dormant-frame height. Deductions 50, 43.5, 24, 102, 54.5 and
/// the /2 divisor are printed constants in the E tables -- no Profile
/// dimension feeds any rule.
///
/// QUANTITY MAPPING (per-placement law, see CutQuantity's doc): tables
/// count pieces PER UNIT; rules count PER MATCHED PLACEMENT. Dormant
/// placements are role-scoped one-piece positions (fixed(1) ×4 roles =
/// the printed 2+2). OF 1v ouvrant placements likewise fixed(1) ×4 roles
/// = the printed 2+2. OF 2v ouvrant placements each span BOTH leaves, so
/// traverses/montants yield fixed(2) per placement -- the placements
/// reach the printed 4+4. The battue centrale is ONE intermediate
/// placement -> fixed(1).
///
/// ROUTING SAFETY: fixe rules carry SectionKindCondition(fixed); OF rules
/// carry exact VantauxCountCondition(1|2) + OpeningTypeCondition(francaise)
/// -- exactly the documented columns (a 3+-vantail française unit is
/// undocumented by this catalogue and stays unmatched). Every rule lists
/// exactly its table row's references; the fixe traverse's "4405 OU 4413"
/// alternative maps to one reference-set condition. Roles/reference sets
/// keep every context disjoint by construction;
/// AmbiguousRuleMatchException stays loud.
///
/// SCOPE LIMIT (single châssis per construction): every L/H refers to the
/// WHOLE dormant-frame elevation of ONE châssis. A construction mixing a
/// fixe section and an OF section is NOT covered by these tables -- model
/// one châssis per construction until a multi-frame scope condition
/// exists (see docs/VERIFIED_SOURCES.md M-2, blocker 0).
///
/// ANGLES: dormant/ouvrant 45° mitres are printed in the E tables' COUPE
/// column AND derived from the A030 assembly statement ("assemblés en
/// coupe d'onglet par équerre à pion"); traverse/battue 90°/90° square
/// cuts are printed. Rule descriptions carry both facts.
///
/// NOT ENCODED (honest noRuleMatched; blockers in
/// docs/VERIFIED_SOURCES.md M-2): OB (à la belge) / Soufflet / Projeté /
/// Porte large / Châssis composé families (no honest OpeningType / door
/// modeling), traverse intermédiaire options for OF (deduction depends on
/// the SIBLING ouvrant reference -- cross-usage dependency), parclose
/// rows (glass-dependent selection), hardware/joints/glass tables.
library;

import '../models/opening.dart';
import '../models/profile.dart';
import '../models/profile_usage.dart';
import '../models/rules/calculation_rule.dart';
import '../models/rules/dimension_expression.dart';
import '../models/rules/rule_condition.dart';
import '../models/rules/system_rule_set.dart';
import '../models/section.dart';
import 'builtin_catalog_seed.dart';

const SystemRuleSet sepSerie4200RuleSet = SystemRuleSet(
  systemId: sepSerie4200Id,
  name: 'Sepalumic Série 4200 — débitage fixe + OF 1/2 vantaux (éd. 05)',
  isPlaceholder: false,
  rules: [
    // --- Châssis fixe (E030/E050, pdf pp. 39-42) ---
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        SectionKindCondition(SectionKind.fixed),
        ProfileReferenceCondition({'4220'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionWidth,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 4220 — L traverse haute '
          '[débitage 4200 fixe, E030/E050, éd. 05 · 45°/45° '
          'imprimés et dérivés (onglet, A030)]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        SectionKindCondition(SectionKind.fixed),
        ProfileReferenceCondition({'4220'}),
        ProfileUsageRoleCondition(ProfileUsageRole.bottom),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionWidth,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 4220 — L traverse basse '
          '[débitage 4200 fixe, E030/E050, éd. 05 · 45°/45° '
          'imprimés et dérivés (onglet, A030)]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        SectionKindCondition(SectionKind.fixed),
        ProfileReferenceCondition({'4220'}),
        ProfileUsageRoleCondition(ProfileUsageRole.left),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionHeight,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 4220 — H montant gauche '
          '[débitage 4200 fixe, E030/E050, éd. 05 · 45°/45° '
          'imprimés et dérivés (onglet, A030)]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        SectionKindCondition(SectionKind.fixed),
        ProfileReferenceCondition({'4220'}),
        ProfileUsageRoleCondition(ProfileUsageRole.right),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionHeight,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 4220 — H montant droit '
          '[débitage 4200 fixe, E030/E050, éd. 05 · 45°/45° '
          'imprimés et dérivés (onglet, A030)]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        SectionKindCondition(SectionKind.fixed),
        ProfileReferenceCondition({'4221'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionWidth),
        operator: BinaryOperator.add,
        right: DimensionExpression.constant(50.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 4221 — L+50 traverse haute '
          '[débitage 4200 fixe, E030/E050, éd. 05 · 45°/45° '
          'imprimés et dérivés (onglet, A030)]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        SectionKindCondition(SectionKind.fixed),
        ProfileReferenceCondition({'4221'}),
        ProfileUsageRoleCondition(ProfileUsageRole.bottom),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionWidth),
        operator: BinaryOperator.add,
        right: DimensionExpression.constant(50.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 4221 — L+50 traverse basse '
          '[débitage 4200 fixe, E030/E050, éd. 05 · 45°/45° '
          'imprimés et dérivés (onglet, A030)]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        SectionKindCondition(SectionKind.fixed),
        ProfileReferenceCondition({'4221'}),
        ProfileUsageRoleCondition(ProfileUsageRole.left),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.add,
        right: DimensionExpression.constant(50.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 4221 — H+50 montant gauche '
          '[débitage 4200 fixe, E030/E050, éd. 05 · 45°/45° '
          'imprimés et dérivés (onglet, A030)]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        SectionKindCondition(SectionKind.fixed),
        ProfileReferenceCondition({'4221'}),
        ProfileUsageRoleCondition(ProfileUsageRole.right),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.add,
        right: DimensionExpression.constant(50.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 4221 — H+50 montant droit '
          '[débitage 4200 fixe, E030/E050, éd. 05 · 45°/45° '
          'imprimés et dérivés (onglet, A030)]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.traverse,
      conditions: [
        SectionKindCondition(SectionKind.fixed),
        ProfileReferenceCondition({'4405', '4413'}),
        ProfileUsageRoleCondition(ProfileUsageRole.intermediate),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionWidth),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(54.5),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.square(),
      isPlaceholder: false,
      description:
          'Traverse intermédiaire 4405/4413 — L−54.5 '
          '[débitage 4200 fixe, E030/E050, éd. 05 · 90°/90° imprimé; '
          'option avec traverse]',
    ),

    // --- OF 1 vantail (E070/E090/E110/E130, pdf pp. 43-50) ---
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'4220'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionWidth,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 4220 — L traverse haute '
          '[débitage 4200 OF 1 vantaux, E070/E090/E110/E130, éd. 05 · 45°/45° '
          'imprimés et dérivés (onglet, A030)]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'4220'}),
        ProfileUsageRoleCondition(ProfileUsageRole.bottom),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionWidth,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 4220 — L traverse basse '
          '[débitage 4200 OF 1 vantaux, E070/E090/E110/E130, éd. 05 · 45°/45° '
          'imprimés et dérivés (onglet, A030)]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'4220'}),
        ProfileUsageRoleCondition(ProfileUsageRole.left),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionHeight,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 4220 — H montant gauche '
          '[débitage 4200 OF 1 vantaux, E070/E090/E110/E130, éd. 05 · 45°/45° '
          'imprimés et dérivés (onglet, A030)]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'4220'}),
        ProfileUsageRoleCondition(ProfileUsageRole.right),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionHeight,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 4220 — H montant droit '
          '[débitage 4200 OF 1 vantaux, E070/E090/E110/E130, éd. 05 · 45°/45° '
          'imprimés et dérivés (onglet, A030)]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'4221'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionWidth),
        operator: BinaryOperator.add,
        right: DimensionExpression.constant(50.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 4221 — L+50 traverse haute '
          '[débitage 4200 OF 1 vantaux, E070/E090/E110/E130, éd. 05 · 45°/45° '
          'imprimés et dérivés (onglet, A030)]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'4221'}),
        ProfileUsageRoleCondition(ProfileUsageRole.bottom),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionWidth),
        operator: BinaryOperator.add,
        right: DimensionExpression.constant(50.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 4221 — L+50 traverse basse '
          '[débitage 4200 OF 1 vantaux, E070/E090/E110/E130, éd. 05 · 45°/45° '
          'imprimés et dérivés (onglet, A030)]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'4221'}),
        ProfileUsageRoleCondition(ProfileUsageRole.left),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.add,
        right: DimensionExpression.constant(50.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 4221 — H+50 montant gauche '
          '[débitage 4200 OF 1 vantaux, E070/E090/E110/E130, éd. 05 · 45°/45° '
          'imprimés et dérivés (onglet, A030)]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'4221'}),
        ProfileUsageRoleCondition(ProfileUsageRole.right),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.add,
        right: DimensionExpression.constant(50.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 4221 — H+50 montant droit '
          '[débitage 4200 OF 1 vantaux, E070/E090/E110/E130, éd. 05 · 45°/45° '
          'imprimés et dérivés (onglet, A030)]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.ouvrant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'4211', '4219', '4244', '4254'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionWidth),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(43.5),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Ouvrant 4211/4219/4244/4254 — traverse à L−43.5 '
          '×1 par position '
          '[débitage 4200 OF 1 vantaux, E070/E090/E110/E130, éd. 05 · 45°/45°]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.ouvrant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'4211', '4219', '4244', '4254'}),
        ProfileUsageRoleCondition(ProfileUsageRole.bottom),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionWidth),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(43.5),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Ouvrant 4211/4219/4244/4254 — traverse à L−43.5 '
          '×1 par position '
          '[débitage 4200 OF 1 vantaux, E070/E090/E110/E130, éd. 05 · 45°/45°]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.ouvrant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'4211', '4219', '4244', '4254'}),
        ProfileUsageRoleCondition(ProfileUsageRole.left),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(43.5),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Ouvrant 4211/4219/4244/4254 — montant à H−43.5 '
          '×1 par côté '
          '[débitage 4200 OF 1 vantaux, E070/E090/E110/E130, éd. 05 · 45°/45°]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.ouvrant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'4211', '4219', '4244', '4254'}),
        ProfileUsageRoleCondition(ProfileUsageRole.right),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(43.5),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Ouvrant 4211/4219/4244/4254 — montant à H−43.5 '
          '×1 par côté '
          '[débitage 4200 OF 1 vantaux, E070/E090/E110/E130, éd. 05 · 45°/45°]',
    ),

    // --- OF 2 vantaux (E150/E170/E190/E210, pdf pp. 51-58) ---
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'4220'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionWidth,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 4220 — L traverse haute '
          '[débitage 4200 OF 2 vantaux, E150/E170/E190/E210, éd. 05 · 45°/45° '
          'imprimés et dérivés (onglet, A030)]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'4220'}),
        ProfileUsageRoleCondition(ProfileUsageRole.bottom),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionWidth,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 4220 — L traverse basse '
          '[débitage 4200 OF 2 vantaux, E150/E170/E190/E210, éd. 05 · 45°/45° '
          'imprimés et dérivés (onglet, A030)]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'4220'}),
        ProfileUsageRoleCondition(ProfileUsageRole.left),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionHeight,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 4220 — H montant gauche '
          '[débitage 4200 OF 2 vantaux, E150/E170/E190/E210, éd. 05 · 45°/45° '
          'imprimés et dérivés (onglet, A030)]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'4220'}),
        ProfileUsageRoleCondition(ProfileUsageRole.right),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionHeight,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 4220 — H montant droit '
          '[débitage 4200 OF 2 vantaux, E150/E170/E190/E210, éd. 05 · 45°/45° '
          'imprimés et dérivés (onglet, A030)]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'4221'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionWidth),
        operator: BinaryOperator.add,
        right: DimensionExpression.constant(50.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 4221 — L+50 traverse haute '
          '[débitage 4200 OF 2 vantaux, E150/E170/E190/E210, éd. 05 · 45°/45° '
          'imprimés et dérivés (onglet, A030)]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'4221'}),
        ProfileUsageRoleCondition(ProfileUsageRole.bottom),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionWidth),
        operator: BinaryOperator.add,
        right: DimensionExpression.constant(50.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 4221 — L+50 traverse basse '
          '[débitage 4200 OF 2 vantaux, E150/E170/E190/E210, éd. 05 · 45°/45° '
          'imprimés et dérivés (onglet, A030)]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'4221'}),
        ProfileUsageRoleCondition(ProfileUsageRole.left),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.add,
        right: DimensionExpression.constant(50.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 4221 — H+50 montant gauche '
          '[débitage 4200 OF 2 vantaux, E150/E170/E190/E210, éd. 05 · 45°/45° '
          'imprimés et dérivés (onglet, A030)]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'4221'}),
        ProfileUsageRoleCondition(ProfileUsageRole.right),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.add,
        right: DimensionExpression.constant(50.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 4221 — H+50 montant droit '
          '[débitage 4200 OF 2 vantaux, E150/E170/E190/E210, éd. 05 · 45°/45° '
          'imprimés et dérivés (onglet, A030)]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.ouvrant,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'4211', '4219', '4244', '4254'}),
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
        right: DimensionExpression.constant(24.0),
      ),
      quantity: CutQuantity.fixed(2),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Ouvrant 4211/4219/4244/4254 — traverse à L/2−24 '
          '×2 par position '
          '[débitage 4200 OF 2 vantaux, E150/E170/E190/E210, éd. 05 · 45°/45°]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.ouvrant,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'4211', '4219', '4244', '4254'}),
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
        right: DimensionExpression.constant(24.0),
      ),
      quantity: CutQuantity.fixed(2),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Ouvrant 4211/4219/4244/4254 — traverse à L/2−24 '
          '×2 par position '
          '[débitage 4200 OF 2 vantaux, E150/E170/E190/E210, éd. 05 · 45°/45°]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.ouvrant,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'4211', '4219', '4244', '4254'}),
        ProfileUsageRoleCondition(ProfileUsageRole.left),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(43.5),
      ),
      quantity: CutQuantity.fixed(2),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Ouvrant 4211/4219/4244/4254 — montant à H−43.5 '
          '×2 par côté '
          '[débitage 4200 OF 2 vantaux, E150/E170/E190/E210, éd. 05 · 45°/45°]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.ouvrant,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'4211', '4219', '4244', '4254'}),
        ProfileUsageRoleCondition(ProfileUsageRole.right),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(43.5),
      ),
      quantity: CutQuantity.fixed(2),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Ouvrant 4211/4219/4244/4254 — montant à H−43.5 '
          '×2 par côté '
          '[débitage 4200 OF 2 vantaux, E150/E170/E190/E210, éd. 05 · 45°/45°]',
    ),

    ProfileCalculationRule(
      appliesTo: ProfileType.ouvrant,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'4206'}),
        ProfileUsageRoleCondition(ProfileUsageRole.intermediate),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(102.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.square(),
      isPlaceholder: false,
      description:
          'Battue centrale 4206 — H−102 '
          '[débitage 4200 OF 2 vantaux, E150/E170/E190/E210, éd. 05 · '
          '90°/90° imprimé]',
    ),
  ],
);
