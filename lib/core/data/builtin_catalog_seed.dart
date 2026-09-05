/// Real `Manufacturer`/`ProfileSystem` records shipped with the app, and
/// the merge logic that adds them to whatever catalog a user already has
/// on disk.
///
/// EVERY value in this seed is transcribed from one identified source
/// document, cited per value in `docs/VERIFIED_SOURCES.md`:
///
///   "Descriptif Coulissant Série 14 600 — MAGHREB EXTRUSION" (31-page
///   PDF supplied by the client; descriptif dated Larache 14/10/2024,
///   EXTRUMAROC alloy/finishing certificates, TECNITAS avis technique
///   BGC N° 1627/2016). Pages 4–13 are PROFILOSCOPE profile sheets
///   (read visually from high-dpi renders; the PDF has no text layer
///   there), pages 20/24 carry the cut-length (débitage) formulas,
///   page 27 the certified test dimensions.
///
/// HARD DOMAIN RULE: nothing here is inferred, estimated, or completed
/// from domain knowledge. Where the document does not state a value, the
/// value is unknown: `Profile.width`/`depth`/`weightPerMeter` use `0` as
/// the explicit unknown marker (same convention as the C2 aggregation
/// work), and `ProfileSystemMetadata.thermalBreak` stays `null` because
/// the document never mentions a thermal break for this series -- null
/// means "not stated", never "no".
///
/// CLEAN-SLATE NOTE: earlier seeds also shipped Aluminium du Maroc
/// (Cuzco 713 OM), Sepalumic Maroc (Coulissant 8800/6700/6900), Menara
/// Profil (Targa Plus) and Maghreb Extrusion (DOMAL) as name-only
/// placeholders. They were removed when the Maghreb Extrusion document
/// made real verified data available: shipping unverified placeholder
/// records next to a verified catalog invites mistaking one for the
/// other. Removing them from the seed does NOT delete them from any
/// existing install -- `withBuiltInCatalogSeed` only ever ADDS missing
/// records and never removes or rewrites what a catalog already
/// contains (see its doc comment below), so pre-existing entries stay
/// until the user deletes them through the normal catalog UI -- with one
/// narrow exception: [adoptBuiltInRuleSets] refreshes ONLY the
/// `ruleSetId` of present built-in systems still pointing at the
/// placeholder, so installs predating a system's real rules adopt them.
library;

import '../models/catalog.dart';
import '../models/manufacturer.dart';
import '../models/opening.dart';
import '../models/profile.dart';
import '../models/profile_system.dart';
import '../models/profile_system_metadata.dart';

/// Manufacturer id for Maghreb Extrusion (ME). A fixed, stable string
/// (not a generated timestamp id like user-created manufacturers get)
/// so this seed is idempotent -- re-running it must always refer to the
/// same manufacturer record, never create a duplicate with a different
/// id on a later run. Reused unchanged from the earlier seed generation
/// so catalogs that already contain this manufacturer keep matching it.
const String maghrebExtrusionId = 'builtin-maghreb-extrusion';

/// System id for the Série 14600 coulissante, fixed for the same
/// idempotency reason as [maghrebExtrusionId].
const String meSerie14600Id = 'builtin-me-14600';

/// Display name used consistently on the manufacturer record and as
/// [Profile.manufacturer] on every seeded profile of this system.
const String _maghrebExtrusionName = 'Maghreb Extrusion (ME)';

/// Display name of the seeded system; also [Profile.system] on every
/// seeded profile.
const String _meSerie14600Name = 'Série 14600 Coulissant';

const Manufacturer maghrebExtrusion = Manufacturer(
  id: maghrebExtrusionId,
  name: _maghrebExtrusionName,
  isBuiltIn: true,
);

