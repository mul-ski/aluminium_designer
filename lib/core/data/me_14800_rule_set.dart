/// The third REAL manufacturer-backed `SystemRuleSet` in AluVis, and the
/// first second-manufacturer consumer of the C8 companion-profile
/// capability: the Maghreb Extrusion Série 14800 frappe débitage table
/// "(1 VANTAIL)" from the Catalogue Général.
///
///   ME "Catalogue Général" (146-page client-supplied PDF), Série 14800
///   section: fiche technique pp. 48-49, PROFILOSCOPE pp. 50-53, débitage
///   "DÉBITAGE FENÊTRE À FRAPPE SÉRIE 14.800 (1 VANTAIL)" p. 65 (text
///   layer + hi-dpi visual verification of every row). Full transcription
///   and per-value citations: docs/VERIFIED_SOURCES.md, section S-3.
///
/// WHAT IS ENCODED — exactly the p. 65 printed rows, nothing else:
///
///   Dormant 14.800 ........... 2×L + 2×H      (45° imprimé)
///   Dormant 14.801 ........... 2×(L+46) + 2×(H+46)
///   Ouvrant 14.802 ........... 2×(L−35.2) + 2×(H−35.2)
///   Ouvrant 14.805 ........... 2×(L−35.2) + 2×(H−35.2)
///   Parclose 14.809/14.810 à côté d'ouvrant 14.802:
///     2×(L−117.6) + 2×(H−157.6)              (90° imprimé)
///   Parclose 14.809/14.810 à côté d'ouvrant 14.805:
///     2×(L−217.4) + 2×(H−257.4)              (90° imprimé)
///   Tige de crémone 14.811 ... 1×(H−90)       (90° imprimé)
///
/// COMPANION DEPENDENCY (the reason this set exists): the two parclose
/// rows are keyed in the source's own Ref column by the SIBLING OUVRANT
/// reference — the same shape Sepalumic 4200's OF traverse options hit
/// first (M-2 blocker 2, resolved in C8). The deduction is a pure lookup
/// on (own parclose ref, sibling ouvrant ref); no arithmetic relation
/// links it to any profile dimension. Encoded with
/// CompanionProfileReferenceCondition: a parclose rule matches only when
/// the section's sash carriers all carry the required ouvrant reference.
/// The simple/double glazing choice is carried entirely by the parclose
/// reference itself (14.809 = 16 mm simple face, 14.810 = 24 mm double
/// face, per the table's own sub-labels) — NO glass domain is consulted
/// or implied. Both parclose refs share one outcome-identical formula per
/// row, so the multi-reference set follows the outcome-identical-row
/// discipline.
///
/// MEMBER MAPPING: L = whole dormant-frame width, H = whole height (the
/// p. 65 table's own variables). Dormant/ouvrant members are role-scoped
/// one-piece positions: top/bottom carry the L-based formula, left/right
/// the H-based one — four placements × fixed(1) = the printed 2+2. The
/// parcloses follow the same mapping (2 L-pieces + 2 H-pieces printed).
/// The p. 56/60 coupes label frame profile 14820 beside sash 14802/14805
/// while the débitage table names only 14.800/14.801 — the tension is
/// recorded verbatim in docs/VERIFIED_SOURCES.md S-3 and the CUTS FOLLOW
/// THE PRINTED TABLE.
///
/// QUANTITY MAPPING (per-placement law): the printed Quantité column
/// counts whole-unit pieces for the 1-vantail unit; rules count per
/// matched placement, so every role-scoped rule here is fixed(1) and the
/// unit totals emerge from the four placements. The tige de crémone is
/// ONE piece per unit → fixed(1) on its single placement.
///
/// ANGLES: PRINTED per row on p. 65 (45° frame/sash mitres, 90°
/// parclose/tige square cuts) — direct provenance, no derivation note
/// needed (unlike the me-14600 set).
///
/// ROUTING SAFETY: every rule carries exact VantauxCountCondition(1) +
/// OpeningTypeCondition(francaise) — the fiche technique (p. 48) and the
/// coupes (pp. 56/60, "Porte ouvrante à la française") pin these rows to
/// the française 1-vantail configuration. NO 2-vantaux (or OB/soufflet/
/// fixe) débitage table exists in the catalogue for this series, so those
/// configurations surface as honest noRuleMatched. The tige rule is the
/// one deliberate no-role-condition rule (chicane 14 624 precedent: the
/// source states no position; collision-free as the only appliesTo-other
/// rule). The eight parclose cells stay mutually exclusive by (own ref ×
/// companion ref); AmbiguousRuleMatchException stays loud.
///
/// P1 GLASS RULES (p. 65 VITRAGE block, 1 vantail française): the source
/// prints one glass dimension per dominant ouvrant ref -- the glass
/// pane sizes to the section's sash carrier, the same way a
/// CompanionProfileReferenceCondition evaluates at section scope. Two
/// glass rules cover the two ouvrant refs 14.802 and 14.805 (the
/// same 1v française frame, different sash depth). Formulae: width
/// L−132, height H−132 beside 14.802; width L−185, height H−185
/// beside 14.805. Each rule's gating profile reference is the
/// section's dominant ouvrant ref (built by the calculator in P1
/// commit 4); the multi-ref set gates on the 2-vantail-gated
/// française configuration, same contract as the profile rules. NO 2v
/// glass row exists in p. 65 -- the 2v française domain stays
/// noRuleMatched with a documented blocker (ledger S-3).
///
/// P1 HARDWARE RULES (p. 65 ACCESSOIRES block, 1 vantail française):
/// 11 of the 12 ACCESSOIRES items have explicit quantities. The
/// "Clapet Anti-refoulement" row prints quantity `*` (variable);
/// that item is INTENTIONALLY left unencoded -- the source itself
/// does not state a quantity, so encoding any number would invent
/// data. The workshop view surfaces it as noRuleMatched (the same
/// honest-diagnostic contract as parclose selection in M-2
/// Sepalumic 4200). Each hardware item is its own rule; the
/// "hardware" / "accessory" category follows the model's split
/// (metal piece vs gasket). The three joint rules all print the
/// same "2L+2H" formula -- one rule per joint ref (different
/// identifiers, same outcome) so the BOM view can render per-ref
/// lines, exactly the outcome-identical-row discipline used in the
/// profile-side parclose encoding (C8).
///
/// NOT ENCODED (honest noRuleMatched; blockers in docs/VERIFIED_SOURCES.md
/// S-3): the 2-vantail glass + hardware (no rows in p. 65 -- the
/// 2v column of the débitage table lists profiles only, not glass
/// dimensions or hardware quantities); OB/soufflet/va-et-vient/fixe
/// configurations (no débitage tables); "Clapet Anti-refoulement"
/// quantity (source prints `*`, unstated); accessories AC-8xx that
/// don't appear in p. 65's 1v ACCESSOIRES block; every profile the
/// table does not name (14803/14804/14806/... — seeded, ruleless).
library;

