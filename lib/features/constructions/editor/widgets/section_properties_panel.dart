import 'package:flutter/material.dart';

import '../../../../core/models/opening.dart';
import '../../../../core/models/profile.dart';
import '../../../../core/models/profile_system.dart';
import '../../../../core/models/profile_usage.dart';
import '../../../../core/models/section.dart';
import 'panel_header.dart';
import 'synced_text_field.dart';

/// Right panel, Sections stage: one selected [Section]'s own properties
/// (dimensions, fixed/ouvrant, opening type, vantaux).
class SectionPropertiesPanel extends StatelessWidget {
  final Section section;
  final ValueChanged<String> onWidthChanged;
  final ValueChanged<String> onHeightChanged;
  final ValueChanged<SectionKind> onKindChanged;
  final ValueChanged<OpeningType> onOpeningTypeChanged;
  final ValueChanged<int> onVantauxCountChanged;

  const SectionPropertiesPanel({
    super.key,
    required this.section,
    required this.onWidthChanged,
    required this.onHeightChanged,
    required this.onKindChanged,
    required this.onOpeningTypeChanged,
    required this.onVantauxCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PanelHeader('GÉNÉRAL -- SECTION ${section.order + 1}'),
        const SizedBox(height: 8),
        const PanelHeader('DIMENSIONS'),
        SyncedTextField(
          key: ValueKey('sec-width-${section.id}'),
          value: section.width.toStringAsFixed(0),
          label: 'Largeur',
          suffixText: 'mm',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onWidthChanged,
        ),
        const SizedBox(height: 12),
        SyncedTextField(
          key: ValueKey('sec-height-${section.id}'),
          value: section.height.toStringAsFixed(0),
          label: 'Hauteur',
          suffixText: 'mm',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onHeightChanged,
        ),
        const SizedBox(height: 20),
        const PanelHeader('TYPE'),
        SegmentedButton<SectionKind>(
          segments: const [
            ButtonSegment(value: SectionKind.fixed, label: Text('Fixe')),
            ButtonSegment(value: SectionKind.ouvrant, label: Text('Ouvrant')),
          ],
          selected: {section.kind},
          onSelectionChanged: (selection) => onKindChanged(selection.first),
        ),
        if (section.kind == SectionKind.ouvrant) ...[
          const SizedBox(height: 20),
          const PanelHeader('OUVERTURE'),
          DropdownButtonFormField<OpeningType>(
            initialValue: section.openingType,
            decoration: const InputDecoration(labelText: "Type d'ouverture"),
            items: const [
              DropdownMenuItem(
                value: OpeningType.francaise,
                child: Text('Française'),
              ),
              DropdownMenuItem(
                value: OpeningType.anglaise,
                child: Text('Anglaise'),
              ),
              DropdownMenuItem(
                value: OpeningType.oscilloBattant,
                child: Text('Oscillo-battant'),
              ),
              DropdownMenuItem(
                value: OpeningType.coulissante,
                child: Text('Coulissante'),
              ),
            ],
            onChanged: (value) {
              if (value != null) onOpeningTypeChanged(value);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Vantaux :'),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: section.vantauxCount > 1
                    ? () => onVantauxCountChanged(section.vantauxCount - 1)
                    : null,
              ),
              Text(
                '${section.vantauxCount}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => onVantauxCountChanged(section.vantauxCount + 1),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Sections stage: assigns [Profile]s (from the currently resolved
/// [ProfileSystem] ONLY) to [section] as [ProfileUsage] records.
///
/// This is intentionally a *separate* panel from [SectionPropertiesPanel]
/// rather than folded into it -- profile assignment is a distinct concern
/// (which catalog profile plays which role) from section geometry (width/
/// height/kind/opening), and keeping them visually separated avoids this
/// becoming one long undifferentiated form.
///
/// [system]'s `.profiles` is the ONLY source of assignable profiles --
/// this never reads `Construction.profiles` (the old, retired path; see
/// `Construction`'s doc comment) and never lets the user pick a profile
/// from any other system.
class SectionProfileAssignmentPanel extends StatelessWidget {
  final Section section;
  final ProfileSystem system;
  final List<ProfileUsage> usages;
  final void Function({
    required String profileId,
    required ProfileUsageRole role,
  })
  onAdd;
  final void Function(ProfileUsage usage, int quantity) onQuantityChanged;
  final ValueChanged<ProfileUsage> onRemove;

  const SectionProfileAssignmentPanel({
    super.key,
    required this.section,
    required this.system,
    required this.usages,
    required this.onAdd,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  String _roleLabel(ProfileUsageRole role) {
    switch (role) {
      case ProfileUsageRole.left:
        return 'Gauche';
      case ProfileUsageRole.right:
        return 'Droite';
      case ProfileUsageRole.top:
        return 'Haut';
      case ProfileUsageRole.bottom:
        return 'Bas';
      case ProfileUsageRole.intermediate:
        return 'Intermédiaire';
    }
  }

  Profile? _profileFor(String profileId) {
    for (final p in system.profiles) {
      if (p.id == profileId) return p;
    }
    return null;
  }

  Future<void> _showAddDialog(BuildContext context) async {
    if (system.profiles.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Aucun profil disponible'),
          content: Text(
            'Le système "${system.name}" ne contient encore aucun profil. '
            'Ajoutez-en un via "Profils du système" dans l\'onglet Général.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
      return;
    }

    String? selectedProfileId = system.profiles.first.id;
    var selectedRole = ProfileUsageRole.left;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Assigner un profil'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedProfileId,
                    decoration: const InputDecoration(labelText: 'Profil'),
                    isExpanded: true,
                    items: [
                      for (final p in system.profiles)
                        DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            '${p.reference} -- ${p.name}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => selectedProfileId = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ProfileUsageRole>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(labelText: 'Rôle'),
                    items: [
                      for (final role in ProfileUsageRole.values)
                        DropdownMenuItem(
                          value: role,
                          child: Text(_roleLabel(role)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedRole = value);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Assigner'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && selectedProfileId != null) {
      onAdd(profileId: selectedProfileId!, role: selectedRole);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              const Expanded(child: PanelHeader('PROFILS ASSIGNÉS')),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Assigner un profil',
                onPressed: () => _showAddDialog(context),
              ),
            ],
          ),
        ),
        if (usages.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Aucun profil assigné à cette section.',
              style: TextStyle(color: Color(0xFF5B6B76)),
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final usage in usages)
                  _ProfileUsageTile(
                    usage: usage,
                    profile: _profileFor(usage.profileId),
                    roleLabel: _roleLabel(usage.role),
                    onQuantityChanged: (q) => onQuantityChanged(usage, q),
                    onRemove: () => onRemove(usage),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One row in [SectionProfileAssignmentPanel]'s list.
///
/// [profile] is nullable to handle the (should-not-normally-happen but
/// must not crash) case of a `ProfileUsage.profileId` that no longer
/// resolves in the current system's profile list -- e.g. the profile was
/// deleted from the system after this usage was created. Shown with a
/// warning treatment rather than throwing or silently omitting the row,
/// so the user can see and remove the broken assignment.
class _ProfileUsageTile extends StatelessWidget {
  final ProfileUsage usage;
  final Profile? profile;
  final String roleLabel;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  const _ProfileUsageTile({
    required this.usage,
    required this.profile,
    required this.roleLabel,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p == null
                        ? 'Profil introuvable (${usage.profileId})'
                        : '${p.reference} -- ${p.name}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: p == null ? const Color(0xFFC62828) : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    roleLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5B6B76),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: usage.quantity > 1
                  ? () => onQuantityChanged(usage.quantity - 1)
                  : null,
              tooltip: 'Réduire la quantité',
            ),
            Text('${usage.quantity}'),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => onQuantityChanged(usage.quantity + 1),
              tooltip: 'Augmenter la quantité',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Retirer cette assignation',
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown in the Sections stage's right panel when no section is currently
/// selected (e.g. the user just switched to this stage, or just removed
/// the selected section). Directs the user to either pick an existing
/// section or add one via the toolbar, rather than showing an empty panel.
class NoSectionSelectedNotice extends StatelessWidget {
  const NoSectionSelectedNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Text(
          'Sélectionnez une section dans la liste à gauche ou '
          'ajoutez-en une avec le bouton "Ajouter une section" '
          'de la barre d\'outils.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF5B6B76)),
        ),
      ),
    );
  }
}

/// Shown in the Sections stage's right panel when a section IS selected
/// but no valid [ProfileSystem] is resolved for the construction -- either
/// none was ever selected, or one was selected and its id no longer
/// resolves in the catalog (deleted system/manufacturer).
///
/// [unresolved] distinguishes the two cases in the message shown (the
/// underlying fact -- no profiles are available to assign -- is the same
/// either way), so the user benefits from knowing which situation they're
/// in even though the available profiles (none, either way) are identical.
class NoSystemSelectedNotice extends StatelessWidget {
  final bool unresolved;

  const NoSystemSelectedNotice({super.key, required this.unresolved});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              unresolved ? Icons.link_off : Icons.info_outline,
              color: const Color(0xFF5B6B76),
            ),
            const SizedBox(height: 8),
            Text(
              unresolved
                  ? 'Le système précédemment sélectionné n\'existe plus '
                        'dans le catalogue. Sélectionnez un système valide '
                        'dans l\'onglet Général pour gérer les profils.'
                  : 'Sélectionnez un système dans l\'onglet Général pour '
                        'pouvoir assigner des profils à cette section.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF5B6B76)),
            ),
          ],
        ),
      ),
    );
  }
}
