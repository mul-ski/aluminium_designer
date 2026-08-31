// IO round-trip tests for the production document exporter.
//
// The exporter takes an explicit [Directory] so tests don't depend on
// path_provider / the platform channel. The tests:
//   1. write the two CSV files into a real temp directory;
//   2. read the bytes back;
//   3. assert the on-disk bytes match the in-memory renderer output;
//   4. pin the documented filename format;
//   5. assert UTF-8 encoding (no BOM, no Latin-1 surprises);
//   6. assert the parent directory is created if it doesn't exist
//      (the export must work in a fresh dir).
//
// The temp dir is `Directory.systemTemp.createTemp`, cleaned up in
// tearDown. No flutter_test fake-async complications: the exporter's
// writeAsString is a real await but does not block on a platform
// channel, so it completes inside the test() body.

import 'dart:convert';
import 'dart:io';

import 'package:aluminium_designer/core/data/builtin_catalog_seed.dart';
import 'package:aluminium_designer/core/logic/rule_set_resolution.dart';
import 'package:aluminium_designer/core/models/catalog.dart';
import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/layout_direction.dart';
import 'package:aluminium_designer/core/models/opening.dart';
import 'package:aluminium_designer/core/models/profile_usage.dart';
import 'package:aluminium_designer/core/models/section.dart';
import 'package:aluminium_designer/core/production_export/production_export.dart';
import 'package:flutter_test/flutter_test.dart';

const _fixedExportedAt = '2026-01-15T14:32:11.000Z';

Catalog _catalog() => withBuiltInCatalogSeed(const Catalog());

ProfileUsage _usage(
  String reference,
  ProfileUsageRole role, {
  required String id,
  required String sectionId,
  required Catalog catalog,
}) {
  final p = meSerie14800.profilesById.values
      .firstWhere((x) => x.reference == reference);
  return ProfileUsage(
    id: id,
    profileId: p.id,
    sectionId: sectionId,
    role: role,
  );
}

Construction _me14800_1v() {
  return Construction(
    id: 'c-14800-1v',
    name: 'ME 14800 1v française',
    type: ConstructionType.door,
    width: 2000.0,
    height: 1500.0,
    manufacturer: 'Maghreb Extrusion (ME)',
    system: 'Série 14800 Frappe',
    manufacturerId: meSerie14800Id,
    systemId: meSerie14800Id,
    sections: [
      Section(
        id: 's1',
        order: 0,
        kind: SectionKind.ouvrant,
        width: 2000.0,
        height: 1500.0,
        openingType: OpeningType.francaise,
        vantauxCount: 1,
      ),
    ],
    layoutDirection: SectionLayoutDirection.horizontal,
    profiles: const [],
    profileUsages: [
      _usage('14.800', ProfileUsageRole.top, id: 'd-top', sectionId: 's1', catalog: const Catalog()),
      _usage('14.800', ProfileUsageRole.bottom, id: 'd-bottom', sectionId: 's1', catalog: const Catalog()),
      _usage('14.800', ProfileUsageRole.left, id: 'd-left', sectionId: 's1', catalog: const Catalog()),
      _usage('14.800', ProfileUsageRole.right, id: 'd-right', sectionId: 's1', catalog: const Catalog()),
      _usage('14.802', ProfileUsageRole.top, id: 'o-top', sectionId: 's1', catalog: const Catalog()),
      _usage('14.802', ProfileUsageRole.bottom, id: 'o-bottom', sectionId: 's1', catalog: const Catalog()),
      _usage('14.802', ProfileUsageRole.left, id: 'o-left', sectionId: 's1', catalog: const Catalog()),
      _usage('14.802', ProfileUsageRole.right, id: 'o-right', sectionId: 's1', catalog: const Catalog()),
      _usage('14.810', ProfileUsageRole.top, id: 'p-top', sectionId: 's1', catalog: const Catalog()),
      _usage('14.810', ProfileUsageRole.bottom, id: 'p-bottom', sectionId: 's1', catalog: const Catalog()),
      _usage('14.810', ProfileUsageRole.left, id: 'p-left', sectionId: 's1', catalog: const Catalog()),
      _usage('14.810', ProfileUsageRole.right, id: 'p-right', sectionId: 's1', catalog: const Catalog()),
      _usage('14.811', ProfileUsageRole.intermediate, id: 'tige', sectionId: 's1', catalog: const Catalog()),
    ],
  );
}

