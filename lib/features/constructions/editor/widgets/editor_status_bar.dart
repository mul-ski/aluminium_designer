import 'package:flutter/material.dart';

import '../../../../core/models/construction.dart';
import '../../../../core/models/section.dart';
import '../../../../core/models/section_geometry.dart';

/// The editor's bottom status bar: geometry status, overall dimensions,
/// section count, current selection, and save state.
///
/// Purely derived from the passed-in state -- the geometry status comes
/// from `constructionGeometryStatus` on the domain model, never from any
/// editor-side bookkeeping.
class EditorStatusBar extends StatelessWidget {
  final Construction construction;
  final Section? selectedSection;
  final bool isDirty;

  const EditorStatusBar({
    super.key,
    required this.construction,
    required this.selectedSection,
    required this.isDirty,
  });

  @override
  Widget build(BuildContext context) {
    final status = constructionGeometryStatus(construction);
    final section = selectedSection;

    String statusLabel;
    Color statusColor;
    switch (status) {
      case GeometryStatus.valid:
        statusLabel = 'Géométrie valide';
        statusColor = const Color(0xFF2E7D32);
        break;
      case GeometryStatus.invalid:
        statusLabel = 'Géométrie invalide';
        statusColor = const Color(0xFFC62828);
        break;
      case GeometryStatus.incomplete:
        statusLabel = 'Incomplète';
        statusColor = const Color(0xFF7A5C00);
        break;
    }

    final width = construction.width;
    final height = construction.height;
    final dims = (width != null && height != null)
        ? '${width.toStringAsFixed(0)} × ${height.toStringAsFixed(0)} mm'
        : 'Dimensions non définies';

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFFEDEFF1),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: statusColor),
          const SizedBox(width: 6),
          Text(statusLabel, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 20),
          Text(dims, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 20),
          Text(
            '${construction.sections.length} section(s)',
            style: const TextStyle(fontSize: 12),
          ),
          if (section != null) ...[
            const SizedBox(width: 20),
            Text(
              'Sélection : section ${section.order + 1}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
          const Spacer(),
          if (isDirty)
            const Text(
              'Modifications non enregistrées',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Color(0xFF7A5C00),
              ),
            )
          else
            const Text(
              'Tout est enregistré',
              style: TextStyle(fontSize: 12, color: Color(0xFF5B6B76)),
            ),
        ],
      ),
    );
  }
}
