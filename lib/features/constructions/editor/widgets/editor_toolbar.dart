import 'package:flutter/material.dart';

import '../editor_drafting_settings.dart' show kSnapIncrementChoicesMm;

/// The editor's toolbar: selection indicator, section add/remove, viewport
/// zoom controls, the manual Calculate action, and undo/redo.
///
/// Purely presentational -- every button delegates to a callback supplied
/// by `ConstructionEditorScreen`, which owns the controller and the
/// viewport. Button order, icons, and tooltips are stable so tests can
/// target them by tooltip.
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

  /// Whether history has past/future states -- gates the undo/redo
  /// buttons exactly as the controller's canUndo/canRedo gate the
  /// keyboard shortcuts.
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  /// Drafting-aid toggles (workshop canvas): whether automatic snapping is
  /// active and whether the measurement grid is drawn. Both reflect the
  /// editor's per-session `EditorDraftingSettings`; every change routes
  /// through the callbacks so this widget stays purely presentational.
  final bool snapEnabled;
  final ValueChanged<bool> onSnapEnabledChanged;
  final bool gridVisible;
  final ValueChanged<bool> onGridVisibleChanged;

  /// Current grid-snap increment and its change callback. The picker is
  /// only interactive while snapping is enabled -- a disabled control
  /// states that dependency instead of accepting no-op clicks.
  final double snapIncrementMm;
  final ValueChanged<double> onSnapIncrementChanged;

  const EditorToolbar({
    super.key,
    required this.canRemoveSection,
    required this.onAddSection,
    required this.onRemoveSelectedSection,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFitToView,
    required this.onCalculate,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    required this.snapEnabled,
    required this.onSnapEnabledChanged,
    required this.gridVisible,
    required this.onGridVisibleChanged,
    required this.snapIncrementMm,
    required this.onSnapIncrementChanged,
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
            icon: Icons.my_location,
            label: 'Aimanter',
            selected: snapEnabled,
            onPressed: () => onSnapEnabledChanged(!snapEnabled),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Tooltip(
              message: 'Incrément d\'aimantation',
              child: PopupMenuButton<double>(
                enabled: snapEnabled,
                initialValue: snapIncrementMm,
                onSelected: onSnapIncrementChanged,
                itemBuilder: (context) => [
                  for (final choice in kSnapIncrementChoicesMm)
                    PopupMenuItem(
                      value: choice,
                      child: Text('${choice.toStringAsFixed(0)} mm'),
                    ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${snapIncrementMm.toStringAsFixed(0)} mm',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
          ),
          _ToolbarButton(
            icon: gridVisible ? Icons.grid_on : Icons.grid_off,
            label: 'Afficher la grille',
            selected: gridVisible,
            onPressed: () => onGridVisibleChanged(!gridVisible),
          ),
          const VerticalDivider(width: 24, indent: 8, endIndent: 8),
          _ToolbarButton(
            icon: Icons.calculate_outlined,
            label: 'Calculer',
            onPressed: onCalculate,
          ),
          const VerticalDivider(width: 24, indent: 8, endIndent: 8),
          _ToolbarButton(
            icon: Icons.undo,
            label: 'Annuler',
            onPressed: canUndo ? onUndo : null,
          ),
          _ToolbarButton(
            icon: Icons.redo,
            label: 'Rétablir',
            onPressed: canRedo ? onRedo : null,
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
