import 'package:flutter/material.dart';
import '../../../core/models/construction.dart';
import '../../../core/models/construction_type.dart';

/// Creates a bare [Construction] stub -- name and type only -- to be added
/// to a project's construction list and immediately opened in
/// `ConstructionEditorScreen` for the user to actually build.
///
/// This screen used to also collect overall width/height and a single
/// initial section before a construction could be created at all, which
/// meant a "fake" one-section construction had to exist just to satisfy
/// the old (pre-nullable) `Construction.width`/`height` fields. Now that
/// `Construction.width`/`height` are nullable and `sections` can honestly
/// start empty (see `Construction`'s doc comment and
/// `constructionGeometryStatus`), there is no need to front-load any of
/// that here: this screen's only job is to give the new construction an
/// id, name, and type, then hand off to the editor, matching the
/// industry-style workflow of "add element" being a lightweight action
/// rather than a form gate.
class NewConstructionScreen extends StatefulWidget {
  const NewConstructionScreen({super.key});

  @override
  State<NewConstructionScreen> createState() => _NewConstructionScreenState();
}

class _NewConstructionScreenState extends State<NewConstructionScreen> {
  final nameController = TextEditingController();
  ConstructionType type = ConstructionType.window;

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  void createConstruction() {
    final constructionId = DateTime.now().millisecondsSinceEpoch.toString();
    final name = nameController.text.trim();

    final construction = Construction(
      id: constructionId,
      name: name.isEmpty ? _typeLabel(type) : name,
      type: type,
      manufacturer: '',
      system: '',
      sections: const [],
      profiles: const [],
    );

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
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Nom (facultatif)',
              hintText: 'Ex : Fenêtre salon',
            ),
          ),

          const SizedBox(height: 16),

          DropdownButtonFormField<ConstructionType>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: [
              for (final t in ConstructionType.values)
                DropdownMenuItem(value: t, child: Text(_typeLabel(t))),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  type = value;
                });
              }
            },
          ),

          const SizedBox(height: 24),

          Text(
            'Les dimensions, le fabricant, le système et les sections se '
            'configurent dans l\'éditeur, à l\'étape suivante.',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),

          const SizedBox(height: 24),

          FilledButton(
            onPressed: createConstruction,
            child: const Text('Créer et ouvrir l\'éditeur'),
          ),
        ],
      ),
    );
  }
}