import '../models/hardware_item.dart';
import '../models/opening.dart';
import '../models/profile.dart';
import '../models/profile_usage.dart';
import '../models/rules/calculation_rule.dart';
import '../models/rules/dimension_expression.dart';
import '../models/rules/glass_calculation_rule.dart';
import '../models/rules/hardware_calculation_rule.dart';
import '../models/rules/rule_condition.dart';
import '../models/rules/system_rule_set.dart';
import 'builtin_catalog_seed.dart';

const SystemRuleSet meSerie14800RuleSet = SystemRuleSet(
  systemId: meSerie14800Id,
  name: 'ME Série 14800 frappe — débitage 1 vantail (Catalogue Général)',
  isPlaceholder: false,
  rules: [
    // --- Dormant 14.800 (45° imprimé) ---
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.800'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionWidth,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 14.800 — L traverse haute '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 · '
          '45° imprimé]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.800'}),
        ProfileUsageRoleCondition(ProfileUsageRole.bottom),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionWidth,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 14.800 — L traverse basse '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 · '
          '45° imprimé]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.800'}),
        ProfileUsageRoleCondition(ProfileUsageRole.left),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionHeight,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 14.800 — H montant gauche '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 · '
          '45° imprimé]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.800'}),
        ProfileUsageRoleCondition(ProfileUsageRole.right),
      ],
      lengthExpression: DimensionExpression.variable(
        DimensionVariable.constructionHeight,
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 14.800 — H montant droit '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 · '
          '45° imprimé]',
    ),
    // --- Dormant 14.801 (45° imprimé) ---
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.801'}),
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
      description:
          'Dormant 14.801 — L+46 traverse haute '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 · '
          '45° imprimé]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.801'}),
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
      description:
          'Dormant 14.801 — L+46 traverse basse '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 · '
          '45° imprimé]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.801'}),
        ProfileUsageRoleCondition(ProfileUsageRole.left),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.add,
        right: DimensionExpression.constant(46.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 14.801 — H+46 montant gauche '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 · '
          '45° imprimé]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.dormant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.801'}),
        ProfileUsageRoleCondition(ProfileUsageRole.right),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.add,
        right: DimensionExpression.constant(46.0),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Dormant 14.801 — H+46 montant droit '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 · '
          '45° imprimé]',
    ),
    // --- Ouvrant 14.802 (45° imprimé) ---
    ProfileCalculationRule(
      appliesTo: ProfileType.ouvrant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.802'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionWidth),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(35.2),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Ouvrant 14.802 — L−35.2 traverse haute '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 · '
          '45° imprimé]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.ouvrant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.802'}),
        ProfileUsageRoleCondition(ProfileUsageRole.bottom),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionWidth),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(35.2),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Ouvrant 14.802 — L−35.2 traverse basse '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 · '
          '45° imprimé]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.ouvrant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.802'}),
        ProfileUsageRoleCondition(ProfileUsageRole.left),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(35.2),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Ouvrant 14.802 — H−35.2 montant gauche '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 · '
          '45° imprimé]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.ouvrant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.802'}),
        ProfileUsageRoleCondition(ProfileUsageRole.right),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(35.2),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Ouvrant 14.802 — H−35.2 montant droit '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 · '
          '45° imprimé]',
    ),
    // --- Ouvrant 14.805 (45° imprimé) ---
    ProfileCalculationRule(
      appliesTo: ProfileType.ouvrant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.805'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionWidth),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(35.2),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Ouvrant 14.805 — L−35.2 traverse haute '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 · '
          '45° imprimé]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.ouvrant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.805'}),
        ProfileUsageRoleCondition(ProfileUsageRole.bottom),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionWidth),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(35.2),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Ouvrant 14.805 — L−35.2 traverse basse '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 · '
          '45° imprimé]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.ouvrant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.805'}),
        ProfileUsageRoleCondition(ProfileUsageRole.left),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(35.2),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Ouvrant 14.805 — H−35.2 montant gauche '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 · '
          '45° imprimé]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.ouvrant,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.805'}),
        ProfileUsageRoleCondition(ProfileUsageRole.right),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(35.2),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.mitred45(),
      isPlaceholder: false,
      description:
          'Ouvrant 14.805 — H−35.2 montant droit '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 · '
          '45° imprimé]',
    ),
    // --- Parcloses à côté d'ouvrant 14.802 (90° imprimé; débit indexé
    // --- sur l'ouvrant du châssis) ---
    ProfileCalculationRule(
      appliesTo: ProfileType.other,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.809', '14.810'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
        CompanionProfileReferenceCondition({'14.802'}),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionWidth),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(117.6),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.square(),
      isPlaceholder: false,
      description:
          'Parclose 14.809/14.810 — L−117.6 à côté d\'ouvrant 14.802 '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 · '
          '90° imprimé; simple/double via le choix de la parclose]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.other,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.809', '14.810'}),
        ProfileUsageRoleCondition(ProfileUsageRole.bottom),
        CompanionProfileReferenceCondition({'14.802'}),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionWidth),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(117.6),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.square(),
      isPlaceholder: false,
      description:
          'Parclose 14.809/14.810 — L−117.6 à côté d\'ouvrant 14.802 '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 · '
          '90° imprimé; simple/double via le choix de la parclose]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.other,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.809', '14.810'}),
        ProfileUsageRoleCondition(ProfileUsageRole.left),
        CompanionProfileReferenceCondition({'14.802'}),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(157.6),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.square(),
      isPlaceholder: false,
      description:
          'Parclose 14.809/14.810 — H−157.6 à côté d\'ouvrant 14.802 '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 · '
          '90° imprimé; simple/double via le choix de la parclose]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.other,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.809', '14.810'}),
        ProfileUsageRoleCondition(ProfileUsageRole.right),
        CompanionProfileReferenceCondition({'14.802'}),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(157.6),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.square(),
      isPlaceholder: false,
      description:
          'Parclose 14.809/14.810 — H−157.6 à côté d\'ouvrant 14.802 '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 · '
          '90° imprimé; simple/double via le choix de la parclose]',
    ),
    // --- Parcloses à côté d'ouvrant 14.805 (90° imprimé) ---
    ProfileCalculationRule(
      appliesTo: ProfileType.other,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.809', '14.810'}),
        ProfileUsageRoleCondition(ProfileUsageRole.top),
        CompanionProfileReferenceCondition({'14.805'}),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionWidth),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(217.4),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.square(),
      isPlaceholder: false,
      description:
          'Parclose 14.809/14.810 — L−217.4 à côté d\'ouvrant 14.805 '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 · '
          '90° imprimé; simple/double via le choix de la parclose]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.other,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.809', '14.810'}),
        ProfileUsageRoleCondition(ProfileUsageRole.bottom),
        CompanionProfileReferenceCondition({'14.805'}),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(DimensionVariable.constructionWidth),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(217.4),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.square(),
      isPlaceholder: false,
      description:
          'Parclose 14.809/14.810 — L−217.4 à côté d\'ouvrant 14.805 '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 · '
          '90° imprimé; simple/double via le choix de la parclose]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.other,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.809', '14.810'}),
        ProfileUsageRoleCondition(ProfileUsageRole.left),
        CompanionProfileReferenceCondition({'14.805'}),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(257.4),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.square(),
      isPlaceholder: false,
      description:
          'Parclose 14.809/14.810 — H−257.4 à côté d\'ouvrant 14.805 '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 · '
          '90° imprimé; simple/double via le choix de la parclose]',
    ),
    ProfileCalculationRule(
      appliesTo: ProfileType.other,
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.809', '14.810'}),
        ProfileUsageRoleCondition(ProfileUsageRole.right),
        CompanionProfileReferenceCondition({'14.805'}),
      ],
      lengthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(257.4),
      ),
      quantity: CutQuantity.fixed(1),
      angles: CutAngles.square(),
      isPlaceholder: false,
      description:
          'Parclose 14.809/14.810 — H−257.4 à côté d\'ouvrant 14.805 '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 · '
          '90° imprimé; simple/double via le choix de la parclose]',
    ),
    // --- Tige de crémone 14.811 (90° imprimé; the source states no
    // --- position — chicane 14 624 precedent: no role condition) ---
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
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 · '
          '90° imprimé; position non déclarée par la source]',
    ),
  ],
  // --- P1 glass rules (p. 65 VITRAGE block, 1 vantail française) ---
  // One rule per dominant ouvrant ref: the section's dominant ouvrant
  // carrier is the gating ref (calculator builds the CalculationContext
  // with profile = that ref in P1 commit 4). The ProfileReferenceCondition
  // here keys on that dominant ref, so a 1v française section whose
  // dominant ouvrant is 14.802 sizes its pane to L−132/H−132, and one
  // whose dominant is 14.805 sizes to L−185/H−185. Mixed-sash (two
  // distinct refs) is caught upstream in the calculator (mixedSashCarrier
  // diagnostic), so no rule needs to defend against it here.
  glassRules: [
    GlassCalculationRule(
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.802'}),
      ],
      widthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionWidth,
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(132.0),
      ),
      heightExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(132.0),
      ),
      quantity: 1,
      isPlaceholder: false,
      description:
          'Vitrage à côté d\'ouvrant 14.802 — L−132 / H−132 '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 '
          'VITRAGE · 1v française]',
    ),
    GlassCalculationRule(
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
        ProfileReferenceCondition({'14.805'}),
      ],
      widthExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionWidth,
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(185.0),
      ),
      heightExpression: BinaryExpression(
        left: DimensionExpression.variable(
          DimensionVariable.constructionHeight,
        ),
        operator: BinaryOperator.subtract,
        right: DimensionExpression.constant(185.0),
      ),
      quantity: 1,
      isPlaceholder: false,
      description:
          'Vitrage à côté d\'ouvrant 14.805 — L−185 / H−185 '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 '
          'VITRAGE · 1v française]',
    ),
  ],
  // --- P1 hardware rules (p. 65 ACCESSOIRES block, 1 vantail française) ---
  // 11 of the 12 ACCESSOIRES items have explicit quantities from the
  // source. The "Clapet Anti-refoulement" row prints quantity `*`
  // (variable) -- INTENTIONALLY left unencoded (the source itself does
  // not state a quantity, so encoding any number would invent data;
  // the workshop view surfaces it as noRuleMatched, the same honest-
  // diagnostic contract as parclose selection in M-2). Each item is its
  // own rule. The category follows the model's split: hardware (metal
  // pieces) vs accessory (gaskets / joints). The three joint rules all
  // use the same 2L+2H formula -- one rule per joint ref so the BOM
  // view renders per-ref lines, exactly the outcome-identical-row
  // discipline used in the profile-side parclose encoding (C8).
  // Length-formula joints carry a lengthExpression; count-only items
  // (paumelles, equerres, etc.) carry no lengthExpression and the
  // calculator's lengthMm stays null.
  hardwareRules: [
    // Vérin de pose multi séries ×2
    HardwareCalculationRule(
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
      ],
      quantity: 2,
      reference: 'AC-805',
      name: 'Vérin de pose multi séries',
      category: HardwareCategory.hardware,
      isPlaceholder: false,
      description:
          'Vérin de pose multi séries ×2 '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 '
          'ACCESSOIRES · 1v française]',
    ),
    // Entraîneur moulé ×1
    HardwareCalculationRule(
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
      ],
      quantity: 1,
      reference: 'AC-822',
      name: 'Entraîneur moulé',
      category: HardwareCategory.hardware,
      isPlaceholder: false,
      description:
          'Entraîneur moulé ×1 '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 '
          'ACCESSOIRES · 1v française]',
    ),
    // Paumelles réversible pour OF ×2
    HardwareCalculationRule(
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
      ],
      quantity: 2,
      reference: 'AC-805P',
      name: 'Paumelles réversible pour OF',
      category: HardwareCategory.hardware,
      isPlaceholder: false,
      description:
          'Paumelles réversible pour OF ×2 '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 '
          'ACCESSOIRES · 1v française]',
    ),
    // Crémone-serrure ×1
    HardwareCalculationRule(
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
      ],
      quantity: 1,
      reference: 'AC-807',
      name: 'Crémone-serrure',
      category: HardwareCategory.hardware,
      isPlaceholder: false,
      description:
          'Crémone-serrure ×1 '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 '
          'ACCESSOIRES · 1v française]',
    ),
    // Support pour ouvrant ×1
    HardwareCalculationRule(
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
      ],
      quantity: 1,
      reference: 'AC-823',
      name: 'Support pour ouvrant',
      category: HardwareCategory.hardware,
      isPlaceholder: false,
      description:
          'Support pour ouvrant ×1 '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 '
          'ACCESSOIRES · 1v française]',
    ),
    // Point supp. + gâche ×2
    HardwareCalculationRule(
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
      ],
      quantity: 2,
      reference: 'AC-808',
      name: 'Point supp. + gâche',
      category: HardwareCategory.hardware,
      isPlaceholder: false,
      description:
          'Point supp. + gâche ×2 '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 '
          'ACCESSOIRES · 1v française]',
    ),
    // Crémone droit 1 fourche ×1
    HardwareCalculationRule(
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
      ],
      quantity: 1,
      reference: 'AC-808C',
      name: 'Crémone droit 1 fourche',
      category: HardwareCategory.hardware,
      isPlaceholder: false,
      description:
          'Crémone droit 1 fourche ×1 '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 '
          'ACCESSOIRES · 1v française]',
    ),
    // Equerre à pions ×8
    HardwareCalculationRule(
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
      ],
      quantity: 8,
      reference: 'AC-600',
      name: 'Équerre à pions',
      category: HardwareCategory.hardware,
      isPlaceholder: false,
      description:
          'Équerre à pions ×8 '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 '
          'ACCESSOIRES · 1v française]',
    ),
    // Joint battue 2L+2H
    HardwareCalculationRule(
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
      ],
      quantity: 1,
      lengthExpression: BinaryExpression(
        left: BinaryExpression(
          left: DimensionExpression.variable(
            DimensionVariable.constructionWidth,
          ),
          operator: BinaryOperator.multiply,
          right: DimensionExpression.constant(2.0),
        ),
        operator: BinaryOperator.add,
        right: BinaryExpression(
          left: DimensionExpression.variable(
            DimensionVariable.constructionHeight,
          ),
          operator: BinaryOperator.multiply,
          right: DimensionExpression.constant(2.0),
        ),
      ),
      reference: 'JO-825',
      name: 'Joint de battue',
      category: HardwareCategory.accessory,
      isPlaceholder: false,
      description:
          'Joint de battue 2L+2H '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 '
          'ACCESSOIRES · 1v française]',
    ),
    // Joint de vitrage 2L+2H
    HardwareCalculationRule(
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
      ],
      quantity: 1,
      lengthExpression: BinaryExpression(
        left: BinaryExpression(
          left: DimensionExpression.variable(
            DimensionVariable.constructionWidth,
          ),
          operator: BinaryOperator.multiply,
          right: DimensionExpression.constant(2.0),
        ),
        operator: BinaryOperator.add,
        right: BinaryExpression(
          left: DimensionExpression.variable(
            DimensionVariable.constructionHeight,
          ),
          operator: BinaryOperator.multiply,
          right: DimensionExpression.constant(2.0),
        ),
      ),
      reference: 'JO-826',
      name: 'Joint de vitrage',
      category: HardwareCategory.accessory,
      isPlaceholder: false,
      description:
          'Joint de vitrage 2L+2H '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 '
          'ACCESSOIRES · 1v française]',
    ),
    // Joint de vitrage portefeuille 2L+2H
    HardwareCalculationRule(
      conditions: [
        VantauxCountCondition(1),
        OpeningTypeCondition(OpeningType.francaise),
      ],
      quantity: 1,
      lengthExpression: BinaryExpression(
        left: BinaryExpression(
          left: DimensionExpression.variable(
            DimensionVariable.constructionWidth,
          ),
          operator: BinaryOperator.multiply,
          right: DimensionExpression.constant(2.0),
        ),
        operator: BinaryOperator.add,
        right: BinaryExpression(
          left: DimensionExpression.variable(
            DimensionVariable.constructionHeight,
          ),
          operator: BinaryOperator.multiply,
          right: DimensionExpression.constant(2.0),
        ),
      ),
      reference: 'JO-828',
      name: 'Joint de vitrage portefeuille',
      category: HardwareCategory.accessory,
      isPlaceholder: false,
      description:
          'Joint de vitrage portefeuille 2L+2H '
          '[débitage 14800 frappe 1 vantail, Catalogue Général p. 65 '
          'ACCESSOIRES · 1v française]',
    ),
  ],
);
