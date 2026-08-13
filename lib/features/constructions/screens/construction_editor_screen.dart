import 'package:flutter/material.dart';

import '../../../core/models/construction.dart';
import '../../../core/models/construction_type.dart';
import '../widgets/construction_painter.dart';

/// Displays one [Construction]'s 2D geometry (outer rectangle + sections),
/// read from the domain model with no separate geometry state.
///
/// This is view-only for this milestone -- no dragging, resizing, or
/// section editing from the canvas. Its job is only to prove that
/// `Construction`/`Section` render correctly in 2D before any editing
/// interaction is layered on top. It does not mutate [construction] and
/// does not return anything on pop, so navigating here and back never
/// changes the project's in-memory state or requires a save.
class ConstructionEditorScreen extends StatelessWidget {
  final Construction construction;

  const ConstructionEditorScreen({super.key, required this.construction});

  String _typeLabel(ConstructionType type) {
    switch (type) {
      case ConstructionType.window:
        return 'Fenêtre';
      case ConstructionType.door:
        return 'Porte';
      case ConstructionType.curtainWall:
        return 'Mur rideau';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(construction.name.isEmpty
            ? _typeLabel(construction.type)
            : construction.name),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                Text(
                  _typeLabel(construction.type),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${construction.width.toStringAsFixed(0)} × '
                  '${construction.height.toStringAsFixed(0)} mm',
                ),
                Text(
                  '${construction.sections.length} section'
                  '${construction.sections.length > 1 ? 's' : ''}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: ConstructionPainter(construction: construction),
                  );
                },
              ),
            ),
          ),
          const _Legend(),
        ],
      ),
    );
  }
}

/// Small static legend explaining the fixed/ouvrant fill colors used by
/// [ConstructionPainter], so the distinction from requirement 5 doesn't
/// rely on the user guessing what each color means.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Wrap(
        spacing: 20,
        runSpacing: 8,
        children: const [
          _LegendEntry(color: Color(0xFFDCE3E8), label: 'Fixe'),
          _LegendEntry(color: Color(0xFFCDE7D8), label: 'Ouvrant'),
        ],
      ),
    );
  }
}

class _LegendEntry extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendEntry({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: const Color(0xFF5B6B76)),
          ),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}
