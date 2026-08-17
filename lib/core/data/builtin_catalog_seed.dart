/// Real `Manufacturer`/`ProfileSystem` records shipped with the app, and
/// the merge logic that adds them to whatever catalog a user already has
/// on disk.
///
/// Confidence varies by source and is stated explicitly on each record
/// below:
///   - Aluminium du Maroc / Cuzco 713 OM: HIGH. Every field set is
///     verified fact from the manufacturer's own product pages.
///   - Sepalumic Maroc and its three Coulissant systems: MEDIUM. Names
///     and thermal-break status are from Sepalumic's own site; no numeric
///     system-level data was published anywhere found.
///   - Menara Profil / "Targa Plus" and Maghreb Extrusion / "DOMAL": LOW.
///     Included as explicitly low-confidence placeholders -- see each
///     record's own doc comment for exactly what is and isn't confirmed.
///
/// Nothing here is inferred numerically or invented -- low confidence
/// means "the name/category itself is uncertain," never "we guessed at
/// numbers." Where the current `ProfileSystem` model has no field to hold
/// a piece of verified data (frame thickness, glazing range, dimension
/// limits, etc.), that data is deliberately left out rather than forced
/// into an unrelated field -- see the "DATA THAT CANNOT BE REPRESENTED
/// YET" note on [cuzco713Om] for the fullest example of this. `profiles`
/// stays empty on every system here for the same reason: no individual
/// profile reference/width/depth/weight data was supplied for any of
/// them, and this file must not fabricate any to make a picker look
/// populated.
library;

import '../models/catalog.dart';
import '../models/manufacturer.dart';
import '../models/opening.dart';
import '../models/profile_system.dart';

/// Manufacturer id for Aluminium du Maroc. A fixed, stable string (not a
/// generated timestamp id like user-created manufacturers get in
/// `ManufacturerSystemPicker._createManufacturer`) so this seed is
/// idempotent -- re-running it must always refer to the same manufacturer
/// record, never create a duplicate with a different id on a later run.
const String aluminiumDuMarocId = 'builtin-aluminium-du-maroc';

/// System id for Cuzco 713 OM, fixed for the same idempotency reason as
/// [aluminiumDuMarocId].
const String cuzco713OmId = 'builtin-cuzco-713-om';

/// Manufacturer id for Sepalumic Maroc.
const String sepalumicId = 'builtin-sepalumic';

/// Manufacturer id for Menara Profil (GPRAL).
const String menaraProfilId = 'builtin-menara-profil';

/// Manufacturer id for Maghreb Extrusion (ME).
const String maghrebExtrusionId = 'builtin-maghreb-extrusion';

const String sepalumic8800Id = 'builtin-sepalumic-8800';
const String sepalumic6700Id = 'builtin-sepalumic-6700';
const String sepalumic6900Id = 'builtin-sepalumic-6900';
const String menaraTargaPlusId = 'builtin-menara-targa-plus';
const String meDomalId = 'builtin-me-domal';

const Manufacturer aluminiumDuMaroc = Manufacturer(
  id: aluminiumDuMarocId,
  // "System family: Profils Systèmes" from the brief is Aluminium du
  // Maroc's own name for its systems product line, not a second
  // manufacturer -- it is not stored as a separate field because
  // `Manufacturer` has none for a product-line label, and folding it into
  // `name` would misrepresent the actual company name. See the "DATA THAT
  // CANNOT BE REPRESENTED YET" note on `ProfileSystem` for where this
  // would belong if a field existed.
  name: 'Aluminium du Maroc',
  isBuiltIn: true,
);

/// Confidence: MEDIUM. Sepalumic Maroc's own website lists these system
/// names (Coulissant 8800/6700/6900) and states thermal-break status for
/// 6700 and 6900, but publishes no numeric profile tables -- same
/// "verified name, unverified numbers" situation as Aluminium du Maroc's
/// systems, just without any numeric system-level data at all this time.
const Manufacturer sepalumic = Manufacturer(
  id: sepalumicId,
  name: 'Sepalumic Maroc',
  isBuiltIn: true,
);

/// Confidence: LOW. No official Menara/GPRAL catalog or spec sheet was
/// found -- "Targa Plus" is a product name seen associated with this
/// distributor, nothing more. See [menaraTargaPlus]'s own doc comment.
const Manufacturer menaraProfil = Manufacturer(
  id: menaraProfilId,
  name: 'Menara Profil (GPRAL)',
  isBuiltIn: true,
);

