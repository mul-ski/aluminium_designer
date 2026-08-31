import 'package:flutter/material.dart';

import '../../../core/models/catalog.dart';
import '../../../core/models/manufacturer.dart';
import '../../../core/models/profile_system.dart';
import 'profile_system_metadata_panel.dart';
import 'profile_system_profiles_panel.dart';

/// Lets the user pick an existing [Manufacturer]/[ProfileSystem] from
/// [catalog], or create/delete one -- shown inside the construction editor
/// so a construction's manufacturer/system can only ever be one of these
/// two things: something the user already created, or something they're
/// creating right now. Never a hardcoded list.
///
/// This widget stays scoped to manufacturer/system selection and
/// creation/deletion only. Managing the PROFILES that belong to a
/// selected system is a separate, focused widget --
/// [ProfileSystemProfilesPanel] -- reached via the "Profils" button shown
/// once a valid system is selected; the system's advisory specification
/// data and dimension limits are edited via [ProfileSystemMetadataPanel]
/// ("Fiche système"). Keeping both out of this widget is deliberate:
/// this picker's job is "which system", not "what's in the system".
///
/// On first launch the catalog is seeded with the verified built-in
/// manufacturers and systems (see `withBuiltInCatalogSeed` +
/// `CatalogStore.load`); the user can then create additional
/// manufacturer / system entries here. Built-in entries stay inspectable
/// and editable through the "Profils" / "Fiche système" buttons (the
/// fiches and profiles are the user-editable surface for a real system)
/// but cannot be deleted from this picker -- the trash affordance is
/// hidden for `isBuiltIn: true` records, since deleting them would leave
/// the calculator with no rule set for constructions already pointing at
/// them and the seeding pass only re-adds records that were never
/// persisted as deleted, not records the user removed mid-session.
///
/// [selectedManufacturerId]/[selectedSystemId] are the AUTHORITATIVE
/// current selection -- `Construction.manufacturerId`/`.systemId`. This
/// widget resolves them to catalog entries by id, never by name.
/// [selectedManufacturerName]/[selectedSystemName] are only used as a
/// display fallback when the id doesn't resolve (old data with no id yet,
/// or a since-deleted catalog entry) -- see `Construction`'s doc comment.
///
/// [onSelected] is called with both the display names (for backward
/// compatibility -- see `Construction.manufacturer`/`.system`) AND the
/// stable ids of the newly chosen manufacturer/system. The caller (the
/// construction editor's `_applyManufacturerSystem`) is responsible for
/// checking whether the change invalidates any existing `ProfileUsage`
/// records and confirming with the user before applying it -- this widget
/// does not know about `ProfileUsage` at all, keeping it focused on
/// selection only.
class ManufacturerSystemPicker extends StatelessWidget {
  final Catalog catalog;
  final String? selectedManufacturerId;
  final String? selectedSystemId;
  final String? selectedManufacturerName;
  final String? selectedSystemName;
  final ValueChanged<Catalog> onCatalogChanged;
  final void Function(
    String manufacturerName,
    String systemName, {
    String? manufacturerId,
    String? systemId,
  })
  onSelected;

  const ManufacturerSystemPicker({
    super.key,
    required this.catalog,
    required this.selectedManufacturerId,
    required this.selectedSystemId,
    required this.selectedManufacturerName,
    required this.selectedSystemName,
    required this.onCatalogChanged,
    required this.onSelected,
  });

  /// Resolves the selected manufacturer by id first (authoritative); if
  /// that doesn't resolve (no id yet, or deleted), falls back to matching
  /// by the display name so old/stale data still shows *something*
  /// sensible rather than blanking out entirely.
  Manufacturer? get _selectedManufacturer {
    final id = selectedManufacturerId;
    if (id != null) {
      for (final m in catalog.manufacturers) {
        if (m.id == id) return m;
      }
    }
    final name = selectedManufacturerName;
    if (name == null || name.isEmpty) return null;
    for (final m in catalog.manufacturers) {
      if (m.name == name) return m;
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
      catalog.copyWith(manufacturers: [...catalog.manufacturers, manufacturer]),
    );
  }

