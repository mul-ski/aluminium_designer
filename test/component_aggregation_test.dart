import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/logic/component_aggregation.dart';
import 'package:aluminium_designer/core/models/cut.dart';
import 'package:aluminium_designer/core/models/glass_item.dart';
import 'package:aluminium_designer/core/models/hardware_item.dart';
import 'package:aluminium_designer/core/models/profile.dart';

/// P1 commit 3: aggregation of glass / hardware / unified BOM.
/// Pure derivation over items the calculator already produced in
/// commits 1+2; the calculator does NOT yet evaluate glass/hardware
/// (that lands in commit 4). These tests pin the aggregation
/// contract.

Profile _profile(
  String id,
  String reference, {
  ProfileType type = ProfileType.montant,
  double widthPerMeter = 0,
}) =>
    Profile(
      id: id,
      manufacturer: 'M',
      system: 'S',
      reference: reference,
      name: 'Profile $reference',
      type: type,
      width: 40,
      depth: 60,
      weightPerMeter: widthPerMeter,
    );

ProfileCut _cut({
  required Profile profile,
  required double length,
  required int quantity,
  double angleStart = 90,
  double angleEnd = 90,
  String sectionId = 's1',
}) =>
    ProfileCut(
      profile: profile,
      length: length,
      quantity: quantity,
      angleStart: angleStart,
      angleEnd: angleEnd,
      profileUsageId: 'u-${profile.id}',
      sectionId: sectionId,
    );