/// Every profile of the Série 14600 transcribed from the source
/// document's PROFILOSCOPE sheets, with the sheet page cited in each
/// doc comment. The full transcription table -- including values the
/// `Profile` model has no field for (sub-dimensions like 14 640's
/// 42.00 clip-stem spacing) and the exact per-sheet orientation
/// conventions -- lives in `docs/VERIFIED_SOURCES.md`.
///
/// Conventions used below, applied uniformly and documented per profile
/// in `docs/VERIFIED_SOURCES.md`:
///   - `width` = the profile's visible face dimension, `depth` = its
///     wall-plane dimension, as drawn on its sheet.
///   - `0` = the sheet does not label that dimension (absence means
///     unknown; it is NEVER a measured zero).
///   - `weightPerMeter` = 0 everywhere: no sheet states a weight per
///     metre (same unknown-marker convention as above).
///   - `inertiaIxxCm4`/`inertiaIyyCm4` = section inertias as printed
///     ("Inertie en cm4"); `0` where a value/axis is not stated on the
///     sheet. 20 of 38 profiles carry both printed values; 17 state no
///     inertia; 14 650's single printed "69.47" has NO axis attribution
///     on the sheet, so BOTH stay 0 until that axis is verified
///     externally -- storing it as IXX would be inference.
///   - `type` follows the sheet's own section heading (DORMANTS ->
///     dormant, MONTANTS LATERAUX -> montant, MONTANTS CENTRAUX ->
///     mullion, TRAVERSE HAUTE ET BASSE -> traverse, everything else ->
///     other), never an inferred role.
const List<Profile> _me14600Profiles = [
  // --- DORMANTS (PROFILOSCOPE p.4) ---
  Profile(
    id: 'builtin-me-14600-14626',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 626',
    name: 'Dormant',
    type: ProfileType.dormant,
    width: 44.66,
    depth: 66.34,
    weightPerMeter: 0,
    // Inertie en cm4 (sheet-labeled).
    inertiaIxxCm4: 7.9,
    inertiaIyyCm4: 26.14,
  ),
  Profile(
    id: 'builtin-me-14600-14627',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 627',
    name: 'Dormant',
    type: ProfileType.dormant,
    width: 44.4,
    depth: 66.34,
    weightPerMeter: 0,
    // Inertie en cm4 (sheet-labeled).
    inertiaIxxCm4: 6.66,
    inertiaIyyCm4: 23.16,
  ),
  Profile(
    id: 'builtin-me-14600-14628',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 628',
    name: 'Dormant',
    type: ProfileType.dormant,
    width: 44.4,
    depth: 66.34,
    weightPerMeter: 0,
    // Inertie en cm4 (sheet-labeled).
    inertiaIxxCm4: 10.24,
    inertiaIyyCm4: 27.22,
  ),
  // --- DORMANTS (PROFILOSCOPE p.5; 14 640 sits under the sheet's own
  // --- DORMANTS heading even though the p.20 coupe shows it used at a
  // --- galandage corner with the (L-64)/2 traverse formula) ---
  Profile(
    id: 'builtin-me-14600-14617',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 617',
    name: 'Dormant',
    type: ProfileType.dormant,
    width: 44.4,
    depth: 44.0,
    weightPerMeter: 0,
    // Inertie en cm4 (sheet-labeled).
    inertiaIxxCm4: 4.95,
    inertiaIyyCm4: 13.65,
  ),
  Profile(
    id: 'builtin-me-14600-14640',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 640',
    name: 'Dormant',
    type: ProfileType.dormant,
    // Sheet labels only horizontal dims: 68.15 overall (stored as depth)
    // and 42.00 clip-stem spacing (no model field; see VERIFIED_SOURCES).
    // The vertical face dimension is not labeled -> unknown.
    width: 0,
    depth: 68.15,
    weightPerMeter: 0,
    // Inertie en cm4 (sheet-labeled).
    inertiaIxxCm4: 6.7,
    inertiaIyyCm4: 17.07,
  ),
  Profile(
    id: 'builtin-me-14600-14618',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 618',
    name: 'Dormant',
    type: ProfileType.dormant,
    width: 44.4,
    depth: 44.0,
    weightPerMeter: 0,
    // Inertie en cm4 (sheet-labeled).
    inertiaIxxCm4: 9.13,
    inertiaIyyCm4: 16.90,
  ),
  // --- DORMANTS FRAPPE (PROFILOSCOPE p.6) ---
  Profile(
    id: 'builtin-me-14600-14818',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 818',
    name: 'Dormant frappé',
    type: ProfileType.dormant,
    width: 42.75,
    depth: 66.34,
    weightPerMeter: 0,
    // Inertie en cm4 (sheet-labeled).
    inertiaIxxCm4: 3,
    inertiaIyyCm4: 13.35,
  ),
  Profile(
    id: 'builtin-me-14600-14820',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 820',
    name: 'Dormant frappé',
    type: ProfileType.dormant,
    width: 42.7,
    depth: 44.0,
    weightPerMeter: 0,
    // Inertie en cm4 (sheet-labeled).
    inertiaIxxCm4: 3.67,
    inertiaIyyCm4: 6.51,
  ),
  // --- MONTANTS LATERAUX (PROFILOSCOPE p.7). 14 633 / 14 623 are the
  // --- reinforced companions of 14 632 / 14 622; their sheets label the
  // --- depth (69.2 / 56) but not the total face width -> width unknown.
  Profile(
    id: 'builtin-me-14600-14632',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 632',
    name: 'Montant latéral',
    type: ProfileType.montant,
    width: 33.4,
    depth: 69.2,
    weightPerMeter: 0,
    // Inertie en cm4 (sheet-labeled).
    inertiaIxxCm4: 7.1,
    inertiaIyyCm4: 14.7,
  ),
  Profile(
    id: 'builtin-me-14600-14633',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 633',
    name: 'Montant latéral',
    type: ProfileType.montant,
    width: 0,
    depth: 69.2,
    weightPerMeter: 0,
    // Inertie en cm4 (sheet-labeled).
    inertiaIxxCm4: 20.16,
    inertiaIyyCm4: 23.3,
  ),
  Profile(
    id: 'builtin-me-14600-14622',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 622',
    name: 'Montant latéral',
    type: ProfileType.montant,
    width: 33.0,
    depth: 56.0,
    weightPerMeter: 0,
    // Inertie en cm4 (sheet-labeled).
    inertiaIxxCm4: 6.95,
    inertiaIyyCm4: 4.8,
  ),
  Profile(
    id: 'builtin-me-14600-14623',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 623',
    name: 'Montant latéral',
    type: ProfileType.montant,
    width: 0,
    depth: 56.0,
    weightPerMeter: 0,
    // Inertie en cm4 (sheet-labeled).
    inertiaIxxCm4: 10.93,
    inertiaIyyCm4: 13.44,
  ),
  // --- MONTANTS CENTRAUX (PROFILOSCOPE p.8). Only 14 619 has both dims
  // --- labeled (41.3 face x 33.60 depth); the others label one or none.
  Profile(
    id: 'builtin-me-14600-14619',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 619',
    name: 'Montant central',
    type: ProfileType.mullion,
    width: 41.3,
    depth: 33.6,
    weightPerMeter: 0,
    // Inertie en cm4 (sheet-labeled).
    inertiaIxxCm4: 4.67,
    inertiaIyyCm4: 3.405,
  ),
  Profile(
    id: 'builtin-me-14600-14620',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 620',
    name: 'Montant central (demi-rond)',
    type: ProfileType.mullion,
    width: 41.3,
    depth: 0,
    weightPerMeter: 0,
    // Inertie en cm4 (sheet-labeled).
    inertiaIxxCm4: 13.80,
    inertiaIyyCm4: 5.7,
  ),
  Profile(
    id: 'builtin-me-14600-14630',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 630',
    name: 'Montant central',
    type: ProfileType.mullion,
    width: 41.3,
    depth: 0,
    weightPerMeter: 0,
    // Inertie en cm4 (sheet-labeled).
    inertiaIxxCm4: 37,
    inertiaIyyCm4: 10.23,
  ),
  Profile(
    id: 'builtin-me-14600-14650',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 650',
    name: 'Montant central',
    type: ProfileType.mullion,
    // Sheet labels only the vertical 96.19 (depth); face not labeled.
    width: 0,
    depth: 96.19,
    weightPerMeter: 0,
  ),
  // --- TRAVERSE HAUTE ET BASSE (PROFILOSCOPE p.9). Sheets label the
  // --- depth (63 / 63.00); the face width is not labeled.
  Profile(
    id: 'builtin-me-14600-14621',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 621',
    name: 'Traverse haute et basse',
    type: ProfileType.traverse,
    width: 0,
    depth: 63.0,
    weightPerMeter: 0,
    // Inertie en cm4 (sheet-labeled).
    inertiaIxxCm4: 4.24,
    inertiaIyyCm4: 9.52,
  ),
  Profile(
    id: 'builtin-me-14600-14631',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 631',
    name: 'Traverse haute et basse',
    type: ProfileType.traverse,
    width: 0,
    depth: 63.0,
    weightPerMeter: 0,
    // Inertie en cm4 (sheet-labeled).
    inertiaIxxCm4: 4.93,
    inertiaIyyCm4: 10.2,
  ),
  // --- CAPOT DE FINITION (PROFILOSCOPE p.9): cache-rail covers, no
  // --- dimensions labeled on the sheet.
  Profile(
    id: 'builtin-me-14600-14603',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 603',
    name: 'Cache rail intérieur et extérieur',
    type: ProfileType.other,
    width: 0,
    depth: 0,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-me-14600-14604',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 604',
    name: 'Cache rail intérieur',
    type: ProfileType.other,
    width: 0,
    depth: 0,
    weightPerMeter: 0,
  ),
  // --- FINITION GALANDAGE / CHICANES (PROFILOSCOPE p.10) ---
  Profile(
    id: 'builtin-me-14600-14639',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 639',
    name: 'Finition galandage',
    type: ProfileType.other,
    width: 28.5,
    depth: 16.9,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-me-14600-14624',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 624',
    name: 'Chicane 4 vantaux 2 rails',
    type: ProfileType.other,
    // Single labeled dim (25.80 horizontal); depth not labeled.
    width: 25.8,
    depth: 0,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-me-14600-14634',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 634',
    name: 'Chicane pour chassis d\'angle',
    type: ProfileType.other,
    // Labeled: 26.30 horizontal, 42.70 vertical, plus sub-dim 14.00
    // (top clip width, no model field -- see VERIFIED_SOURCES).
    width: 26.3,
    depth: 42.7,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-me-14600-14635',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 635',
    name: 'Chicane pour chassis d\'angle',
    type: ProfileType.other,
    // Single labeled dim (63.70 vertical = depth); face not labeled.
    width: 0,
    depth: 63.7,
    weightPerMeter: 0,
  ),
  // --- DORMANT MONO RAIL / COULISSE-FIXE / COMPLEMENT (PROFILOSCOPE
  // --- p.11); 14 625's own heading is COMPLEMENT MULTI RAILS.
  Profile(
    id: 'builtin-me-14600-14638',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 638',
    name: 'Dormant mono rail',
    type: ProfileType.dormant,
    width: 44.66,
    depth: 42.0,
    weightPerMeter: 0,
    // Inertie en cm4 (sheet-labeled).
    inertiaIxxCm4: 4.37,
    inertiaIyyCm4: 4.067,
  ),
  Profile(
    id: 'builtin-me-14600-14637',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 637',
    name: 'Dormant coulisse / fixe',
    type: ProfileType.dormant,
    width: 44.61,
    depth: 68.35,
    weightPerMeter: 0,
    // Inertie en cm4 (sheet-labeled).
    inertiaIxxCm4: 6.21,
    inertiaIyyCm4: 22.6,
  ),
  Profile(
    id: 'builtin-me-14600-14625',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 625',
    name: 'Complément multi rails',
    type: ProfileType.other,
    width: 44.4,
    depth: 42.0,
    weightPerMeter: 0,
    // Inertie en cm4 (sheet-labeled).
    inertiaIxxCm4: 3.2,
    inertiaIyyCm4: 8.12,
  ),
  // --- COULIFIX FINITION (PROFILOSCOPE p.11) ---
  Profile(
    id: 'builtin-me-14600-14610',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 610',
    name: 'Profile finition Coulifix',
    type: ProfileType.other,
    width: 41.0,
    depth: 23.1,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-me-14600-14643',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 643',
    name: 'Montant central Coulifix',
    type: ProfileType.mullion,
    width: 40.0,
    depth: 41.8,
    weightPerMeter: 0,
  ),
  // --- PROFILES DE LIAISON (PROFILOSCOPE p.12) ---
  Profile(
    id: 'builtin-me-14600-14827',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 827',
    name: 'Profile de liaison',
    type: ProfileType.other,
    width: 44.0,
    depth: 8.7,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-me-14600-14817',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 817',
    name: 'Profile de liaison',
    type: ProfileType.other,
    // Single labeled dim (47.90 horizontal); depth not labeled.
    width: 47.9,
    depth: 0,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-me-14600-85627',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '85 627',
    name: 'Profile de liaison',
    type: ProfileType.other,
    // No dimensions labeled on the sheet.
    width: 0,
    depth: 0,
    weightPerMeter: 0,
  ),
  // --- PARCLOSES (PROFILOSCOPE p.12) ---
  Profile(
    id: 'builtin-me-14600-14810',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 810',
    name: 'Parclose',
    type: ProfileType.other,
    width: 22.5,
    depth: 19.5,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-me-14600-14809',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 809',
    name: 'Parclose',
    type: ProfileType.other,
    width: 16.0,
    depth: 19.5,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-me-14600-14809-1',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 809/1',
    name: 'Parclose',
    type: ProfileType.other,
    width: 12.5,
    depth: 19.5,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-me-14600-14819',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 819',
    name: 'Parclose',
    type: ProfileType.other,
    // Single labeled dim (4.50 horizontal); depth not labeled.
    width: 4.5,
    depth: 0,
    weightPerMeter: 0,
  ),
  // --- COUVRES JOINTS (PROFILOSCOPE p.12): only the height is labeled.
  Profile(
    id: 'builtin-me-14600-14601',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 601',
    name: 'Couvre joint',
    type: ProfileType.other,
    width: 0,
    depth: 26.0,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-me-14600-14602',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14600Name,
    reference: '14 602',
    name: 'Couvre joint',
    type: ProfileType.other,
    width: 0,
    depth: 33.1,
    weightPerMeter: 0,
  ),
];

