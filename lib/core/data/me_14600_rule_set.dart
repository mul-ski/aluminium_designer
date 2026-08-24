/// The first REAL manufacturer-backed `SystemRuleSet` in AluVis: the
/// complete débitage (cut-length) table of the Série 14 600, page 24 of
/// the source document -- the "2 vantaux", "3 vantaux (avec fixe)" and
/// "4 vantaux" columns, all seven rows.
///
///   "Descriptif Coulissant Série 14 600 — MAGHREB EXTRUSION" (31-page
///   client PDF; descriptif dated Larache 14/10/2024), p. 24 DEBITAGE
///   table, transcribed and cited per value in docs/VERIFIED_SOURCES.md
///   (two low-dpi misreads were caught and corrected there by re-reading
///   at 150 dpi -- including this table's (L-64)/2).
///
/// WHAT IS ENCODED HERE -- every documented cell of all three columns:
///
///   Dormant rows {14 617/14 627} et {14 618/628/626}:
///     identical in ALL columns ....... 2+2 × (L ; H) / (L+46 ; H+46)
///   Montant latéral + central:
///     2v / 3v ........................ 2 × (H−74) each row
///     4v ............................. 4 × (H−74) each row
///   Traverse 14 621 ... 4 × (L−64)/2 . | 6 × (L−25)/3 | 8 × (L−60)/4
///   Traverse 14 631 ... 4 × (L−85)/2 . | 6 × (L−47)/3 | 8 × (L−106)/4
///   Chicane 14 624 .................. | .............. | 1 × (H−92)
///
/// L = whole construction width, H = whole construction height (the
/// table's own variables; both exist as DimensionVariable values). The
/// deductions 74, 64, 85, 46, 25, 47, 60, 106 and 92 are printed
/// constants on p. 24, not derived from profile dimensions -- no
/// Profile.width/depth value feeds any rule.
///
/// QUANTITY MAPPING (per-placement law, see CutQuantity's doc): the
/// table counts pieces PER UNIT; AluVis rules count pieces PER MATCHED
/// USAGE PLACEMENT. A unit is modelled as ONE ouvrant coulissante
/// section whose vantauxCount selects the column:
///
///   - dormant placements are role-scoped one-piece positions
///     (fixed(1)); the unit's 2+2 emerges from four placements;
///   - montant latéral: fixed(1) per side at 2/3 vantaux; fixed(2) per
///     side at 4 vantaux (one side placement covers both leaves on that
///     side -- DERIVED decomposition of the printed 4);
///   - montant central (mullion): one intermediate placement covers the
///     meeting stiles -> fixed(2) at 2/3 vantaux, fixed(4) at 4 vantaux;
///   - a top-or-bottom traverse placement spans EVERY panel's track
///     segment ((L−64)/2 or (L−85)/2 -> fixed(2); (L−25)/3 or (L−47)/3
///     -> fixed(3); (L−60)/4 or (L−106)/4 -> fixed(4)) -- top + bottom
///     placements reach the documented 4, 6 or 8 pieces.
///
/// ROUTING SAFETY: every rule carries an exact
/// VantauxCountCondition(2|3|4) tying it to its printed column. Every
/// rule also carries OpeningTypeCondition(coulissante): the source is a
/// coulissant-ONLY descriptif, so any other opening type is covered by
/// NO page of it and must surface as a noRuleMatched issue, not as real
/// cuts (the condition also implies SectionKind.ouvrant). Traverses are
/// routed to their exact reference (14 621 vs 14 631); dormant/mullion
/// rows list exactly the references their table row names (mullions
/// 14 650 / 14 643 are NOT in any row and stay unmatched). Dormant/
/// montant/mullion rules are duplicated per column because several
/// formulas coincide across columns while quantities differ -- gating
/// each rule to its printed column keeps provenance exact instead of
/// relying on coincidences. The chicane rule is the ONE deliberate
/// exception to role gating: the source states no position for it, so a
/// role condition would fabricate one (see its inline comment). Rule
/// selection throws AmbiguousRuleMatchException rather than guessing,
/// but roles/reference sets keep every context disjoint by construction.
///
/// MODELING NOTE ("avec fixe"): the source does not state which third
/// of the 3-vantaux unit is fixed, its rail arrangement, or the fixed
/// panel's framing membership -- and no encoded cut length depends on
/// any of that. The configuration is therefore represented as one
/// ouvrant section with vantauxCount = 3, with NO representation of the
/// fixed-third position (a deliberate, recorded limitation until a
/// verified rule ever needs it).
///
/// ANGLES: p. 24 states lengths only. The 45° mitre comes from the
/// descriptif's assembly statement "Dormants assemblés en coupe d'onglet
/// avec équerres" (pp. 1–3; also stored in the system metadata's
/// assemblyNote). That statement names the DORMANTS; applying the same
/// mitre to sash members is an extension of it -- a DERIVED choice,
/// recorded here and in the ledger (rule descriptions carry "angles
/// dérivés pp. 1-3" so cut-level provenance does not overstate p. 24),
/// not a per-row statement of the débitage table.
///
/// NOTHING IS LEFT UNENCODED: this rule set now covers every cell of
/// the p. 24 débitage table. See docs/VERIFIED_SOURCES.md for the full
/// transcription and status.
library;

