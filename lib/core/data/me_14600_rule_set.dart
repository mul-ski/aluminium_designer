/// The first REAL manufacturer-backed `SystemRuleSet` in AluVis: the
/// "2 vantaux" column of the Série 14 600 débitage (cut-length) table,
/// page 24 of the source document.
///
///   "Descriptif Coulissant Série 14 600 — MAGHREB EXTRUSION" (31-page
///   client PDF; descriptif dated Larache 14/10/2024), p. 24 DEBITAGE
///   table, transcribed and cited per value in docs/VERIFIED_SOURCES.md
///   (two low-dpi misreads were caught and corrected there by re-reading
///   at 150 dpi -- including this column's own (L-64)/2).
///
/// WHAT IS ENCODED HERE -- exactly the "2 vantaux" column, the six
/// table rows that have a 2-vantaux entry (the chicane row does not),
/// nothing else:
///
///   Dormant 14 617 / 14 627 ............ 2+2 × (L ; H)
///   Dormant 14 618 / 14 628 / 14 626 .. 2+2 × (L+46 ; H+46)
///   Montant latéral 14 622/623/632/633 . 2 × (H−74)
///   Montant central 14 619/620/630 ..... 2 × (H−74)   [intermediate role]
///   Traverse 14 621 .................... 4 × (L−64)/2
///   Traverse 14 631 .................... 4 × (L−85)/2
///
/// L = whole construction width, H = whole construction height (the
/// table's own variables; both exist as DimensionVariable values). The
/// deductions 74, 64, 85 and 46 are printed constants on p. 24, not
/// derived from profile dimensions -- no Profile.width/depth value feeds
/// any rule.
///
/// QUANTITY MAPPING (per-placement law, see CutQuantity's doc): the
/// table counts pieces PER UNIT; AluVis rules count pieces PER MATCHED
/// USAGE PLACEMENT. A 2-vantaux unit is modelled as one ouvrant section
/// with vantauxCount = 2:
///
///   - dormant/montant latéral placements are role-scoped one-piece
///     positions (top+bottom dormants at L or L+46, left+right at H or
///     H+46; left+right montants), so those rules yield fixed(1) per
///     placement and the unit totals emerge from the placements
///     themselves;
///   - a top-or-bottom traverse placement spans BOTH leaves' track half
///     ((L−64)/2 or (L−85)/2 each), so those rules yield fixed(2) per
///     placement -- top + bottom placements reach the documented 4
///     pieces;
///   - a central-mullion placement uses the intermediate role (the only
///     fitting position for members BETWEEN the leaves) and covers BOTH
///     leaves' meeting stile, so that rule yields fixed(2) per placement
///     -- the documented 2 × (H−74).
///
/// ROUTING SAFETY: every rule carries VantauxCountCondition(2) because
/// only the "2 vantaux" column is encoded -- the 3/4-vantaux columns use
/// different traverse formulas/quantities and would fabricate wrong cuts
/// if served these rules. Every rule also carries
/// OpeningTypeCondition(coulissante): the source is a coulissant-ONLY
/// descriptif, so an oscillo-battant/française section at 2 vantaux is
/// covered by NO page of it and must surface as a noRuleMatched issue,
/// not as real cuts (the condition also implies SectionKind.ouvrant).
/// Traverses are routed to their exact reference (14 621 vs 14 631 --
/// different deductions); dormant/mullion rows list exactly the
/// references their table row names (mullions 14 650 / 14 643 are NOT in
/// the row and stay unmatched). Rule selection throws
/// AmbiguousRuleMatchException rather than guessing, but roles/reference
/// sets keep every context disjoint by construction.
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
/// NOT ENCODED (still honest noRuleMatched issues): chicane 14 624
/// (4-vantaux-only row) and EVERY 3/4-vantaux formula ((L−25)/3,
/// (L−47)/3, (L−60)/4, (L−106)/4; montant/mullion quantities double).
/// The 3-vantaux column additionally needs an explicit modeling decision
/// for its "avec fixe" configurations before anything is encoded. See
/// docs/VERIFIED_SOURCES.md for the full table and status.
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
  name: 'Maghreb Extrusion Série 14600 — débitage 2 vantaux (p. 24)',
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
  ],
);