/// Maghreb Extrusion "Série 14 600" sliding (coulissant) system --
/// portes-fenêtres et fenêtres coulissantes -- with every system-level
/// fact the source document states, and nothing it doesn't.
///
/// `ruleSetId` points at `meSerie14600RuleSet` (me_14600_rule_set.dart,
/// registered in rule_set_resolution.dart): the FIRST REAL manufacturer
/// rules in AluVis, encoding the COMPLETE débitage table of the document
/// (p. 24) -- all three configuration columns ("2 vantaux", "3 vantaux
/// (avec fixe)", "4 vantaux"), all seven rows: dormants 14 617/14 627
/// (2+2 × (L ; H)) and 14 618/14 628/14 626 (2+2 × (L+46 ; H+46)),
/// montants latéraux 14 622/623/632/633 and centraux 14 619/620/630
/// ((H−74), quantities doubling at 4 vantaux), traverses 14 621 / 14 631
/// (4/6/8 pieces with /2, /3, /4 divisors per column) and chicane 14 624
/// (H−92, 4 vantaux only) -- routed by profile reference + exact
/// vantaux count + opening type + role so no uncovered configuration can
/// silently match. The 3-vantaux unit is modelled as one ouvrant
/// coulissante section; which third is fixed is not stated by the table,
/// affects no cut length, and is not represented. The chicane rule alone
/// carries no role condition because the source states no position for
/// it. See docs/VERIFIED_SOURCES.md for the full transcription and the
/// placement-mapping doctrine.
///
/// `metadata` carries the system-level verified facts (frame depths
/// 44/66.34, sash stile depths 56/69.2, glazing rebate 26 with 6-22 mm
/// glass, assembly/drainage/finish notes, and the certified test
/// dimensions 1600x1800 / 2500x2500 from p.27). `thermalBreak` is left
/// null: the document never mentions one for this series.
const ProfileSystem meSerie14600 = ProfileSystem(
  id: meSerie14600Id,
  manufacturer: _maghrebExtrusionName,
  manufacturerId: maghrebExtrusionId,
  name: _meSerie14600Name,
  ruleSetId: meSerie14600Id,
  profiles: _me14600Profiles,
  supportedOpenings: [OpeningType.coulissante],
  isBuiltIn: true,
  metadata: ProfileSystemMetadata(
    // "Dormants tubulaires de 44 mm ou 66 mm" (p.1-3 text); exact sheet
    // values 44.00 / 66.34 (pp.4-6).
    frameDepthOptionsMm: [44.0, 66.34],
    // "Montant latéral simple ou renforcé tubulaire de 56 mm ou 69 mm"
    // (p.1-3 text); exact sheet values 56.00 / 69.2 (p.7).
    sashStileDepthOptionsMm: [56.0, 69.2],
    // "Montant central ... tubulaire de 41 mm" (p.1-3) is the tube FACE
    // (41.3 on the sheets), not a depth -- the meeting-stile DEPTH is
    // not stated as a system value, so this field stays null rather
    // than storing a face dimension under a depth field name.
    glazingRebateMm: 26.0,
    glazingMinMm: 6.0,
    glazingMaxMm: 22.0,
    assemblyNote:
        'Dormants assemblés en coupe d\'onglet avec équerres; ouvrant à '
        'prise en feuillure des vitrages en portefeuille.',
    drainageNote:
        'Drainage par trous oblongs sur la traverse basse du dormant, '
        'avec busettes à clapets anti-retour d\'eau.',
    finishNote:
        'Laquage 60 µ QUALICOAT (licence N° 1106 mention SEASIDE) ou '
        'anodisation 15 µ QUALANOD (licence N° 1902); alliage 6063 '
        '(EXTRUMAROC). Le descriptif p.27 mentionne par ailleurs '
        '\'alliage d\'aluminium 6060 suivant normes AFNOR\'.',
    // p.27 states "DIM : 1600 x 1800 / 2500 x 2500" for the series --
    // the two certified test sizes. Stored as the two documented
    // envelopes; the advisory limit check warns only when a
    // construction exceeds EVERY listed envelope (a 2000x2000 design
    // is inside the 2500x2500 one). No other max-dimension table
    // exists anywhere in the document.
    dimensionLimits: [
      DimensionLimit(maxWidthMm: 1600, maxHeightMm: 1800),
      DimensionLimit(maxWidthMm: 2500, maxHeightMm: 2500),
    ],
    sourceDescription:
        '"Descriptif Coulissant Série 14 600 — MAGHREB EXTRUSION", PDF '
        '31 pages fourni par le client (descriptif daté Larache '
        '14/10/2024; certificats alliage/laquage/anodisation EXTRUMAROC; '
        'avis technique TECNITAS BGC N° 1627/2016, 09/05/2016). '
        'Transcription page à page: texte pp.1-3 + 26-31, planches '
        'PROFILOSCOPE pp.4-13 lues visuellement sur rendus haute '
        'résolution. Détail par valeur: docs/VERIFIED_SOURCES.md.',
  ),
);

// ============================================================================
// MAGHREB EXTRUSION — Série 14800 (fenêtre/porte-fenêtre à frappe)
// ============================================================================

/// System id for the Série 14800 frappe, fixed for the same idempotency
/// reason as [maghrebExtrusionId].
const String meSerie14800Id = 'builtin-me-14800';

/// Display name of the seeded 14800 system; also [Profile.system] on
/// every seeded profile of this system.
const String _meSerie14800Name = 'Série 14800 Frappe';

