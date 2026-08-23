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
/// until the user deletes them through the normal catalog UI.
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
/// `Profile` model has no field for (section inertias IXX/IYY in cm4,
/// sub-dimensions like 14 640's 42.00 clip-stem spacing) and the exact
/// per-sheet orientation conventions -- lives in
/// `docs/VERIFIED_SOURCES.md`.
///
/// Conventions used below, applied uniformly and documented per profile
/// in `docs/VERIFIED_SOURCES.md`:
///   - `width` = the profile's visible face dimension, `depth` = its
///     wall-plane dimension, as drawn on its sheet.
///   - `0` = the sheet does not label that dimension (absence means
///     unknown; it is NEVER a measured zero).
///   - `weightPerMeter` = 0 everywhere: no sheet states a weight per
///     metre (same unknown-marker convention as above).
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
/// `ruleSetId` deliberately stays `generic-placeholder`. The document's
/// débitage pages (20/24) DO carry real cut formulas (montants H-74;
/// traverses (L-64)/2, (L-85)/2, (L-25)/3, (L-47)/3, (L-60)/4,
/// (L-106)/4 depending on configuration and on which traverse/montant
/// pairing is used -- all transcribed in `docs/VERIFIED_SOURCES.md`),
/// but the current rule engine selects rules by `ProfileType` +
/// section conditions only: it cannot distinguish 14 621 from 14 631
/// (same `ProfileType.traverse`, different deductions) and has no
/// whole-unit configuration variable for L. Encoding one configuration's
/// formula unconditionally would silently produce wrong cuts for the
/// others -- a fabrication error, not a placeholder -- so the honest
/// state remains "no real rule set yet" until the engine gains a
/// profile-reference condition and configuration semantics.
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
  ruleSetId: 'generic-placeholder',
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

/// Every built-in manufacturer.
const List<Manufacturer> builtInManufacturers = [maghrebExtrusion];

/// Every built-in profile system.
const List<ProfileSystem> builtInProfileSystems = [meSerie14600];

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
/// never modifies or re-adds a record that's already present.
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
