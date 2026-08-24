/// The first REAL manufacturer-backed `SystemRuleSet` in AluVis: the
/// "2 vantaux" and "3 vantaux (avec fixe)" columns of the Série 14 600
/// débitage (cut-length) table, page 24 of the source document.
///
///   "Descriptif Coulissant Série 14 600 — MAGHREB EXTRUSION" (31-page
///   client PDF; descriptif dated Larache 14/10/2024), p. 24 DEBITAGE
///   table, transcribed and cited per value in docs/VERIFIED_SOURCES.md
///   (two low-dpi misreads were caught and corrected there by re-reading
///   at 150 dpi -- including this table's (L-64)/2).
///
/// WHAT IS ENCODED HERE -- exactly the documented rows of BOTH encoded
/// columns, nothing else:
///
///   2 VANTAUX                          | 3 VANTAUX (AVEC FIXE)
///   Dormant 14 617 / 14 627 ........... | same: 2+2 × (L ; H)
///   Dormant 14 618 / 14 628 / 14 626 .. | same: 2+2 × (L+46 ; H+46)
///   Montant latéral 14 622/623/632/633  | same: 2 × (H−74)
///   Montant central 14 619/620/630 ..... | same: 2 × (H−74)
///   Traverse 14 621 .... 4 × (L−64)/2 .. | 6 × (L−25)/3
///   Traverse 14 631 .... 4 × (L−85)/2 .. | 6 × (L−47)/3
///
/// L = whole construction width, H = whole construction height (the
/// table's own variables; both exist as DimensionVariable values). The
/// deductions 74, 64, 85, 46, 25 and 47 are printed constants on p. 24,
/// not derived from profile dimensions -- no Profile.width/depth value
/// feeds any rule.
///
/// QUANTITY MAPPING (per-placement law, see CutQuantity's doc): the
/// table counts pieces PER UNIT; AluVis rules count pieces PER MATCHED
/// USAGE PLACEMENT. A unit is modelled as ONE ouvrant coulissante
/// section whose vantauxCount selects the column:
///
///   - dormant/montant latéral placements are role-scoped one-piece
///     positions, so those rules yield fixed(1) per placement and the
///     unit totals emerge from the placements themselves;
///   - a top-or-bottom traverse placement spans EVERY panel's track
///     segment ((L−64)/2 or (L−85)/2 at 2 vantaux -> fixed(2);
///     (L−25)/3 or (L−47)/3 at 3 vantaux -> fixed(3)) -- top + bottom
///     placements reach the documented 4 or 6 pieces;
///   - a central-mullion placement uses the intermediate role (the only
///     fitting position for members BETWEEN the leaves) and covers both
///     meeting stiles, so that rule yields fixed(2) per placement --
///     the documented 2 × (H−74) in both columns.
///
/// ROUTING SAFETY: every rule carries an exact
/// VantauxCountCondition(2|3) because only these two columns are
/// encoded -- the 4-vantaux column uses different traverse
/// formulas/quantities and would fabricate wrong cuts if served these
/// rules. Every rule also carries OpeningTypeCondition(coulissante):
/// the source is a coulissant-ONLY descriptif, so any other opening
/// type is covered by NO page of it and must surface as a noRuleMatched
/// issue, not as real cuts (the condition also implies
/// SectionKind.ouvrant). Traverses are routed to their exact reference
/// (14 621 vs 14 631 -- different deductions); dormant/mullion rows
/// list exactly the references their table row names (mullions
/// 14 650 / 14 643 are NOT in the row and stay unmatched). Dormant/
/// montant/mullion rules are duplicated per column because their
/// formulas happen to coincide at 2 and 3 vantaux while quantities'
/// placement mapping stays the same -- exact-column gating keeps every
/// rule tied to its printed row instead of relying on that coincidence.
/// Rule selection throws AmbiguousRuleMatchException rather than
/// guessing, but roles/reference sets keep every context disjoint by
/// construction.
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
/// NOT ENCODED (still honest noRuleMatched issues): chicane 14 624 and
/// the ENTIRE 4-vantaux column (8 × (L−60)/4, 8 × (L−106)/4, doubled
/// montant/mullion counts). See docs/VERIFIED_SOURCES.md for the full
/// table and status.
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
  ],
);
