library;

import '../models/catalog.dart';
import '../models/manufacturer.dart';
import '../models/opening.dart';
import '../models/profile_system.dart';

/// Real, manufacturer-verified `Manufacturer`/`ProfileSystem` records
/// shipped with the app, and the merge logic that adds them to whatever
/// catalog a user already has on disk.
///
/// EVERY field set below was supplied as verified fact from Aluminium du
/// Maroc's own product pages -- nothing here is inferred, estimated, or
/// invented. Where the current `ProfileSystem` model has no field to hold
/// a piece of verified data, that data is deliberately left out rather
/// than forced into an unrelated field -- see the "DATA THAT CANNOT BE
/// REPRESENTED YET" section below for the full list of what's missing and
/// why. `profiles` stays empty for the same reason: individual profile
/// reference/width/depth/weight data was not supplied, and this file must
/// not fabricate any to make a picker look populated.

/// Manufacturer id for Aluminium du Maroc. A fixed, stable string (not a
/// generated timestamp id like user-created manufacturers get in
/// `ManufacturerSystemPicker._createManufacturer`) so this seed is
/// idempotent -- re-running it must always refer to the same manufacturer
/// record, never create a duplicate with a different id on a later run.
const String aluminiumDuMarocId = 'builtin-aluminium-du-maroc';

/// System id for Cuzco 713 OM, fixed for the same idempotency reason as
/// [aluminiumDuMarocId].
const String cuzco713OmId = 'builtin-cuzco-713-om';

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

/// Returns [catalog] with the built-in manufacturer/system records above
/// merged in, added only if not already present (matched by id).
///
/// Idempotent and non-destructive by design: calling this on every
/// `CatalogStore.load()` (see that class) must never duplicate entries on
/// a second run, and must never overwrite a user's own edits to their
/// catalog -- a user could in principle rename or delete their own
/// unrelated manufacturers/systems, or even (via existing delete UI) the
/// built-in ones themselves, and this function must respect that rather
/// than resurrecting anything the user removed. It only ADDS a record
/// when one with that exact id is completely absent; it never modifies or
/// re-adds an existing one.
Catalog withBuiltInCatalogSeed(Catalog catalog) {
  final hasManufacturer = catalog.manufacturers.any(
    (m) => m.id == aluminiumDuMarocId,
  );
  final hasSystem = catalog.profileSystems.any((s) => s.id == cuzco713OmId);

  if (hasManufacturer && hasSystem) return catalog;

  return catalog.copyWith(
    manufacturers: hasManufacturer
        ? catalog.manufacturers
        : [...catalog.manufacturers, aluminiumDuMaroc],
    profileSystems: hasSystem
        ? catalog.profileSystems
        : [...catalog.profileSystems, cuzco713Om],
  );
}
