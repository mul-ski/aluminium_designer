import 'package:flutter/material.dart';

import '../../../../core/logic/dimension_limit_check.dart';
import '../../../../core/models/catalog.dart';
import '../../../../core/models/construction.dart';
import '../../../../core/models/construction_type.dart';
import '../../../../core/models/layout_direction.dart';
import '../../widgets/manufacturer_system_picker.dart';
import 'dimension_limit_warning_banner.dart';
import 'panel_header.dart';
import 'synced_text_field.dart';

/// Right panel, General stage: construction identity + manufacturer
/// system -- everything construction-level that isn't dimensions or layout
/// direction (those live in [EditorGeometryPropertiesPanel]).
///
/// Purely presentational: every field edit delegates to a callback, and
/// catalog mutations (creating/deleting manufacturers/systems inside the
/// picker) are pushed up through [onCatalogChanged] for the caller to
/// persist.
class EditorGeneralPropertiesPanel extends StatelessWidget {
  final Construction draft;
  final Catalog catalog;
  final String Function(ConstructionType) typeLabel;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<ConstructionType> onTypeChanged;
  final void Function(
    String manufacturerName,
    String systemName, {
    String? manufacturerId,
    String? systemId,
  })
  onManufacturerSystemSelected;
  final ValueChanged<Catalog> onCatalogChanged;

  const EditorGeneralPropertiesPanel({
    super.key,
    required this.draft,
    required this.catalog,
    required this.typeLabel,
    required this.onNameChanged,
    required this.onTypeChanged,
    required this.onManufacturerSystemSelected,
    required this.onCatalogChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PanelHeader('GÉNÉRAL'),
        SyncedTextField(
          value: draft.name,
          label: 'Nom',
          onChanged: onNameChanged,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ConstructionType>(
          initialValue: draft.type,
          decoration: const InputDecoration(labelText: 'Type'),
          items: [
            for (final type in ConstructionType.values)
              DropdownMenuItem(value: type, child: Text(typeLabel(type))),
          ],
          onChanged: (value) {
            if (value != null) onTypeChanged(value);
          },
        ),
        const SizedBox(height: 20),
        const PanelHeader('SYSTÈME'),
        ManufacturerSystemPicker(
          catalog: catalog,
          selectedManufacturerId: draft.manufacturerId,
          selectedSystemId: draft.systemId,
          selectedManufacturerName: draft.manufacturer.isEmpty
              ? null
              : draft.manufacturer,
          selectedSystemName: draft.system.isEmpty ? null : draft.system,
          onCatalogChanged: onCatalogChanged,
          onSelected: onManufacturerSystemSelected,
        ),
      ],
    );
  }
}

/// Right panel, Geometry stage: construction width/height + layout
/// direction -- the dimensions/layout portion of the construction-level
/// properties.
///
/// Also shows the advisory dimension-limit warning when the draft's
/// overall dimensions exceed every envelope documented on the selected
/// system's fiche (see `checkDimensionLimits`) -- advisory only, it
/// never blocks editing.
class EditorGeometryPropertiesPanel extends StatelessWidget {
  final Construction draft;

  /// The catalog, read-only, to resolve the selected system's dimension
  /// limits. No system selected, or one without a fiche, simply means no
  /// warning can be produced -- unknown limits never read as "within
  /// limits".
  final Catalog catalog;
  final ValueChanged<String> onWidthChanged;
  final ValueChanged<String> onHeightChanged;
  final ValueChanged<SectionLayoutDirection> onLayoutDirectionChanged;

  /// Optional focus nodes so the canvas's dimension-label interaction can
  /// land the user directly in the matching field. Owned by the screen.
  final FocusNode? widthFocusNode;
  final FocusNode? heightFocusNode;

  const EditorGeometryPropertiesPanel({
    super.key,
    required this.draft,
    required this.catalog,
    required this.onWidthChanged,
    required this.onHeightChanged,
    required this.onLayoutDirectionChanged,
    this.widthFocusNode,
    this.heightFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    final limits = catalog
        .systemById(draft.systemId)
        ?.metadata
        ?.dimensionLimits;
    final exceeded = checkDimensionLimits(
      widthMm: draft.width,
      heightMm: draft.height,
      limits: limits ?? const [],
      sectionOpeningTypes: {
        for (final section in draft.sections)
          if (section.openingType != null) section.openingType!,
      },
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PanelHeader('DIMENSIONS'),
        SyncedTextField(
          value: draft.width?.toStringAsFixed(0) ?? '',
          label: 'Largeur',
          suffixText: 'mm',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onWidthChanged,
          focusNode: widthFocusNode,
        ),
        const SizedBox(height: 12),
        SyncedTextField(
          value: draft.height?.toStringAsFixed(0) ?? '',
          label: 'Hauteur',
          suffixText: 'mm',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onHeightChanged,
          focusNode: heightFocusNode,
        ),
        DimensionLimitWarningBanner(exceeded: exceeded),
        const SizedBox(height: 20),
        const PanelHeader('DISPOSITION'),
        SegmentedButton<SectionLayoutDirection>(
          segments: const [
            ButtonSegment(
              value: SectionLayoutDirection.horizontal,
              label: Text('Horizontal'),
            ),
            ButtonSegment(
              value: SectionLayoutDirection.vertical,
              label: Text('Vertical'),
            ),
          ],
          selected: {draft.layoutDirection},
          onSelectionChanged: (selection) =>
              onLayoutDirectionChanged(selection.first),
        ),
      ],
    );
  }
}
