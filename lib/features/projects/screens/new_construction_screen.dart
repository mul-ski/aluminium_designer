import 'package:flutter/material.dart';
import '../../../core/models/construction.dart';
import '../../../core/models/construction_type.dart';
import '../../../core/models/layout_direction.dart';
import '../../../core/models/opening.dart';
import '../../../core/models/section.dart';
import '../../../core/models/section_geometry.dart';

/// Creates one [Construction] to be added to a project's construction list.
///
/// This is a focused creation flow for a single construction -- it does
/// not touch `Project` at all, and the caller (the workspace screen) is
/// responsible for adding the returned `Construction` to
/// `Project.constructions`. Kept to the simplest valid approach for this
/// milestone: one initial [Section] is created for the whole construction,
/// rather than requiring the user to build a full multi-section layout
/// immediately -- that full section editor already exists in spirit from
/// the old New Project form and can be reintroduced inside a future
/// construction designer.
class NewConstructionScreen extends StatefulWidget {
  const NewConstructionScreen({super.key});

  @override
  State<NewConstructionScreen> createState() => _NewConstructionScreenState();
}

class _NewConstructionScreenState extends State<NewConstructionScreen> {
  final widthController = TextEditingController();
  final heightController = TextEditingController();

  ConstructionType type = ConstructionType.window;
  SectionKind sectionKind = SectionKind.fixed;
  OpeningType? openingType;
  int vantauxCount = 1;

  @override
  void dispose() {
    widthController.dispose();
    heightController.dispose();
    super.dispose();
  }

  void createConstruction() {
    final width = double.tryParse(widthController.text);
    final height = double.tryParse(heightController.text);

    if (width == null || height == null || width <= 0 || height <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Largeur et hauteur doivent être renseignées et '
            'supérieures à zéro.',
          ),
        ),
      );
      return;
    }

    if (sectionKind == SectionKind.ouvrant && openingType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez choisir un type d'ouverture.")),
      );
      return;
    }

    if (sectionKind == SectionKind.ouvrant && vantauxCount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le nombre de vantaux doit être au moins 1.'),
        ),
      );
      return;
    }

    final constructionId = DateTime.now().millisecondsSinceEpoch.toString();

    final section = Section(
      id: '$constructionId-0',
      order: 0,
      kind: sectionKind,
      width: width,
      height: height,
      openingType: sectionKind == SectionKind.ouvrant ? openingType : null,
      vantauxCount: sectionKind == SectionKind.ouvrant ? vantauxCount : 0,
    );

    final construction = Construction(
      id: constructionId,
      name: _typeLabel(type),
      type: type,
      width: width,
      height: height,
      manufacturer: '',
      system: '',
      sections: [section],
      layoutDirection: SectionLayoutDirection.horizontal,
      profiles: const [],
    );

    final problems = validateSectionGeometry(construction);
    if (problems.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(problems.first)));
      return;
    }

    Navigator.pop(context, construction);
  }

  String _typeLabel(ConstructionType type) {
    switch (type) {
      case ConstructionType.window:
        return 'Fenêtre';
      case ConstructionType.door:
        return 'Porte';
      case ConstructionType.curtainWall:
        return 'Mur rideau';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle construction')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
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
              labelText: 'Largeur',
              suffixText: 'mm',
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: heightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Hauteur',
              suffixText: 'mm',
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),

          const Text(
            'Section',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          SegmentedButton<SectionKind>(
            segments: const [
              ButtonSegment(value: SectionKind.fixed, label: Text('Fixe')),
              ButtonSegment(value: SectionKind.ouvrant, label: Text('Ouvrant')),
            ],
            selected: {sectionKind},
            onSelectionChanged: (selection) {
              setState(() {
                sectionKind = selection.first;
                if (sectionKind == SectionKind.fixed) {
                  openingType = null;
                  vantauxCount = 0;
                } else if (vantauxCount < 1) {
                  vantauxCount = 1;
                }
              });
            },
          ),

          if (sectionKind == SectionKind.ouvrant) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<OpeningType>(
              initialValue: openingType,
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
                setState(() {
                  openingType = value;
                });
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Nombre de vantaux :'),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: vantauxCount > 1
                      ? () => setState(() => vantauxCount--)
                      : null,
                ),
                Text(
                  '$vantauxCount',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setState(() => vantauxCount++),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          FilledButton(
            onPressed: createConstruction,
            child: const Text('Ajouter la construction'),
          ),
        ],
      ),
    );
  }
}
