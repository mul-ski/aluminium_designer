import 'package:flutter/material.dart';

import '../../../core/models/catalog.dart';
import '../../../core/models/manufacturer.dart';
import '../../../core/models/profile_system.dart';

/// Lets the user pick an existing [Manufacturer]/[ProfileSystem] from
/// [catalog], or create a new one -- shown inside the construction editor
/// so a construction's manufacturer/system can only ever be one of these
/// two things: something the user already created, or something they're
/// creating right now. Never a hardcoded list.
///
/// [catalog] starts empty for a fresh install and stays empty until the
/// user creates their first manufacturer here -- there is no seeded data.
/// [onCatalogChanged] is called whenever a new manufacturer or system is
/// created, so the caller (the construction editor) can persist the
/// updated catalog via `CatalogStore` and keep its own copy in sync; this
/// widget does not talk to storage directly.
///
/// [selectedManufacturerName]/[selectedSystemName] are the *names*
/// currently stored on the construction being edited
/// (`Construction.manufacturer`/`Construction.system` stay plain strings
/// -- see `Construction`'s doc comment for why), not ids -- this widget
/// resolves them back to catalog entries by name for display, but the
/// callback it invokes on selection passes the chosen entries' names, not
/// ids, matching what the construction model actually stores.
class ManufacturerSystemPicker extends StatelessWidget {
  final Catalog catalog;
  final String? selectedManufacturerName;
  final String? selectedSystemName;
  final ValueChanged<Catalog> onCatalogChanged;
  final void Function(String manufacturerName, String systemName)
  onSelected;

  const ManufacturerSystemPicker({
    super.key,
    required this.catalog,
    required this.selectedManufacturerName,
    required this.selectedSystemName,
    required this.onCatalogChanged,
    required this.onSelected,
  });

  Manufacturer? get _selectedManufacturer {
    if (selectedManufacturerName == null || selectedManufacturerName!.isEmpty) {
      return null;
    }
    for (final manufacturer in catalog.manufacturers) {
      if (manufacturer.name == selectedManufacturerName) {
        return manufacturer;
      }
    }
    return null;
  }

  Future<void> _createManufacturer(BuildContext context) async {
    final name = await _promptForName(
      context,
      title: 'Nouveau fabricant',
      label: 'Nom du fabricant',
    );
    if (name == null || name.isEmpty) return;

    final manufacturer = Manufacturer(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      isBuiltIn: false,
    );

    onCatalogChanged(
      catalog.copyWith(
        manufacturers: [...catalog.manufacturers, manufacturer],
      ),
    );
  }

  Future<void> _createSystem(BuildContext context, Manufacturer manufacturer) async {
    final name = await _promptForName(
      context,
      title: 'Nouveau système',
      label: 'Nom du système',
    );
    if (name == null || name.isEmpty) return;

    // ruleSetId points at the generic placeholder rule set -- this is an
    // honest "no real fabrication rules assigned yet" marker (see
    // `genericPlaceholderRuleSet`'s own doc comment), not invented
    // manufacturer data. profiles/supportedOpenings start empty because
    // this milestone has no profile-catalogue UI to populate them from.
    final system = ProfileSystem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      manufacturer: manufacturer.name,
      manufacturerId: manufacturer.id,
      name: name,
      ruleSetId: 'generic-placeholder',
      profiles: const [],
      supportedOpenings: const [],
      isBuiltIn: false,
    );

    onCatalogChanged(
      catalog.copyWith(profileSystems: [...catalog.profileSystems, system]),
    );
    onSelected(manufacturer.name, system.name);
  }

  Future<String?> _promptForName(
    BuildContext context, {
    required String title,
    required String label,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: label),
            onSubmitted: (value) =>
                Navigator.pop(dialogContext, value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Créer'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final manufacturer = _selectedManufacturer;
    final systems = manufacturer == null
        ? const <ProfileSystem>[]
        : catalog.systemsFor(manufacturer.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: manufacturer?.id,
                decoration: const InputDecoration(labelText: 'Fabricant'),
                hint: catalog.manufacturers.isEmpty
                    ? const Text('Aucun fabricant -- créez-en un')
                    : const Text('Sélectionner un fabricant'),
                items: [
                  for (final m in catalog.manufacturers)
                    DropdownMenuItem(value: m.id, child: Text(m.name)),
                ],
                onChanged: (id) {
                  final chosen = catalog.manufacturers.firstWhere(
                    (m) => m.id == id,
                  );
                  // Selecting a different manufacturer invalidates
                  // whatever system was chosen for the previous one --
                  // an empty system name means "not selected yet" here,
                  // consistent with how selectedSystemName is read above.
                  onSelected(chosen.name, '');
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Créer un fabricant',
              onPressed: () => _createManufacturer(context),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: systems
                        .any((s) => s.name == selectedSystemName)
                    ? systems.firstWhere((s) => s.name == selectedSystemName).id
                    : null,
                decoration: const InputDecoration(labelText: 'Système'),
                hint: manufacturer == null
                    ? const Text('Choisissez d\'abord un fabricant')
                    : systems.isEmpty
                    ? const Text('Aucun système -- créez-en un')
                    : const Text('Sélectionner un système'),
                items: [
                  for (final s in systems)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: manufacturer == null
                    ? null
                    : (id) {
                        final chosen = systems.firstWhere((s) => s.id == id);
                        onSelected(manufacturer.name, chosen.name);
                      },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Créer un système',
              onPressed: manufacturer == null
                  ? null
                  : () => _createSystem(context, manufacturer),
            ),
          ],
        ),
      ],
    );
  }
}
