enum ProfileType { montant, traverse, ouvrant, dormant, mullion, other }

class Profile {
  final String id;
  final String manufacturer;
  final String system;
  final String reference;
  final String name;
  final ProfileType type;

  // Physical dimensions in millimeters.
  final double width;
  final double depth;
  final double weightPerMeter;

  const Profile({
    required this.id,
    required this.manufacturer,
    required this.system,
    required this.reference,
    required this.name,
    required this.type,
    required this.width,
    required this.depth,
    required this.weightPerMeter,
  });
}