import '../models/opening.dart';
import '../models/profile.dart';
import '../models/profile_usage.dart';
import '../models/rules/calculation_rule.dart';
import '../models/rules/dimension_expression.dart';
import '../models/rules/rule_condition.dart';
import '../models/rules/system_rule_set.dart';
import 'builtin_catalog_seed.dart';

const SystemRuleSet meSerie14600RuleSet = SystemRuleSet(
  systemId: meSerie14600Id,
  name: 'Maghreb Extrusion Série 14600 — débitage 2 & 3 vantaux (p. 24)',
  isPlaceholder: false,
  rules: [
    // --- Dormant 14 617 / 14 627: 2+2 × (L ; H), 2 vantaux ---
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 617', '14 627'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionWidth,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Dormant 14 617/14 627 — traverse haute à L '
          '[débitage p. 24, 2 vantaux · angles dérivés pp. 1-3]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 617', '14 627'}),
        ProfileUsageRoleCondition(ProfileUsageRole.bottom),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionWidth,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Dormant 14 617/14 627 — traverse basse à L '
          '[débitage p. 24, 2 vantaux · angles dérivés pp. 1-3]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 617', '14 627'}),
        ProfileUsageRoleCondition(ProfileUsageRole.left),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionHeight,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Dormant 14 617/14 627 — montant gauche à H '
          '[débitage p. 24, 2 vantaux · angles dérivés pp. 1-3]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 617', '14 627'}),
        ProfileUsageRoleCondition(ProfileUsageRole.right),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionHeight,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Dormant 14 617/14 627 — montant droit à H '
          '[débitage p. 24, 2 vantaux · angles dérivés pp. 1-3]',
    ),
    // --- Montant latéral 14 622 / 14 623 / 14 632 / 14 633: 2 × (H−74) ---
    ProfileCalculationRule(
      appliesTo: ProfileType.montant,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 622', '14 623', '14 632', '14 633'}),
        ProfileUsageRoleCondition(ProfileUsageRole.left),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionHeight),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(74.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Montant latéral 14 622/623/632/633 — H−74 '
          '[débitage p. 24, 2 vantaux · angles dérivés pp. 1-3]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.montant,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 622', '14 623', '14 632', '14 633'}),
        ProfileUsageRoleCondition(ProfileUsageRole.right),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionHeight),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(74.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Montant latéral 14 622/623/632/633 — H−74 '
          '[débitage p. 24, 2 vantaux · angles dérivés pp. 1-3]',
    ),
    // --- Traverse 14 621: 4 × (L−64)/2, 2 vantaux ---
    // One placement covers the track across both leaves -> fixed(2).
    ProfileCalculationRule(
      appliesTo: ProfileType.traverse,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 621'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
      ],
      lengthExpression: BinaryExpression(
        left: BinaryExpression(
          left: DimensionExpression.variable(
            DimensionVariable.constructionWidth,
          ),
          operator: BinaryOperator.subtract,
          right: DimensionExpression.constant(64.0),
        ),
        operator: BinaryOperator.divide,
        right: DimensionExpression.constant(2.0),
      ),
      quantity: CutQuantity.fixed(2),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Traverse 14 621 — (L−64)/2 ×2 par position '
          '(haute+basse = 4 pièces) [débitage p. 24, 2 vantaux · angles '
          'dérivés pp. 1-3; appariement montants face 56]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.traverse,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 621'}),
        ProfileUsageRoleCondition(ProfileUsageRole.bottom),
      ],
      lengthExpression: BinaryExpression(
        left: BinaryExpression(
          left: DimensionExpression.variable(
            DimensionVariable.constructionWidth,
          ),
          operator: BinaryOperator.subtract,
          right: DimensionExpression.constant(64.0),
        ),
        operator: BinaryOperator.divide,
        right: DimensionExpression.constant(2.0),
      ),
      quantity: CutQuantity.fixed(2),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Traverse 14 621 — (L−64)/2 ×2 par position '
          '(haute+basse = 4 pièces) [débitage p. 24, 2 vantaux · angles '
          'dérivés pp. 1-3; appariement montants face 56]',
    ),
    // --- Traverse 14 631: 4 × (L−85)/2, 2 vantaux ---
    // Same placement mapping as 14 621: one placement covers the track
    // across both leaves -> fixed(2).
    ProfileCalculationRule(
      appliesTo: ProfileType.traverse,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 631'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
      ],
      lengthExpression: BinaryExpression(
        left: BinaryExpression(
          left: DimensionExpression.variable(
            DimensionVariable.constructionWidth,
          ),
          operator: BinaryOperator.subtract,
          right: DimensionExpression.constant(85.0),
        ),
        operator: BinaryOperator.divide,
        right: DimensionExpression.constant(2.0),
      ),
      quantity: CutQuantity.fixed(2),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Traverse 14 631 — (L−85)/2 ×2 par position '
          '(haute+basse = 4 pièces) [débitage p. 24, 2 vantaux · angles '
          'dérivés pp. 1-3; appariement montants face 69.2]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.traverse,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 631'}),
        ProfileUsageRoleCondition(ProfileUsageRole.bottom),
      ],
      lengthExpression: BinaryExpression(
        left: BinaryExpression(
          left: DimensionExpression.variable(
            DimensionVariable.constructionWidth,
          ),
          operator: BinaryOperator.subtract,
          right: DimensionExpression.constant(85.0),
        ),
        operator: BinaryOperator.divide,
        right: DimensionExpression.constant(2.0),
      ),
      quantity: CutQuantity.fixed(2),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Traverse 14 631 — (L−85)/2 ×2 par position '
          '(haute+basse = 4 pièces) [débitage p. 24, 2 vantaux · angles '
          'dérivés pp. 1-3; appariement montants face 69.2]',
    ),
    // --- Dormant 14 618 / 14 628 / 14 626: 2+2 × (L+46 ; H+46), 2
    // --- vantaux (double-équerre assembly row) ---
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 618', '14 628', '14 626'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionWidth),
        operator: BinaryOperator.add,
        right: DimensionExpression.constant(46.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Dormant 14 618/14 628/14 626 — traverse haute à L+46 '
          '[débitage p. 24, 2 vantaux, double équerre · angles dérivés '
          'pp. 1-3]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 618', '14 628', '14 626'}),
        ProfileUsageRoleCondition(ProfileUsageRole.bottom),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionWidth),
        operator: BinaryOperator.add,
        right: DimensionExpression.constant(46.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Dormant 14 618/14 628/14 626 — traverse basse à L+46 '
          '[débitage p. 24, 2 vantaux, double équerre · angles dérivés '
          'pp. 1-3]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 618', '14 628', '14 626'}),
        ProfileUsageRoleCondition(ProfileUsageRole.left),
      ],
      lengthExpression: BinaryExpression(
        left:
            DimensionExpression.variable(DimensionVariable.constructionHeight),
        operator: BinaryOperator.add,
        right: DimensionExpression.constant(46.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Dormant 14 618/14 628/14 626 — montant gauche à H+46 '
          '[débitage p. 24, 2 vantaux, double équerre · angles dérivés '
          'pp. 1-3]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 618', '14 628', '14 626'}),
        ProfileUsageRoleCondition(ProfileUsageRole.right),
      ],
      lengthExpression: BinaryExpression(
        left:
            DimensionExpression.variable(DimensionVariable.constructionHeight),
        operator: BinaryOperator.add,
        right: DimensionExpression.constant(46.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Dormant 14 618/14 628/14 626 — montant droit à H+46 '
          '[débitage p. 24, 2 vantaux, double équerre · angles dérivés '
          'pp. 1-3]',
    ),
    // --- Montant central 14 619 / 14 620 / 14 630: 2 × (H−74), 2
    // --- vantaux --- The two meeting stiles are vertical members BETWEEN
    // the leaves: role=intermediate is their only fitting placement, and
    // one such placement covers BOTH leaves' meeting stile ->
    // fixed(2), mirroring the traverse mapping. Mullions 14 650 and
    // 14 643 are NOT named by this débitage row and stay unmatched.
    ProfileCalculationRule(
      appliesTo: ProfileType.mullion,
      conditions: [
        VantauxCountCondition(2),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 619', '14 620', '14 630'}),
        ProfileUsageRoleCondition(ProfileUsageRole.intermediate),
      ],
      lengthExpression: BinaryExpression(
        left:
            DimensionExpression.variable(DimensionVariable.constructionHeight),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(74.0),
      ),
      quantity: CutQuantity.fixed(2),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Montant central 14 619/620/630 — (H−74) ×2 par position '
          'intermédiaire [débitage p. 24, 2 vantaux · angles dérivés '
          'pp. 1-3]',
    ),

    // =====================================================================
    // --- "3 VANTAUX (AVEC FIXE)" COLUMN (p. 24) ---
    // Three equal panels spanning L (the traverses' /3 divisor is the
    // source's own arithmetic). Dormant/montant/mullion rows are
    // IDENTICAL to the 2-vantaux column, so they are duplicated here
    // under VantauxCountCondition(3) -- exact-documentation-column
    // gating, same doctrine as the 2v rules. The model represents this
    // configuration as one ouvrant coulissante section with
    // vantauxCount = 3; WHICH third of the unit is fixed is not stated
    // by the débitage table, has no effect on any encoded cut length,
    // and is deliberately not represented.
    // =====================================================================

    // --- Dormant 14 617 / 14 627: 2+2 × (L ; H), 3 vantaux ---
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(3),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 617', '14 627'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionWidth,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Dormant 14 617/14 627 — traverse haute à L '
          '[débitage p. 24, 3 vantaux · angles dérivés pp. 1-3]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(3),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 617', '14 627'}),
        ProfileUsageRoleCondition(ProfileUsageRole.bottom),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionWidth,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Dormant 14 617/14 627 — traverse basse à L '
          '[débitage p. 24, 3 vantaux · angles dérivés pp. 1-3]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(3),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 617', '14 627'}),
        ProfileUsageRoleCondition(ProfileUsageRole.left),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionHeight,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Dormant 14 617/14 627 — montant gauche à H '
          '[débitage p. 24, 3 vantaux · angles dérivés pp. 1-3]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(3),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 617', '14 627'}),
        ProfileUsageRoleCondition(ProfileUsageRole.right),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionHeight,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Dormant 14 617/14 627 — montant droit à H '
          '[débitage p. 24, 3 vantaux · angles dérivés pp. 1-3]',
    ),
    // --- Dormant 14 618 / 14 628 / 14 626: 2+2 × (L+46 ; H+46), 3
    // --- vantaux (double-équerre assembly row) ---
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(3),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 618', '14 628', '14 626'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionWidth),
        operator: BinaryOperator.add,
        right: DimensionExpression.constant(46.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Dormant 14 618/14 628/14 626 — traverse haute à L+46 '
          '[débitage p. 24, 3 vantaux, double équerre · angles dérivés '
          'pp. 1-3]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(3),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 618', '14 628', '14 626'}),
        ProfileUsageRoleCondition(ProfileUsageRole.bottom),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionWidth),
        operator: BinaryOperator.add,
        right: DimensionExpression.constant(46.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Dormant 14 618/14 628/14 626 — traverse basse à L+46 '
          '[débitage p. 24, 3 vantaux, double équerre · angles dérivés '
          'pp. 1-3]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(3),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 618', '14 628', '14 626'}),
        ProfileUsageRoleCondition(ProfileUsageRole.left),
      ],
      lengthExpression: BinaryExpression(
        left:
            DimensionExpression.variable(DimensionVariable.constructionHeight),
        operator: BinaryOperator.add,
        right: DimensionExpression.constant(46.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Dormant 14 618/14 628/14 626 — montant gauche à H+46 '
          '[débitage p. 24, 3 vantaux, double équerre · angles dérivés '
          'pp. 1-3]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(3),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 618', '14 628', '14 626'}),
        ProfileUsageRoleCondition(ProfileUsageRole.right),
      ],
      lengthExpression: BinaryExpression(
        left:
            DimensionExpression.variable(DimensionVariable.constructionHeight),
        operator: BinaryOperator.add,
        right: DimensionExpression.constant(46.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Dormant 14 618/14 628/14 626 — montant droit à H+46 '
          '[débitage p. 24, 3 vantaux, double équerre · angles dérivés '
          'pp. 1-3]',
    ),
    // --- Montant latéral 14 622 / 14 623 / 14 632 / 14 633: 2 × (H−74),
    // --- 3 vantaux ---
    ProfileCalculationRule(
      appliesTo: ProfileType.montant,
      conditions: [
        VantauxCountCondition(3),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 622', '14 623', '14 632', '14 633'}),
        ProfileUsageRoleCondition(ProfileUsageRole.left),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionHeight),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(74.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Montant latéral 14 622/623/632/633 — H−74 '
          '[débitage p. 24, 3 vantaux · angles dérivés pp. 1-3]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.montant,
      conditions: [
        VantauxCountCondition(3),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 622', '14 623', '14 632', '14 633'}),
        ProfileUsageRoleCondition(ProfileUsageRole.right),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionHeight),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(74.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Montant latéral 14 622/623/632/633 — H−74 '
          '[débitage p. 24, 3 vantaux · angles dérivés pp. 1-3]',
    ),
    // --- Montant central 14 619 / 14 620 / 14 630: 2 × (H−74), 3
    // --- vantaux --- Same intermediate-role mapping as the 2v column:
    // one placement covers both meeting stiles -> fixed(2).
    ProfileCalculationRule(
      appliesTo: ProfileType.mullion,
      conditions: [
        VantauxCountCondition(3),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 619', '14 620', '14 630'}),
        ProfileUsageRoleCondition(ProfileUsageRole.intermediate),
      ],
      lengthExpression: BinaryExpression(
        left:
            DimensionExpression.variable(DimensionVariable.constructionHeight),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(74.0),
      ),
      quantity: CutQuantity.fixed(2),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Montant central 14 619/620/630 — (H−74) ×2 par position '
          'intermédiaire [débitage p. 24, 3 vantaux · angles dérivés '
          'pp. 1-3]',
    ),
    // --- Traverse 14 621: 6 × (L−25)/3, 3 vantaux --- One top-or-bottom
    // placement spans ALL THREE panels' track thirds -> fixed(3); top +
    // bottom placements reach the documented 6 pieces.
    ProfileCalculationRule(
      appliesTo: ProfileType.traverse,
      conditions: [
        VantauxCountCondition(3),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 621'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
      ],
      lengthExpression: BinaryExpression(
        left: BinaryExpression(
          left: DimensionExpression.variable(
            DimensionVariable.constructionWidth,
          ),
          operator: BinaryOperator.subtract,
          right: DimensionExpression.constant(25.0),
        ),
        operator: BinaryOperator.divide,
        right: DimensionExpression.constant(3.0),
      ),
      quantity: CutQuantity.fixed(3),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Traverse 14 621 — (L−25)/3 ×3 par position '
          '(haute+basse = 6 pièces) [débitage p. 24, 3 vantaux · angles '
          'dérivés pp. 1-3]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.traverse,
      conditions: [
        VantauxCountCondition(3),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 621'}),
        ProfileUsageRoleCondition(ProfileUsageRole.bottom),
      ],
      lengthExpression: BinaryExpression(
        left: BinaryExpression(
          left: DimensionExpression.variable(
            DimensionVariable.constructionWidth,
          ),
          operator: BinaryOperator.subtract,
          right: DimensionExpression.constant(25.0),
        ),
        operator: BinaryOperator.divide,
        right: DimensionExpression.constant(3.0),
      ),
      quantity: CutQuantity.fixed(3),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Traverse 14 621 — (L−25)/3 ×3 par position '
          '(haute+basse = 6 pièces) [débitage p. 24, 3 vantaux · angles '
          'dérivés pp. 1-3]',
    ),
    // --- Traverse 14 631: 6 × (L−47)/3, 3 vantaux ---
    ProfileCalculationRule(
      appliesTo: ProfileType.traverse,
      conditions: [
        VantauxCountCondition(3),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 631'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
      ],
      lengthExpression: BinaryExpression(
        left: BinaryExpression(
          left: DimensionExpression.variable(
            DimensionVariable.constructionWidth,
          ),
          operator: BinaryOperator.subtract,
          right: DimensionExpression.constant(47.0),
        ),
        operator: BinaryOperator.divide,
        right: DimensionExpression.constant(3.0),
      ),
      quantity: CutQuantity.fixed(3),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Traverse 14 631 — (L−47)/3 ×3 par position '
          '(haute+basse = 6 pièces) [débitage p. 24, 3 vantaux · angles '
          'dérivés pp. 1-3; appariement montants face 69.2]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.traverse,
      conditions: [
        VantauxCountCondition(3),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 631'}),
        ProfileUsageRoleCondition(ProfileUsageRole.bottom),
      ],
      lengthExpression: BinaryExpression(
        left: BinaryExpression(
          left: DimensionExpression.variable(
            DimensionVariable.constructionWidth,
          ),
          operator: BinaryOperator.subtract,
          right: DimensionExpression.constant(47.0),
        ),
        operator: BinaryOperator.divide,
        right: DimensionExpression.constant(3.0),
      ),
      quantity: CutQuantity.fixed(3),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Traverse 14 631 — (L−47)/3 ×3 par position '
          '(haute+basse = 6 pièces) [débitage p. 24, 3 vantaux · angles '
          'dérivés pp. 1-3; appariement montants face 69.2]',
    ),

    // =====================================================================
    // --- "4 VANTAUX" COLUMN (p. 24) ---
    // Four equal panels spanning L (the traverses' /4 divisor is the
    // source's own arithmetic). The doubled montant/mullion counts
    // (4 + 4) match four fully-framed sliding leaves -- this column
    // carries no "avec fixe" qualifier. Placement decompositions of the
    // printed per-unit totals follow the established spanning doctrine:
    // one side placement covers both leaves on that side (fixed(2)),
    // the intermediate placement covers all four central stiles
    // (fixed(4)). These decompositions are DERIVED, not printed.
    // =====================================================================

    // --- Dormant 14 617 / 14 627: 2+2 × (L ; H), 4 vantaux ---
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(4),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 617', '14 627'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionWidth,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Dormant 14 617/14 627 — traverse haute à L '
          '[débitage p. 24, 4 vantaux · angles dérivés pp. 1-3]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(4),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 617', '14 627'}),
        ProfileUsageRoleCondition(ProfileUsageRole.bottom),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionWidth,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Dormant 14 617/14 627 — traverse basse à L '
          '[débitage p. 24, 4 vantaux · angles dérivés pp. 1-3]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(4),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 617', '14 627'}),
        ProfileUsageRoleCondition(ProfileUsageRole.left),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionHeight,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Dormant 14 617/14 627 — montant gauche à H '
          '[débitage p. 24, 4 vantaux · angles dérivés pp. 1-3]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(4),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 617', '14 627'}),
        ProfileUsageRoleCondition(ProfileUsageRole.right),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionHeight,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Dormant 14 617/14 627 — montant droit à H '
          '[débitage p. 24, 4 vantaux · angles dérivés pp. 1-3]',
    ),
    // --- Dormant 14 618 / 14 628 / 14 626: 2+2 × (L+46 ; H+46), 4
    // --- vantaux (double-équerre assembly row) ---
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(4),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 618', '14 628', '14 626'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionWidth),
        operator: BinaryOperator.add,
        right: DimensionExpression.constant(46.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Dormant 14 618/14 628/14 626 — traverse haute à L+46 '
          '[débitage p. 24, 4 vantaux, double équerre · angles dérivés '
          'pp. 1-3]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(4),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 618', '14 628', '14 626'}),
        ProfileUsageRoleCondition(ProfileUsageRole.bottom),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionWidth),
        operator: BinaryOperator.add,
        right: DimensionExpression.constant(46.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Dormant 14 618/14 628/14 626 — traverse basse à L+46 '
          '[débitage p. 24, 4 vantaux, double équerre · angles dérivés '
          'pp. 1-3]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(4),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 618', '14 628', '14 626'}),
        ProfileUsageRoleCondition(ProfileUsageRole.left),
      ],
      lengthExpression: BinaryExpression(
        left:
            DimensionExpression.variable(DimensionVariable.constructionHeight),
        operator: BinaryOperator.add,
        right: DimensionExpression.constant(46.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Dormant 14 618/14 628/14 626 — montant gauche à H+46 '
          '[débitage p. 24, 4 vantaux, double équerre · angles dérivés '
          'pp. 1-3]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(4),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 618', '14 628', '14 626'}),
        ProfileUsageRoleCondition(ProfileUsageRole.right),
      ],
      lengthExpression: BinaryExpression(
        left:
            DimensionExpression.variable(DimensionVariable.constructionHeight),
        operator: BinaryOperator.add,
        right: DimensionExpression.constant(46.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Dormant 14 618/14 628/14 626 — montant droit à H+46 '
          '[débitage p. 24, 4 vantaux, double équerre · angles dérivés '
          'pp. 1-3]',
    ),
    // --- Montant latéral 14 622 / 14 623 / 14 632 / 14 633: 4 × (H−74),
    // --- 4 vantaux --- Derived mapping: each side placement covers both
    // leaves positioned on that side -> fixed(2); left+right reach the
    // documented 4 pieces.
    ProfileCalculationRule(
      appliesTo: ProfileType.montant,
      conditions: [
        VantauxCountCondition(4),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 622', '14 623', '14 632', '14 633'}),
        ProfileUsageRoleCondition(ProfileUsageRole.left),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionHeight),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(74.0),
      ),
      quantity: CutQuantity.fixed(2),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Montant latéral 14 622/623/632/633 — (H−74) ×2 par côté '
          '(gauche+droite = 4 pièces) [débitage p. 24, 4 vantaux · angles '
          'dérivés pp. 1-3]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.montant,
      conditions: [
        VantauxCountCondition(4),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 622', '14 623', '14 632', '14 633'}),
        ProfileUsageRoleCondition(ProfileUsageRole.right),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionHeight),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(74.0),
      ),
      quantity: CutQuantity.fixed(2),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Montant latéral 14 622/623/632/633 — (H−74) ×2 par côté '
          '(gauche+droite = 4 pièces) [débitage p. 24, 4 vantaux · angles '
          'dérivés pp. 1-3]',
    ),
    // --- Montant central 14 619 / 14 620 / 14 630: 4 × (H−74), 4
    // --- vantaux --- One intermediate placement covers all four central
    // stiles -> fixed(4).
    ProfileCalculationRule(
      appliesTo: ProfileType.mullion,
      conditions: [
        VantauxCountCondition(4),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 619', '14 620', '14 630'}),
        ProfileUsageRoleCondition(ProfileUsageRole.intermediate),
      ],
      lengthExpression: BinaryExpression(
        left:
            DimensionExpression.variable(DimensionVariable.constructionHeight),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(74.0),
      ),
      quantity: CutQuantity.fixed(4),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Montant central 14 619/620/630 — (H−74) ×4 par position '
          'intermédiaire [débitage p. 24, 4 vantaux · angles dérivés '
          'pp. 1-3]',
    ),
    // --- Traverse 14 621: 8 × (L−60)/4, 4 vantaux --- One placement
    // spans ALL FOUR panels' track quarters -> fixed(4); top + bottom
    // placements reach the documented 8 pieces.
    ProfileCalculationRule(
      appliesTo: ProfileType.traverse,
      conditions: [
        VantauxCountCondition(4),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 621'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
      ],
      lengthExpression: BinaryExpression(
        left: BinaryExpression(
          left: DimensionExpression.variable(
            DimensionVariable.constructionWidth,
          ),
          operator: BinaryOperator.subtract,
          right: DimensionExpression.constant(60.0),
        ),
        operator: BinaryOperator.divide,
        right: DimensionExpression.constant(4.0),
      ),
      quantity: CutQuantity.fixed(4),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Traverse 14 621 — (L−60)/4 ×4 par position '
          '(haute+basse = 8 pièces) [débitage p. 24, 4 vantaux · angles '
          'dérivés pp. 1-3]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.traverse,
      conditions: [
        VantauxCountCondition(4),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 621'}),
        ProfileUsageRoleCondition(ProfileUsageRole.bottom),
      ],
      lengthExpression: BinaryExpression(
        left: BinaryExpression(
          left: DimensionExpression.variable(
            DimensionVariable.constructionWidth,
          ),
          operator: BinaryOperator.subtract,
          right: DimensionExpression.constant(60.0),
        ),
        operator: BinaryOperator.divide,
        right: DimensionExpression.constant(4.0),
      ),
      quantity: CutQuantity.fixed(4),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Traverse 14 621 — (L−60)/4 ×4 par position '
          '(haute+basse = 8 pièces) [débitage p. 24, 4 vantaux · angles '
          'dérivés pp. 1-3]',
    ),
    // --- Traverse 14 631: 8 × (L−106)/4, 4 vantaux ---
    ProfileCalculationRule(
      appliesTo: ProfileType.traverse,
      conditions: [
        VantauxCountCondition(4),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 631'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
      ],
      lengthExpression: BinaryExpression(
        left: BinaryExpression(
          left: DimensionExpression.variable(
            DimensionVariable.constructionWidth,
          ),
          operator: BinaryOperator.subtract,
          right: DimensionExpression.constant(106.0),
        ),
        operator: BinaryOperator.divide,
        right: DimensionExpression.constant(4.0),
      ),
      quantity: CutQuantity.fixed(4),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Traverse 14 631 — (L−106)/4 ×4 par position '
          '(haute+basse = 8 pièces) [débitage p. 24, 4 vantaux · angles '
          'dérivés pp. 1-3; appariement montants face 69.2]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.traverse,
      conditions: [
        VantauxCountCondition(4),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 631'}),
        ProfileUsageRoleCondition(ProfileUsageRole.bottom),
      ],
      lengthExpression: BinaryExpression(
        left: BinaryExpression(
          left: DimensionExpression.variable(
            DimensionVariable.constructionWidth,
          ),
          operator: BinaryOperator.subtract,
          right: DimensionExpression.constant(106.0),
        ),
        operator: BinaryOperator.divide,
        right: DimensionExpression.constant(4.0),
      ),
      quantity: CutQuantity.fixed(4),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Traverse 14 631 — (L−106)/4 ×4 par position '
          '(haute+basse = 8 pièces) [débitage p. 24, 4 vantaux · angles '
          'dérivés pp. 1-3; appariement montants face 69.2]',
    ),
    // --- Chicane 14 624: 1 × (H−92), 4-vantaux-only row --- The source
    // states NO position for the chicane, so this rule deliberately
    // carries NO role condition (gating it to a role would fabricate a
    // positional claim the table never makes). Any placed usage yields
    // its documented piece; multiples compose via usage.quantity. No
    // ambiguity risk: every other rule in this set is type-gated away
    // from ProfileType.other.
    ProfileCalculationRule(
      appliesTo: ProfileType.other,
      conditions: [
        VantauxCountCondition(4),
        OpeningTypeCondition(OpeningType.coulissante),
        ProfileReferenceCondition({'14 624'}),
      ],
      lengthExpression: BinaryExpression(
        left:
            DimensionExpression.variable(DimensionVariable.constructionHeight),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(92.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description: 'Chicane 14 624 — H−92 [débitage p. 24, 4 vantaux · '
          'angles dérivés pp. 1-3; position non indiquée par la source]',
    ),
  ],
);