/// Every profile of the Série 14800 transcribed from the Catalogue
/// Général's PROFILOSCOPE sheets for this series (pdf pp. 50-53), with the
/// sheet page cited per profile block. Full transcription table (including
/// sub-dimensions the model has no field for) in `docs/VERIFIED_SOURCES.md`,
/// section S-3.
///
/// Conventions: identical to the Série 14600 block above (`width` = face,
/// `depth` = wall-plane, `0` = not labeled, `weightPerMeter` = 0
/// everywhere, inertias only where the sheet prints them).
///
/// TYPE SOURCING: these sheets carry NO family headings (unlike the 14600
/// descriptif's headed sheets). Types are assigned only where a source
/// states them: the débitage table (p. 65) names 14.800/14.801 "Dormant",
/// 14.802/14.805 "Ouvrant", the parcloses "Pareclose"; the S-1 descriptif
/// sheet heading "DORMANTS FRAPPE" covers 14820/14818; 14 827/14 817 were
/// under S-1's "PROFILES DE LIAISON" heading. Every other profile keeps
/// `ProfileType.other` with a "type not stated" note -- shape-based
/// guessing (mullion/ouvrant) would violate the domain rule that types
/// follow source headings, never inference.
///
/// REFERENCE NOTATION: the débitage table (p. 65) prints dotted
/// references ("14.802") while the profile sheets print undotted ones
/// ("14802"). Each seeded reference follows the notation of the source
/// element that names it: dotted for the seven profiles the débitage
/// table names (the rule set keys on that table), sheet notation for the
/// rest. Both notations are recorded per reference in the ledger.
const List<Profile> _me14800Profiles = [
  // --- DORMANTS FRAPPE (PROFILOSCOPE p.50; heading cross-sourced from
  // --- the S-1 descriptif's own "DORMANTS FRAPPE" sheet) ---
  Profile(
    id: 'builtin-me-14800-14820',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14800Name,
    reference: '14820',
    name: 'Dormant frappé',
    type: ProfileType.dormant,
    // Sheet labels 36.5 (sash side), 42.7 (face), 44.0 (wall plane).
    width: 42.7,
    depth: 44.0,
    weightPerMeter: 0,
    inertiaIxxCm4: 3.67,
    inertiaIyyCm4: 6.51,
  ),
  Profile(
    id: 'builtin-me-14800-14818',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14800Name,
    reference: '14818',
    name: 'Dormant frappé',
    type: ProfileType.dormant,
    // Sheet labels 36.5 / 42.8 / 66.3. The S-1 descriptif sheet prints
    // the same profile as 42.75 / 66.34 -- both transcriptions recorded
    // in VERIFIED_SOURCES S-3; this seed follows this series' own sheet.
    width: 42.8,
    depth: 66.3,
    weightPerMeter: 0,
    inertiaIxxCm4: 3,
    inertiaIyyCm4: 13.35,
  ),
  // --- DORMANTS (PROFILOSCOPE p.50; named "Dormant tubulaire" by the
  // --- p.65 débitage table) ---
  Profile(
    id: 'builtin-me-14800-14800',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14800Name,
    reference: '14.800',
    name: 'Dormant tubulaire',
    type: ProfileType.dormant,
    width: 43.6,
    depth: 44.0,
    weightPerMeter: 0,
    inertiaIxxCm4: 4.90,
    inertiaIyyCm4: 2.40,
  ),
  Profile(
    id: 'builtin-me-14800-14801',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14800Name,
    reference: '14.801',
    name: 'Dormant tubulaire couvre-joint',
    type: ProfileType.dormant,
    // Sheet labels 43.6 / 44 plus a 23 cover-joint stem (sub-dim, no
    // model field).
    width: 43.6,
    depth: 44.0,
    weightPerMeter: 0,
    inertiaIxxCm4: 6.30,
    inertiaIyyCm4: 4.60,
  ),
  // --- OUVRANTS (PROFILOSCOPE p.51; named by the p.65 débitage table) ---
  Profile(
    id: 'builtin-me-14800-14802',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14800Name,
    reference: '14.802',
    name: 'Ouvrant fenêtre',
    type: ProfileType.ouvrant,
    width: 47.9,
    depth: 61.2,
    weightPerMeter: 0,
    inertiaIxxCm4: 2,
    inertiaIyyCm4: 3.67,
  ),
  Profile(
    id: 'builtin-me-14800-14805',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14800Name,
    reference: '14.805',
    name: 'Ouvrant porte et fenêtre extérieur',
    type: ProfileType.ouvrant,
    width: 47.9,
    depth: 87.8,
    weightPerMeter: 0,
    inertiaIxxCm4: 12.4,
    inertiaIyyCm4: 18.9,
  ),
  // --- PARCLOSES (PROFILOSCOPE p.53; named "Pareclose" by the p.65
  // --- débitage table; 14.809 = simple-vitrage face, 14.810 =
  // --- double-vitrage face per the table's own sub-labels) ---
  Profile(
    id: 'builtin-me-14800-14809',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14800Name,
    reference: '14.809',
    name: 'Parclose (simple vitrage)',
    type: ProfileType.other,
    width: 16.0,
    depth: 19.5,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-me-14800-14810',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14800Name,
    reference: '14.810',
    name: 'Parclose (double vitrage)',
    type: ProfileType.other,
    // This sheet labels 24; the S-1 descriptif sheet prints 22.5 for the
    // same reference -- both transcriptions recorded (S-3), this seed
    // follows this series' own sheet.
    width: 24.0,
    depth: 19.5,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-me-14800-14809-1',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14800Name,
    reference: '14809/1',
    name: 'Parclose',
    type: ProfileType.other,
    width: 12.5,
    depth: 19.5,
    weightPerMeter: 0,
  ),
  // --- TIGE DE CRÉMONE (p.65 débitage row; no PROFILOSCOPE sheet seen,
  // --- no dimensions labeled anywhere in the section) ---
  Profile(
    id: 'builtin-me-14800-14811',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14800Name,
    reference: '14.811',
    name: 'Tige de crémone',
    type: ProfileType.other,
    width: 0,
    depth: 0,
    weightPerMeter: 0,
  ),
  // --- PROFILES DE LIAISON (PROFILOSCOPE p.50; heading cross-sourced
  // --- from S-1's "PROFILES DE LIAISON" sheet) ---
  Profile(
    id: 'builtin-me-14800-14827',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14800Name,
    reference: '14827',
    name: 'Profile de liaison',
    type: ProfileType.other,
    width: 44.0,
    depth: 8.7,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-me-14800-14817',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14800Name,
    reference: '14817',
    name: 'Profile de liaison',
    type: ProfileType.other,
    // S-1 labeled only 47.90; this sheet also labels the 10.4 height.
    width: 47.9,
    depth: 10.4,
    weightPerMeter: 0,
  ),
  // --- PROFILES WITHOUT A STATED FAMILY (PROFILOSCOPE pp.51-53): the
  // --- sheets carry no headings and no other source element names
  // --- them; `other` + unknown-marker dims where unlabeled. Shape-based
  // --- typing would be inference.
  Profile(
    id: 'builtin-me-14800-14806',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14800Name,
    reference: '14806',
    name: 'Profil (famille non déclarée)',
    type: ProfileType.other,
    width: 87.8,
    depth: 47.9,
    weightPerMeter: 0,
    inertiaIxxCm4: 13.4,
    inertiaIyyCm4: 22.79,
  ),
  Profile(
    id: 'builtin-me-14800-14804',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14800Name,
    reference: '14804',
    name: 'Profil (famille non déclarée)',
    type: ProfileType.other,
    // Sheet labels 56.5 / 44.4 plus sub-dim 27.9 (no model field).
    width: 56.5,
    depth: 44.4,
    weightPerMeter: 0,
    inertiaIxxCm4: 7.14,
    inertiaIyyCm4: 6.25,
  ),
  Profile(
    id: 'builtin-me-14800-14825',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14800Name,
    reference: '14825',
    name: 'Profil châssis va-et-vient (coupe p.62)',
    type: ProfileType.other,
    width: 29.5,
    depth: 14.5,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-me-14800-14807',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14800Name,
    reference: '14807',
    name: 'Profil (famille non déclarée)',
    type: ProfileType.other,
    width: 33.5,
    depth: 19.5,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-me-14800-14803',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14800Name,
    reference: '14803',
    name: 'Profil (famille non déclarée)',
    type: ProfileType.other,
    // Sheet labels 68.8 top, 40 right, 28.8 bottom (sub-dim).
    width: 68.8,
    depth: 40.0,
    weightPerMeter: 0,
    inertiaIxxCm4: 6.26,
    inertiaIyyCm4: 6.7,
  ),
  Profile(
    id: 'builtin-me-14800-14812',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14800Name,
    reference: '14812',
    name: 'Profil (famille non déclarée)',
    type: ProfileType.other,
    width: 88.8,
    depth: 48.8,
    weightPerMeter: 0,
    inertiaIxxCm4: 12.4,
    inertiaIyyCm4: 18.9,
  ),
  Profile(
    id: 'builtin-me-14800-14808',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14800Name,
    reference: '14808',
    name: 'Profil (famille non déclarée)',
    type: ProfileType.other,
    // Sheet labels 50 horizontal and TWO vertical dims (90 and 110);
    // face/depth orientation not stated -- 90 stored as depth, 110
    // recorded as a sub-dimension in VERIFIED_SOURCES S-3.
    width: 50.0,
    depth: 90.0,
    weightPerMeter: 0,
    inertiaIxxCm4: 107.73,
    inertiaIyyCm4: 28.86,
  ),
  Profile(
    id: 'builtin-me-14800-14813',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14800Name,
    reference: '14813',
    name: 'Profil (famille non déclarée)',
    type: ProfileType.other,
    width: 40.0,
    depth: 140.0,
    weightPerMeter: 0,
    inertiaIxxCm4: 96.41,
    inertiaIyyCm4: 16.15,
  ),
  // --- COUVRE JOINT (PROFILOSCOPE p.53; only the height is labeled --
  // --- same reading as S-1's 14 601 sheet) ---
  Profile(
    id: 'builtin-me-14800-14601',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14800Name,
    reference: '14601',
    name: 'Couvre joint',
    type: ProfileType.other,
    width: 0,
    depth: 26.0,
    weightPerMeter: 0,
  ),
];