/// Confidence: LOW. Confirmed only via a business directory (Kerix)
/// listing Maghreb Extrusion as a Casablanca-based extruder/distributor
/// with named series including "DOMAL" -- not confirmed against Maghreb
/// Extrusion's own materials. See [meDomal]'s own doc comment.
const Manufacturer maghrebExtrusion = Manufacturer(
  id: maghrebExtrusionId,
  name: 'Maghreb Extrusion (ME)',
  isBuiltIn: true,
);

/// Cuzco 713 OM -- casement window / French window / entrance door system,
/// thermally broken, 70 mm frame / 78.1 mm sash.
///
/// `supportedOpenings` is populated ONLY with `OpeningType` values that
/// have a matching, explicitly listed dimension configuration in the
/// verified data (single/double-leaf window and French window entries ->
/// `francaise`; tilt-and-turn window/French-window entries ->
/// `oscilloBattant`). "Entrance door" is listed as a category the system
/// covers, but no `OpeningType` value distinctly represents a swinging
/// entrance door apart from `francaise`, and none of the verified
/// dimension entries are specifically a plain door -- so it is not mapped
/// to any `OpeningType` here rather than guessed.
///
/// `profiles` is intentionally empty -- see this file's top doc comment.
/// `ruleSetId` points at the existing generic placeholder rule set
/// (`generic-placeholder`), same as every user-created system gets today;
/// this is an honest "no real calculation rules assigned yet" marker, not
/// real Cuzco 713 OM fabrication logic (none was supplied, and building
/// any is explicitly out of scope for this seed).
///
/// DATA THAT CANNOT BE REPRESENTED YET -- verified but with no current
/// model field to hold it, so it is NOT stored anywhere by this seed:
///   - Category label ("Casement window / French window / entrance door")
///   - Thermal break: yes
///   - Frame thickness: 70 mm / Sash thickness: 78.1 mm
///   - Lining/rebate accommodation: 100/120/140/160/180/200 mm
///   - Glazing: 28 mm insulating glazing, min. rebate height 16 mm,
///     clip-on bead on exterior side, EPDM/TPE gaskets
///   - Assembly: 45° cuts, pin-bracket assembly, Small-Joint sealing
///   - Drainage: oblong/rectangular holes, optional non-return valves
///   - Hardware: rebated hinges (nylon/fibreglass-reinforced sleeves or
///     pins depending on configuration)
///   - Locking: 1- or 3-point espagnolette, roller keepers, 1/4-turn
///     lacquered aluminium handle
///   - Per-configuration maximum dimensions/areas (single-sash window
///     900x1650mm/1.48m², single-leaf French window 1000x2050mm/2.05m²,
///     double-leaf window 1700x1650mm/2.80m², double-leaf French window
///     1600x2050mm/3.28m², French window 2 leaves+fixed
///     2400x2050mm/4.92m², tilt-and-turn window 1350x1650mm/2.22m²,
///     tilt-and-turn French window 1000x2050mm/2.05m², tilt-and-turn
///     window 2 leaves 1800x1650mm/2.97m², tilt-and-turn French window 2
///     leaves 1600x2050mm/3.28m², bellows window 1800x850mm/1.53m²)
///
/// `ProfileSystem` has no free-form/metadata field and no per-category
/// dimension-limit structure -- adding either is a model change outside
/// this seed's scope (see the milestone's "do not stuff verified values
/// into unrelated fields" instruction). This comment is the record of
/// what was verified so a future model change can populate it correctly
/// instead of re-researching it.
const ProfileSystem cuzco713Om = ProfileSystem(
  id: cuzco713OmId,
  manufacturer: 'Aluminium du Maroc',
  manufacturerId: aluminiumDuMarocId,
  name: 'Cuzco 713 OM',
  ruleSetId: 'generic-placeholder',
  profiles: [],
  supportedOpenings: [OpeningType.francaise, OpeningType.oscilloBattant],
  isBuiltIn: true,
);

