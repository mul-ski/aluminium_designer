import '../models/calculation_outcome.dart';
import '../models/construction.dart';
import '../models/construction_type.dart';

/// The metadata block prepended to every produced CSV file.
///
/// Pure string assembly: no engineering number is invented here. The
/// only field the exporter introduces is [exportedAt] (a `DateTime`
/// stamped at the moment the user taps Exporter, or a fixed value in
/// tests) -- a fact about the file itself, not about the construction.
///
/// RFC 4180 defines CSV rows and field escaping; it does NOT define a
/// comment convention. The `#`-prefixed block at the top of each file
/// is the exporter's metadata channel -- LibreOffice / awk / Python
/// `csv.reader` (with a `skip_lines` filter) all handle it, but a strict
/// RFC 4180 parser will treat each `#` line as a one-field row. This
/// trade-off is intentional: keeping the metadata inline avoids the
/// "one more file to email" problem of a sidecar, and every consumer
/// the workshop realistically uses tolerates the prefix.
///
/// The block is a single string with a fixed layout so golden tests
/// can assert byte-for-byte equality; line endings are LF (no CR) and
/// the block always ends with a trailing `# ---` separator so a CSV
/// parser that consumes the file from line 1 knows where the metadata
/// ends and the data rows begin.
class ProductionHeader {
  /// `DateTime` stamped at the moment the export was produced. Tests
  /// supply a fixed value so the rendered bytes are deterministic;
  /// production code passes `DateTime.now()`.
  final DateTime exportedAt;

  /// The construction whose calculation is being exported. Used for
  /// the project / manufacturer / system / dimensions / sections lines.
  /// The exporter does not re-derive the engineering data from here --
  /// it pulls cuts, glass, and hardware from [outcome].
  final Construction construction;

  /// The last calculation run. The exporter reads [CalculationOutcome.isStale]
  /// via the [ConstructionEditorController] field that produced this
  /// outcome; the header itself accepts a plain [bool] so the renderer
  /// is decoupled from the editor controller.
  final bool isStale;

  /// The total number of sections in the construction (for the
  /// `Sections: N` line). Held separately from the construction so
  /// the header can be constructed in tests without a full Section
  /// list, and so it stays a one-line summary rather than a structured
  /// breakdown.
  final int sectionCount;

  /// Number of fixed sections in the construction, for the
  /// `N fixe / N ouvrant` sub-summary.
  final int fixedSectionCount;

  /// Number of ouvrant sections in the construction.
  final int ouvrantSectionCount;

  const ProductionHeader({
    required this.exportedAt,
    required this.construction,
    required this.isStale,
    required this.sectionCount,
    required this.fixedSectionCount,
    required this.ouvrantSectionCount,
  });

  /// Renders the block as a single multi-line string with a trailing
  /// `# ---` separator. The trailing separator is followed by LF so
  /// the first data row begins on its own line.
  String render() {
    final c = construction;
    final dims = (c.width == null || c.height == null)
        ? 'non définie'
        : '${_fmt(c.width!.toDouble())} × ${_fmt(c.height!.toDouble())} mm';
    final mfr = c.manufacturerId == null || c.manufacturerId!.isEmpty
        ? c.manufacturer
        : '${c.manufacturer} (id: ${c.manufacturerId})';
    final sys = c.systemId == null || c.systemId!.isEmpty
        ? c.system
        : '${c.system} (id: ${c.systemId})';
    final type = _typeLabel(c.type);
    final sectionSummary = sectionCount == 0
        ? '0'
        : '$sectionCount ($fixedSectionCount fixe, $ouvrantSectionCount ouvrant)';

    final lines = <String>[
      '# AluVis export',
      '# Project: ${_sanitizeForComment(c.name)}',
      '# Construction: ${_sanitizeForComment(c.name)} ($type)',
      '# Manufacturer: ${_sanitizeForComment(mfr)}',
      '# System: ${_sanitizeForComment(sys)}',
      '# Dimensions: $dims',
      '# Sections: $sectionSummary',
      '# Exported at: ${exportedAt.toUtc().toIso8601String()}',
      if (isStale) ...[
        '# Stale: yes',
        '# WARNING: this calculation is obsolete. The construction has '
            'changed since the last Calculer run; re-run Calculer and '
            're-export to refresh the numbers.',
      ] else
        '# Stale: no',
      '# ---',
    ];

    return '${lines.join('\n')}\n';
  }

  /// Slug used in the export filename: lowercased, non-ASCII letters
  /// are stripped, runs of non-alphanumerics collapse to a single `-`,
  /// leading and trailing `-` are removed. An empty slug becomes `untitled`.
  ///
  /// Kept on [ProductionHeader] because the header already owns the
  /// construction reference, and the slug is a property of that
  /// construction as a string (not a property of the calculation or
  /// the BOM).
  String slug() => _slug(construction.name);