void main() {
  group('ProductionExporter.exportToDirectory (IO round-trip)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('aluvis_export_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('writes both files into the target directory; the on-disk bytes '
        'match the in-memory render output', () async {
      final c = _me14800_1v();
      final outcome = calculateConstructionCuts(c, _catalog())!;
      final exporter = ProductionExporter(
        exportedAt: DateTime.parse(_fixedExportedAt),
      );

      final written = await exporter.exportToDirectory(
        construction: c,
        outcome: outcome,
        sections: c.sections,
        isStale: false,
        directory: tempDir,
      );

      expect(written, hasLength(2));
      expect(written[0].path, endsWith('.cuts.csv'));
      expect(written[1].path, endsWith('.bom.csv'));

      // The exporter's returned `contents` field is the in-memory
      // rendered string. The on-disk file must contain the same bytes
      // (modulo encoding). Read the file as UTF-8 and assert equality.
      final cutsFile = File(written[0].path);
      final bomFile = File(written[1].path);
      expect(await cutsFile.exists(), isTrue);
      expect(await bomFile.exists(), isTrue);
      final cutsOnDisk = await cutsFile.readAsString();
      final bomOnDisk = await bomFile.readAsString();
      expect(cutsOnDisk, written[0].contents);
      expect(bomOnDisk, written[1].contents);
    });

    test('produces the documented filename format: '
        'aluvis-{slug}-{short-id}.cuts.csv and .bom.csv', () async {
      final c = _me14800_1v();
      final outcome = calculateConstructionCuts(c, _catalog())!;
      final exporter = ProductionExporter(
        exportedAt: DateTime.parse(_fixedExportedAt),
      );

      final written = await exporter.exportToDirectory(
        construction: c,
        outcome: outcome,
        sections: c.sections,
        isStale: false,
        directory: tempDir,
      );

      // Expected: slug = "me-14800-1v-francaise" (lowercased,
      // diacritic-stripped, alnum-+-), shortId = "c-1480" (first 6
      // chars of the construction id).
      final expectedBase = 'aluvis-me-14800-1v-francaise-c-1480';
      expect(written[0].path, '${tempDir.path}/$expectedBase.cuts.csv');
      expect(written[1].path, '${tempDir.path}/$expectedBase.bom.csv');
    });

    test('creates the target directory recursively if it does not exist',
        () async {
      final nested = Directory('${tempDir.path}/a/b/c');
      expect(await nested.exists(), isFalse);

      final c = _me14800_1v();
      final outcome = calculateConstructionCuts(c, _catalog())!;
      final exporter = ProductionExporter(
        exportedAt: DateTime.parse(_fixedExportedAt),
      );
      await exporter.exportToDirectory(
        construction: c,
        outcome: outcome,
        sections: c.sections,
        isStale: false,
        directory: nested,
      );

      expect(await nested.exists(), isTrue);
      // The cuts file is inside the new dir.
      final cutsFile = File('${nested.path}/'
          'aluvis-me-14800-1v-francaise-c-1480.cuts.csv');
      expect(await cutsFile.exists(), isTrue);
    });

    test('UTF-8 round-trip: accented characters in the construction name '
        'and in the metadata block survive a write+read cycle', () async {
      // The `c` variable below was originally assigned `cWithName` from
      // `c.copyWith(name: ...)` but `copyWith`'s null-coalescing pattern
      // does NOT override a non-null value. Build a fresh Construction
      // with the desired name directly.
      final baseC = _me14800_1v();
      final cWithName = Construction(
        id: baseC.id,
        name: 'Fénêtre Sud 01 — étage 2',
        type: baseC.type,
        width: baseC.width,
        height: baseC.height,
        manufacturer: baseC.manufacturer,
        system: baseC.system,
        manufacturerId: baseC.manufacturerId,
        systemId: baseC.systemId,
        sections: baseC.sections,
        layoutDirection: baseC.layoutDirection,
        profiles: baseC.profiles,
        profileUsages: baseC.profileUsages,
      );
      final outcome = calculateConstructionCuts(cWithName, _catalog())!;
      final exporter = ProductionExporter(
        exportedAt: DateTime.parse(_fixedExportedAt),
      );
      final written = await exporter.exportToDirectory(
        construction: cWithName,
        outcome: outcome,
        sections: cWithName.sections,
        isStale: false,
        directory: tempDir,
      );

      // Read the bytes raw -- we want to assert there is no UTF-8 BOM
      // (Excel would otherwise interpret the file as UTF-16 / cp1252).
      final raw = await File(written[0].path).readAsBytes();
      expect(raw.length, greaterThan(0));
      // UTF-8 BOM is EF BB BF (3 bytes). The first byte must be `#`
      // (0x23) from the `# AluVis export` comment.
      expect(raw[0], 0x23);
      // No BOM.
      expect(raw[0] != 0xEF || raw[1] != 0xBB || raw[2] != 0xBF, isTrue);

      // The on-disk file, when re-decoded as UTF-8, must contain the
      // accented characters. `utf8.decode` is the inverse of
      // `writeAsString` (which writes UTF-8 by default).
      final decoded = utf8.decode(raw);
      expect(decoded.contains('Fénêtre'), isTrue);
      expect(decoded.contains('étage'), isTrue);
      expect(decoded.contains('Maghreb'), isTrue);
      // The file name is slugged to ASCII (diacritics stripped), so the
      // on-disk filename is pure ASCII.
      final baseName = written[0].path.split('/').last;
      expect(baseName.contains('é'), isFalse);
    });

    test('stale flag is reflected in the on-disk file\'s metadata block',
        () async {
      final c = _me14800_1v();
      final outcome = calculateConstructionCuts(c, _catalog())!;
      final exporter = ProductionExporter(
        exportedAt: DateTime.parse(_fixedExportedAt),
      );
      final written = await exporter.exportToDirectory(
        construction: c,
        outcome: outcome,
        sections: c.sections,
        isStale: true,
        directory: tempDir,
      );
      final cutsOnDisk = await File(written[0].path).readAsString();
      final bomOnDisk = await File(written[1].path).readAsString();
      expect(cutsOnDisk, contains('# Stale: yes'));
      expect(cutsOnDisk, contains('# WARNING: this calculation is obsolete.'));
      expect(bomOnDisk, contains('# Stale: yes'));
      expect(bomOnDisk, contains('# WARNING: this calculation is obsolete.'));
    });

    test('overwriting an existing file with the same name works (same '
        'construction re-exported)', () async {
      final c = _me14800_1v();
      final outcome = calculateConstructionCuts(c, _catalog())!;
      final exporter = ProductionExporter(
        exportedAt: DateTime.parse(_fixedExportedAt),
      );

      // First export creates the files.
      final first = await exporter.exportToDirectory(
        construction: c,
        outcome: outcome,
        sections: c.sections,
        isStale: false,
        directory: tempDir,
      );
      final firstSize = await File(first[0].path).length();

      // Second export overwrites.
      final second = await exporter.exportToDirectory(
        construction: c,
        outcome: outcome,
        sections: c.sections,
        isStale: false,
        directory: tempDir,
      );
      final secondSize = await File(second[0].path).length();
      expect(second[0].path, first[0].path);
      expect(secondSize, firstSize);
    });
  });
}
