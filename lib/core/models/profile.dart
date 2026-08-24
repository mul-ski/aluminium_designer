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

  /// Section inertias in cm⁴, as printed on the manufacturer's
  /// PROFILOSCOPE-style sheets ("Inertie en cm4"). `0` = not stated by
  /// the source (the same unknown marker as width/depth/weightPerMeter).
  ///
  /// Display/analysis data only: no calculation rule consumes inertia
  /// today, so these fields are deliberately excluded from the catalog
  /// calculation fingerprint (see calculation_staleness.dart) -- the
  /// same display-only class as width/depth.
  final double inertiaIxxCm4;
  final double inertiaIyyCm4;

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
    this.inertiaIxxCm4 = 0,
    this.inertiaIyyCm4 = 0,
  });
}
