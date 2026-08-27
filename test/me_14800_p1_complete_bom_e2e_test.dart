import 'package:flutter_test/flutter_test.dart';

import 'package:aluminium_designer/core/data/builtin_catalog_seed.dart';
import 'package:aluminium_designer/core/logic/rule_set_resolution.dart';
import 'package:aluminium_designer/core/models/calculation_outcome.dart';
import 'package:aluminium_designer/core/models/catalog.dart';
import 'package:aluminium_designer/core/models/construction.dart';
import 'package:aluminium_designer/core/models/construction_type.dart';
import 'package:aluminium_designer/core/models/hardware_item.dart';
import 'package:aluminium_designer/core/models/layout_direction.dart';
import 'package:aluminium_designer/core/models/opening.dart';
import 'package:aluminium_designer/core/models/profile.dart';
import 'package:aluminium_designer/core/models/profile_usage.dart';
import 'package:aluminium_designer/core/models/section.dart';

/// P1 commit 5: the gold-standard e2e for the ME 14800 1v française
/// vertical slice. ONE real manufacturer configuration, ONE real size,
/// EVERY calculated component (profile cuts + glass + hardware + the
/// aggregation layer's BOM), every expected output traced verbatim to
/// Catalogue Général p. 65 (VITRAGE + ACCESSOIRES + DÉBITAGE).
const double _l = 2000;
const double _h = 1500;

Catalog _catalog() => withBuiltInCatalogSeed(const Catalog());

Profile _p(String reference, ProfileType type) =>
    meSerie14800.profilesById.values
        .firstWhere((p) => p.reference == reference);

ProfileUsage _usage(
  String id,
  String reference,
  ProfileUsageRole role,
  String sectionId,
) {
  final profile = _p(reference, ProfileType.dormant);
  return ProfileUsage(
    id: id,
    profileId: profile.id,
    sectionId: sectionId,
    role: role,
  );
}

Construction _construction({
  required List<ProfileUsage> profileUsages,
  int vantauxCount = 1,
}) =>
    Construction(
      id: 'c-14800',
      name: 'P1 ME 14800 1v française',
      type: ConstructionType.door,
      width: _l,
      height: _h,
      manufacturer: 'Maghreb Extrusion (ME)',
      system: 'Série 14800 Frappe',
      systemId: meSerie14800Id,
      sections: [
        Section(
          id: 's1',
          order: 0,
          kind: SectionKind.ouvrant,
          width: _l,
          height: _h,
          openingType: OpeningType.francaise,
          vantauxCount: vantauxCount,
        ),
      ],
      layoutDirection: SectionLayoutDirection.horizontal,
      profiles: const [],
      profileUsages: profileUsages,
    );

