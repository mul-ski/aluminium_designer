import 'package:flutter/material.dart';

import '../../../core/models/catalog.dart';
import '../../../core/models/opening.dart';
import '../../../core/models/profile_system.dart';
import '../../../core/models/profile_system_metadata.dart';

/// One editable [DimensionLimit] row inside [ProfileSystemMetadataPanel].
class _LimitDraft {
  final TextEditingController maxWidthController;
  final TextEditingController maxHeightController;
  OpeningType? openingType;

  _LimitDraft({
    required double? maxWidth,
    required double? maxHeight,
    required this.openingType,
  }) : maxWidthController = TextEditingController(
         text: maxWidth?.toStringAsFixed(0) ?? '',
       ),
       maxHeightController = TextEditingController(
         text: maxHeight?.toStringAsFixed(0) ?? '',
       );

  void dispose() {
    maxWidthController.dispose();
    maxHeightController.dispose();
  }
}

String _openingTypeLabel(OpeningType type) {
  switch (type) {
    case OpeningType.fixe:
      return 'Fixe';
    case OpeningType.francaise:
      return 'À la française';
    case OpeningType.anglaise:
      return 'À l\'anglaise';
    case OpeningType.oscilloBattant:
      return 'Oscillo-battant';
    case OpeningType.coulissante:
      return 'Coulissant';
  }
}

/// Views and edits the advisory specification data ("fiche système") of
/// ONE [ProfileSystem]: frame/stile depths, glazing range, thermal-break
/// status, assembly/drainage/finish notes, source citation, and the
/// verified maximum-dimension envelopes ([DimensionLimit]) that the
/// editor's limit warnings read.
///
/// Everything here is ADVISORY data: nothing edited by this panel feeds
/// `ConstructionCalculator` -- the calculation path still runs entirely
/// off the system's `ruleSetId` and `profiles`. This panel exists so the
/// facts live in typed models instead of sticky notes, and so users can
/// maintain limits for their own (non-seeded) systems -- the built-in
/// Série 14600 ships pre-filled from `docs/VERIFIED_SOURCES.md`-cited
/// data, and editing it here is the user's own responsibility.
///
/// Same mutation shape as [ProfileSystemProfilesPanel]: [system] is a
/// snapshot; saving reconstructs the whole [ProfileSystem] (no
/// `copyWith` exists) with an updated `metadata` and pushes the updated
/// [catalog] through [onCatalogChanged]. Saving an entirely empty form
/// clears `metadata` to null -- absent means "no verified fiche", the
/// same state every user-created system starts in.
class ProfileSystemMetadataPanel extends StatefulWidget {
  final Catalog catalog;
  final ProfileSystem system;
  final ValueChanged<Catalog> onCatalogChanged;

  const ProfileSystemMetadataPanel({
    super.key,
    required this.catalog,
    required this.system,
    required this.onCatalogChanged,
  });

  @override
  State<ProfileSystemMetadataPanel> createState() =>
      _ProfileSystemMetadataPanelState();
}

