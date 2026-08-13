import 'catalog.dart';
import 'manufacturer_json.dart';
import 'profile_system_json.dart';

/// Current on-disk schema version for a persisted [Catalog].
///
/// Mirrors `projectSchemaVersion` in `project_json.dart` -- same pattern,
/// separate counter, since the catalog and a project are independent
/// files that can evolve on their own schedules. No migration system
/// exists yet, matching the project store's "don't overbuild" constraint;
/// this is only a marker for a future migration step to branch on.
const int catalogSchemaVersion = 1;

/// Converts [Catalog] to/from JSON.
extension CatalogJson on Catalog {
  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': catalogSchemaVersion,
      'manufacturers': manufacturers.map((m) => m.toJson()).toList(),
      'profileSystems': profileSystems.map((s) => s.toJson()).toList(),
    };
  }
}

/// Rebuilds a [Catalog] from JSON previously produced by [CatalogJson.toJson].
///
/// Throws [FormatException] if [json]'s `schemaVersion` is newer than
/// [catalogSchemaVersion] this build understands, matching
/// `projectFromJson`'s behaviour for the same reason: refusing to guess at
/// an unknown future format is safer than silently misreading it.
Catalog catalogFromJson(Map<String, dynamic> json) {
  final schemaVersion = json['schemaVersion'] as int? ?? 1;
  if (schemaVersion > catalogSchemaVersion) {
    throw FormatException(
      'Catalog JSON has schemaVersion $schemaVersion, but this app only '
      'understands up to $catalogSchemaVersion.',
    );
  }

  final manufacturersJson = json['manufacturers'] as List<dynamic>? ?? [];
  final profileSystemsJson = json['profileSystems'] as List<dynamic>? ?? [];

  return Catalog(
    manufacturers: manufacturersJson
        .map((m) => manufacturerFromJson(m as Map<String, dynamic>))
        .toList(),
    profileSystems: profileSystemsJson
        .map((s) => profileSystemFromJson(s as Map<String, dynamic>))
        .toList(),
  );
}
