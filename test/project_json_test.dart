import 'package:flutter_test/flutter_test.dart';
import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/layout_direction.dart';
import 'package:aluminium_designer/core/models/opening.dart';
import 'package:aluminium_designer/core/models/profile.dart';
import 'package:aluminium_designer/core/models/profile_usage.dart';
import 'package:aluminium_designer/core/models/project.dart';
import 'package:aluminium_designer/core/models/project_json.dart';
import 'package:aluminium_designer/core/models/section.dart';

void main() {
  group('Project JSON round-trip', () {
    test('project with no constructions', () {
      final project = Project(
        id: 'p1',
        name: 'Empty project',
        constructions: const [],
      );

      final json = project.toJson();
      final restored = projectFromJson(json);

      expect(restored.id, project.id);
      expect(restored.name, project.name);
      expect(restored.constructions, isEmpty);
    });

    test('project with one fixed-section construction', () {
      final section = Section(
        id: 's1',
        order: 0,
        kind: SectionKind.fixed,
        width: 1200,
        height: 1400,
      );

      final construction = Construction(
        id: 'c1',
        name: 'Fenêtre',
        type: ConstructionType.window,
        width: 1200,
        height: 1400,
        manufacturer: '',
        system: '',
        sections: [section],
        layoutDirection: SectionLayoutDirection.horizontal,
        profiles: const [],
      );

      final project = Project(
        id: 'p1',
        name: 'Chantier A',
        constructions: [construction],
      );

      final json = project.toJson();
      final restored = projectFromJson(json);

      expect(restored.constructions, hasLength(1));
      final restoredConstruction = restored.constructions.single;
      expect(restoredConstruction.id, 'c1');
      expect(restoredConstruction.type, ConstructionType.window);
      expect(restoredConstruction.width, 1200);
      expect(restoredConstruction.height, 1400);
      expect(
        restoredConstruction.layoutDirection,
        SectionLayoutDirection.horizontal,
      );

      final restoredSection = restoredConstruction.sections.single;
      expect(restoredSection.kind, SectionKind.fixed);
      expect(restoredSection.width, 1200);
      expect(restoredSection.height, 1400);
      expect(restoredSection.openingType, isNull);
      expect(restoredSection.vantauxCount, 0);
    });

    test('ouvrant section preserves openingType and vantauxCount', () {
      final section = Section(
        id: 's1',
        order: 0,
        kind: SectionKind.ouvrant,
        width: 1200,
        height: 1400,
        openingType: OpeningType.oscilloBattant,
        vantauxCount: 2,
      );

      final construction = Construction(
        id: 'c1',
        name: 'Porte',
        type: ConstructionType.door,
        width: 1200,
        height: 1400,
        manufacturer: '',
        system: '',
        sections: [section],
        layoutDirection: SectionLayoutDirection.vertical,
        profiles: const [],
      );

      final json = constructionFromJson(construction.toJson());

      expect(json.layoutDirection, SectionLayoutDirection.vertical);
      final restoredSection = json.sections.single;
      expect(restoredSection.kind, SectionKind.ouvrant);
      expect(restoredSection.openingType, OpeningType.oscilloBattant);
      expect(restoredSection.vantauxCount, 2);
    });

    test('curtain wall type round-trips', () {
      final construction = Construction(
        id: 'c1',
        name: 'Mur rideau',
        type: ConstructionType.curtainWall,
        width: 3000,
        height: 3000,
        manufacturer: '',
        system: '',
        sections: const [],
        profiles: const [],
      );

      final restored = constructionFromJson(construction.toJson());

      expect(restored.type, ConstructionType.curtainWall);
    });

    test('profiles and profileUsages round-trip', () {
      final profile = Profile(
        id: 'pr1',
        manufacturer: 'Test Manufacturer',
        system: 'Test System',
        reference: 'REF-123',
        name: 'Montant',
        type: ProfileType.montant,
        width: 45,
        depth: 60,
        weightPerMeter: 1.2,
      );

      final usage = ProfileUsage(
        id: 'u1',
        profileId: 'pr1',
        sectionId: 's1',
        role: ProfileUsageRole.left,
        quantity: 1,
      );

      final construction = Construction(
        id: 'c1',
        name: 'Fenêtre',
        type: ConstructionType.window,
        width: 1200,
        height: 1400,
        manufacturer: '',
        system: '',
        sections: const [],
        profiles: [profile],
        profileUsages: [usage],
      );

      final restored = constructionFromJson(construction.toJson());

      expect(restored.profiles, hasLength(1));
      expect(restored.profiles.single.reference, 'REF-123');
      expect(restored.profiles.single.type, ProfileType.montant);

      expect(restored.profileUsages, hasLength(1));
      expect(restored.profileUsages.single.role, ProfileUsageRole.left);
    });

    test('schemaVersion is present and defaults correctly when missing', () {
      final project = Project(id: 'p1', name: 'X', constructions: const []);
      final json = project.toJson();

      expect(json['schemaVersion'], 1);

      final withoutVersion = Map<String, dynamic>.from(json)
        ..remove('schemaVersion');
      final restored = projectFromJson(withoutVersion);
      expect(restored.id, 'p1');
    });

    test('newer schemaVersion than supported throws FormatException', () {
      final project = Project(id: 'p1', name: 'X', constructions: const []);
      final json = Map<String, dynamic>.from(project.toJson());
      json['schemaVersion'] = 999;

      expect(() => projectFromJson(json), throwsFormatException);
    });
  });
}