class _ProfileSystemMetadataPanelState
    extends State<ProfileSystemMetadataPanel> {
  static const String _unknownThermalBreak = 'unknown';
  static const String _yesThermalBreak = 'yes';
  static const String _noThermalBreak = 'no';

  late final TextEditingController _frameDepthsController;
  late final TextEditingController _stileDepthsController;
  late final TextEditingController _meetingStileController;
  late final TextEditingController _glazingRebateController;
  late final TextEditingController _glazingMinController;
  late final TextEditingController _glazingMaxController;
  late final TextEditingController _assemblyNoteController;
  late final TextEditingController _drainageNoteController;
  late final TextEditingController _finishNoteController;
  late final TextEditingController _sourceController;
  String? _thermalBreakSelection;
  List<_LimitDraft> _limits = [];

  @override
  void initState() {
    super.initState();
    final metadata = widget.system.metadata;
    _frameDepthsController = TextEditingController(
      text: _joinDepths(metadata?.frameDepthOptionsMm),
    );
    _stileDepthsController = TextEditingController(
      text: _joinDepths(metadata?.sashStileDepthOptionsMm),
    );
    _meetingStileController = TextEditingController(
      text: metadata?.sashMeetingStileDepthMm?.toStringAsFixed(2) ?? '',
    );
    _glazingRebateController = TextEditingController(
      text: metadata?.glazingRebateMm?.toStringAsFixed(2) ?? '',
    );
    _glazingMinController = TextEditingController(
      text: metadata?.glazingMinMm?.toStringAsFixed(2) ?? '',
    );
    _glazingMaxController = TextEditingController(
      text: metadata?.glazingMaxMm?.toStringAsFixed(2) ?? '',
    );
    _assemblyNoteController = TextEditingController(
      text: metadata?.assemblyNote ?? '',
    );
    _drainageNoteController = TextEditingController(
      text: metadata?.drainageNote ?? '',
    );
    _finishNoteController = TextEditingController(
      text: metadata?.finishNote ?? '',
    );
    _sourceController = TextEditingController(
      text: metadata?.sourceDescription ?? '',
    );
    _thermalBreakSelection = switch (metadata?.thermalBreak) {
      null => _unknownThermalBreak,
      true => _yesThermalBreak,
      false => _noThermalBreak,
    };
    _limits = [
      for (final limit in metadata?.dimensionLimits ?? const <DimensionLimit>[])
        _LimitDraft(
          maxWidth: limit.maxWidthMm,
          maxHeight: limit.maxHeightMm,
          openingType: limit.openingType,
        ),
    ];
  }

  @override
  void dispose() {
    _frameDepthsController.dispose();
    _stileDepthsController.dispose();
    _meetingStileController.dispose();
    _glazingRebateController.dispose();
    _glazingMinController.dispose();
    _glazingMaxController.dispose();
    _assemblyNoteController.dispose();
    _drainageNoteController.dispose();
    _finishNoteController.dispose();
    _sourceController.dispose();
    for (final limit in _limits) {
      limit.dispose();
    }
    super.dispose();
  }

  /// "44, 66.34" -> [44.0, 66.34]. Splits on commas/semicolons, drops
  /// anything unparseable or non-positive -- a typo must not silently
  /// become a fabricated depth.
  static String _joinDepths(List<double>? depths) =>
      depths?.map((d) => d.toStringAsFixed(2)).join(', ') ?? '';

  static List<double> _splitDepths(String raw) => [
    for (final part in raw.split(RegExp('[,;]')))
      ...() {
        final value = double.tryParse(part.trim());
        return [if (value != null && value > 0) value];
      }(),
  ];

  static double? _parseOptional(String raw) {
    final value = double.tryParse(raw.trim());
    return value == null || value <= 0 ? null : value;
  }

  void _addLimit() {
    setState(() {
      _limits.add(_LimitDraft(maxWidth: null, maxHeight: null, openingType: null));
    });
  }

  void _removeLimit(int index) {
    setState(() {
      _limits.removeAt(index).dispose();
    });
  }

  void _save() {
    final frameDepths = _splitDepths(_frameDepthsController.text);
    final stileDepths = _splitDepths(_stileDepthsController.text);
    final meetingStile = _parseOptional(_meetingStileController.text);
    final glazingRebate = _parseOptional(_glazingRebateController.text);
    final glazingMin = _parseOptional(_glazingMinController.text);
    final glazingMax = _parseOptional(_glazingMaxController.text);
    final thermalBreak = switch (_thermalBreakSelection) {
      _yesThermalBreak => true,
      _noThermalBreak => false,
      _ => null,
    };
    final assemblyNote = _assemblyNoteController.text.trim();
    final drainageNote = _drainageNoteController.text.trim();
    final finishNote = _finishNoteController.text.trim();
    final source = _sourceController.text.trim();
    final limits = <DimensionLimit>[];
    for (final draft in _limits) {
      final maxWidth = _parseOptional(draft.maxWidthController.text);
      final maxHeight = _parseOptional(draft.maxHeightController.text);
      if (maxWidth == null || maxHeight == null) {
        // An incomplete row (one dim missing/unparseable) is dropped
        // rather than half-saved -- a limit with a made-up zero side
        // would either never warn or always warn.
        continue;
      }
      limits.add(
        DimensionLimit(
          openingType: draft.openingType,
          maxWidthMm: maxWidth,
          maxHeightMm: maxHeight,
        ),
      );
    }

    final isEverythingEmpty =
        frameDepths.isEmpty &&
        stileDepths.isEmpty &&
        meetingStile == null &&
        glazingRebate == null &&
        glazingMin == null &&
        glazingMax == null &&
        thermalBreak == null &&
        assemblyNote.isEmpty &&
        drainageNote.isEmpty &&
        finishNote.isEmpty &&
        limits.isEmpty &&
        source.isEmpty;

    final metadata = isEverythingEmpty
        ? null
        : ProfileSystemMetadata(
            frameDepthOptionsMm: frameDepths,
            sashStileDepthOptionsMm: stileDepths,
            sashMeetingStileDepthMm: meetingStile,
            glazingRebateMm: glazingRebate,
            glazingMinMm: glazingMin,
            glazingMaxMm: glazingMax,
            thermalBreak: thermalBreak,
            assemblyNote: assemblyNote.isEmpty ? null : assemblyNote,
            drainageNote: drainageNote.isEmpty ? null : drainageNote,
            finishNote: finishNote.isEmpty ? null : finishNote,
            dimensionLimits: limits,
            sourceDescription: source,
          );

    final system = widget.system;
    final updatedSystem = ProfileSystem(
      id: system.id,
      manufacturer: system.manufacturer,
      manufacturerId: system.manufacturerId,
      name: system.name,
      ruleSetId: system.ruleSetId,
      profiles: system.profiles,
      supportedOpenings: system.supportedOpenings,
      isBuiltIn: system.isBuiltIn,
      metadata: metadata,
    );
    widget.onCatalogChanged(
      widget.catalog.copyWith(
        profileSystems: [
          for (final s in widget.catalog.profileSystems)
            if (s.id == system.id) updatedSystem else s,
        ],
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final system = widget.system;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Fiche système -- ${system.name}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Fermer sans enregistrer',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _frameDepthsController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Profondeurs dormant (séparées par virgule)',
                      suffixText: 'mm',
                      helperText: 'ex. 44, 66.34',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _stileDepthsController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText:
                          'Profondeurs montants latéraux (séparées par '
                          'virgule)',
                      suffixText: 'mm',
                      helperText: 'ex. 56, 69.2',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _meetingStileController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Profondeur montant central',
                      suffixText: 'mm',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _glazingRebateController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                          decoration: const InputDecoration(
                            labelText: 'Feuillure vitrage',
                            suffixText: 'mm',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _glazingMinController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                          decoration: const InputDecoration(
                            labelText: 'Vitre min',
                            suffixText: 'mm',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _glazingMaxController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                          decoration: const InputDecoration(
                            labelText: 'Vitre max',
                            suffixText: 'mm',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _thermalBreakSelection,
                    decoration: const InputDecoration(
                      labelText: 'Rupture de pont thermique',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: _unknownThermalBreak,
                        child: Text('Non renseigné'),
                      ),
                      DropdownMenuItem(
                        value: _yesThermalBreak,
                        child: Text('Oui'),
                      ),
                      DropdownMenuItem(
                        value: _noThermalBreak,
                        child: Text('Non'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _thermalBreakSelection = value);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _assemblyNoteController,
                    decoration: const InputDecoration(
                      labelText: 'Assemblage (note)',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _drainageNoteController,
                    decoration: const InputDecoration(
                      labelText: 'Drainage (note)',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _finishNoteController,
                    decoration: const InputDecoration(
                      labelText: 'Finition (note)',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Dimensions maximales vérifiées',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Avertissements conseillers: la construction sera '
                    'signalée si elle dépasse TOUTES les limites listées '
                    'pour son type d\'ouverture. Laisser vide = aucune '
                    'limite connue.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF5B6B76)),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < _limits.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<OpeningType?>(
                              initialValue: _limits[i].openingType,
                              decoration: const InputDecoration(
                                labelText: 'Type',
                              ),
                              items: [
                                const DropdownMenuItem<OpeningType?>(
                                  value: null,
                                  child: Text('Tous'),
                                ),
                                for (final type in OpeningType.values)
                                  DropdownMenuItem(
                                    value: type,
                                    child: Text(_openingTypeLabel(type)),
                                  ),
                              ],
                              onChanged: (value) {
                                setState(() => _limits[i].openingType = value);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _limits[i].maxWidthController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'L max',
                                suffixText: 'mm',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _limits[i].maxHeightController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'H max',
                                suffixText: 'mm',
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Supprimer cette limite',
                            onPressed: () => _removeLimit(i),
                          ),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _addLimit,
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter une limite'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _sourceController,
                    decoration: const InputDecoration(
                      labelText: 'Source des données',
                      helperText:
                          'ex. référence du document constructeur, fiche '
                          'atelier...',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _save,
                    child: const Text('Enregistrer'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
