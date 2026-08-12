import 'package:flutter/material.dart';
import '../../../core/models/project.dart';

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

  @override
  void dispose() {
    nameController.dispose();
    widthController.dispose();
    heightController.dispose();
    super.dispose();
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

    final project = Project(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      type: type,
      width: width,
      height: height,
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

          FilledButton(
            onPressed: createProject,
            child: const Text('Créer le projet'),
          ),
        ],
      ),
    );
  }
}
