/// RFC 4180-style CSV field encoder.
///
/// Quoting rules (per RFC 4180 §2):
/// - A field containing a comma, double-quote, CR, or LF MUST be
///   wrapped in double-quotes.
/// - A double-quote inside a quoted field is escaped by doubling it
///   (`"` → `""`).
/// - A field that contains none of those four characters is left
///   unquoted (Excel / LibreOffice both accept this).
///
/// Note: a field consisting only of whitespace, only of `0`, or only
/// of `null` IS emitted as the empty string `""` for null / unknown
/// markers (e.g. `weightKg == null` → empty cell). The renderer for
/// the cell decides whether to emit a value or fall through to empty;
/// this encoder is purely about the escaping, not about the semantics
/// of "no data". That separation is what lets a workshop see
/// `weight_kg,` (empty cell) for an unknown weight -- exactly the
/// same surface the in-app dialog shows.
class CsvField {
  /// Encodes [value] as a single CSV field. Null becomes the empty
  /// string (no quotes, no value -- a workshop importing the file
  /// sees an empty cell).
  static String encode(String? value) {
    if (value == null || value.isEmpty) return '';
    final needsQuoting =
        value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuoting) return value;
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}

/// Joins [fields] with `,` and emits a single line WITHOUT a trailing
/// newline. The caller is responsible for adding `\n` after each row
/// (the renderer does this so the trailing-line convention is
/// explicit at every call site).
String csvRow(List<String?> fields) =>
    fields.map(CsvField.encode).join(',');