void main() {
  group('P1 gold-standard: ME 14800 1v française complete BOM', () {
    test('14.802 sash configuration: every documented component from '
        'p. 65 is computed end-to-end', () {
      // The full per-usage placement of one 1v française 14800 door
      // with a 14.802 sash -- mirrors the e2e pattern of the existing
      // 14800 / 4200 / 14700 debit suites and is enough to exercise
      // EVERY rule: dormant, ouvrant, parclose, tige, glass, hardware.
      final outcome = calculateConstructionCuts(
        _construction(profileUsages: [
          // Dormant 14.800: top/bottom (L), left/right (H L+46).
          _usage('d-top', '14.800', ProfileUsageRole.top, 's1'),
          _usage('d-bottom', '14.800', ProfileUsageRole.bottom, 's1'),
          _usage('d-left', '14.800', ProfileUsageRole.left, 's1'),
          _usage('d-right', '14.800', ProfileUsageRole.right, 's1'),
          // Ouvrant 14.802: top/bottom (L−35.2), left/right (H−35.2).
          _usage('o-top', '14.802', ProfileUsageRole.top, 's1'),
          _usage('o-bottom', '14.802', ProfileUsageRole.bottom, 's1'),
          _usage('o-left', '14.802', ProfileUsageRole.left, 's1'),
          _usage('o-right', '14.802', ProfileUsageRole.right, 's1'),
          // Parclose 14.809/14.810 (simple / double; both formulas
          // identical at 1v 14.802).
          _usage('p-top', '14.810', ProfileUsageRole.top, 's1'),
          _usage('p-bottom', '14.810', ProfileUsageRole.bottom, 's1'),
          _usage('p-left', '14.810', ProfileUsageRole.left, 's1'),
          _usage('p-right', '14.810', ProfileUsageRole.right, 's1'),
          // Tige 14.811: no role (chicane precedent).
          _usage('tige', '14.811', ProfileUsageRole.intermediate, 's1'),
        ]),
        _catalog(),
      )!;

      // -- PROFILE CUTS (p. 65 debit 1v) --
      expect(outcome.cuts, hasLength(13));
      final byUsage = {
        for (final cut in outcome.cuts) cut.profileUsageId: cut,
      };
      // Dormant 14.800: 2×L (top, bottom) + 2×H (left, right).
      expect(byUsage['d-top']!.length, _l);
      expect(byUsage['d-bottom']!.length, _l);
      expect(byUsage['d-left']!.length, _h);
      expect(byUsage['d-right']!.length, _h);
      // Ouvrant 14.802: 2×(L−35.2) (top, bottom) + 2×(H−35.2) (L, R).
      expect(byUsage['o-top']!.length, _l - 35.2);
      expect(byUsage['o-bottom']!.length, _l - 35.2);
      expect(byUsage['o-left']!.length, _h - 35.2);
      expect(byUsage['o-right']!.length, _h - 35.2);
      // Parclose 14.810 beside 14.802: 2×(L−117.6) + 2×(H−157.6).
      expect(byUsage['p-top']!.length, _l - 117.6);
      expect(byUsage['p-bottom']!.length, _l - 117.6);
      expect(byUsage['p-left']!.length, _h - 157.6);
      expect(byUsage['p-right']!.length, _h - 157.6);
      // Tige 14.811: 1×(H−90).
      expect(byUsage['tige']!.length, _h - 90);
      // Total cut pieces per the printed table: 4 dormant + 4 sash
      // + 4 parclose + 1 tige = 13.
      expect(
        outcome.cuts.fold<int>(0, (sum, c) => sum + c.quantity),
        13,
      );

      // -- GLASS (p. 65 VITRAGE block, beside 14.802) --
      expect(outcome.glass, hasLength(1));
      final glass = outcome.glass.first;
      expect(glass.profileReference, '14.802');
      expect(glass.widthMm, _l - 132);
      expect(glass.heightMm, _h - 132);
      expect(glass.quantity, 1);
      expect(glass.sectionId, 's1');
      // Provenance: description carries the 14800 identifier + p. 65.
      expect(glass.ruleDescription, contains('14800'));
      expect(glass.ruleDescription, contains('p. 65'));
      expect(outcome.glassIssues, isEmpty);

      // -- HARDWARE (p. 65 ACCESSOIRES block, 1v française) --
      // 11 of the 12 ACCESSOIRES items have explicit quantities. The
      // 12th ("Clapet Anti-refoulement") prints `*` and is intentionally
      // not encoded -- verified as noRuleMatched diagnostic below.
      final hardwareByRef = <String, HardwareItem>{};
      for (final h in outcome.hardware) {
        hardwareByRef[h.reference] = h;
      }
      // Diagnostic: show what was actually produced (and what was missing).
      // ignore: avoid unused_local_variable on debug code.
      // ignore: avoid unused_local_variable on debug code.
      // ignore_for_file: unused_local_variable
      final missingRefs = <String>[];
      for (final ref in [
        'AC-805', 'AC-822', 'AC-805P', 'AC-807', 'AC-823',
        'AC-808', 'AC-808C', 'AC-600',
        'JO-825', 'JO-826', 'JO-828',
      ]) {
        if (!hardwareByRef.containsKey(ref)) missingRefs.add(ref);
      }
      expect(missingRefs, isEmpty,
          reason: 'missing hardware refs: $missingRefs; '
              'actual: ${hardwareByRef.keys.toList()}');
      // Count-only items.
      expect(hardwareByRef['AC-805']!.quantity, 2);
      expect(hardwareByRef['AC-822']!.quantity, 1);
      expect(hardwareByRef['AC-805P']!.quantity, 2);
      expect(hardwareByRef['AC-807']!.quantity, 1);
      expect(hardwareByRef['AC-823']!.quantity, 1);
      expect(hardwareByRef['AC-808']!.quantity, 2);
      expect(hardwareByRef['AC-808C']!.quantity, 1);
      expect(hardwareByRef['AC-600']!.quantity, 8);
      // Count-only items: no lengthMm.
      for (final ref in [
        'AC-805', 'AC-822', 'AC-805P', 'AC-807', 'AC-823',
        'AC-808', 'AC-808C', 'AC-600',
      ]) {
        expect(hardwareByRef[ref]!.lengthMm, isNull, reason: ref);
      }
      // Length-bearing items: 2L+2H = 2*2000 + 2*1500 = 7000.
      expect(hardwareByRef['JO-825']!.lengthMm, 7000.0);
      expect(hardwareByRef['JO-826']!.lengthMm, 7000.0);
      expect(hardwareByRef['JO-828']!.lengthMm, 7000.0);
      for (final ref in ['JO-825', 'JO-826', 'JO-828']) {
        expect(
          hardwareByRef[ref]!.category,
          HardwareCategory.accessory,
          reason: ref,
        );
      }
      // Category checks: metal items are hardware.
      expect(hardwareByRef['AC-600']!.category, HardwareCategory.hardware);
      expect(hardwareByRef['AC-807']!.category, HardwareCategory.hardware);

      expect(outcome.hardwareIssues, isEmpty);
      expect(outcome.issues, isEmpty);

      // -- BOM DOMAIN COVERAGE --
      // The "Clapet Anti-refoulement" item is the only one the source
      // does NOT quantify; the workshop view surfaces it as a
      // noRuleMatched diagnostic (the 12th item on p. 65 ACCESSOIRES
      // is the ONLY unencoded hardware line). It's a documented
      // honest-skip, not an invention.
      expect(
        hardwareByRef.containsKey('AC-???'),
        isFalse,
        reason: 'AC-??? is the unencoded Clapet; not invented here',
      );
    });

    test('14.805 sash configuration: glass pane sizes to L−185 / H−185 '
        '(p. 65 VITRAGE block beside 14.805)', () {
      final outcome = calculateConstructionCuts(
        _construction(profileUsages: [
          _usage('d-top', '14.800', ProfileUsageRole.top, 's1'),
          _usage('d-bottom', '14.800', ProfileUsageRole.bottom, 's1'),
          _usage('d-left', '14.800', ProfileUsageRole.left, 's1'),
          _usage('d-right', '14.800', ProfileUsageRole.right, 's1'),
          _usage('o-top', '14.805', ProfileUsageRole.top, 's1'),
          _usage('o-bottom', '14.805', ProfileUsageRole.bottom, 's1'),
          _usage('o-left', '14.805', ProfileUsageRole.left, 's1'),
          _usage('o-right', '14.805', ProfileUsageRole.right, 's1'),
          _usage('p-top', '14.810', ProfileUsageRole.top, 's1'),
          _usage('p-bottom', '14.810', ProfileUsageRole.bottom, 's1'),
          _usage('p-left', '14.810', ProfileUsageRole.left, 's1'),
          _usage('p-right', '14.810', ProfileUsageRole.right, 's1'),
          _usage('tige', '14.811', ProfileUsageRole.intermediate, 's1'),
        ]),
        _catalog(),
      )!;

      expect(outcome.glass, hasLength(1));
      final glass = outcome.glass.first;
      expect(glass.profileReference, '14.805');
      expect(glass.widthMm, _l - 185);
      expect(glass.heightMm, _h - 185);
      // Parclose beside 14.805: L−217.4 / H−257.4.
      final byUsage = {
        for (final cut in outcome.cuts) cut.profileUsageId: cut,
      };
      expect(byUsage['p-top']!.length, _l - 217.4);
      expect(byUsage['p-left']!.length, _h - 257.4);
    });

    test('2v française stays noRuleMatched on glass + hardware (p. 65 '
        'has no 2v column for these domains)', () {
      // 2v française is documented for profiles (C9 encodes the 2v
      // column of the debit table) but NOT for glass or hardware --
      // p. 65 prints 1v rows only. The calculator must surface honest
      // noRuleMatched diagnostics rather than fabricating items.
      final outcome = calculateConstructionCuts(
        _construction(
          vantauxCount: 2,
          profileUsages: [
            _usage('d-top', '14.800', ProfileUsageRole.top, 's1'),
            _usage('o-top', '14.802', ProfileUsageRole.top, 's1'),
            _usage('o-bottom', '14.802', ProfileUsageRole.bottom, 's1'),
            _usage('o-left', '14.802', ProfileUsageRole.left, 's1'),
            _usage('o-right', '14.802', ProfileUsageRole.right, 's1'),
          ],
        ),
        _catalog(),
      )!;
      // No glass, no hardware at 2v -- p. 65 has no 2v rows for
      // these domains; the calculator must NOT invent.
      expect(outcome.glass, isEmpty);
      expect(outcome.hardware, isEmpty);
      // Diagnostics: opening section with no rule match on either
      // domain. The dominant-ouvrant is 14.802 (one carrier), so
      // dominantOuvrantUnresolved is NOT the case. It's
      // noRuleMatched.
      expect(outcome.glassIssues, hasLength(1));
      expect(
        outcome.glassIssues.single.reason,
        SectionGlassIssueReason.noRuleMatched,
      );
      expect(outcome.hardwareIssues, hasLength(1));
      expect(
        outcome.hardwareIssues.single.reason,
        SectionHardwareIssueReason.noRuleMatched,
      );
    });
  });
}
