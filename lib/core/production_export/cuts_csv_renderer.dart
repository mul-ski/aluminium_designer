import '../logic/cut_aggregation.dart';
import '../logic/cut_grouping.dart';
import '../models/calculation_outcome.dart';
import '../models/section.dart';
import 'csv_field.dart';
import 'production_header.dart';

/// Renders the workshop-facing cut list for one [CalculationOutcome]
/// to a CSV string. Pure derivation over the same data the on-screen
/// `CutListDialog` consumes: identical cuts are merged with summed
/// quantities (via [buildCutListLines]), provenance survives the
/// merge, weights are present only when `weightPerMeter > 0`.
///
/// Every value rendered here is data already on a [CutListLine] (a
/// pure aggregation of [ProfileCut] data the calculator produced) --
/// no engineering number is invented at render time. The `weight_kg`
/// column is the empty string for unknown weight; the `provenance`
/// column carries the rule descriptions verbatim from the calculator
/// output.
///
/// The CSV follows RFC 4180 escaping (via [CsvField.encode]); a
/// provenance string containing a comma, double-quote, or newline is
/// quoted with internal `"` escaped as `""`.
class CutsCsvRenderer {
  /// [header] supplies the project / construction / dimensions / stale
  /// metadata block. The renderer's output begins with that block,
  /// followed by the cut-list rows.
  final ProductionHeader header;

  /// Sections are needed to resolve the `section` column's
  /// human-readable label via [sectionLabelForCutGroup].
  final List<Section> sections;

  /// The last calculation run. Only [CalculationOutcome.cuts] and
  /// [CalculationOutcome.issues] are read; the other domains (glass /
  /// hardware) are not relevant to the cut list.
  final CalculationOutcome outcome;

  const CutsCsvRenderer({
    required this.header,
    required this.sections,
    required this.outcome,
  });

  static const _header = <String>[
    'section',
    'reference',
    'name',
    'length_mm',
    'quantity',
    'angle_start_deg',
    'angle_end_deg',
    'total_length_m',
    'weight_kg',
    'provenance',
  ];

  /// Renders the full CSV document as a single string. Layout:
  /// 1. The metadata block (from [ProductionHeader.render]).
  /// 2. The header row.
  /// 3. One data row per [CutListLine] in first-encounter order
  ///    (the same ordering `buildCutListLines` returns).
  /// 4. A blank line.
  /// 5. A summary row (or rows) with the total pieces / metres.
  /// 6. The diagnostics block, if any.
  String render() {
    final lines = buildCutListLines(outcome.cuts);
    final summary = sumCutListLines(lines);

    final buf = StringBuffer();
    buf.write(header.render());

    // The header row is a single CSV line: column names joined by `,`.
    // Per RFC 4180 a row is one line; splitting the header across lines
    // would be read by a workshop's spreadsheet importer as a column
    // named "section", a row of one cell named "reference", a row of one
    // cell named "name", etc. -- the file would parse, but only the
    // first column would ever line up. One row, one LF.
    buf.write(csvRow(_header));
    buf.write('\n');

    if (lines.isEmpty) {
      buf.write('# (no cuts produced)\n');
    } else {
      for (final line in lines) {
        final sectionLabel = line.contributingSectionIds.isEmpty
            ? ''
            : line.contributingSectionIds
                .map((id) => sectionLabelForCutGroup(id, sections))
                .join(', ');
        buf.write(
          csvRow([
            sectionLabel,
            line.reference,
            line.profileName,
            line.lengthMm.toStringAsFixed(0),
            line.quantity.toString(),
            line.angleStart.toStringAsFixed(0),
            line.angleEnd.toStringAsFixed(0),
            (line.totalLengthMm / 1000).toStringAsFixed(2),
            line.weightKg?.toStringAsFixed(2),
            line.ruleDescriptions.isEmpty
                ? null
                : line.ruleDescriptions.join(' | '),
          ]),
        );
        buf.write('\n');
      }
    }

    // Blank line + summary + diagnostics, separated from the data rows
    // by an empty line so a downstream parser (or a human reading the
    // raw file) sees a clean separation.
    buf.write('\n');
    buf.write('# Summary\n');
    buf.write(csvRow([
      null,
      null,
      null,
      null,
      summary.pieces.toString(),
      null,
      null,
      (summary.totalLengthMm / 1000).toStringAsFixed(2),
      summary.weightKg?.toStringAsFixed(2),
      null,
    ]));
    buf.write('\n');

    if (outcome.issues.isNotEmpty) {
      buf.write('\n');
      buf.write('# Diagnostics\n');
      buf.write('# ${outcome.issues.length} assignation(s) sans coupe\n');
      for (final issue in outcome.issues) {
        buf.write(
          '# ${_issueReasonLabel(issue.reason)} (assignation '
          '${issue.profileUsageId})\n',
        );
      }
    }

    return buf.toString();
  }

  /// Same wording as the on-screen `CutListDialog` and the calculation
  /// results banner. Single source of truth: when the user changes the
  /// reason label there, the export follows.
  static String _issueReasonLabel(ProfileUsageIssueReason reason) {
    switch (reason) {
      case ProfileUsageIssueReason.profileUnresolved:
        return 'profil introuvable dans le système';
      case ProfileUsageIssueReason.noRuleMatched:
        return 'aucune règle de calcul ne correspond';
    }
  }
}
