import '../logic/component_aggregation.dart';
import '../logic/cut_grouping.dart';
import '../models/calculation_outcome.dart';
import '../models/section.dart';
import 'csv_field.dart';
import 'production_header.dart';

/// Renders the unified bill of materials (BOM) for one
/// [CalculationOutcome] to a CSV string. Pure derivation over the same
/// data the on-screen `BOM — nomenclature` dialog consumes: profile
/// cuts, glass panes, and hardware items aggregated via [buildBom]
/// into a flat list of [BomLine] rows grouped by [BomDomain].
///
/// Every value rendered here is data already on a [BomLine] (a pure
/// aggregation of [ProfileCut] / [GlassItem] / [HardwareItem] data
/// the calculator produced) -- no engineering number is invented at
/// render time.
///
/// The four domains (`profile`, `glass`, `hardware`, `accessory`) are
/// emitted in source-declaration order (the same order the
/// aggregation layer produces and the on-screen dialog renders), so
/// the file is stable across runs: the same `CalculationOutcome`
/// produces the same bytes. A workshop that imports the file into a
/// spreadsheet gets a stable row order and can sort by the `domain`
/// column without losing information.
class BomCsvRenderer {
  /// [header] supplies the project / construction / dimensions / stale
  /// metadata block. The renderer's output begins with that block.
  final ProductionHeader header;

  /// Sections used to resolve diagnostic rows to the human-readable
  /// `Section N` labels via [sectionLabelForCutGroup] -- the same
  /// convention the on-screen BOM dialog and the cut list use. Kept
  /// (unlike other redundant inputs) because the renderer genuinely
  /// reads it below.
  final List<Section> sections;

  /// The last calculation run. All three domain lists
  /// ([CalculationOutcome.cuts], [CalculationOutcome.glass],
  /// [CalculationOutcome.hardware]) and both per-section issue
  /// lists ([CalculationOutcome.glassIssues],
  /// [CalculationOutcome.hardwareIssues]) are read.
  final CalculationOutcome outcome;

  const BomCsvRenderer({
    required this.header,
    required this.sections,
    required this.outcome,
  });

  static const _header = <String>[
    'domain',
    'reference',
    'name',
    'quantity',
    'length_mm',
    'width_mm',
    'height_mm',
    'angle_start_deg',
    'angle_end_deg',
    'provenance',
  ];

  String render() {
    final lines = buildBom(
      profileCuts: outcome.cuts,
      glass: outcome.glass,
      hardware: outcome.hardware,
    );
    final summary = summarizeBom(lines);

    final buf = StringBuffer();
    buf.write(header.render());

    // The header row is a single CSV line: column names joined by `,`.
    // See [CutsCsvRenderer.render] for the rationale.
    buf.write(csvRow(_header));
    buf.write('\n');

    if (lines.isEmpty) {
      buf.write('# (no BOM lines)\n');
    } else {
      for (final line in lines) {
        buf.write(
          csvRow([
            line.domain.name,
            line.reference,
            line.name,
            line.quantity.toString(),
            line.lengthMm?.toStringAsFixed(0),
            line.widthMm?.toStringAsFixed(0),
            line.heightMm?.toStringAsFixed(0),
            line.angleStart?.toStringAsFixed(0),
            line.angleEnd?.toStringAsFixed(0),
            line.ruleDescriptions.isEmpty
                ? null
                : line.ruleDescriptions.join(' | '),
          ]),
        );
        buf.write('\n');
      }
    }

    // Blank line + summary. The summary row carries the
    // construction-wide pieces / hardware length on the cells that map
    // to those quantities; the rest of the row is empty so a
    // downstream reader sees a single consistent "totals" row. The
    // hardware length stays in millimetres (same unit as the data
    // rows' length_mm cells) so the column remains summable.
    buf.write('\n');
    buf.write('# Summary\n');
    buf.write(csvRow([
      null,
      null,
      null,
      summary.totalPieces.toString(),
      summary.hardwareTotalLengthMm == 0
          ? null
          : summary.hardwareTotalLengthMm.toStringAsFixed(0),
      null,
      null,
      null,
      null,
      // Glass area is surfaced only via the '# Glass area:' line
      // below, never in a data cell.
      null,
    ]));
    buf.write('\n');
    // The glass-area summary is added as a labelled `#` line so a
    // workshop reading the file does not have to interpret the
    // `width_mm` cell above.
    buf.write('# Glass area: ${summary.glassAreaM2.toStringAsFixed(2)} m²\n');

    if (outcome.glassIssues.isNotEmpty || outcome.hardwareIssues.isNotEmpty) {
      buf.write('\n');
      buf.write('# Diagnostics\n');
      if (outcome.glassIssues.isNotEmpty) {
        buf.write('# Sections sans vitrage\n');
        for (final issue in outcome.glassIssues) {
          buf.write(
            '# ${sectionLabelForCutGroup(issue.sectionId, sections)} — '
            '${_labelForGlassReason(issue.reason)}\n',
          );
        }
      }
      if (outcome.hardwareIssues.isNotEmpty) {
        buf.write('# Sections sans quincaillerie\n');
        for (final issue in outcome.hardwareIssues) {
          buf.write(
            '# ${sectionLabelForCutGroup(issue.sectionId, sections)} — '
            '${_labelForHardwareReason(issue.reason)}\n',
          );
        }
      }
    }

    return buf.toString();
  }

  // Same wording as the on-screen `BOMDialog`. Single source of
  // truth: when the user changes the label there, the export follows.
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