/// Maghreb Extrusion "Série 14800" frappe system (fenêtres et
/// portes-fenêtres à la française, oscillo-battants, soufflets, fixes per
/// the fiche technique) with every system-level fact the source states,
/// nothing it doesn't.
///
/// `ruleSetId` points at `meSerie14800RuleSet` (me_14800_rule_set.dart):
/// the p. 65 débitage "(1 VANTAIL)" table — dormant 14.800/14.801,
/// ouvrant 14.802/14.805, parcloses 14.809/14.810 keyed by the SIBLING
/// ouvrant reference via CompanionProfileReferenceCondition (first
/// second-manufacturer consumer of the C8 capability), and tige de
/// crémone 14.811. No 2-vantaux (or OB/soufflet/fixe) débitage table
/// exists in the catalogue for this series, so those configurations stay
/// honestly unmatched. See docs/VERIFIED_SOURCES.md S-3.
const ProfileSystem meSerie14800 = ProfileSystem(
  id: meSerie14800Id,
  manufacturer: _maghrebExtrusionName,
  manufacturerId: maghrebExtrusionId,
  name: _meSerie14800Name,
  ruleSetId: meSerie14800Id,
  profiles: _me14800Profiles,
  supportedOpenings: [OpeningType.francaise],
  isBuiltIn: true,
  metadata: ProfileSystemMetadata(
    // "Dormant tubulaires de 44 mm avec ou sans couvre joint" (p.48).
    frameDepthOptionsMm: [44.0],
    // "Ouvrant tubulaires de 47,9 mm" (p.48).
    sashStileDepthOptionsMm: [47.9],
    // "Les ouvrants ont une feuillure de 24 mm permettant de recevoir
    // des vitrages simples ou isolants de 6 à 20 mm" (p.48).
    glazingRebateMm: 24.0,
    glazingMinMm: 6.0,
    glazingMaxMm: 20.0,
    assemblyNote:
        'Dormants tubulaires 44 mm assemblés en coupe d\'onglet avec '
        'équerres; ouvrant tubulaire 47,9 mm à prise en feuillure des '
        'vitrages en portefeuille ou parclosé (feuillure 24 mm).',
    drainageNote:
        'Drainage par trous oblongs sur la traverse basse du dormant, '
        'avec busettes à clapet anti-retour.',
    finishNote:
        'Alliage 6063 (EXTRUMAROC). Laquage 60 µ QUALICOAT ou '
        'anodisation 15 µ QUALANOD. Essais CEBTP: A4 / E1050 / V1C3.',
    // No dimension-limit statement exists in the transcribed section;
    // none seeded (absence = unknown).
    dimensionLimits: [],
    sourceDescription:
        '"Catalogue Général — Maghreb Extrusion" (146-page PDF fourni '
        'par le client), section Série 14800: fiche technique pp.48-49, '
        'planches PROFILOSCOPE pp.50-53 (lecture visuelle sur rendus '
        'haute résolution), débitage "(1 VANTAIL)" p.65 (texte + '
        'vérification visuelle). Détail par valeur: '
        'docs/VERIFIED_SOURCES.md, section S-3.',
  ),
);

// ============================================================================
// MAGHREB EXTRUSION — Série 14700 (portes lourdes à frappe)
// ============================================================================

/// System id for the Série 14700 portes, fixed for the same idempotency
/// reason as [maghrebExtrusionId].
const String meSerie14700Id = 'builtin-me-14700';

/// Display name of the seeded 14700 system; also [Profile.system] on
/// every seeded profile.
const String _meSerie14700Name = 'Série 14700 Portes Lourdes';

/// Every profile of the Série 14700 transcribed from the Catalogue
/// Général's PROFILOSCOPE sheets for this series (pdf pp. 76-80) plus
/// the débitage-only réf 14.811 (no PROFILOSCOPE sheet seen). The full
/// transcription table -- including values the `Profile` model has no
/// field for -- lives in `docs/VERIFIED_SOURCES.md`, section S-4.
///
/// Conventions: identical to the me-14600 / me-14800 blocks above
/// (`width` = face, `depth` = wall-plane, `0` = not labeled,
/// `weightPerMeter` = 0 everywhere).
///
/// TYPE SOURCING: as in me-14800, the PROFILOSCOPE sheets carry no
/// family headings; types are assigned only where a source element
/// states them. The p. 94 débitage table names 14.700 "Dormant",
/// 14.705 "Ouvrant intérieur", 14.706 "Ouvrant extérieur", 14.807
/// "Complément traverse basse", 14.813 "TÉ traverse", 14.809/14.810
/// "Parclose", 14.811 "Tige de crémone". Everything else stays
/// `ProfileType.other` with a "famille non déclarée" note -- shape-based
/// guessing would violate the domain rule that types follow source
/// headings, never inference. The coupes (pp. 86-88) label 14.701 as
/// the "imposte fixe" panel and 14.712 as the traverse-basse cap;
/// since neither has a heading, both stay `other`.
///
/// NOTATION: same dotted/undotted split as the 14800 section. The p. 94
/// débitage table prints "14.807" (dotted) while the PROFILOSCOPE sheet
/// p. 80 prints "14707" (undotted); the débitage table prints "14.813"
/// while the sheet p. 79 prints "14813". Seeded references follow the
/// notation of the source element that names each profile -- dotted for
/// the débitage-named rows, sheet notation for the rest -- with the
/// mapping recorded in the ledger.
const List<Profile> _me14700Profiles = [
  // --- DORMANTS (PROFILOSCOPE p.76; named "Dormant" by p.94 débitage) ---
  Profile(
    id: 'builtin-me-14700-14700',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14700Name,
    reference: '14.700',
    name: 'Dormant',
    type: ProfileType.dormant,
    // Sheet labels 72.1 (face) and 50.1 (sub-dim, not the wall plane).
    // The fiche states "Dormant tubulaire de 54 mm" as a system value
    // (metadata.frameDepthOptionsMm); the wall-plane dim is not labeled
    // on this profile's sheet -> stored as the labeled face.
    width: 72.1,
    depth: 0,
    weightPerMeter: 0,
  ),
  // --- FIXE / IMPOSTE (PROFILOSCOPE p.76; coupes pp.86-88 label as
  // --- imposte fixe) ---
  Profile(
    id: 'builtin-me-14700-14701',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14700Name,
    reference: '14.701',
    name: 'Imposte fixe',
    type: ProfileType.other,
    // Sheet labels 75.1 (face) / 54 (wall plane) plus a 20 sub-dim.
    width: 75.1,
    depth: 54.0,
    weightPerMeter: 0,
  ),
  // --- OUVRANTS (PROFILOSCOPE p.77; named by p.94 débitage) ---
  Profile(
    id: 'builtin-me-14700-14705',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14700Name,
    reference: '14.705',
    name: 'Ouvrant intérieur',
    type: ProfileType.ouvrant,
    // Sheet labels 91.8 (face) / 71.8 (sub-dim). Fiche states
    // "Ouvrant tubulaire de 54 mm" (metadata.sashStileDepthOptionsMm).
    width: 91.8,
    depth: 0,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-me-14700-14706',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14700Name,
    reference: '14.706',
    name: 'Ouvrant extérieur',
    type: ProfileType.ouvrant,
    // Sheet labels 91.8 (face) / 49.8 (sub-dim) plus 12.2 (another
    // sub-dim). 14.706 is the dedicated "ouvrant extérieur" leaf
    // (label verified p.88); narrower base than 14.705.
    width: 91.8,
    depth: 0,
    weightPerMeter: 0,
  ),
  // --- PARCLOSES (PROFILOSCOPE p.80; named "Parclose" by p.94 débitage;
  // --- 14.819 appears only on p.92 parclose/vitrage mapping, 22-27mm
  // --- glazing, no débitage row in p.94) ---
  Profile(
    id: 'builtin-me-14700-14810',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14700Name,
    reference: '14.810',
    name: 'Parclose (5-10mm glazing)',
    type: ProfileType.other,
    // Sheet p.80 labels 22 / 20 -- and p.94 row labeled "14.810 ou
    // 14.809" with "Double vitrage" sub-label (the nomenclature
    // disagrees with the p.92 parclose/vitrage mapping: p.80 sheet
    // sub-labels are absent, p.92 assigns 14.810 to 5-10mm). Both
    // statements kept verbatim in the ledger.
    width: 22.0,
    depth: 20.0,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-me-14700-14809',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14700Name,
    reference: '14.809',
    name: 'Parclose (12-20mm glazing)',
    type: ProfileType.other,
    // Sheet p.80 labels 16 / 20.
    width: 16.0,
    depth: 20.0,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-me-14700-14809-1',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14700Name,
    reference: '14.809/1',
    name: 'Parclose',
    type: ProfileType.other,
    width: 12.5,
    depth: 20.0,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-me-14700-14819',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14700Name,
    reference: '14.819',
    name: 'Parclose (22-27mm glazing)',
    type: ProfileType.other,
    // Sheet p.80 labels 4.5 / 20. Only the p.92 parclose/vitrage
    // mapping names this ref (for 22-27mm glazing); no row in the
    // p.94 débitage table -- its cut formula is unknown. C10a encodes
    // NO rule for 14.819; the profile is seeded for the catalogue
    // map to be complete, the glass-dependent cut is a documented
    // blocker.
    width: 4.5,
    depth: 20.0,
    weightPerMeter: 0,
  ),
  // --- TRAVERSE BASSE ASSEMBLY (p.94 débitage: 14.813 "TÉ traverse" +
  // --- 14.807 "Complément traverse basse"; sheet notation 14813 and
  // --- 14707 respectively -- same profiles, dotted/undotted split) ---
  Profile(
    id: 'builtin-me-14700-14813',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14700Name,
    reference: '14.813',
    name: 'Té traverse (traverse basse)',
    type: ProfileType.traverse,
    // Sheet p.79 labels 140 (face) / 40 (wall plane).
    width: 140.0,
    depth: 40.0,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-me-14700-14707',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14700Name,
    reference: '14.807',
    name: 'Complément traverse basse',
    type: ProfileType.traverse,
    // Sheet p.80 labels 22 (face) / 48 (wall plane).
    width: 22.0,
    depth: 48.0,
    weightPerMeter: 0,
  ),
  // --- TIGE DE CRÉMONE (p.94 débitage row only; no PROFILOSCOPE sheet
  // --- seen in the section; no dimensions labeled anywhere) ---
  Profile(
    id: 'builtin-me-14700-14811',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14700Name,
    reference: '14.811',
    name: 'Tige de crémone',
    type: ProfileType.other,
    width: 0,
    depth: 0,
    weightPerMeter: 0,
  ),
  // --- PROFILES WITHOUT A STATED FAMILY OR DÉBITAGE ROW (PROFILOSCOPE
  // --- pp. 78-80): heading-less sheets, not named by the p.94 table;
  // --- used in the section's va-et-vient, imposte-fixe, and other
  // --- coupes that C10a does NOT encode. Seeded with type `other` and
  // --- a "famille non déclarée" note so the catalogue map is complete. ---
  Profile(
    id: 'builtin-me-14700-14718',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14700Name,
    reference: '14.718',
    name: 'Profil (famille non déclarée)',
    type: ProfileType.other,
    // Sheet p.78 labels 117.5 / 87.6 plus sub 49.2.
    width: 117.5,
    depth: 87.6,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-me-14700-14704',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14700Name,
    reference: '14.704',
    name: 'Profil (famille non déclarée)',
    type: ProfileType.other,
    // Sheet p.78 labels 54 / 19.
    width: 54.0,
    depth: 19.0,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-me-14700-14712',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14700Name,
    reference: '14.712',
    name: 'Traverse basse cap',
    type: ProfileType.other,
    // Sheet p.78 labels 89.2 / 54. Coupe p.87 labels this profile at
    // the bottom-rail cap position; no heading in the source.
    width: 89.2,
    depth: 54.0,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-me-14700-14708',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14700Name,
    reference: '14.708',
    name: 'Profil (famille non déclarée)',
    type: ProfileType.other,
    // Sheet p.80 labels 22 / 20 / 54.
    width: 22.0,
    depth: 54.0,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-me-14700-14711',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14700Name,
    reference: '14.711',
    name: 'Tige de crémone (variante 14.811)',
    type: ProfileType.other,
    // Sheet p.80 -- no dimensions labeled on the sheet.
    width: 0,
    depth: 0,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-me-14700-14803',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14700Name,
    reference: '14.803',
    name: 'Profil (famille non déclarée)',
    type: ProfileType.other,
    // Sheet p.79 labels 68.8 / 40 plus sub 28.8.
    width: 68.8,
    depth: 40.0,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-me-14700-14812',
    manufacturer: _maghrebExtrusionName,
    system: _meSerie14700Name,
    reference: '14.812',
    name: 'Profil (famille non déclarée)',
    type: ProfileType.other,
    // Sheet p.79 labels 88.8 / 48.8.
    width: 88.8,
    depth: 48.8,
    weightPerMeter: 0,
  ),
];

