import 'package:flutter/material.dart';

/// The editor's toolbar: selection indicator, section add/remove, viewport
/// zoom controls, and the manual Calculate action.
///
/// Purely presentational -- every button delegates to a callback supplied
/// by `ConstructionEditorScreen`, which owns the controller and the
/// viewport's `TransformationController`. Button order, icons, and
/// tooltips match the original toolbar exactly.
class EditorToolbar extends StatelessWidget {
  /// Whether a section (as opposed to the construction root) is currently
  /// selected -- gates the remove button.
  final bool canRemoveSection;

  final VoidCallback onAddSection;
  final VoidCallback onRemoveSelectedSection;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFitToView;
  final VoidCallback onCalculate;

  const EditorToolbar({
    super.key,
    required this.canRemoveSection,
    required this.onAddSection,
    required this.onRemoveSelectedSection,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFitToView,
    required this.onCalculate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _ToolbarButton(
            icon: Icons.near_me_outlined,
            label: 'Sélection',
            selected: true,
            onPressed: () {},
          ),
          _ToolbarButton(
            icon: Icons.add_box_outlined,
            label: 'Ajouter une section',
            onPressed: onAddSection,
          ),
          _ToolbarButton(
            icon: Icons.delete_outline,
            label: 'Supprimer la sélection',
            onPressed: canRemoveSection ? onRemoveSelectedSection : null,
          ),
          const VerticalDivider(width: 24, indent: 8, endIndent: 8),
          _ToolbarButton(
            icon: Icons.zoom_in,
            label: 'Zoom avant',
            onPressed: onZoomIn,
          ),
          _ToolbarButton(
            icon: Icons.zoom_out,
            label: 'Zoom arrière',
            onPressed: onZoomOut,
          ),
          _ToolbarButton(
            icon: Icons.fit_screen_outlined,
            label: 'Ajuster à la vue',
            onPressed: onFitToView,
          ),
          const VerticalDivider(width: 24, indent: 8, endIndent: 8),
          _ToolbarButton(
            icon: Icons.calculate_outlined,
            label: 'Calculer',
            onPressed: onCalculate,
          ),
        ],
      ),
    );
  }
}

/// One icon button with a tooltip. A plain `IconButton` would work too,
/// but wrapping it here keeps every toolbar entry visually consistent
/// without repeating the same Padding/Tooltip pair.
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: label,
        child: IconButton(
          icon: Icon(icon),
          isSelected: selected,
          onPressed: onPressed,
        ),
      ),
    );
  }
}
