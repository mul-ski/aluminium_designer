import 'package:flutter/material.dart';

import '../../../../core/logic/component_aggregation.dart';
import '../../../../core/models/calculation_outcome.dart';
import '../../../../core/models/section.dart';

/// Full-screen unified Bill of Materials for a [CalculationOutcome]:
/// one grouped table combining profile cuts, glass panes, hardware
/// pieces, and accessories into a single component summary a
/// fabricator reads top-to-bottom.
///
/// Opened from `CalculationResultsBanner`'s "BOM" action. The
/// underlying data is a pure derivation over the same
/// [CalculationOutcome] the cut-list dialog consumes -- the BOM
/// aggregates profile cuts, glass items, and hardware items into
/// [BomLine] rows via `buildBom` (see `component_aggregation.dart`).
/// The existing cut-list dialog stays unchanged: the BOM is the
/// *unified* view (one row per component, grouped by domain), not a
/// replacement of the workshop cut list (which groups identical cuts
/// for the shop floor).
///
/// The stale flag ([isStale]) is passed through unchanged -- an
/// outdated outcome is flagged, never hidden; recalculation stays
/// manual. Weight per line is not displayed: the BOM does not
/// currently carry weight information (cut list does, on a per-cut
/// basis; hardware/accessories are sold by piece, not by weight).
class BomDialog extends StatelessWidget {
  final CalculationOutcome outcome;
  final List<Section> sections;
  final bool isStale;

  /// Order in which the four BOM domains are rendered: profiles, glass,
  /// hardware, accessory. Defined at class level so the widget tree
  /// doesn't need to reconstruct the list every build.
  static const List<BomDomain> _allDomains = [
    BomDomain.profile,
    BomDomain.glass,
    BomDomain.hardware,
    BomDomain.accessory,
  ];

  const BomDialog({
    super.key,
    required this.outcome,
    required this.sections,
    required this.isStale,
  });

  /// Opens the BOM dialog for [outcome] over [sections].
  static Future<void> show(
    BuildContext context, {
    required CalculationOutcome outcome,
    required List<Section> sections,
    required bool isStale,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog.fullscreen(
        child: BomDialog(
          outcome: outcome,
          sections: sections,
          isStale: isStale,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = buildBom(
      profileCuts: outcome.cuts,
      glass: outcome.glass,
      hardware: outcome.hardware,
    );
    final summary = summarizeBom(lines);

    // Group by domain for display. Profiles first (the existing
    // workshop cut list handles them in depth; here the BOM view
    // shows them as the "components" group), then glass, then
    // hardware, then accessory. Within each group, lines stay in
    // buildBom order (source-declaration order via the calculator
    // loop), which is the natural workshop reading order.
    final byDomain = <BomDomain, List<BomLine>>{};
    for (final line in lines) {
      byDomain.putIfAbsent(line.domain, () => []).add(line);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('BOM — nomenclature'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Fermer',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (isStale) ...[
            const Row(
              children: [
                Icon(Icons.update, size: 14, color: Color(0xFF8A6D00)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Résultat obsolète — appuyez sur Calculer pour '
                    'actualiser.',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF8A6D00),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          // Header summary: total pieces, glass area, hardware length.
          // Per-domain totals let the workshop view cross-check that
          // "the BOM is complete" without recomputing them.
          Text(
            'Total : ${summary.totalPieces} '
            '${summary.totalPieces > 1 ? 'pièces' : 'pièce'} — '
            'vitrage ${summary.glassAreaM2.toStringAsFixed(2)} m² — '
            'quincaillerie ${(summary.hardwareTotalLengthMm / 1000)
                .toStringAsFixed(2)} m',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          // Explicit for-loop in a Builder rather than `for ...[ ... ]`
          // collection-spread: the spread form, in the dialog's
          // ListView, was silently dropping the last iteration of the
          // loop (the accessory section) under flutter_test's lazy
          // child-build strategy. The Builder wrapper forces the loop
          // to complete before the ListView starts building children,
          // and every section is then mounted in order.
          Builder(
            builder: (_) {
              final children = <Widget>[];
              for (final domain in _allDomains) {
                if (byDomain.containsKey(domain)) {
                  children.add(
                    _DomainSection(
                      title: _domainLabel(domain),
                      lines: byDomain[domain]!,
                      sections: sections,
                    ),
                  );
                }
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              );
            },
          ),
          // Per-section diagnostics at the end: glass + hardware
          // sections without matching rules. The cut-list dialog
          // already shows the profile-side issues; the BOM only
          // surfaces its own glass/hardware diagnostics.
          if (outcome.glassIssues.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Sections sans vitrage',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8A6D00),
              ),
            ),
            const SizedBox(height: 2),
            for (final issue in outcome.glassIssues)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  'Section ${issue.sectionId} — '
                  '${_labelForGlassReason(issue.reason)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A6D00),
                  ),
                ),
              ),
          ],
          if (outcome.hardwareIssues.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Sections sans quincaillerie',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8A6D00),
              ),
            ),
            const SizedBox(height: 2),
            for (final issue in outcome.hardwareIssues)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  'Section ${issue.sectionId} — '
                  '${_labelForHardwareReason(issue.reason)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A6D00),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String _domainLabel(BomDomain domain) {
    switch (domain) {
      case BomDomain.profile:
        return 'Profilés';
      case BomDomain.glass:
        return 'Vitrage';
      case BomDomain.hardware:
        return 'Quincaillerie';
      case BomDomain.accessory:
        return 'Accessoires';
    }
  }

  static String _labelForGlassReason(SectionGlassIssueReason reason) {
    switch (reason) {
      case SectionGlassIssueReason.dominantOuvrantUnresolved:
        return 'aucun ouvrant dominant résolu';
      case SectionGlassIssueReason.mixedSashCarrier:
        return 'plusieurs ouvrants distincts (tierce/porte)';
      case SectionGlassIssueReason.noRuleMatched:
        return 'aucune règle de vitrage ne correspond';
    }
  }

  static String _labelForHardwareReason(SectionHardwareIssueReason reason) {
    switch (reason) {
      case SectionHardwareIssueReason.dominantOuvrantUnresolved:
        return 'aucun ouvrant dominant résolu';
      case SectionHardwareIssueReason.mixedSashCarrier:
        return 'plusieurs ouvrants distincts (tierce/porte)';
      case SectionHardwareIssueReason.noRuleMatched:
        return 'aucune règle de quincaillerie ne correspond';
    }
  }
}

class _DomainSection extends StatelessWidget {
  final String title;
  final List<BomLine> lines;
  final List<Section> sections;