/// Maghreb Extrusion "Série 14700" portes lourdes system -- portes
/// fenêtres et fenêtres à la française 1 ou 2 vantaux (fiche p.73), with
/// every system-level fact the source states and nothing it doesn't.
///
/// `ruleSetId` points at `meSerie14700RuleSet` (me_14700_rule_set.dart):
/// the unambiguous subset of the p. 94 débitage table. The 2-vantaux
/// 14.705 stile formula (Qté 3) and 14.706 stile formula (Qté 1) are
/// DELIBERATELY not encoded -- the 3+1 split is a documented source
/// tension (ledger S-4; Coupes pp.87, 88 label 14.705 = "OUVRANT A
/// L'INTERIEUR" and 14.706 = "OUVRANT A L'EXTERIEUR" but no coupe
/// labels the per-stile positional distribution). Per the locked
/// decision: 2v 14.705/14.706 stile rules stay noRuleMatched; the
/// tension is recorded, not resolved by inference. See
/// docs/VERIFIED_SOURCES.md S-4 for the full transcription and the
/// C10b blocker.
const ProfileSystem meSerie14700 = ProfileSystem(
  id: meSerie14700Id,
  manufacturer: _maghrebExtrusionName,
  manufacturerId: maghrebExtrusionId,
  name: _meSerie14700Name,
  ruleSetId: meSerie14700Id,
  profiles: _me14700Profiles,
  supportedOpenings: [OpeningType.francaise],
  isBuiltIn: true,
  metadata: ProfileSystemMetadata(
    // "Dormant tubulaires de 54 mm avec ou sans couvre joint" (p.73).
    frameDepthOptionsMm: [54.0],
    // "Ouvrant tubulaires de 54 mm" (p.73).
    sashStileDepthOptionsMm: [54.0],
    // "Les ouvrants ont une feuillure pour vitrage allant de 6 à 24 mm"
    // (p.74). The rebate depth itself is NOT stated on the fiche --
    // only the glazing range is. Stored as a glazing range, not as
    // glazingRebateMm (which would be a depth, not a range).
    glazingMinMm: 6.0,
    glazingMaxMm: 24.0,
    assemblyNote:
        'Dormant tubulaire 54 mm avec ou sans couvre joint, assemblage '
        'en coupe d\'onglet avec équerres; ouvrant tubulaire 54 mm à '
        'prise en feuillure portefeuille ou parclosé. Ferrage par '
        '3 paumelles ou plus selon dimension/poids; fermeture par '
        'serrure à 1, 2 ou 3 points.',
    drainageNote:
        'Drainage par oblongs sur la traverse basse du dormant avec '
        'busettes à clapets anti-retour.',
    finishNote:
        'Alliage 6063 (EXTRUMAROC). Laquage 60 µ QUALICOAT ou '
        'anodisation 15 µ QUALANOD.',
    // No dimension-limit statement exists in the fiche section.
    dimensionLimits: [],
    sourceDescription:
        '"Catalogue Général — Maghreb Extrusion" (146-page PDF fourni '
        'par le client), section Série 14700: titre p.72, fiche '
        'technique pp.73-75, PROFILOSCOPE pp.76-80, coupes pp.81-93 '
        '(lecture visuelle sur rendus haute résolution), débitage '
        '"PORTE À FRAPPE 1 ET 2 VANTAUX AVEC TRAVERSE BASSE" p.94 '
        '(texte + vérification visuelle haute résolution). Détail par '
        'valeur et tensions documentées: docs/VERIFIED_SOURCES.md, '
        'section S-4.',
  ),
);

// ============================================================================
// SEPALUMIC — Série 4200 (châssis à frappe / oscillo-battants)
// ============================================================================

/// Manufacturer id for Sepalumic. Fixed stable string, same idempotency
/// rationale as [maghrebExtrusionId].
const String sepalumicId = 'builtin-sepalumic';

/// System id for the Série 4200.
const String sepSerie4200Id = 'builtin-sepalumic-4200';

/// Display names (manufacturer/system), same role as the ME names.
const String _sepalumicName = 'Sepalumic';
const String _sepSerie4200Name = 'Série 4200';

