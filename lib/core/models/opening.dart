enum OpeningType { fixe, francaise, anglaise, oscilloBattant, coulissante }

class Opening {
  final OpeningType type;
  final double width;
  final double height;

  const Opening({
    required this.type,
    required this.width,
    required this.height,
  });
}
