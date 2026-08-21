import 'package:flutter/material.dart';

import '../../../../core/models/construction.dart';
import '../../../../core/models/section_geometry.dart';
import '../../widgets/construction_painter.dart';

/// The editor's center working zone: a pan/zoomable 2D view of the
/// construction, plus the geometry status banners overlaid on top.
///
/// MODEL-DRIVEN RENDERING: this widget owns no geometry state of its own.
/// Everything drawn comes from [construction] via `ConstructionPainter`/
/// `layoutConstruction`, and every user interaction results in exactly one
/// domain-model change reported back through [onSectionTap] -- there is no
/// second, canvas-side representation of the construction that could
/// diverge from the model.
///
/// The pan/zoom matrix lives in [transformationController], owned by the
/// screen so the toolbar's zoom/fit buttons can drive the same transform.
class EditorCanvas extends StatelessWidget {
  final Construction construction;

  /// Id of the currently selected [Section], or null for the construction
  /// root -- passed straight through to the painter so the highlighted
  /// rectangle always matches what the tree and properties panel show.
  final String? selectedSectionId;

  final TransformationController transformationController;

  /// Called with the tapped section's id, or null when the tap landed on
  /// empty space (selecting the construction root).
  final ValueChanged<String?> onSectionTap;

  const EditorCanvas({
    super.key,
    required this.construction,
    required this.selectedSectionId,
    required this.transformationController,
    required this.onSectionTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = constructionGeometryStatus(construction);
    final problems = validateSectionGeometry(construction);

    return Container(
      color: const Color(0xFFF3F5F6),
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: transformationController,
              minScale: 0.2,
              maxScale: 6,
              boundaryMargin: const EdgeInsets.all(2000),
              child: SizedBox(
                // Large fixed logical canvas so there is visible empty
                // workspace around the construction to pan into, rather
                // than a viewport that always exactly hugs the drawing.
                width: 2000,
                height: 1400,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) => _handleCanvasTap(
                        details.localPosition,
                        Size(constraints.maxWidth, constraints.maxHeight),
                      ),
                      child: CustomPaint(
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                        painter: ConstructionPainter(
                          construction: construction,
                          selectedSectionId: selectedSectionId,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (status == GeometryStatus.incomplete)
            Positioned(
              left: 16,
              top: 16,
              right: 16,
              child: _StatusBanner(
                color: const Color(0xFFFFF3CD),
                textColor: const Color(0xFF7A5C00),
                icon: Icons.edit_note,
                message:
                    'Construction en cours de création -- ajoutez les '
                    'dimensions et au moins une section pour voir l\'aperçu.',
              ),
            )
          else if (status == GeometryStatus.invalid)
            Positioned(
              left: 16,
              top: 16,
              right: 16,
              child: _StatusBanner(
                color: const Color(0xFFFDE2E1),
                textColor: const Color(0xFF8C2E27),
                icon: Icons.error_outline,
                message: problems.join(' '),
              ),
            ),
        ],
      ),
    );
  }

  /// Turns a tap in the (already pan/zoomed) canvas widget's own local
  /// coordinate space into a section selection callback. Because the
  /// `GestureDetector`/`CustomPaint` sit *inside* `InteractiveViewer`'s
  /// child, `details.localPosition` from `onTapUp` is already in the
  /// child's untransformed coordinate space -- `InteractiveViewer` applies
  /// its pan/zoom transform to the child as a whole and reports child-local
  /// coordinates for hits on that child, so no manual matrix math against
  /// the transformation controller is needed here for correctness.
  void _handleCanvasTap(Offset localPosition, Size size) {
    final painter = ConstructionPainter(
      construction: construction,
      selectedSectionId: selectedSectionId,
    );
    final hit = painter.sectionAt(localPosition, size);
    onSectionTap(hit?.section.id);
  }
}

/// Floating message banner shown over the canvas for incomplete/invalid
/// geometry states -- see `GeometryStatus` for why those are distinct
/// states with distinct visual treatments (informational vs error).
class _StatusBanner extends StatelessWidget {
  final Color color;
  final Color textColor;
  final IconData icon;
  final String message;

  const _StatusBanner({
    required this.color,
    required this.textColor,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: textColor))),
        ],
      ),
    );
  }
}