  /// First 6 characters of [Construction.id], used as a
  /// collision-resistant suffix in the export filename. Stable
  /// across runs (the construction id is assigned once at creation
  /// and never changes -- see `ProjectStore` and
  /// `ConstructionEditorController`).
  String shortId() => construction.id.length >= 6
      ? construction.id.substring(0, 6)
      : construction.id;

  static String _typeLabel(ConstructionType type) {
    switch (type) {
      case ConstructionType.window:
        return 'Fenêtre';
      case ConstructionType.door:
        return 'Porte';
      case ConstructionType.curtainWall:
        return 'Mur rideau';
    }
  }

  /// Sanitizes a free-form string for the `#`-comment block. Newlines
  /// and carriage returns are collapsed to a space so a multi-line
  /// construction name cannot break the comment-block layout; runs
  /// of whitespace are also collapsed. CR / LF / tab stay readable as
  /// a single space.
  static String _sanitizeForComment(String raw) {
    final collapsed = raw
        .replaceAll('\r\n', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('\t', ' ');
    return collapsed.replaceAll(RegExp(r' {2,}'), ' ').trim();
  }

  /// Slug for the filename: lowercased, diacritics stripped to their
  /// base letter (so `Fênêtre salon` becomes `fenetre-salon`), runs
  /// of non-alphanumerics collapse to a single `-`, leading and
  /// trailing `-` are removed. An all-empty result is replaced with
  /// `untitled` so the filename always has a body.
  ///
  /// The diacritic strip is a small fixed table covering the Latin-1
  /// Supplement (French, German, Spanish, Portuguese -- the workshop
  /// language set we care about). Unicode NFD decomposition alone is
  /// not enough: Dart's `String` exposes precomposed code points like
  /// `ç` (U+00E7) as a single rune, and the combining-mark range
  /// `[\u0300-\u036f]` does not include the cedilla combining mark
  /// (U+0327). The table approach is explicit, deterministic, and
  /// audit-friendly; a future workshop language can extend the table
  /// without touching the rest of the slug logic.
  static String _slug(String raw) {
    final lower = raw.toLowerCase();
    final stripped = StringBuffer();
    for (final rune in lower.runes) {
      stripped.writeCharCode(_stripDiacritic(rune));
    }
    final collapsed = stripped.toString().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '-',
    );
    final trimmed = collapsed.replaceAll(RegExp(r'^-+|-+$'), '');
    return trimmed.isEmpty ? 'untitled' : trimmed;
  }

  /// Maps a Latin-1 letter with a diacritic to its base letter. Any
  /// rune outside the small set returns the original rune, so the
  /// function is a safe identity for everything else.
  static int _stripDiacritic(int rune) {
    switch (rune) {
      // Lowercase Latin-1 with diacritics.
      case 0x00E0: // à
      case 0x00E1: // á
      case 0x00E2: // â
      case 0x00E3: // ã
      case 0x00E4: // ä
      case 0x00E5: // å
        return 0x0061; // a
      case 0x00E7: // ç
        return 0x0063; // c
      case 0x00E8: // è
      case 0x00E9: // é
      case 0x00EA: // ê
      case 0x00EB: // ë
        return 0x0065; // e
      case 0x00EC: // ì
      case 0x00ED: // í
      case 0x00EE: // î
      case 0x00EF: // ï
        return 0x0069; // i
      case 0x00F1: // ñ
        return 0x006E; // n
      case 0x00F2: // ò
      case 0x00F3: // ó
      case 0x00F4: // ô
      case 0x00F5: // õ
      case 0x00F6: // ö
        return 0x006F; // o
      case 0x00F9: // ù
      case 0x00FA: // ú
      case 0x00FB: // û
      case 0x00FC: // ü
        return 0x0075; // u
      case 0x00FD: // ý
      case 0x00FF: // ÿ
        return 0x0079; // y
      // Uppercase variants: the input is already lowered before this
      // function, but we still map them defensively so a stray
      // uppercase rune (from a construction name with embedded
      // characters) doesn't fall through unstripped.
      case 0x00C0:
      case 0x00C1:
      case 0x00C2:
      case 0x00C3:
      case 0x00C4:
      case 0x00C5:
        return 0x0061;
      case 0x00C7:
        return 0x0063;
      case 0x00C8:
      case 0x00C9:
      case 0x00CA:
      case 0x00CB:
        return 0x0065;
      case 0x00CC:
      case 0x00CD:
      case 0x00CE:
      case 0x00CF:
        return 0x0069;
      case 0x00D1:
        return 0x006E;
      case 0x00D2:
      case 0x00D3:
      case 0x00D4:
      case 0x00D5:
      case 0x00D6:
        return 0x006F;
      case 0x00D9:
      case 0x00DA:
      case 0x00DB:
      case 0x00DC:
        return 0x0075;
      case 0x00DD:
      case 0x0178:
        return 0x0079;
      default:
        return rune;
    }
  }

  /// Integer-like formatting: the construction's width / height are
  /// always rendered as whole mm to match the workshop's expectations
  /// (a `2 000 mm` written as `2000.0` would be a tiny but
  /// workshop-visible annoyance in a printed CSV).
  static String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toString();
  }
}
