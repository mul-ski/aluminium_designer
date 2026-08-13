import 'manufacturer.dart';

/// Converts [Manufacturer] to/from JSON.
///
/// Kept as free functions/extensions next to the domain model, matching
/// `project_json.dart`'s pattern -- `Manufacturer` stays the single source
/// of truth, this file only describes how to read/write it as JSON.
extension ManufacturerJson on Manufacturer {
  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'isBuiltIn': isBuiltIn};
  }
}

Manufacturer manufacturerFromJson(Map<String, dynamic> json) {
  return Manufacturer(
    id: json['id'] as String,
    name: json['name'] as String,
    isBuiltIn: json['isBuiltIn'] as bool? ?? false,
  );
}