/// Sepalumic "Série 4200" — châssis à frappe et oscillo-battants, portes,
/// châssis composés ("série froide").
///
/// EVERY value below is transcribed from ONE identified source document,
/// cited per value in `docs/VERIFIED_SOURCES.md` (section M-2):
///
///   Sepalumic "Catalogue Technique Série 4200", Édition 05 — Septembre
///   2019 (199-page PDF supplied by the client; AutoCAD-plotted sheets,
///   text layer + hi-dpi visual verification of every encoded table).
///   B-section profile sheets B020–B080; E-section débitage tables
///   E030–E210.
///
/// HARD DOMAIN RULE: nothing inferred. `0` = the sheet does not label
/// that dimension; `thermalBreak` stays null (the catalogue never
/// mentions one); profile types follow the sheets' own headings.
///
/// RULE SET STATUS: `ruleSetId` points at `sepSerie4200RuleSet`
/// (sep_4200_rule_set.dart) which encodes the honestly-representable
/// families — Châssis fixe and OF (à la française) 1/2 vantaux. The OB /
/// Soufflet / Projeté / Porte large / Châssis composé families and the
/// traverse-option + parclose rows are deliberately NOT encoded — each
/// blocker is documented in docs/VERIFIED_SOURCES.md (M-2): missing
/// OpeningType values, a cross-usage dependency the engine cannot
/// evaluate, and glass-dependent parclose selection. Those usages
/// surface as honest `noRuleMatched` issues.
const List<Profile> _sep4200Profiles = [
  // --- DORMANTS (PROFILÉS B020) ---
  Profile(
    id: 'builtin-sepalumic-4200-4220',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '4220',
    name: 'Dormant sans couvre-joint',
    type: ProfileType.dormant,
    width: 40,
    depth: 49,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-sepalumic-4200-4221',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '4221',
    name: 'Dormant avec couvre-joint',
    type: ProfileType.dormant,
    width: 40,
    depth: 49,
    weightPerMeter: 0,
  ),
  // --- OUVRANTS (PROFILÉS B030/B040) ---
  Profile(
    id: 'builtin-sepalumic-4200-4211',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '4211',
    name: 'Ouvrant étroit feuillure portefeuille',
    type: ProfileType.ouvrant,
    width: 50,
    depth: 37.5,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-sepalumic-4200-4219',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '4219',
    name: 'Ouvrant feuillure portefeuille',
    type: ProfileType.ouvrant,
    width: 50,
    depth: 49,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-sepalumic-4200-4244',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '4244',
    name: 'Ouvrant feuillure portefeuille',
    type: ProfileType.ouvrant,
    width: 49.5,
    depth: 67.5,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-sepalumic-4200-4254',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '4254',
    name: 'Ouvrant feuillure portefeuille',
    type: ProfileType.ouvrant,
    width: 50,
    depth: 76,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-sepalumic-4200-4206',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '4206',
    name: 'Battue centrale',
    type: ProfileType.ouvrant,
    width: 52,
    depth: 40,
    weightPerMeter: 0,
  ),
  // --- TRAVERSES INTERMÉDIAIRES / RENFORCÉES (PROFILÉS B050/B060) ---
  Profile(
    id: 'builtin-sepalumic-4200-4413',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '4413',
    name: 'Traverse intermédiaire',
    type: ProfileType.traverse,
    width: 40,
    depth: 44,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-sepalumic-4200-4405',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '4405',
    name: 'Traverse intermédiaire',
    type: ProfileType.traverse,
    width: 40,
    depth: 26,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-sepalumic-4200-2656',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '2656',
    name: 'Traverse intermédiaire',
    type: ProfileType.traverse,
    width: 26,
    // Sheet labels a 19/24/19 chain, no total: 62 is the shown
    // derivation (see VERIFIED_SOURCES M-2).
    depth: 62,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-sepalumic-4200-4243',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '4243',
    name: 'Traverse renforcée',
    type: ProfileType.traverse,
    width: 40,
    depth: 44,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-sepalumic-4200-4233',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '4233',
    name: 'Traverse intermédiaire renforcée',
    type: ProfileType.traverse,
    width: 26,
    depth: 26,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-sepalumic-4200-4253',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '4253',
    name: 'Traverse intermédiaire renforcée',
    type: ProfileType.traverse,
    width: 26,
    depth: 26,
    weightPerMeter: 0,
  ),
  // --- PARCLOSES (PROFILÉS B070): faces vary by glass configuration ---
  Profile(
    id: 'builtin-sepalumic-4200-4464',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '4464',
    name: 'Parclose',
    type: ProfileType.other,
    width: 5.4,
    depth: 22,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-sepalumic-4200-4418',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '4418',
    name: 'Parclose',
    type: ProfileType.other,
    width: 9.4,
    depth: 22,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-sepalumic-4200-5026',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '5026',
    name: 'Parclose',
    type: ProfileType.other,
    width: 14.3,
    depth: 22,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-sepalumic-4200-5120',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '5120',
    name: 'Parclose',
    type: ProfileType.other,
    width: 18.2,
    depth: 22,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-sepalumic-4200-5016',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '5016',
    name: 'Parclose',
    type: ProfileType.other,
    width: 22,
    depth: 22,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-sepalumic-4200-4250',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '4250',
    name: 'Parclose',
    type: ProfileType.other,
    width: 7.9,
    depth: 22,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-sepalumic-4200-4252',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '4252',
    name: 'Parclose',
    type: ProfileType.other,
    width: 12.1,
    depth: 26.7,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-sepalumic-4200-4251',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '4251',
    name: 'Parclose',
    type: ProfileType.other,
    width: 15.8,
    depth: 26.7,
    weightPerMeter: 0,
  ),
  // --- COMPLÉMENTAIRES (PROFILÉS B080): finishing/accessory profiles ---
  Profile(
    id: 'builtin-sepalumic-4200-3380m',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '3380M',
    name: 'Profil complémentaire',
    type: ProfileType.other,
    width: 0,
    depth: 30,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-sepalumic-4200-4080',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '4080',
    name: 'Profil complémentaire',
    type: ProfileType.other,
    width: 0,
    depth: 30,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-sepalumic-4200-4081',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '4081',
    name: 'Profil complémentaire',
    type: ProfileType.other,
    width: 0,
    depth: 45,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-sepalumic-4200-4082',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '4082',
    name: 'Profil complémentaire',
    type: ProfileType.other,
    width: 0,
    depth: 60,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-sepalumic-4200-2648',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '2648',
    name: 'Profil complémentaire',
    type: ProfileType.other,
    width: 30,
    // Sheet labels a 28/42 vertical chain with no total.
    depth: 0,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-sepalumic-4200-463',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '463',
    name: 'Profil complémentaire',
    type: ProfileType.other,
    width: 45,
    depth: 7,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-sepalumic-4200-4582',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '4582',
    name: 'Profil complémentaire',
    type: ProfileType.other,
    width: 52,
    depth: 20,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-sepalumic-4200-5067',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '5067',
    name: 'Profil complémentaire',
    type: ProfileType.other,
    width: 35,
    depth: 15,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-sepalumic-4200-4568',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '4568',
    name: 'Profil complémentaire',
    type: ProfileType.other,
    width: 20,
    depth: 12,
    weightPerMeter: 0,
  ),
  Profile(
    id: 'builtin-sepalumic-4200-412',
    manufacturer: _sepalumicName,
    system: _sepSerie4200Name,
    reference: '412',
    name: 'Profil complémentaire',
    type: ProfileType.other,
    width: 19.6,
    depth: 4.5,
    weightPerMeter: 0,
  ),
];

