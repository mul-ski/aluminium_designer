import 'package:flutter/material.dart';

import '../../../core/models/catalog.dart';
import '../../../core/models/profile.dart';
import '../../../core/models/profile_system.dart';

/// Manages the [Profile]s belonging to ONE selected [ProfileSystem].
///
/// This is deliberately its own small widget rather than folded into
/// [ManufacturerSystemPicker] (see that widget's doc comment) -- picking
/// "which system" and managing "what's in the system" are different
/// concerns with different UI shapes (a couple of dropdowns vs. a
/// list+form), and this milestone's UI requirement is to keep the picker
/// itself small.
///
/// [system] is a snapshot of the system as it existed when this panel was
/// opened; every mutation here reconstructs the same [ProfileSystem] with
/// an updated `profiles` list and pushes the WHOLE updated [catalog]
/// through [onCatalogChanged] -- there is no separate profile storage
/// layer. `ProfileSystem` has no `copyWith` (checked: it doesn't exist),
/// so updates build a new `ProfileSystem` directly with every existing
/// field carried over unchanged except `profiles`.
///
/// Does not create, rename, or delete the system itself, and does not
/// touch `Manufacturer`s -- purely profile CRUD within one system.
class ProfileSystemProfilesPanel extends StatelessWidget {
  final Catalog catalog;
  final ProfileSystem system;
  final ValueChanged<Catalog> onCatalogChanged;

  const ProfileSystemProfilesPanel({
    super.key,
    required this.catalog,
    required this.system,
    required this.onCatalogChanged,
  });

  String _typeLabel(ProfileType type) {
    switch (type) {
      case ProfileType.montant:
        return 'Montant';
      case ProfileType.traverse:
        return 'Traverse';
      case ProfileType.ouvrant:
        return 'Ouvrant';
      case ProfileType.dormant:
        return 'Dormant';
      case ProfileType.mullion:
        return 'Meneau';
      case ProfileType.other:
        return 'Autre';
    }
  }

  void _replaceSystemProfiles(List<Profile> profiles) {
    final updatedSystem = ProfileSystem(
      id: system.id,
      manufacturer: system.manufacturer,
      manufacturerId: system.manufacturerId,
      name: system.name,
      ruleSetId: system.ruleSetId,
      profiles: profiles,
      supportedOpenings: system.supportedOpenings,
      isBuiltIn: system.isBuiltIn,
    );
    onCatalogChanged(
      catalog.copyWith(
        profileSystems: [
          for (final s in catalog.profileSystems)
            if (s.id == system.id) updatedSystem else s,
        ],
      ),
    );
  }

  Future<void> _addProfile(BuildContext context) async {
    final profile = await _showProfileDialog(context);
    if (profile == null) return;
    _replaceSystemProfiles([...system.profiles, profile]);
  }

  Future<void> _editProfile(BuildContext context, Profile existing) async {
    final updated = await _showProfileDialog(context, existing: existing);
    if (updated == null) return;
    _replaceSystemProfiles([
      for (final p in system.profiles)
        if (p.id == existing.id) updated else p,
    ]);
  }

  Future<void> _deleteProfile(BuildContext context, Profile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer le profil'),
        content: Text(
          'Supprimer "${profile.reference} -- ${profile.name}" ? Toute '
          'assignation de profil existante référençant ce profil dans une '
          'construction restera enregistrée mais ne pourra plus être '
          'résolue. Cette action est irréversible.',
        ),
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
    if (confirmed != true) return;

    _replaceSystemProfiles(
      system.profiles.where((p) => p.id != profile.id).toList(),
    );
  }

  Future<Profile?> _showProfileDialog(
    BuildContext context, {
    Profile? existing,
  }) async {
    final referenceController = TextEditingController(
      text: existing?.reference ?? '',
    );
    final nameController = TextEditingController(text: existing?.name ?? '');
    final widthController = TextEditingController(
      text: existing?.width.toStringAsFixed(0) ?? '',
    );
    final depthController = TextEditingController(
      text: existing?.depth.toStringAsFixed(0) ?? '',
    );
    final weightController = TextEditingController(
      text: existing?.weightPerMeter.toStringAsFixed(2) ?? '',
    );
    var selectedType = existing?.type ?? ProfileType.montant;

    final result = await showDialog<Profile>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(
                existing == null ? 'Nouveau profil' : 'Modifier le profil',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: referenceController,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Référence'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nom'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<ProfileType>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: [
                        for (final t in ProfileType.values)
                          DropdownMenuItem(
                            value: t,
                            child: Text(_typeLabel(t)),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedType = value);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: widthController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Largeur',
                        suffixText: 'mm',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: depthController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Profondeur',
                        suffixText: 'mm',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Poids',
                        suffixText: 'kg/m',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () {
                    final reference = referenceController.text.trim();
                    final name = nameController.text.trim();
                    final width = double.tryParse(widthController.text.trim());
                    final depth = double.tryParse(depthController.text.trim());
                    final weight = double.tryParse(
                      weightController.text.trim(),
                    );
                    if (reference.isEmpty ||
                        name.isEmpty ||
                        width == null ||
                        depth == null ||
                        weight == null) {
                      return;
                    }
                    Navigator.pop(
                      dialogContext,
                      Profile(
                        id:
                            existing?.id ??
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        manufacturer: system.manufacturer,
                        system: system.name,
                        reference: reference,
                        name: name,
                        type: selectedType,
                        width: width,
                        depth: depth,
                        weightPerMeter: weight,
                      ),
                    );
                  },
                  child: Text(existing == null ? 'Créer' : 'Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );

    referenceController.dispose();
    nameController.dispose();
    widthController.dispose();
    depthController.dispose();
    weightController.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Profils -- ${system.name}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Ajouter un profil',
                onPressed: () => _addProfile(context),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Fermer',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: system.profiles.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Aucun profil dans ce système. Utilisez le bouton + '
                    'pour en ajouter un.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF5B6B76)),
                  ),
                )
              : ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final profile in system.profiles)
                      ListTile(
                        title: Text('${profile.reference} -- ${profile.name}'),
                        subtitle: Text(
                          '${_typeLabel(profile.type)} · '
                          '${profile.width.toStringAsFixed(0)}×'
                          '${profile.depth.toStringAsFixed(0)} mm · '
                          '${profile.weightPerMeter.toStringAsFixed(2)} kg/m'
                          // Inertia shown only when stated on the source
                          // sheet (0 = not stated -- honest omission).
                          '${profile.inertiaIxxCm4 > 0 || profile.inertiaIyyCm4 > 0 ? ' · I ${profile.inertiaIxxCm4.toStringAsFixed(2)}/${profile.inertiaIyyCm4.toStringAsFixed(2)} cm⁴' : ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Modifier',
                              onPressed: () => _editProfile(context, profile),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Supprimer',
                              onPressed: () => _deleteProfile(context, profile),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
