import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:aluminium_designer/core/data/builtin_catalog_seed.dart';
import 'package:aluminium_designer/core/data/me_14600_rule_set.dart';
import 'package:aluminium_designer/core/data/me_14700_rule_set.dart';
import 'package:aluminium_designer/core/data/me_14800_rule_set.dart';
import 'package:aluminium_designer/core/logic/rule_set_resolution.dart';
import 'package:aluminium_designer/core/models/catalog.dart';
import 'package:aluminium_designer/core/models/catalog_json.dart';
import 'package:aluminium_designer/core/models/manufacturer.dart';
import 'package:aluminium_designer/core/models/opening.dart';
import 'package:aluminium_designer/core/models/profile.dart';
import 'package:aluminium_designer/core/models/profile_system.dart';
import 'package:aluminium_designer/core/storage/catalog_store.dart';

import 'support/fake_path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('withBuiltInCatalogSeed (pure merge logic)', () {
    test('manufacturer exists after seeding an empty catalog', () {
      final seeded = withBuiltInCatalogSeed(const Catalog());

      expect(
        seeded.manufacturers.any((m) => m.id == maghrebExtrusionId),
        isTrue,
      );
      expect(
        seeded.manufacturers.firstWhere((m) => m.id == maghrebExtrusionId).name,
        'Maghreb Extrusion (ME)',
      );
    });

    test('Série 14600 belongs to Maghreb Extrusion and is reachable via '
        'the picker lookup path', () {
      final seeded = withBuiltInCatalogSeed(const Catalog());

      final system = seeded.profileSystems.firstWhere(
        (s) => s.id == meSerie14600Id,
      );
      expect(system.manufacturerId, maghrebExtrusionId);
      expect(system.name, 'Série 14600 Coulissant');
      expect(
        seeded.systemsFor(maghrebExtrusionId).map((s) => s.id),
        contains(meSerie14600Id),
      );
    });

    test('seeded profiles are the verified transcription -- spot-checked '
        'values against the source sheets', () {
      final seeded = withBuiltInCatalogSeed(const Catalog());
      final system = seeded.profileSystems.firstWhere(
        (s) => s.id == meSerie14600Id,
      );

      // The document's own profile count as transcribed (see
      // docs/VERIFIED_SOURCES.md for the full per-page table).
      expect(system.profiles, hasLength(38));

      Profile profileByRef(String reference) =>
          system.profiles.firstWhere((p) => p.reference == reference);

      // p.4 DORMANTS (hi-dpi verified).
      final p14626 = profileByRef('14 626');
      expect(p14626.type, ProfileType.dormant);
      expect(p14626.width, 44.66);
      expect(p14626.depth, 66.34);

      // p.7 MONTANTS LATERAUX: 56 mm series.
      final p14622 = profileByRef('14 622');
      expect(p14622.type, ProfileType.montant);
      expect(p14622.width, 33.0);
      expect(p14622.depth, 56.0);

      // p.8 MONTANTS CENTRAUX: the one profile with both dims labeled.
      final p14619 = profileByRef('14 619');
      expect(p14619.type, ProfileType.mullion);
      expect(p14619.width, 41.3);
      expect(p14619.depth, 33.6);

      // p.9 TRAVERSE: depth labeled, face not -> width 0 = unknown.
      final p14621 = profileByRef('14 621');
      expect(p14621.type, ProfileType.traverse);
      expect(p14621.width, 0);
      expect(p14621.depth, 63.0);
    });

    test('every seeded profile carries the owning manufacturer/system '
        'names and the 0-means-unknown convention is used consistently', () {
      final seeded = withBuiltInCatalogSeed(const Catalog());
      final system = seeded.profileSystems.firstWhere(
        (s) => s.id == meSerie14600Id,
      );

      for (final profile in system.profiles) {
        expect(profile.manufacturer, 'Maghreb Extrusion (ME)');
        expect(profile.system, 'Série 14600 Coulissant');
        expect(profile.id, startsWith('builtin-me-14600-'));
        // No sheet states a weight per metre -- none may be invented.
        expect(profile.weightPerMeter, 0);
        // A dimension is either the transcribed value or the explicit
        // unknown marker; nothing in between.
        expect(
          profile.width == 0 || profile.width > 0,
          isTrue,
          reason: '${profile.reference}: width must be 0 or positive',
        );
        expect(
          profile.depth == 0 || profile.depth > 0,
          isTrue,
          reason: '${profile.reference}: depth must be 0 or positive',
        );
      }

      // The profiles whose sheets label no face width must stay unknown,
      // not silently carry another profile's width.
      final unknownWidthRefs = [
        '14 640', // p.5: only horizontal dims labeled
        '14 633', // p.7: reinforced companion, face not labeled
        '14 623', // p.7: reinforced companion, face not labeled
        '14 650', // p.8: only vertical 96.19 labeled
        '14 621', // p.9: depth 63 only
        '14 631', // p.9: depth 63.00 only
      ];
      for (final reference in unknownWidthRefs) {
        expect(
          system.profiles.firstWhere((p) => p.reference == reference).width,
          0,
          reason: '$reference: face width not labeled on its sheet',
        );
      }
    });

    test('system-level metadata carries exactly the facts the document '
        'states -- including what it does NOT state', () {
      final seeded = withBuiltInCatalogSeed(const Catalog());
      final system = seeded.profileSystems.firstWhere(
        (s) => s.id == meSerie14600Id,
      );

      final metadata = system.metadata;
      expect(metadata, isNotNull);
      expect(metadata!.frameDepthOptionsMm, [44.0, 66.34]);
      expect(metadata.sashStileDepthOptionsMm, [56.0, 69.2]);
      // The document states the central mullion FACE (41 mm), not a
      // meeting-stile depth -- the depth field must stay null rather
      // than hold a face value.
      expect(metadata.sashMeetingStileDepthMm, isNull);
      expect(metadata.glazingRebateMm, 26.0);
      expect(metadata.glazingMinMm, 6.0);
      expect(metadata.glazingMaxMm, 22.0);
      // Never stated in the document -> null, not false.
      expect(metadata.thermalBreak, isNull);
      expect(metadata.assemblyNote, isNotNull);
      expect(metadata.drainageNote, isNotNull);
      expect(metadata.finishNote, isNotNull);
      expect(metadata.sourceDescription, isNotEmpty);

      // p.27's two certified test sizes, stored as two envelopes.
      expect(metadata.dimensionLimits, hasLength(2));
      expect(metadata.dimensionLimits[0].maxWidthMm, 1600);
      expect(metadata.dimensionLimits[0].maxHeightMm, 1800);
      expect(metadata.dimensionLimits[0].openingType, isNull);
      expect(metadata.dimensionLimits[1].maxWidthMm, 2500);
      expect(metadata.dimensionLimits[1].maxHeightMm, 2500);
    });

    test('rule set points at the real me-14600 débitage set (2 vantaux '
        'column, p. 24); the rest of the table stays unencoded', () {
      final seeded = withBuiltInCatalogSeed(const Catalog());
      final system = seeded.profileSystems.firstWhere(
        (s) => s.id == meSerie14600Id,
      );

      expect(system.ruleSetId, meSerie14600Id);
      expect(resolveRuleSetById(system.ruleSetId), same(meSerie14600RuleSet));
      expect(meSerie14600RuleSet.isPlaceholder, isFalse);
      expect(system.supportedOpenings, [OpeningType.coulissante]);
      expect(system.isBuiltIn, isTrue);
    });

    test('merging is idempotent -- running it twice does not duplicate', () {
      final once = withBuiltInCatalogSeed(const Catalog());
      final twice = withBuiltInCatalogSeed(once);

      expect(
        twice.manufacturers.where((m) => m.id == maghrebExtrusionId).length,
        1,
      );
      expect(
        twice.profileSystems.where((s) => s.id == meSerie14600Id).length,
        1,
      );
    });

    test('does not touch existing user-created manufacturers/systems', () {
      const userManufacturer = Manufacturer(
        id: 'user-1',
        name: 'My Workshop',
        isBuiltIn: false,
      );
      const userSystem = ProfileSystem(
        id: 'user-sys-1',
        manufacturer: 'My Workshop',
        manufacturerId: 'user-1',
        name: 'Custom System',
        ruleSetId: 'generic-placeholder',
        profiles: [],
        supportedOpenings: [],
        isBuiltIn: false,
      );
      final existing = Catalog(
        manufacturers: const [userManufacturer],
        profileSystems: const [userSystem],
      );

      final seeded = withBuiltInCatalogSeed(existing);

      expect(seeded.manufacturers, contains(userManufacturer));
      expect(seeded.profileSystems, contains(userSystem));
      expect(
        seeded.manufacturers.any((m) => m.id == maghrebExtrusionId),
        isTrue,
      );
    });

    test('catalogue survives a JSON round-trip after seeding -- profiles '
        'and metadata included', () {
      final seeded = withBuiltInCatalogSeed(const Catalog());
      final restored = catalogFromJson(seeded.toJson());

      expect(
        restored.manufacturers.any((m) => m.id == maghrebExtrusionId),
        isTrue,
      );
      final restoredSystem = restored.profileSystems.firstWhere(
        (s) => s.id == meSerie14600Id,
      );
      expect(restoredSystem.name, 'Série 14600 Coulissant');
      expect(restoredSystem.manufacturerId, maghrebExtrusionId);
      expect(restoredSystem.profiles, hasLength(38));
      expect(restoredSystem.metadata, isNotNull);
      expect(restoredSystem.metadata!.frameDepthOptionsMm, [44.0, 66.34]);
      expect(restoredSystem.metadata!.thermalBreak, isNull);
      expect(restoredSystem.metadata!.dimensionLimits, hasLength(2));
      expect(
        restoredSystem.profiles
            .firstWhere((p) => p.reference == '14 626')
            .depth,
        66.34,
      );
    });

    test('seeding produces exactly the built-in manufacturers and '
        'systems, no duplicates', () {
      final seeded = withBuiltInCatalogSeed(const Catalog());

      expect(seeded.manufacturers, hasLength(2));
      expect(
        seeded.manufacturers.map((m) => m.id).toSet(),
        {maghrebExtrusionId, sepalumicId},
      );
      expect(seeded.profileSystems, hasLength(4));
      expect(
        seeded.profileSystems.map((s) => s.id).toSet(),
        {meSerie14600Id, meSerie14700Id, meSerie14800Id, sepSerie4200Id},
      );
    });

    test('each record is added independently -- pre-seeding the built-in '
        'manufacturer does not block the system from being added', () {
      final partial = Catalog(manufacturers: const [maghrebExtrusion]);

      final seeded = withBuiltInCatalogSeed(partial);

      expect(
        seeded.manufacturers.where((m) => m.id == maghrebExtrusionId).length,
        1,
      );
      expect(
        seeded.profileSystems.where((s) => s.id == meSerie14600Id).length,
        1,
      );
    });

    test('pre-seeding the built-in system does not block the manufacturer '
        'from being added (records evaluated independently)', () {
      final systemOnly = withBuiltInCatalogSeed(
        const Catalog(),
      ).profileSystems.where((s) => s.id == meSerie14600Id).toList();
      final partial = Catalog(profileSystems: systemOnly);

      final seeded = withBuiltInCatalogSeed(partial);

      expect(
        seeded.manufacturers.where((m) => m.id == maghrebExtrusionId).length,
        1,
      );
      expect(
        seeded.profileSystems.where((s) => s.id == meSerie14600Id).length,
        1,
      );
    });
  });

  group('pruneRemovedBuiltIns (pure prune logic)', () {
    /// A faithful stand-in for a pre-C4b persisted catalog: the old
    /// `Aluminium du Maroc` / `Cuzco 713 OM` seed, exactly as stored on
    /// disk by installs from that era (see the C4b clean-slate note).
    Catalog preC4bCatalog() => Catalog(
      manufacturers: const [
        Manufacturer(
          id: 'builtin-aluminium-du-maroc',
          name: 'Aluminium du Maroc',
          isBuiltIn: true,
        ),
      ],
      profileSystems: const [
        ProfileSystem(
          id: 'builtin-cuzco-713-om',
          manufacturer: 'Aluminium du Maroc',
          manufacturerId: 'builtin-aluminium-du-maroc',
          name: 'Cuzco 713 OM',
          ruleSetId: 'generic-placeholder',
          profiles: [],
          supportedOpenings: [OpeningType.francaise],
          isBuiltIn: true,
        ),
      ],
    );

    test('drops superseded built-ins and keeps everything else', () {
      final userMfr = Manufacturer(
        id: 'user-mfr-1',
        name: 'Atelier du coin',
        isBuiltIn: false,
      );
      final withUser = preC4bCatalog().copyWith(
        manufacturers: [...preC4bCatalog().manufacturers, userMfr],
      );

      final pruned = pruneRemovedBuiltIns(withUser);

      expect(
        pruned.manufacturers.map((m) => m.id),
        isNot(contains('builtin-aluminium-du-maroc')),
      );
      expect(
        pruned.profileSystems.map((s) => s.id),
        isNot(contains('builtin-cuzco-713-om')),
      );
      // User-created records survive untouched, whatever their ids.
      expect(
        pruned.manufacturers.map((m) => m.id),
        contains('user-mfr-1'),
      );
    });

    test('a pre-C4b install heals to the full shipped seed on merge+prune',
        () {
      final healed = pruneRemovedBuiltIns(
        withBuiltInCatalogSeed(preC4bCatalog()),
      );

      // Real systems arrive...
      expect(
        healed.manufacturers.map((m) => m.id),
        containsAll([maghrebExtrusionId, sepalumicId]),
      );
      expect(
        healed.profileSystems.map((s) => s.id),
        containsAll([meSerie14600Id, meSerie14800Id, sepSerie4200Id]),
      );
      // ...and the superseded seed is gone.
      expect(
        healed.manufacturers.map((m) => m.id),
        isNot(contains('builtin-aluminium-du-maroc')),
      );
      expect(
        healed.profileSystems.map((s) => s.id),
        isNot(contains('builtin-cuzco-713-om')),
      );
    });

    test('returns the same instance when there is nothing to prune', () {
      final seeded = withBuiltInCatalogSeed(const Catalog());
      expect(identical(pruneRemovedBuiltIns(seeded), seeded), isTrue);
    });

    test('never touches user-created records, even with odd ids', () {
      final catalog = Catalog(
        manufacturers: const [
          Manufacturer(id: 'x', name: 'Y', isBuiltIn: false),
        ],
        profileSystems: const [
          ProfileSystem(
            id: 'z',
            manufacturer: 'Y',
            manufacturerId: 'x',
            name: 'Z',
            ruleSetId: 'generic-placeholder',
            profiles: [],
            supportedOpenings: [],
            isBuiltIn: false,
          ),
        ],
      );
      expect(identical(pruneRemovedBuiltIns(catalog), catalog), isTrue);
    });
  });

  group('adoptBuiltInRuleSets (pure refresh logic)', () {
    /// A faithful stand-in for a pre-C5 persisted record: identical to
    /// the shipped me-14600 definition except it still points at the
    /// placeholder rule set.
    ProfileSystem driftedBuiltin() => ProfileSystem(
      id: meSerie14600Id,
      manufacturer: meSerie14600.manufacturer,
      manufacturerId: meSerie14600.manufacturerId,
      name: meSerie14600.name,
      ruleSetId: 'generic-placeholder',
      profiles: meSerie14600.profiles,
      supportedOpenings: meSerie14600.supportedOpenings,
      isBuiltIn: true,
      metadata: null, // Pre-C4a installs had no metadata either.
    );

    test('refreshes a drifted built-in system in place', () {
      // Non-null metadata pins the "verified metadata preserved exactly"
      // promise of the refresh.
      final withMetadata = ProfileSystem(
        id: driftedBuiltin().id,
        manufacturer: driftedBuiltin().manufacturer,
        manufacturerId: driftedBuiltin().manufacturerId,
        name: driftedBuiltin().name,
        ruleSetId: driftedBuiltin().ruleSetId,
        profiles: driftedBuiltin().profiles,
        supportedOpenings: driftedBuiltin().supportedOpenings,
        isBuiltIn: true,
        metadata: meSerie14600.metadata,
      );
      final catalog = Catalog(profileSystems: [withMetadata]);

      final adopted = adoptBuiltInRuleSets(catalog);

      expect(adopted.profileSystems, hasLength(1));
      final system = adopted.profileSystems.single;
      expect(system.ruleSetId, meSerie14600Id);
      // Everything else is preserved exactly as persisted.
      expect(system.id, meSerie14600Id);
      expect(system.name, meSerie14600.name);
      expect(system.profiles, same(meSerie14600.profiles));
      expect(system.isBuiltIn, isTrue);
      expect(system.metadata, same(meSerie14600.metadata));
    });

    test('a stored record matching a built-in id but flagged '
        'isBuiltIn:false stays untouched (user-created wins)', () {
      final userOwned = ProfileSystem(
        id: meSerie14600Id,
        manufacturer: 'Someone',
        manufacturerId: 'someone',
        name: 'Recreated by user',
        ruleSetId: 'generic-placeholder',
        profiles: const [],
        supportedOpenings: const [],
        isBuiltIn: false,
      );
      final catalog = Catalog(profileSystems: [userOwned]);

      final adopted = adoptBuiltInRuleSets(catalog);

      expect(identical(adopted, catalog), isTrue);
    });

    test('is a no-op (same instance) when nothing needs adoption', () {
      const catalog = Catalog();

      expect(identical(adoptBuiltInRuleSets(catalog), catalog), isTrue);

      // Already-adopted built-in: untouched.
      final current = Catalog(profileSystems: [meSerie14600]);
      expect(identical(adoptBuiltInRuleSets(current), current), isTrue);
    });

    test('never touches user-created systems even on placeholder rules', () {
      final userSystem = ProfileSystem(
        id: 'user-system',
        manufacturer: 'User Manufacturer',
        manufacturerId: 'user-manufacturer',
        name: 'My System',
        ruleSetId: 'generic-placeholder',
        profiles: const [],
        supportedOpenings: const [],
        isBuiltIn: false,
      );
      final catalog = Catalog(profileSystems: [driftedBuiltin(), userSystem]);

      final adopted = adoptBuiltInRuleSets(catalog);

      expect(adopted.profileSystems, hasLength(2));
      expect(
        adopted.profileSystems
            .firstWhere((s) => s.id == 'user-system')
            .ruleSetId,
        'generic-placeholder',
      );
    });

    test('a non-placeholder stored value wins -- no override of user '
        'choices, even for a built-in id', () {
      final customized = ProfileSystem(
        id: meSerie14600Id,
        manufacturer: meSerie14600.manufacturer,
        manufacturerId: meSerie14600.manufacturerId,
        name: meSerie14600.name,
        ruleSetId: 'my-own-rules',
        profiles: meSerie14600.profiles,
        supportedOpenings: meSerie14600.supportedOpenings,
        isBuiltIn: true,
      );
      final catalog = Catalog(profileSystems: [customized]);

      final adopted = adoptBuiltInRuleSets(catalog);

      expect(adopted.profileSystems.single.ruleSetId, 'my-own-rules');
    });

    test('idempotent: adopting an already-adopted catalog changes nothing', () {
      final once = adoptBuiltInRuleSets(
        Catalog(profileSystems: [driftedBuiltin()]),
      );
      final twice = adoptBuiltInRuleSets(once);

      expect(identical(twice, once), isTrue);
      expect(twice.profileSystems.single.ruleSetId, meSerie14600Id);
    });
  });

  group('seeded profile inertias (VERIFIED_SOURCES.md transcription)', () {
    Profile profileByRef(String reference) => meSerie14600.profilesById.values
        .firstWhere((p) => p.reference == reference);

    test('sheet-printed IXX/IYY pairs are seeded verbatim (cm⁴)', () {
      // ALL 20 verified pairs -- a transcription typo anywhere must fail
      // CI, not just in the spot-checked subset.
      final expected = {
        '14 626': (7.9, 26.14),
        '14 627': (6.66, 23.16),
        '14 628': (10.24, 27.22),
        '14 617': (4.95, 13.65),
        '14 640': (6.7, 17.07),
        '14 618': (9.13, 16.90),
        '14 818': (3.0, 13.35),
        '14 820': (3.67, 6.51),
        '14 638': (4.37, 4.067),
        '14 637': (6.21, 22.6),
        '14 632': (7.1, 14.7),
        '14 633': (20.16, 23.3),
        '14 622': (6.95, 4.8),
        '14 623': (10.93, 13.44),
        '14 619': (4.67, 3.405),
        '14 620': (13.80, 5.7),
        '14 630': (37.0, 10.23),
        '14 621': (4.24, 9.52),
        '14 631': (4.93, 10.2),
        '14 625': (3.2, 8.12),
      };
      expected.forEach((reference, values) {
        final profile = profileByRef(reference);
        expect(
          profile.inertiaIxxCm4,
          values.$1,
          reason: '$reference IXX must match the sheet',
        );
        expect(
          profile.inertiaIyyCm4,
          values.$2,
          reason: '$reference IYY must match the sheet',
        );
      });
    });

    test('profiles whose sheets state no inertia stay at the unknown '
        'marker (0/0)', () {
      for (final reference in [
        '14 643',
        '14 603',
        '14 604',
        '14 810',
        '14 601',
      ]) {
        final profile = profileByRef(reference);
        expect(profile.inertiaIxxCm4, 0, reason: reference);
        expect(profile.inertiaIyyCm4, 0, reason: reference);
      }
    });

    test("14 650's axis-less printed value is NOT seeded as an inferred "
        'axis -- both stay 0 pending external verification', () {
      final profile = profileByRef('14 650');
      expect(profile.inertiaIxxCm4, 0);
      expect(profile.inertiaIyyCm4, 0);
    });

    test('every seeded inertia is zero or positive -- never negative', () {
      for (final profile in meSerie14600.profiles) {
        expect(
          profile.inertiaIxxCm4,
          greaterThanOrEqualTo(0),
          reason: profile.reference,
        );
        expect(
          profile.inertiaIyyCm4,
          greaterThanOrEqualTo(0),
          reason: profile.reference,
        );
      }
    });
  });

  group('seeded Sepalumic 4200 profile dimensions (M-2 transcription)',
      () {
    Profile profileByRef(String reference) => sepSerie4200.profilesById.values
        .firstWhere((p) => p.reference == reference);

    test('sheet-labeled width/depth pairs are seeded verbatim', () {
      final expected = {
        '4220': (40.0, 49.0),
        '4221': (40.0, 49.0),
        '4211': (50.0, 37.5),
        '4219': (50.0, 49.0),
        '4244': (49.5, 67.5),
        '4254': (50.0, 76.0),
        '4206': (52.0, 40.0),
        '4413': (40.0, 44.0),
        '4405': (40.0, 26.0),
        '2656': (26.0, 62.0), // depth derived 19+24+19, shown in ledger
        '4243': (40.0, 44.0),
        '4233': (26.0, 26.0),
        '4253': (26.0, 26.0),
        '4464': (5.4, 22.0),
        '4418': (9.4, 22.0),
        '5026': (14.3, 22.0),
        '5120': (18.2, 22.0),
        '5016': (22.0, 22.0),
        '4250': (7.9, 22.0),
        '4252': (12.1, 26.7),
        '4251': (15.8, 26.7),
        '463': (45.0, 7.0),
        '4582': (52.0, 20.0),
        '5067': (35.0, 15.0),
        '4568': (20.0, 12.0),
        '412': (19.6, 4.5),
      };
      expected.forEach((reference, values) {
        final profile = profileByRef(reference);
        expect(profile.width, values.$1, reason: '$reference width');
        expect(profile.depth, values.$2, reason: '$reference depth');
      });
    });

    test('unlabeled dimensions stay at the 0 = not-stated marker', () {
      // 3380M/4080/4081/4082 sheets label only the vertical dim.
      for (final entry in [
        ('3380M', 30.0),
        ('4080', 30.0),
        ('4081', 45.0),
        ('4082', 60.0),
      ]) {
        final profile = profileByRef(entry.$1);
        expect(profile.width, 0, reason: entry.$1);
        expect(profile.depth, entry.$2, reason: entry.$1);
      }
      // 2648 labels a 28/42 vertical chain with no total.
      final p2648 = profileByRef('2648');
      expect(p2648.width, 30);
      expect(p2648.depth, 0);
    });

    test('system metadata carries the A030/A040 facts and nothing more',
        () {
      final metadata = sepSerie4200.metadata!;
      expect(metadata.frameDepthOptionsMm, [49.0]);
      expect(metadata.sashStileDepthOptionsMm, [37.5, 49.0, 67.5, 76.0]);
      expect(metadata.glazingMinMm, 6.0);
      expect(metadata.glazingMaxMm, 24.0);
      // The catalogue never mentions a thermal break for this series.
      expect(metadata.thermalBreak, isNull);
      // No dimension-limit statement exists in the transcribed sections.
      expect(metadata.dimensionLimits, isEmpty);
      expect(metadata.assemblyNote, isNotNull);
      expect(metadata.sourceDescription, contains('4200'));
    });

    test('system wiring: rule set + supported openings', () {
      expect(sepSerie4200.ruleSetId, sepSerie4200Id);
      expect(sepSerie4200.supportedOpenings, [OpeningType.francaise]);
      expect(sepSerie4200.isBuiltIn, isTrue);
      expect(sepSerie4200.profiles, hasLength(31));
    });
  });

  group('seeded ME Série 14800 profile dimensions (S-3 transcription)',
      () {
    Profile profileByRef(String reference) => meSerie14800.profilesById.values
        .firstWhere((p) => p.reference == reference);

    test('system wiring: rule set + supported openings + profile count',
        () {
      expect(meSerie14800.ruleSetId, meSerie14800Id);
      expect(
        resolveRuleSetById(meSerie14800Id),
        same(meSerie14800RuleSet),
      );
      expect(meSerie14800RuleSet.isPlaceholder, isFalse);
      expect(meSerie14800.manufacturerId, maghrebExtrusionId);
      expect(meSerie14800.supportedOpenings, [OpeningType.francaise]);
      expect(meSerie14800.isBuiltIn, isTrue);
      // The four PROFILOSCOPE sheets' full transcription (S-3):
      // 21 profiles across pp. 50-53.
      expect(meSerie14800.profiles, hasLength(21));
    });

    test('sheet-labeled width/depth pairs are seeded verbatim', () {
      final expected = {
        '14820': (42.7, 44.0),
        '14818': (42.8, 66.3),
        '14.800': (43.6, 44.0),
        '14.801': (43.6, 44.0),
        '14.802': (47.9, 61.2),
        '14.805': (47.9, 87.8),
        '14.809': (16.0, 19.5),
        '14.810': (24.0, 19.5),
        '14809/1': (12.5, 19.5),
        '14827': (44.0, 8.7),
        '14817': (47.9, 10.4),
        '14806': (87.8, 47.9),
        '14804': (56.5, 44.4),
        '14825': (29.5, 14.5),
        '14807': (33.5, 19.5),
        '14803': (68.8, 40.0),
        '14812': (88.8, 48.8),
        '14808': (50.0, 90.0),
        '14813': (40.0, 140.0),
      };
      expected.forEach((reference, values) {
        final profile = profileByRef(reference);
        expect(profile.width, values.$1, reason: '$reference width');
        expect(profile.depth, values.$2, reason: '$reference depth');
      });
    });

    test('unlabeled dimensions stay at the 0 = not-stated marker', () {
      // 14.811 (tige de crémone) has no dimensioned sheet in the section.
      final tige = profileByRef('14.811');
      expect(tige.width, 0);
      expect(tige.depth, 0);
      // 14601 labels only the 26 height.
      final couvreJoint = profileByRef('14601');
      expect(couvreJoint.width, 0);
      expect(couvreJoint.depth, 26.0);
    });

    test('types follow source statements only -- heading-less sheets '
        'stay `other`', () {
      expect(profileByRef('14.800').type, ProfileType.dormant);
      expect(profileByRef('14.801').type, ProfileType.dormant);
      expect(profileByRef('14820').type, ProfileType.dormant);
      expect(profileByRef('14818').type, ProfileType.dormant);
      expect(profileByRef('14.802').type, ProfileType.ouvrant);
      expect(profileByRef('14.805').type, ProfileType.ouvrant);
      // Parcloses: named by the table, but the enum has no parclose
      // value -- `other`, same as the 14600 seed.
      expect(profileByRef('14.809').type, ProfileType.other);
      expect(profileByRef('14.810').type, ProfileType.other);
      // No heading names these -- shape-based typing would be inference.
      for (final reference in [
        '14803',
        '14804',
        '14806',
        '14807',
        '14808',
        '14812',
        '14813',
        '14825',
        '14.811',
      ]) {
        expect(
          profileByRef(reference).type,
          ProfileType.other,
          reason: '$reference: no source heading states a family',
        );
      }
    });

    test('system metadata carries exactly the fiche technique facts',
        () {
      final metadata = meSerie14800.metadata!;
      expect(metadata.frameDepthOptionsMm, [44.0]);
      expect(metadata.sashStileDepthOptionsMm, [47.9]);
      expect(metadata.glazingRebateMm, 24.0);
      expect(metadata.glazingMinMm, 6.0);
      expect(metadata.glazingMaxMm, 20.0);
      // Never stated in the section -> null, not false.
      expect(metadata.thermalBreak, isNull);
      // No dimension-limit statement exists -> none seeded.
      expect(metadata.dimensionLimits, isEmpty);
      expect(metadata.assemblyNote, isNotNull);
      // The AEV classification has no structured field; the ledger S-3
      // records it as carried verbatim inside finishNote -- pin that.
      expect(metadata.finishNote, contains('E1050'));
      expect(metadata.sourceDescription, contains('14800'));
    });

    test('sheet-printed IXX/IYY pairs are seeded verbatim (cm⁴)', () {
      // ALL 12 printed pairs -- same fail-CI standard as the 14600
      // inertia group above.
      final expected = {
        '14820': (3.67, 6.51),
        '14818': (3.0, 13.35),
        '14.800': (4.90, 2.40),
        '14.801': (6.30, 4.60),
        '14.802': (2.0, 3.67),
        '14.805': (12.4, 18.9),
        '14806': (13.4, 22.79),
        '14804': (7.14, 6.25),
        '14803': (6.26, 6.7),
        '14812': (12.4, 18.9),
        '14808': (107.73, 28.86),
        '14813': (96.41, 16.15),
      };
      expected.forEach((reference, values) {
        final profile = profileByRef(reference);
        expect(
          profile.inertiaIxxCm4,
          values.$1,
          reason: '$reference IXX must match the sheet',
        );
        expect(
          profile.inertiaIyyCm4,
          values.$2,
          reason: '$reference IYY must match the sheet',
        );
      });
    });

    test('profiles whose sheets state no inertia stay at the unknown '
        'marker (0/0), and no inertia is ever negative', () {
      for (final profile in meSerie14800.profiles) {
        expect(
          profile.inertiaIxxCm4,
          greaterThanOrEqualTo(0),
          reason: profile.reference,
        );
        expect(
          profile.inertiaIyyCm4,
          greaterThanOrEqualTo(0),
          reason: profile.reference,
        );
      }
      for (final reference in [
        '14.809',
        '14.810',
        '14809/1',
        '14.811',
        '14827',
        '14817',
        '14825',
        '14807',
        '14601',
      ]) {
        final profile = profileByRef(reference);
        expect(profile.inertiaIxxCm4, 0, reason: reference);
        expect(profile.inertiaIyyCm4, 0, reason: reference);
      }
    });
  });

  group('seeded ME Série 14700 profile dimensions (S-4 transcription)',
      () {
    Profile profileByRef(String reference) => meSerie14700.profilesById.values
        .firstWhere((p) => p.reference == reference);

    test('system wiring: rule set + supported openings + profile count',
        () {
      expect(meSerie14700.ruleSetId, meSerie14700Id);
      expect(
        resolveRuleSetById(meSerie14700Id),
        same(meSerie14700RuleSet),
      );
      expect(meSerie14700RuleSet.isPlaceholder, isFalse);
      expect(meSerie14700.manufacturerId, maghrebExtrusionId);
      expect(meSerie14700.supportedOpenings, [OpeningType.francaise]);
      expect(meSerie14700.isBuiltIn, isTrue);
      // The five PROFILOSCOPE sheets' full transcription (S-4):
      // 18 profiles across pp. 76-80 (9 table-named + 9 sheet-only).
      expect(meSerie14700.profiles, hasLength(18));
    });

    test('sheet-labeled width/depth pairs are seeded verbatim', () {
      final expected = {
        '14.700': (72.1, 0.0),    // wall-plane dim not labeled; fiche = 54mm
        '14.701': (75.1, 54.0),
        '14.705': (91.8, 0.0),    // fiche = 54mm
        '14.706': (91.8, 0.0),    // fiche = 54mm; sheet sub-dims only
        '14.810': (22.0, 20.0),
        '14.809': (16.0, 20.0),
        '14.809/1': (12.5, 20.0),
        '14.819': (4.5, 20.0),
        '14.813': (140.0, 40.0),
        '14.807': (22.0, 48.0),
        '14.718': (117.5, 87.6),
        '14.704': (54.0, 19.0),
        '14.712': (89.2, 54.0),
        '14.708': (22.0, 54.0),
        '14.803': (68.8, 40.0),
        '14.812': (88.8, 48.8),
      };
      expected.forEach((reference, values) {
        final profile = profileByRef(reference);
        expect(profile.width, values.$1, reason: '$reference width');
        expect(profile.depth, values.$2, reason: '$reference depth');
      });
    });

    test('unlabeled dimensions stay at the 0 = not-stated marker', () {
      // 14.811 (tige de crémone) has no PROFILOSCOPE sheet in the section.
      final tige = profileByRef('14.811');
      expect(tige.width, 0);
      expect(tige.depth, 0);
      // 14.711 (tige de crémone variante) -- no dimensions labeled.
      final tige711 = profileByRef('14.711');
      expect(tige711.width, 0);
      expect(tige711.depth, 0);
    });

    test('types follow source statements only -- heading-less sheets '
        'stay `other`', () {
      // p.94 débitage names 14.700 "Dormant" and 14.705/14.706
      // "Ouvrant intérieur / extérieur".
      expect(profileByRef('14.700').type, ProfileType.dormant);
      expect(profileByRef('14.705').type, ProfileType.ouvrant);
      expect(profileByRef('14.706').type, ProfileType.ouvrant);
      // Traverse basse assembly (bottom rail / threshold): named by
      // the débitage table, both typed as traverse.
      expect(profileByRef('14.813').type, ProfileType.traverse);
      expect(profileByRef('14.807').type, ProfileType.traverse);
      // Parcloses: enum has no parclose value -- `other`, same as the
      // 14600 / 14800 seeds.
      expect(profileByRef('14.810').type, ProfileType.other);
      expect(profileByRef('14.809').type, ProfileType.other);
      // 14.811 tige de crémone: no source statement on a family --
      // `other`.
      expect(profileByRef('14.811').type, ProfileType.other);
      // No heading names these -- shape-based typing would be inference.
      for (final reference in [
        '14.701', '14.704', '14.708', '14.711', '14.712', '14.718',
        '14.803', '14.812', '14.819', '14.809/1',
      ]) {
        expect(
          profileByRef(reference).type,
          ProfileType.other,
          reason: '$reference: no source heading states a family',
        );
      }
    });

    test('system metadata carries exactly the fiche technique facts',
        () {
      final metadata = meSerie14700.metadata!;
      // Fiche p.73: dormant tubulaire 54mm.
      expect(metadata.frameDepthOptionsMm, [54.0]);
      // Fiche p.73: ouvrant tubulaire 54mm.
      expect(metadata.sashStileDepthOptionsMm, [54.0]);
      // Fiche p.74: glazing 6 à 24 mm; rebate depth not stated.
      expect(metadata.glazingMinMm, 6.0);
      expect(metadata.glazingMaxMm, 24.0);
      // Fiche never mentions a thermal break for this series.
      expect(metadata.thermalBreak, isNull);
      // No dimension-limit statement exists in the fiche section.
      expect(metadata.dimensionLimits, isEmpty);
      expect(metadata.assemblyNote, isNotNull);
      expect(metadata.drainageNote, isNotNull);
      expect(metadata.sourceDescription, contains('14700'));
    });
  });

  group('CatalogStore seeding via real file I/O', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('aluvis_seed_test');
      PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('first-ever load seeds the built-in manufacturer/system', () async {
      final store = CatalogStore();
      final catalog = await store.load();

      expect(
        catalog.manufacturers.any((m) => m.id == maghrebExtrusionId),
        isTrue,
      );
      expect(catalog.profileSystems.any((s) => s.id == meSerie14600Id), isTrue);
    });

    test('app restart persistence: a fresh CatalogStore instance still sees '
        'the seeded data after the first one seeded and saved it', () async {
      final firstRun = CatalogStore();
      await firstRun.load(); // Seeds and persists.

      // A brand-new store instance simulates the app being closed and
      // reopened -- no shared in-memory state with `firstRun`.
      final secondRun = CatalogStore();
      final reloaded = await secondRun.load();

      expect(
        reloaded.manufacturers.any((m) => m.id == maghrebExtrusionId),
        isTrue,
      );
      expect(
        reloaded.profileSystems.any((s) => s.id == meSerie14600Id),
        isTrue,
      );
    });

    test('a missing built-in is restored on reload, while user-created '
        'records are never touched by the merge', () async {
      // New contract (the picker no longer offers delete for built-in
      // records, so re-adding a missing one cannot resurrect a
      // deliberate user deletion): every-load merging restores any
      // shipped built-in absent from disk, and never touches
      // user-created records.
      final store = CatalogStore();
      final catalog = await store.load(); // Seeds on first load.

      // Simulate an old install whose stored catalog lost the
      // built-in manufacturer (and its system), but which also holds
      // a user-created manufacturer the merge must preserve.
      final userMfr = Manufacturer(
        id: 'user-mfr-1',
        name: 'Atelier du coin',
        isBuiltIn: false,
      );
      final withoutBuiltIns = catalog.copyWith(
        manufacturers: [userMfr],
        profileSystems: [],
      );
      await store.save(withoutBuiltIns);

      // Reload (simulating app restart) -- missing built-ins come
      // back, the user record survives untouched.
      final reloadedStore = CatalogStore();
      final reloaded = await reloadedStore.load();

      expect(
        reloaded.manufacturers.any((m) => m.id == maghrebExtrusionId),
        isTrue,
      );
      expect(
        reloaded.profileSystems.any((s) => s.id == meSerie14600Id),
        isTrue,
      );
      expect(
        reloaded.manufacturers.any((m) => m.id == 'user-mfr-1'),
        isTrue,
      );
    });

    test('a pre-C5 install (drifted built-in + sentinel present) adopts '
        'the real rule set on load and persists the adoption', () async {
      final store = CatalogStore();

      // Simulate the on-disk state of an install last run before C5b:
      // the seeded me-14600 record still points at the placeholder, and
      // the one-time seed sentinel already exists.
      final drifted = ProfileSystem(
        id: meSerie14600Id,
        manufacturer: meSerie14600.manufacturer,
        manufacturerId: meSerie14600.manufacturerId,
        name: meSerie14600.name,
        ruleSetId: 'generic-placeholder',
        profiles: const [],
        supportedOpenings: const [OpeningType.coulissante],
        isBuiltIn: true,
      );
      await store.save(
        Catalog(manufacturers: [maghrebExtrusion], profileSystems: [drifted]),
      );
      final dir = await store.directoryForTest();
      File('${dir.path}/.catalog_seeded').writeAsStringSync('1');

      // Load: the adoption pass must refresh ruleSetId despite the
      // sentinel short-circuiting the seed merge.
      final loaded = await store.load();
      final adopted = loaded.profileSystems.firstWhere(
        (s) => s.id == meSerie14600Id,
      );
      expect(adopted.ruleSetId, meSerie14600Id);
      expect(adopted.isBuiltIn, isTrue);

      // PERSISTENCE proof: read catalog.json raw, bypassing load()'s
      // self-healing re-adoption -- a regression that drops the save()
      // would otherwise be invisible because every load re-derives the
      // fix in memory.
      final rawOnDisk =
          jsonDecode(File('${dir.path}/catalog.json').readAsStringSync())
              as Map<String, dynamic>;
      final storedSystems = (rawOnDisk['profileSystems'] as List)
          .cast<Map<String, dynamic>>();
      expect(
        storedSystems.firstWhere((s) => s['id'] == meSerie14600Id)['ruleSetId'],
        meSerie14600Id,
      );

      // The adoption survives a fresh store too.
      final reloadedStore = CatalogStore();
      final reloaded = await reloadedStore.load();
      expect(
        reloaded.profileSystems
            .firstWhere((s) => s.id == meSerie14600Id)
            .ruleSetId,
        meSerie14600Id,
      );
    });
  });
}