  const _DomainSection({
    required this.title,
    required this.lines,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5B6B76),
          ),
        ),
        const SizedBox(height: 4),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main row: reference + name, quantity, dimensions
                // (per-domain field semantics preserved -- profile
                // lines carry length + angles; glass lines carry
                // width × height; hardware/accessory lines carry
                // length only).
                Text(
                  _mainLineText(line),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  _secondaryLineText(line),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF5B6B76),
                  ),
                ),
                // Rule provenance survives grouping, exactly as the
                // cut-list dialog.
                for (final description in line.ruleDescriptions)
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF5B6B76),
                    ),
                  ),
                const Divider(height: 1),
              ],
            ),
          ),
      ],
    );
  }

  String _mainLineText(BomLine line) {
    final parts = <String>[
      '${line.reference} — ${line.name} : ${line.quantity} '
          '${line.quantity > 1 ? 'pièces' : 'pièce'}',
    ];
    if (line.lengthMm != null) {
      parts.add('${line.lengthMm!.toStringAsFixed(0)} mm');
    }
    if (line.widthMm != null && line.heightMm != null) {
      parts.add(
        '${line.widthMm!.toStringAsFixed(0)} × '
        '${line.heightMm!.toStringAsFixed(0)} mm',
      );
    }
    if (line.angleStart != null && line.angleEnd != null) {
      parts.add(
        '(${line.angleStart!.toStringAsFixed(0)}° / '
        '${line.angleEnd!.toStringAsFixed(0)}°)',
      );
    }
    return parts.join(' — ');
  }

  String _secondaryLineText(BomLine line) {
    final parts = <String>[];
    if (line.lengthMm != null) {
      final total = line.lengthMm! * line.quantity;
      parts.add(
        '${(total / 1000).toStringAsFixed(2)} m',
      );
    }
    if (line.widthMm != null && line.heightMm != null) {
      final area = line.widthMm! * line.heightMm! * line.quantity / 1e6;
      parts.add('${area.toStringAsFixed(2)} m²');
    }
    return parts.isEmpty ? '' : parts.join(' — ');
  }
}
