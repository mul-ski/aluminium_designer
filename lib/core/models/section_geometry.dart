import 'construction.dart';
import 'construction_type.dart';
import 'layout_direction.dart';

/// Tolerance for floating-point dimension comparisons (mm). User-entered
/// values summed across sections will rarely equal the construction's
/// overall dimension exactly, so equality checks below use this instead of
/// `==`.
const double sectionGeometryTolerance = 0.01;

/// Validates that [construction]'s sections geometrically fit its overall
/// width/height, given its [Construction.layoutDirection].
///
/// This only applies to linear (1D) layouts -- window and door
/// constructions, whose sections are assumed to sit in a single ordered
/// row or column. Curtain walls are deliberately excluded: they will
/// eventually need a proper 2D grid/mullion/transom model that
/// `List<Section>` + a single `layoutDirection` cannot represent, so
/// applying this linear check to a curtain wall would either reject valid
/// grid layouts or silently pass on the wrong basis. Curtain wall geometry
/// is left unvalidated until that model exists, rather than validated
/// incorrectly now.
///
/// Rules for window/door:
/// - `horizontal`: section widths must sum to `construction.width`; every
///   section's height must equal `construction.height`.
/// - `vertical`: section heights must sum to `construction.height`; every
///   section's width must equal `construction.width`.
/// - A single section must match the construction's full width and height
///   regardless of direction (the sum-of-one-section case of the same
///   rule).
///
/// Returns an empty list if valid, otherwise a list of human-readable
/// problem descriptions. Does not throw -- callers (e.g. a UI form) decide
/// how to surface problems.
List<String> validateSectionGeometry(Construction construction) {
  if (construction.type == ConstructionType.curtainWall) {
    return const [];
  }

  final problems = <String>[];
  final sections = construction.sections;

  if (sections.isEmpty) {
    problems.add('La construction ne contient aucune section.');
    return problems;
  }

  switch (construction.layoutDirection) {
    case SectionLayoutDirection.horizontal:
      final widthSum = sections.fold<double>(
        0,
        (sum, section) => sum + section.width,
      );
      if ((widthSum - construction.width).abs() > sectionGeometryTolerance) {
        problems.add(
          'La somme des largeurs des sections ($widthSum mm) ne '
          'correspond pas à la largeur totale (${construction.width} mm).',
        );
      }
      for (final section in sections) {
        if ((section.height - construction.height).abs() >
            sectionGeometryTolerance) {
          problems.add(
            'La section ${section.order + 1} a une hauteur '
            '(${section.height} mm) différente de la hauteur totale '
            '(${construction.height} mm).',
          );
        }
      }
      break;

    case SectionLayoutDirection.vertical:
      final heightSum = sections.fold<double>(
        0,
        (sum, section) => sum + section.height,
      );
      if ((heightSum - construction.height).abs() > sectionGeometryTolerance) {
        problems.add(
          'La somme des hauteurs des sections ($heightSum mm) ne '
          'correspond pas à la hauteur totale (${construction.height} mm).',
        );
      }
      for (final section in sections) {
        if ((section.width - construction.width).abs() >
            sectionGeometryTolerance) {
          problems.add(
            'La section ${section.order + 1} a une largeur '
            '(${section.width} mm) différente de la largeur totale '
            '(${construction.width} mm).',
          );
        }
      }
      break;
  }

  return problems;
}
