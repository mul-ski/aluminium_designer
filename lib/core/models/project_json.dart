import 'construction.dart';
import 'construction_type.dart';
import 'layout_direction.dart';
import 'opening.dart';
import 'profile.dart';
import 'profile_usage.dart';
import 'project.dart';
import 'section.dart';

/// Current on-disk schema version for a persisted [Project].
///
/// Bumped whenever the JSON shape produced/consumed here changes in a way
/// that isn't purely additive. No migration system exists yet -- this is
/// only a marker so a future migration step has something to branch on. Do
/// not build out multi-version migration logic until it's actually needed.
const int projectSchemaVersion = 1;

/// Converts [Project] (and everything it contains) to/from JSON.
///
/// This is deliberately kept as free functions next to the domain models,
/// not a parallel "ProjectDto"/"ProjectData" class hierarchy -- `Project`,
/// `Construction`, `Section`, etc. remain the single source of truth for
/// the data; these functions only describe how to read/write that same
/// data as JSON. No fields are added, dropped, or renamed here relative to
/// the domain models.
extension ProjectJson on Project {
  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': projectSchemaVersion,
      'id': id,
      'name': name,
      'constructions': constructions.map((c) => c.toJson()).toList(),
    };
  }
}

/// Rebuilds a [Project] from JSON previously produced by [ProjectJson.toJson].
///
/// Throws [FormatException] if [json]'s `schemaVersion` is newer than
/// [projectSchemaVersion] this build understands -- there is no migration
/// path yet, so refusing to guess is safer than silently misreading a
/// future format.
Project projectFromJson(Map<String, dynamic> json) {
  final schemaVersion = json['schemaVersion'] as int? ?? 1;
  if (schemaVersion > projectSchemaVersion) {
    throw FormatException(
      'Project JSON has schemaVersion $schemaVersion, but this app only '
      'understands up to $projectSchemaVersion.',
    );
  }

  final constructionsJson = json['constructions'] as List<dynamic>? ?? [];

  return Project(
    id: json['id'] as String,
    name: json['name'] as String,
    constructions: constructionsJson
        .map((c) => constructionFromJson(c as Map<String, dynamic>))
        .toList(),
  );
}

extension ConstructionJson on Construction {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'width': width,
      'height': height,
      'manufacturer': manufacturer,
      'system': system,
      'layoutDirection': layoutDirection.name,
      'sections': sections.map((s) => s.toJson()).toList(),
      'profiles': profiles.map((p) => p.toJson()).toList(),
      'profileUsages': profileUsages.map((u) => u.toJson()).toList(),
    };
  }
}

Construction constructionFromJson(Map<String, dynamic> json) {
  final sectionsJson = json['sections'] as List<dynamic>? ?? [];
  final profilesJson = json['profiles'] as List<dynamic>? ?? [];
  final profileUsagesJson = json['profileUsages'] as List<dynamic>? ?? [];

  return Construction(
    id: json['id'] as String,
    name: json['name'] as String,
    type: ConstructionType.values.byName(json['type'] as String),
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
    manufacturer: json['manufacturer'] as String,
    system: json['system'] as String,
    layoutDirection: SectionLayoutDirection.values.byName(
      json['layoutDirection'] as String? ?? 'horizontal',
    ),
    sections: sectionsJson
        .map((s) => sectionFromJson(s as Map<String, dynamic>))
        .toList(),
    profiles: profilesJson
        .map((p) => profileFromJson(p as Map<String, dynamic>))
        .toList(),
    profileUsages: profileUsagesJson
        .map((u) => profileUsageFromJson(u as Map<String, dynamic>))
        .toList(),
  );
}

extension SectionJson on Section {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order': order,
      'kind': kind.name,
      'width': width,
      'height': height,
      'openingType': openingType?.name,
      'vantauxCount': vantauxCount,
    };
  }
}

Section sectionFromJson(Map<String, dynamic> json) {
  final openingTypeName = json['openingType'] as String?;

  return Section(
    id: json['id'] as String,
    order: json['order'] as int,
    kind: SectionKind.values.byName(json['kind'] as String),
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
    openingType: openingTypeName == null
        ? null
        : OpeningType.values.byName(openingTypeName),
    vantauxCount: json['vantauxCount'] as int? ?? 0,
  );
}

extension ProfileJson on Profile {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'manufacturer': manufacturer,
      'system': system,
      'reference': reference,
      'name': name,
      'type': type.name,
      'width': width,
      'depth': depth,
      'weightPerMeter': weightPerMeter,
    };
  }
}

Profile profileFromJson(Map<String, dynamic> json) {
  return Profile(
    id: json['id'] as String,
    manufacturer: json['manufacturer'] as String,
    system: json['system'] as String,
    reference: json['reference'] as String,
    name: json['name'] as String,
    type: ProfileType.values.byName(json['type'] as String),
    width: (json['width'] as num).toDouble(),
    depth: (json['depth'] as num).toDouble(),
    weightPerMeter: (json['weightPerMeter'] as num).toDouble(),
  );
}

extension ProfileUsageJson on ProfileUsage {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profileId': profileId,
      'sectionId': sectionId,
      'role': role.name,
      'quantity': quantity,
    };
  }
}

ProfileUsage profileUsageFromJson(Map<String, dynamic> json) {
  return ProfileUsage(
    id: json['id'] as String,
    profileId: json['profileId'] as String,
    sectionId: json['sectionId'] as String,
    role: ProfileUsageRole.values.byName(json['role'] as String),
    quantity: json['quantity'] as int? ?? 1,
  );
}