void main() {
  group('aggregateGlassItems', () {
    test('empty input yields zeroed totals (no nulls)', () {
      final t = aggregateGlassItems(const []);
      expect(t.paneCount, 0);
      expect(t.totalAreaM2, 0.0);
      expect(t.unknownThicknessCount, 0);
    });

    test('sums quantity and area, counts unknown-thickness panes', () {
      final t = aggregateGlassItems(const [
        GlassItem(
          profileReference: '14.802',
          widthMm: 1868,
          heightMm: 1368,
          quantity: 1,
          glazingThicknessMm: 6,
          sectionId: 's1',
        ),
        GlassItem(
          profileReference: '14.805',
          widthMm: 1815,
          heightMm: 1315,
          quantity: 1,
          // No thickness -- the source didn't state one.
          sectionId: 's2',
        ),
      ]);
      expect(t.paneCount, 2);
      // 1868*1368*1/1e6 + 1815*1315*1/1e6
      final expected = 1868 * 1368 / 1e6 + 1815 * 1315 / 1e6;
      expect(t.totalAreaM2, closeTo(expected, 1e-9));
      expect(t.unknownThicknessCount, 1);
    });
  });

  group('buildHardwareLines', () {
    test('empty input yields no lines', () {
      expect(buildHardwareLines(const []), isEmpty);
    });

    test('count-only items group by (reference, category, null length)',
        () {
      final lines = buildHardwareLines(const [
        HardwareItem(
          reference: 'AC-600',
          name: 'Équerre à pions',
          category: HardwareCategory.hardware,
          quantity: 4,
          sectionId: 's1',
        ),
        HardwareItem(
          reference: 'AC-600',
          name: 'Équerre à pions',
          category: HardwareCategory.hardware,
          quantity: 4,
          sectionId: 's2',
        ),
      ]);
      expect(lines, hasLength(1));
      expect(lines.first.reference, 'AC-600');
      expect(lines.first.quantity, 8);
      expect(lines.first.lengthMm, isNull);
      expect(
        lines.first.contributingSectionIds,
        containsAllInOrder(['s1', 's2']),
      );
    });

    test('length-bearing items group by exact length', () {
      final lines = buildHardwareLines(const [
        HardwareItem(
          reference: 'JO-826',
          name: 'Joint',
          category: HardwareCategory.accessory,
          quantity: 1,
          lengthMm: 7000,
          sectionId: 's1',
        ),
        HardwareItem(
          reference: 'JO-826',
          name: 'Joint',
          category: HardwareCategory.accessory,
          quantity: 1,
          lengthMm: 7000,
          sectionId: 's2',
        ),
        HardwareItem(
          reference: 'JO-826',
          name: 'Joint',
          category: HardwareCategory.accessory,
          quantity: 1,
          lengthMm: 6800, // different length -> different line
          sectionId: 's3',
        ),
      ]);
      expect(lines, hasLength(2));
      // First-encounter order: the 7000mm line (s1+s2) before 6800mm.
      expect(lines[0].lengthMm, 7000);
      expect(lines[0].quantity, 2);
      expect(lines[1].lengthMm, 6800);
      expect(lines[1].quantity, 1);
    });

    test('mixed count-only and length-bearing stay separate (same '
        'reference, different physical types)', () {
      // Real catalogues are consistent, but if a document ever
      // produces this state the BOM keeps them as two lines rather
      // than silently merging -- the workshop view can surface a
      // diagnostic instead of wrong totals.
      final lines = buildHardwareLines(const [
        HardwareItem(
          reference: 'X',
          name: 'X count',
          category: HardwareCategory.hardware,
          quantity: 2,
          sectionId: 's1',
        ),
        HardwareItem(
          reference: 'X',
          name: 'X length',
          category: HardwareCategory.hardware,
          quantity: 1,
          lengthMm: 1000,
          sectionId: 's2',
        ),
      ]);
      expect(lines, hasLength(2));
      expect(lines[0].lengthMm, isNull);
      expect(lines[0].quantity, 2);
      expect(lines[1].lengthMm, 1000);
      expect(lines[1].quantity, 1);
    });

    test('provenance lists grow without duplicates and keep first-'
        'encounter order', () {
      final lines = buildHardwareLines(const [
        HardwareItem(
          reference: 'A',
          name: 'A',
          category: HardwareCategory.hardware,
          quantity: 1,
          sectionId: 's1',
          ruleDescription: 'rule-1',
        ),
        HardwareItem(
          reference: 'A',
          name: 'A',
          category: HardwareCategory.hardware,
          quantity: 1,
          sectionId: 's2',
          ruleDescription: 'rule-1', // duplicate description
        ),
        HardwareItem(
          reference: 'A',
          name: 'A',
          category: HardwareCategory.hardware,
          quantity: 1,
          sectionId: 's1', // duplicate section
          ruleDescription: 'rule-2',
        ),
      ]);
      expect(lines, hasLength(1));
      expect(lines.first.contributingSectionIds, ['s1', 's2']);
      expect(lines.first.ruleDescriptions, ['rule-1', 'rule-2']);
    });
  });

  group('sumHardwareLines', () {
    test('empty input yields zeroed summary', () {
      final s = sumHardwareLines(const []);
      expect(s.pieces, 0);
      expect(s.totalLengthMm, 0.0);
    });

    test('sums quantities and totalLengthMm across lines', () {
      final s = sumHardwareLines([
        const HardwareLine(
          reference: 'A',
          name: 'A',
          category: HardwareCategory.hardware,
          quantity: 4,
          lengthMm: null,
          totalLengthMm: 0,
          ruleDescriptions: [],
          contributingSectionIds: ['s1'],
        ),
        const HardwareLine(
          reference: 'B',
          name: 'B',
          category: HardwareCategory.accessory,
          quantity: 2,
          lengthMm: 3000,
          totalLengthMm: 6000,
          ruleDescriptions: [],
          contributingSectionIds: ['s1'],
        ),
      ]);
      expect(s.pieces, 6);
      expect(s.totalLengthMm, 6000.0);
    });
  });

  group('buildBom + summarizeBom (unified bill of materials)', () {
    test('empty outcome yields empty lines and zeroed summary', () {
      final lines = buildBom(
        profileCuts: const [],
        glass: const [],
        hardware: const [],
      );
      expect(lines, isEmpty);
      final s = summarizeBom(lines);
      expect(s.totalPieces, 0);
      expect(s.glassAreaM2, 0.0);
      expect(s.hardwareTotalLengthMm, 0.0);
    });

    test('combines all three domains into one line list, with per-'
        'domain field semantics preserved', () {
      final p1 = _profile('p-1', '14.621', type: ProfileType.traverse);
      final p2 = _profile('p-2', '14.622', type: ProfileType.montant);

      final lines = buildBom(
        profileCuts: [
          _cut(profile: p1, length: 1000, quantity: 2),
          _cut(profile: p2, length: 1500, quantity: 4),
        ],
        glass: const [
          GlassItem(
            profileReference: '14.802',
            widthMm: 1868,
            heightMm: 1368,
            quantity: 1,
            sectionId: 's1',
          ),
        ],
        hardware: const [
          HardwareItem(
            reference: 'AC-600',
            name: 'Équerre',
            category: HardwareCategory.hardware,
            quantity: 8,
            sectionId: 's1',
          ),
          HardwareItem(
            reference: 'JO-826',
            name: 'Joint',
            category: HardwareCategory.accessory,
            quantity: 1,
            lengthMm: 7000,
            sectionId: 's1',
          ),
        ],
      );

      // 2 profile lines + 1 glass line + 1 hardware + 1 accessory = 5.
      expect(lines, hasLength(5));

      // Domain tagging.
      expect(
        lines.where((l) => l.domain == BomDomain.profile).length,
        2,
      );
      expect(
        lines.where((l) => l.domain == BomDomain.glass).length,
        1,
      );
      expect(
        lines.where((l) => l.domain == BomDomain.hardware).length,
        1,
      );
      expect(
        lines.where((l) => l.domain == BomDomain.accessory).length,
        1,
      );

      // Field semantics: profile has length+angles+profileId, glass has
      // width+height, hardware has length only, accessory has length only.
      final profileLine = lines.firstWhere(
        (l) => l.domain == BomDomain.profile && l.reference == '14.621',
      );
      expect(profileLine.lengthMm, 1000);
      expect(profileLine.angleStart, 90);
      expect(profileLine.profileId, 'p-1');

      final glassLine =
          lines.firstWhere((l) => l.domain == BomDomain.glass);
      expect(glassLine.widthMm, 1868);
      expect(glassLine.heightMm, 1368);
      expect(glassLine.lengthMm, isNull);

      final accessoryLine = lines.firstWhere(
        (l) => l.domain == BomDomain.accessory,
      );
      expect(accessoryLine.lengthMm, 7000);
      expect(accessoryLine.quantity, 1);

      // Summary.
      final s = summarizeBom(lines);
      // pieces: 2 + 4 + 1 + 8 + 1 = 16.
      expect(s.totalPieces, 16);
      expect(s.glassAreaM2, closeTo(1868 * 1368 / 1e6, 1e-9));
      expect(s.hardwareTotalLengthMm, 7000.0);
    });
  });
}