  Future<void> _createSystem(
    BuildContext context,
    Manufacturer manufacturer,
  ) async {
    final name = await _promptForName(
      context,
      title: 'Nouveau système',
      label: 'Nom du système',
    );
    if (name == null || name.isEmpty) return;

    // ruleSetId points at the generic placeholder rule set -- this is an
    // honest "no real fabrication rules assigned yet" marker (see
    // `genericPlaceholderRuleSet`'s own doc comment), not invented
    // manufacturer data. profiles/supportedOpenings start empty -- see
    // `ProfileSystemProfilesPanel` for where profiles are added to a
    // system after it's created.
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
    onSelected(
      manufacturer.name,
      system.name,
      manufacturerId: manufacturer.id,
      systemId: system.id,
    );
  }

  Future<bool> _confirmDelete(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Deletes [manufacturer] and every [ProfileSystem] that belongs to it
  /// (a system with no manufacturer left would be meaningless). If the
  /// construction currently being edited was pointing at this manufacturer
  /// (by id or, for old data, by name), that selection is cleared via
  /// `onSelected('', '')` with no ids -- the editor's own
  /// `_applyManufacturerSystem` will see the change (an empty/absent
  /// system means no `ProfileUsage`s can possibly be compatible, so it
  /// runs the same confirmation-before-clearing flow as any other
  /// incompatible change).
  Future<void> _deleteManufacturer(
    BuildContext context,
    Manufacturer manufacturer,
  ) async {
    final systemNamesToRemove = catalog
        .systemsFor(manufacturer.id)
        .map((s) => s.name)
        .toSet();

    final confirmed = await _confirmDelete(
      context,
      title: 'Supprimer le fabricant',
      message: systemNamesToRemove.isEmpty
          ? 'Supprimer "${manufacturer.name}" ? Cette action est '
                'irréversible.'
          : 'Supprimer "${manufacturer.name}" et ${systemNamesToRemove.length} '
                'système(s) associé(s) ? Cette action est irréversible.',
    );
    if (!confirmed) return;

    onCatalogChanged(
      catalog.copyWith(
        manufacturers: catalog.manufacturers
            .where((m) => m.id != manufacturer.id)
            .toList(),
        profileSystems: catalog.profileSystems
            .where((s) => s.manufacturerId != manufacturer.id)
            .toList(),
      ),
    );

    if (selectedManufacturerId == manufacturer.id ||
        selectedManufacturerName == manufacturer.name) {
      onSelected('', '');
    }
  }

  /// Deletes [system]. If it was the one currently selected on the
  /// construction being edited, clears just the system half of the
  /// selection (the manufacturer, if any, stays selected) -- see
  /// `_deleteManufacturer`'s doc for why this routes through the same
  /// `onSelected` path rather than special-casing anything here.
  Future<void> _deleteSystem(
    BuildContext context,
    Manufacturer manufacturer,
    ProfileSystem system,
  ) async {
    final confirmed = await _confirmDelete(
      context,
      title: 'Supprimer le système',
      message: 'Supprimer "${system.name}" ? Cette action est irréversible.',
    );
    if (!confirmed) return;

    onCatalogChanged(
      catalog.copyWith(
        profileSystems: catalog.profileSystems
            .where((s) => s.id != system.id)
            .toList(),
      ),
    );

    if (selectedSystemId == system.id || selectedSystemName == system.name) {
      onSelected(manufacturer.name, '', manufacturerId: manufacturer.id);
    }
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
            onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
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

  Future<void> _openProfilesPanel(
    BuildContext context,
    ProfileSystem system,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 640),
          child: ProfileSystemProfilesPanel(
            catalog: catalog,
            system: system,
            onCatalogChanged: onCatalogChanged,
          ),
        ),
      ),
    );
  }

  Future<void> _openMetadataPanel(
    BuildContext context,
    ProfileSystem system,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ProfileSystemMetadataPanel(
        catalog: catalog,
        system: system,
        onCatalogChanged: onCatalogChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manufacturer = _selectedManufacturer;
    final systems = manufacturer == null
        ? const <ProfileSystem>[]
        : catalog.systemsFor(manufacturer.id);

    ProfileSystem? selectedSystem;
    final systemId = selectedSystemId;
    if (systemId != null) {
      for (final s in systems) {
        if (s.id == systemId) {
          selectedSystem = s;
          break;
        }
      }
    }
    selectedSystem ??= systems.any((s) => s.name == selectedSystemName)
        ? systems.firstWhere((s) => s.name == selectedSystemName)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: manufacturer?.id,
                decoration: const InputDecoration(labelText: 'Fabricant'),
                isExpanded: true,
                hint: catalog.manufacturers.isEmpty
                    ? const Text(
                        'Aucun fabricant -- créez-en un',
                        overflow: TextOverflow.ellipsis,
                      )
                    : const Text(
                        'Sélectionner un fabricant',
                        overflow: TextOverflow.ellipsis,
                      ),
                items: [
                  for (final m in catalog.manufacturers)
                    DropdownMenuItem(
                      value: m.id,
                      child: Text(m.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (id) {
                  final chosen = catalog.manufacturers.firstWhere(
                    (m) => m.id == id,
                  );
                  // Selecting a different manufacturer invalidates
                  // whatever system was chosen for the previous one --
                  // no systemId means "not selected yet", consistent with
                  // how selectedSystemId is read above.
                  onSelected(chosen.name, '', manufacturerId: chosen.id);
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Créer un fabricant',
              onPressed: () => _createManufacturer(context),
            ),
            // Built-in manufacturers are seeded data and can't be
            // removed from this picker (the calculator needs them to
            // resolve constructions already pointing at them; the
            // CatalogStore's seeding pass is add-only on the first
            // launch and adopts the user's stored state thereafter).
            // The trash affordance is hidden, not just disabled, so the
            // user can't trigger a confirmation flow for a record the
            // app will not let them remove anyway.
            if (manufacturer != null && !manufacturer.isBuiltIn)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Supprimer ce fabricant',
                onPressed: () => _deleteManufacturer(context, manufacturer),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: selectedSystem?.id,
                decoration: const InputDecoration(labelText: 'Système'),
                isExpanded: true,
                hint: manufacturer == null
                    ? const Text(
                        'Choisissez d\'abord un fabricant',
                        overflow: TextOverflow.ellipsis,
                      )
                    : systems.isEmpty
                    ? const Text(
                        'Aucun système -- créez-en un',
                        overflow: TextOverflow.ellipsis,
                      )
                    : const Text(
                        'Sélectionner un système',
                        overflow: TextOverflow.ellipsis,
                      ),
                items: [
                  for (final s in systems)
                    DropdownMenuItem(
                      value: s.id,
                      child: Text(s.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: manufacturer == null
                    ? null
                    : (id) {
                        final chosen = systems.firstWhere((s) => s.id == id);
                        onSelected(
                          manufacturer.name,
                          chosen.name,
                          manufacturerId: manufacturer.id,
                          systemId: chosen.id,
                        );
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
            // Same built-in guard as the manufacturer delete button:
            // seeded systems are read-only in the picker, the trash
            // affordance is hidden for `isBuiltIn: true` records.
            if (manufacturer != null &&
                selectedSystem != null &&
                !selectedSystem.isBuiltIn)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Supprimer ce système',
                onPressed: () =>
                    _deleteSystem(context, manufacturer, selectedSystem!),
              ),
          ],
        ),
        if (selectedSystem != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openProfilesPanel(context, selectedSystem!),
                  icon: const Icon(Icons.view_list_outlined),
                  label: Text(
                    'Profils (${selectedSystem.profiles.length})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openMetadataPanel(context, selectedSystem!),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text(
                    'Fiche système',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