/// Sepalumic "Série 4200" system record — every system-level fact the
/// source states (A030 descriptif / A040 norms), nothing it doesn't.
///
/// `ruleSetId` points at `sepSerie4200RuleSet` (sep_4200_rule_set.dart):
/// the Châssis fixe + OF (à la française) 1/2 vantaux débitage families.
/// See this file's profile block doc for the deliberately-unencoded
/// families and their blockers.
const ProfileSystem sepSerie4200 = ProfileSystem(
  id: sepSerie4200Id,
  manufacturer: _sepalumicName,
  manufacturerId: sepalumicId,
  name: _sepSerie4200Name,
  ruleSetId: sepSerie4200Id,
  profiles: _sep4200Profiles,
  supportedOpenings: [OpeningType.francaise],
  isBuiltIn: true,
  metadata: ProfileSystemMetadata(
    // "Dormant tubulaire aluminium 6060, base de 40 mm" (A030); sheet
    // B020 labels the depth 49.
    frameDepthOptionsMm: [49.0],
    // Ouvrant sheets B030: 37.5 / 49 / 67.5 / 76 across the four
    // ouvrant refs (étroit → porte-large depths).
    sashStileDepthOptionsMm: [37.5, 49.0, 67.5, 76.0],
    // "Vitrage de 6 à 24 mm en portefeuille" (A030).
    glazingMinMm: 6.0,
    glazingMaxMm: 24.0,
    // "Assemblé en coupe d'onglet par équerre à pion" (A030, dormant et
    // ouvrant). The 45° angles on the encoded rules derive from this
    // statement; square-cut members (traverse/battue) are printed
    // 90°/90° in the E tables.
    assemblyNote:
        'Dormant tubulaire aluminium 6060 base 40 mm et ouvrant à '
        'feuillure portefeuille, assemblés en coupe d\'onglet par '
        'équerre à pion. Joint de battement EPDM. Vitrage 6 à 24 mm en '
        'portefeuille, feuillure drainée à parclose.',
    // A040: NF EN 14351-1 (produit), NF EN 12519; qualification
    // européenne, essais FCBA (A050). Alloy 6060 per A030.
    finishNote:
        'Aluminium 6060 (A030). Qualifiée suivant la réglementation '
        'européenne — NF EN 14351-1, NF EN 12519 (A040).',
    // No dimension-limit statement exists in the catalogue sections
    // transcribed; none seeded (absence = unknown).
    sourceDescription:
        '"Catalogue Technique Série 4200 — SEPALUMIC", Édition 05 — '
        'Septembre 2019 (199-page PDF fourni par le client; planches '
        'profilés B020-B080 et débitages E030-E210, lecture texte + '
        'vérification visuelle haute résolution). Détail par valeur: '
        'docs/VERIFIED_SOURCES.md, section M-2.',
  ),
);

/// Every built-in manufacturer.
const List<Manufacturer> builtInManufacturers = [
  maghrebExtrusion,
  sepalumic,
];

/// The Sepalumic manufacturer record.
const Manufacturer sepalumic = Manufacturer(
  id: sepalumicId,
  name: _sepalumicName,
  isBuiltIn: true,
);

/// Every built-in profile system.
const List<ProfileSystem> builtInProfileSystems = [
  meSerie14600,
  meSerie14800,
  meSerie14700,
  sepSerie4200,
];

/// Returns [catalog] with every built-in manufacturer/system record above
/// merged in, each added only if not already present (matched by id).
///
/// Idempotent and non-destructive by design: calling this on every
/// `CatalogStore.load()` (see that class) must never duplicate entries on
/// a second run, and must never overwrite a user's own edits to their
/// catalog -- a user could in principle rename or delete their own
/// unrelated manufacturers/systems, or even (via existing delete UI) the
/// built-in ones themselves, and this function must respect that rather
/// than resurrecting anything the user removed. Each record is checked
/// independently by id: deleting one built-in manufacturer/system does
/// not affect whether any other one gets (re-)added, and this function
/// never modifies or re-adds a record that's already present -- with ONE
/// deliberate exception handled separately by [adoptBuiltInRuleSets]
/// below.
///
/// This is also why removing records from the seed (e.g. the earlier
/// ADM/Sepalumic/Menara/DOMAL placeholders) cannot clean them out of an
/// existing install: merge-by-addition never deletes. See this file's
/// module doc comment.
Catalog withBuiltInCatalogSeed(Catalog catalog) {
  final existingManufacturerIds = catalog.manufacturers
      .map((m) => m.id)
      .toSet();
  final existingSystemIds = catalog.profileSystems.map((s) => s.id).toSet();

  final manufacturersToAdd = builtInManufacturers.where(
    (m) => !existingManufacturerIds.contains(m.id),
  );
  final systemsToAdd = builtInProfileSystems.where(
    (s) => !existingSystemIds.contains(s.id),
  );

  if (manufacturersToAdd.isEmpty && systemsToAdd.isEmpty) return catalog;

  return catalog.copyWith(
    manufacturers: [...catalog.manufacturers, ...manufacturersToAdd],
    profileSystems: [...catalog.profileSystems, ...systemsToAdd],
  );
}

/// Removes built-in manufacturer/system records whose ids no longer match
/// anything this build ships (e.g. `Aluminium du Maroc` / `Cuzco 713 OM`,
/// dropped in the C4b clean-slate). Pre-C4b installs persist those records
/// with `isBuiltIn: true`, and the one-time seed sentinel means
/// [withBuiltInCatalogSeed] never revisits them -- without pruning, a
/// superseded manufacturer stays in the picker forever next to the real
/// systems.
///
/// Narrow and deliberate, mirroring [adoptBuiltInRuleSets]'s contract:
/// - only records carrying `isBuiltIn == true` whose id is absent from
///   the shipped [builtInManufacturers]/[builtInProfileSystems] are
///   removed; user-created records (`isBuiltIn: false`) are never
///   touched, whatever their ids;
/// - pruning a stale manufacturer also drops profile systems pointing
///   at it (by `manufacturerId`), even if such a system id somehow
///   still shipped -- a system with no manufacturer left would be
///   meaningless in the picker;
/// - constructions referencing a pruned system id are NOT touched here
///   (catalog merge must stay construction-agnostic); they resolve as
///   "unresolved" downstream, which the editor already surfaces.
///
/// Returns the SAME instance when there is nothing to prune, so callers
/// (`CatalogStore.load`) can detect "changed" by identity.
Catalog pruneRemovedBuiltIns(Catalog catalog) {
  final shippedManufacturerIds =
      builtInManufacturers.map((m) => m.id).toSet();
  final shippedSystemIds =
      builtInProfileSystems.map((s) => s.id).toSet();

  final prunedManufacturerIds = catalog.manufacturers
      .where((m) => m.isBuiltIn && !shippedManufacturerIds.contains(m.id))
      .map((m) => m.id)
      .toSet();
  final prunedSystemIds = catalog.profileSystems
      .where(
        (s) =>
            (s.isBuiltIn && !shippedSystemIds.contains(s.id)) ||
            prunedManufacturerIds.contains(s.manufacturerId),
      )
      .map((s) => s.id)
      .toSet();

  if (prunedManufacturerIds.isEmpty && prunedSystemIds.isEmpty) {
    return catalog;
  }

  return catalog.copyWith(
    manufacturers: catalog.manufacturers
        .where((m) => !prunedManufacturerIds.contains(m.id))
        .toList(),
    profileSystems: catalog.profileSystems
        .where((s) => !prunedSystemIds.contains(s.id))
        .toList(),
  );
}

/// Returns [catalog] with every PRESENT built-in profile system whose
/// stored rule set is still the generic placeholder refreshed to the
/// rule set the shipped definition carries.
///
/// [withBuiltInCatalogSeed] runs once per install (`CatalogStore`'s
/// `.catalog_seeded` sentinel), so a system seeded BEFORE its real rules
/// existed keeps `ruleSetId: 'generic-placeholder'` forever under pure
/// add-only merging -- silently calculating placeholder cuts next to an
/// app that now ships verified rules. This function is the narrow,
/// deliberate exception to add-only merging:
///
/// - a record qualifies only if it matches a shipped built-in BY ID,
///   carries `isBuiltIn == true`, and still stores the placeholder id;
/// - ONLY `ruleSetId` changes -- every other field of the stored record
///   (including user-visible names and verified metadata) is preserved
///   exactly as persisted;
/// - user-created systems (`isBuiltIn == false`) and any stored value
///   that is not the placeholder are untouched -- if a user ever pointed
///   a built-in at their own rule set, that choice wins;
/// - built-in systems the user deleted stay deleted: only records still
///   present are considered, nothing is resurrected.
///
/// Returns the SAME instance when there is nothing to refresh, so
/// callers (CatalogStore.load) can detect "changed" by identity.
Catalog adoptBuiltInRuleSets(Catalog catalog) {
  var changed = false;
  final systems = <ProfileSystem>[];
  for (final stored in catalog.profileSystems) {
    ProfileSystem? seed;
    for (final candidate in builtInProfileSystems) {
      if (candidate.id == stored.id) {
        seed = candidate;
        break;
      }
    }

    final needsAdoption = seed != null &&
        seed.ruleSetId != 'generic-placeholder' &&
        stored.isBuiltIn &&
        stored.ruleSetId == 'generic-placeholder';

    if (!needsAdoption) {
      systems.add(stored);
      continue;
    }

    changed = true;
    systems.add(
      ProfileSystem(
        id: stored.id,
        manufacturer: stored.manufacturer,
        manufacturerId: stored.manufacturerId,
        name: stored.name,
        ruleSetId: seed.ruleSetId,
        profiles: stored.profiles,
        supportedOpenings: stored.supportedOpenings,
        isBuiltIn: stored.isBuiltIn,
        metadata: stored.metadata,
      ),
    );
  }

  if (!changed) return catalog;
  return catalog.copyWith(profileSystems: systems);
}
