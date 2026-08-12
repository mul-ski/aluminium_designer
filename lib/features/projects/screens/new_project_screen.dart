import 'package:flutter/material.dart';
import '../../../core/models/construction.dart';
import '../../../core/models/construction_type.dart';
import '../../../core/models/opening.dart';
import '../../../core/models/project.dart';
import '../../../core/models/section.dart';

/// Draft state for one section being edited, before it's converted into an
/// immutable [Section]. A plain mutable holder is used here (rather than
/// constructing [Section] directly per keystroke) because [Section]'s
/// constructor throws on invalid combinations (e.g. ouvrant with no
/// openingType) -- the UI needs to hold in-progress, possibly-incomplete
/// state without ever tripping that validation.
class _SectionDraft {
  SectionKind kind = SectionKind.fixed;
  final TextEditingController widthController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  OpeningType? openingType;
  int vantauxCount = 1;

  void dispose() {
    widthController.dispose();
    heightController.dispose();
  }
}

class NewProjectScreen extends StatefulWidget {
  const NewProjectScreen({super.key});

  @override
  State<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends State<NewProjectScreen> {
  final nameController = TextEditingController();
  final widthController = TextEditingController();
  final heightController = TextEditingController();

  ConstructionType type = ConstructionType.window;

  final List<_SectionDraft> sectionDrafts = [_SectionDraft()];

  @override
  void dispose() {
    nameController.dispose();
    widthController.dispose();
    heightController.dispose();
    for (final draft in sectionDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void addSection() {
    setState(() {
      sectionDrafts.add(_SectionDraft());
    });
  }

  void removeSection(int index) {
    setState(() {
      sectionDrafts[index].dispose();
      sectionDrafts.removeAt(index);
    });
  }

  /// Validates and builds the ordered [Section] list from [sectionDrafts].
  ///
  /// Returns `null` (and shows a [SnackBar]) if any draft is incomplete or
  /// invalid, instead of letting an invalid [Section] be constructed --
  /// per the requirement that the UI prevent invalid `Section` objects
  /// rather than create invalid data.
  List<Section>? buildSections() {
    if (sectionDrafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins une section.')),
      );
      return null;
    }

    final sections = <Section>[];

    for (var i = 0; i < sectionDrafts.length; i++) {
      final draft = sectionDrafts[i];
      final width = double.tryParse(draft.widthController.text);
      final height = double.tryParse(draft.heightController.text);

      if (width == null || height == null || width <= 0 || height <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Section ${i + 1} : largeur et hauteur doivent être '
              'renseignées et supérieures à zéro.',
            ),
          ),
        );
        return null;
      }

      if (draft.kind == SectionKind.ouvrant && draft.openingType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Section ${i + 1} : veuillez choisir un type d\'ouverture.',
            ),
          ),
        );
        return null;
      }

      if (draft.kind == SectionKind.ouvrant && draft.vantauxCount < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Section ${i + 1} : le nombre de vantaux doit être au '
              'moins 1.',
            ),
          ),
        );
        return null;
      }

      sections.add(
        Section(
          id: '${DateTime.now().millisecondsSinceEpoch}-$i',
          order: i,
          kind: draft.kind,
          width: width,
          height: height,
          openingType: draft.kind == SectionKind.ouvrant
              ? draft.openingType
              : null,
          vantauxCount: draft.kind == SectionKind.ouvrant
              ? draft.vantauxCount
              : 0,
        ),
      );
    }

    return sections;
  }

  void createProject() {
    final name = nameController.text.trim();
    final width = double.tryParse(widthController.text);
    final height = double.tryParse(heightController.text);

    if (name.isEmpty || width == null || height == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir correctement tous les champs.'),
        ),
      );
      return;
    }

    if (width <= 0 || height <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Les dimensions doivent être supérieures à zéro.'),
        ),
      );
      return;
    }

    final sections = buildSections();
    if (sections == null) {
      return;
    }

    final constructionId = DateTime.now().millisecondsSinceEpoch.toString();

    final construction = Construction(
      id: constructionId,
      name: name,
      type: type,
      width: width,
      height: height,
      manufacturer: '',
      system: '',
      sections: sections,
      profiles: const [],
    );

    final project = Project(
      id: constructionId,
      name: name,
      construction: construction,
    );

    Navigator.pop(context, project);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau projet')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Nom du projet'),
          ),

          const SizedBox(height: 16),

          DropdownButtonFormField<ConstructionType>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(
                value: ConstructionType.window,
                child: Text('Fenêtre'),
              ),
              DropdownMenuItem(
                value: ConstructionType.door,
                child: Text('Porte'),
              ),
              DropdownMenuItem(
                value: ConstructionType.curtainWall,
                child: Text('Mur rideau'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  type = value;
                });
              }
            },
          ),

          const SizedBox(height: 16),

          TextField(
            controller: widthController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Largeur totale',
              suffixText: 'mm',
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: heightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Hauteur totale',
              suffixText: 'mm',
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sections',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: addSection,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une section'),
              ),
            ],
          ),

          const SizedBox(height: 8),

          for (var i = 0; i < sectionDrafts.length; i++)
            _SectionEditorCard(
              index: i,
              draft: sectionDrafts[i],
              onRemove: sectionDrafts.length > 1
                  ? () => removeSection(i)
                  : null,
              onChanged: () => setState(() {}),
            ),

          const SizedBox(height: 24),

          FilledButton(
            onPressed: createProject,
            child: const Text('Créer le projet'),
          ),
        ],
      ),
    );
  }
}

/// Card editing a single [_SectionDraft] in place.
class _SectionEditorCard extends StatelessWidget {
  final int index;
  final _SectionDraft draft;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _SectionEditorCard({
    required this.index,
    required this.draft,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Section ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onRemove,
                    tooltip: 'Supprimer cette section',
                  ),
              ],
            ),

            const SizedBox(height: 8),

            SegmentedButton<SectionKind>(
              segments: const [
                ButtonSegment(value: SectionKind.fixed, label: Text('Fixe')),
                ButtonSegment(
                  value: SectionKind.ouvrant,
                  label: Text('Ouvrant'),
                ),
              ],
              selected: {draft.kind},
              onSelectionChanged: (selection) {
                draft.kind = selection.first;
                if (draft.kind == SectionKind.fixed) {
                  draft.openingType = null;
                  draft.vantauxCount = 0;
                } else if (draft.vantauxCount < 1) {
                  draft.vantauxCount = 1;
                }
                onChanged();
              },
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: draft.widthController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Largeur',
                      suffixText: 'mm',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: draft.heightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Hauteur',
                      suffixText: 'mm',
                    ),
                  ),
                ),
              ],
            ),

            if (draft.kind == SectionKind.ouvrant) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<OpeningType>(
                initialValue: draft.openingType,
                decoration: const InputDecoration(
                  labelText: "Type d'ouverture",
                ),
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
                  draft.openingType = value;
                  onChanged();
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Nombre de vantaux :'),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: draft.vantauxCount > 1
                        ? () {
                            draft.vantauxCount--;
                            onChanged();
                          }
                        : null,
                  ),
                  Text(
                    '${draft.vantauxCount}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      draft.vantauxCount++;
                      onChanged();
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
