import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/logic/cut_grouping.dart';
import 'package:aluminium_designer/core/models/cut.dart';
import 'package:aluminium_designer/core/models/profile.dart';
import 'package:aluminium_designer/core/models/section.dart';

Profile _profile(String id) => Profile(
  id: id,
  manufacturer: 'Test Manufacturer',
  system: 'Test System',
  reference: id,
  name: 'Profile $id',
  type: ProfileType.montant,
  width: 40,
  depth: 60,
  weightPerMeter: 1.2,
);

ProfileCut _cut({
  required String profileUsageId,
  required String sectionId,
  double length = 1000,
}) => ProfileCut(
  profile: _profile('P1'),
  length: length,
  quantity: 1,
  angleStart: 45,
  angleEnd: 45,
  profileUsageId: profileUsageId,
  sectionId: sectionId,
);

Section _section(String id, {int order = 0}) => Section(
  id: id,
  order: order,
  kind: SectionKind.fixed,
  width: 1000,
  height: 1200,
);

void main() {
  group('groupCutsBySectionId', () {
    test('groups cuts sharing a sectionId together', () {
      final cuts = [
        _cut(profileUsageId: 'u1', sectionId: 's1'),
        _cut(profileUsageId: 'u2', sectionId: 's1'),
        _cut(profileUsageId: 'u3', sectionId: 's2'),
      ];

      final grouped = groupCutsBySectionId(cuts);

      expect(grouped.keys.toList(), ['s1', 's2']);
      expect(grouped['s1']!.length, 2);
      expect(grouped['s2']!.length, 1);
    });

    test('preserves each group\'s cuts in original order', () {
      final cuts = [
        _cut(profileUsageId: 'u1', sectionId: 's1', length: 100),
        _cut(profileUsageId: 'u2', sectionId: 's1', length: 200),
      ];

      final grouped = groupCutsBySectionId(cuts);

      expect(grouped['s1']![0].length, 100);
      expect(grouped['s1']![1].length, 200);
    });

    test('returns an empty map for an empty cut list', () {
      expect(groupCutsBySectionId(const []), isEmpty);
    });

    test('group key order follows first-encountered order in the cut list, '
        'not insertion/alphabetical order of the section ids', () {
      final cuts = [
        _cut(profileUsageId: 'u1', sectionId: 'sZ'),
        _cut(profileUsageId: 'u2', sectionId: 'sA'),
      ];

      final grouped = groupCutsBySectionId(cuts);

      expect(grouped.keys.toList(), ['sZ', 'sA']);
    });
  });

  group('sectionLabelForCutGroup', () {
    test('resolves to "Section N" using 1-based Section.order', () {
      final sections = [_section('s1', order: 0), _section('s2', order: 1)];

      expect(sectionLabelForCutGroup('s1', sections), 'Section 1');
      expect(sectionLabelForCutGroup('s2', sections), 'Section 2');
    });

    test('falls back to a distinct label when sectionId does not resolve '
        '(stale/deleted section) rather than crashing or mislabeling', () {
      final sections = [_section('s1', order: 0)];

      expect(
        sectionLabelForCutGroup('ghost-section', sections),
        'Section supprimée',
      );
    });

    test('falls back the same way for an empty sections list', () {
      expect(sectionLabelForCutGroup('s1', const []), 'Section supprimée');
    });
  });
}
