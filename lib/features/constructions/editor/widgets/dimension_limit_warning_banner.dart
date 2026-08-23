import 'package:flutter/material.dart';

import '../../../../core/logic/dimension_limit_check.dart';

/// Advisory notice shown under the construction width/height fields when
/// [checkDimensionLimits] reports that the dimensions exceed every
/// dimension envelope documented for the selected system's fiche.
///
/// Visual language matches [CalculationResultsBanner]'s notice rows:
/// same flat container tone, icon + Expanded text, warning-amber for
/// advisory content -- this is a "you are leaving the documented range"
/// hint, not an error; nothing blocks editing or calculation.
class DimensionLimitWarningBanner extends StatelessWidget {
  final List<DimensionLimitExceeded> exceeded;

  const DimensionLimitWarningBanner({super.key, required this.exceeded});

  @override
  Widget build(BuildContext context) {
    if (exceeded.isEmpty) return const SizedBox.shrink();

    final envelopeLabels = exceeded
        .map(
          (e) =>
              '${_format(e.limit.maxWidthMm)} × '
              '${_format(e.limit.maxHeightMm)} mm',
        )
        .join(' ; ');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      color: const Color(0xFFF3F5F6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_outlined, size: 16, color: Color(0xFF8A6D00)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Dimensions hors limites vérifiées du système : aucun '
              'enveloppe documentée (max $envelopeLabels) n\'est '
              'respectée. À vérifier auprès du fabricant.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF8A6D00)),
            ),
          ),
        ],
      ),
    );
  }

  static String _format(double value) =>
      value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(2);
}
