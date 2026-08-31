/// Production-document export for AluVis: CSV cut list + CSV BOM
/// derived from a [CalculationOutcome] + the construction that
/// produced it.
///
/// The exporter is the only place that knows how to assemble a
/// human-readable production document out of the calculation
/// envelope. It reuses every existing aggregation function
/// (`buildCutListLines`, `sumCutListLines`, `buildBom`,
/// `summarizeBom`, `sectionLabelForCutGroup`) -- no parallel
/// aggregation, no re-derived engineering numbers. The CSV escaping
/// is RFC 4180; the metadata block uses `#`-prefixed comment lines
/// (a deliberate, non-RFC convention -- RFC 4180 only standardises
/// the row format, not comments -- documented in [CsvField]).
library;

export 'bom_csv_renderer.dart';
export 'csv_field.dart';
export 'cuts_csv_renderer.dart';
export 'production_exporter.dart';
export 'production_header.dart';