/// Confidence: MEDIUM. Sliding system, name confirmed on Sepalumic's own
/// site. No thermal-break status stated for this one specifically (unlike
/// 6700/6900 below), so `supportedOpenings` is the only content beyond
/// name/manufacturer -- `coulissante` because "Coulissant" is the system's
/// own stated category. No numeric system-level data (frame thickness,
/// glazing, dimension limits) was published anywhere found -- entirely
/// absent, not just unrepresentable, unlike Cuzco 713 OM where the
/// numbers exist but the model has nowhere to put them.
const ProfileSystem sepalumic8800 = ProfileSystem(
  id: sepalumic8800Id,
  manufacturer: 'Sepalumic Maroc',
  manufacturerId: sepalumicId,
  name: 'Coulissant 8800',
  ruleSetId: 'generic-placeholder',
  profiles: [],
  supportedOpenings: [OpeningType.coulissante],
  isBuiltIn: true,
);

/// Confidence: MEDIUM. Sliding, thermally broken -- both stated on
/// Sepalumic's own site (name includes "(TB)" in their own materials).
/// No numeric system-level data published/found.
const ProfileSystem sepalumic6700 = ProfileSystem(
  id: sepalumic6700Id,
  manufacturer: 'Sepalumic Maroc',
  manufacturerId: sepalumicId,
  name: 'Coulissant 6700 (TB)',
  ruleSetId: 'generic-placeholder',
  profiles: [],
  supportedOpenings: [OpeningType.coulissante],
  isBuiltIn: true,
);

/// Confidence: MEDIUM. Same basis as [sepalumic6700].
const ProfileSystem sepalumic6900 = ProfileSystem(
  id: sepalumic6900Id,
  manufacturer: 'Sepalumic Maroc',
  manufacturerId: sepalumicId,
  name: 'Coulissant 6900 (TB)',
  ruleSetId: 'generic-placeholder',
  profiles: [],
  supportedOpenings: [OpeningType.coulissante],
  isBuiltIn: true,
);

/// Confidence: LOW -- included as an explicitly low-confidence
/// placeholder, not a verified catalog entry. No official documentation
/// was located for "Targa Plus"; it is associated with Menara Profil
/// (GPRAL) in distributor/product-name references only, and its own
/// category is uncertain (possibly a pergola/track system rather than a
/// window/door system at all). Because the category itself is unverified,
/// `supportedOpenings` is left empty rather than guessed -- unlike the
/// Sepalumic/Cuzco entries above, where at least the opening category is
/// confidently known even though numeric specs aren't.
const ProfileSystem menaraTargaPlus = ProfileSystem(
  id: menaraTargaPlusId,
  manufacturer: 'Menara Profil (GPRAL)',
  manufacturerId: menaraProfilId,
  name: 'Targa Plus (non vérifié)',
  ruleSetId: 'generic-placeholder',
  profiles: [],
  supportedOpenings: [],
  isBuiltIn: true,
);

/// Confidence: LOW -- included as an explicitly low-confidence
/// placeholder. "DOMAL" is a series name found via a business directory
/// listing for Maghreb Extrusion, not confirmed against the
/// manufacturer's own materials, and not confirmed to match the sliding
/// system the original request described. `supportedOpenings` uses
/// `coulissante` on the strength of "sliding systems" being the
/// directory's stated product category for this manufacturer -- the
/// weakest justification of any `supportedOpenings` value in this file,
/// flagged here explicitly rather than presented with the same confidence
/// as the Sepalumic entries.
const ProfileSystem meDomal = ProfileSystem(
  id: meDomalId,
  manufacturer: 'Maghreb Extrusion (ME)',
  manufacturerId: maghrebExtrusionId,
  name: 'DOMAL (non vérifié)',
  ruleSetId: 'generic-placeholder',
  profiles: [],
  supportedOpenings: [OpeningType.coulissante],
  isBuiltIn: true,
);

/// Every built-in manufacturer, in the order they were introduced.
const List<Manufacturer> builtInManufacturers = [
  aluminiumDuMaroc,
  sepalumic,
  menaraProfil,
  maghrebExtrusion,
];

/// Every built-in profile system, in the order they were introduced.
const List<ProfileSystem> builtInProfileSystems = [
  cuzco713Om,
  sepalumic8800,
  sepalumic6700,
  sepalumic6900,
  menaraTargaPlus,
  meDomal,
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
/// never modifies or re-adds a record that's already present.
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
