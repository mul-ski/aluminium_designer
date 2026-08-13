import 'opening.dart';
import 'profile_system.dart';
import 'project_json.dart' show ProfileJson, profileFromJson;

/// Converts [ProfileSystem] to/from JSON.
///
/// Reuses [ProfileJson]/[profileFromJson] from `project_json.dart` for the
/// `profiles` list rather than re-implementing `Profile` serialization a
/// second time -- a `Profile` is serialized identically whether it's
/// reached via a `Construction` or via the `ProfileSystem` that defines
/// it.
extension ProfileSystemJson on ProfileSystem {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'manufacturer': manufacturer,
      'manufacturerId': manufacturerId,
      'name': name,
      'ruleSetId': ruleSetId,
      'profiles': profiles.map((p) => p.toJson()).toList(),
      'supportedOpenings': supportedOpenings.map((o) => o.name).toList(),
      'isBuiltIn': isBuiltIn,
    };
  }
}

ProfileSystem profileSystemFromJson(Map<String, dynamic> json) {
  final profilesJson = json['profiles'] as List<dynamic>? ?? [];
  final supportedOpeningsJson =
      json['supportedOpenings'] as List<dynamic>? ?? [];

  return ProfileSystem(
    id: json['id'] as String,
    manufacturer: json['manufacturer'] as String,
    manufacturerId: json['manufacturerId'] as String,
    name: json['name'] as String,
    ruleSetId: json['ruleSetId'] as String,
    profiles: profilesJson
        .map((p) => profileFromJson(p as Map<String, dynamic>))
        .toList(),
    supportedOpenings: supportedOpeningsJson
        .map((o) => OpeningType.values.byName(o as String))
        .toList(),
    isBuiltIn: json['isBuiltIn'] as bool? ?? false,
  );
}
