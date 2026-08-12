enum ConstructionType { window, door }

class Project {
  final String id;
  final String name;
  final ConstructionType type;

  /// Overall dimensions in millimeters.
  final double width;
  final double height;

  const Project({
    required this.id,
    required this.name,
    required this.type,
    required this.width,
    required this.height,
  });
}
