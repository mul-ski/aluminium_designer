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
///
/// [Construction.width]/[Construction.height] are nullable to honestly
/// represent a construction the user hasn't finished dimensioning yet (see
/// [constructionGeometryStatus] for why that's a distinct, non-error
/// state). This function is deliberately *not* the place that reports
/// "incomplete" -- if either overall dimension is still unset, or there
/// are no sections yet, there is nothing to check for consistency, so it
/// returns no problems rather than guessing. Callers that need to
/// distinguish "nothing to check yet" from "checked and fine" should use
/// [constructionGeometryStatus] instead of calling this directly.
List<String> validateSectionGeometry(Construction construction) {
  if (construction.type == ConstructionType.curtainWall) {
    return const [];
  }

  final problems = <String>[];
  final sections = construction.sections;
  final width = construction.width;
  final height = construction.height;

  if (sections.isEmpty) {
    return problems;
  }
  if (width == null || height == null) {
    return problems;
  }

  switch (construction.layoutDirection) {
    case SectionLayoutDirection.horizontal:
      final widthSum = sections.fold<double>(
        0,
        (sum, section) => sum + section.width,
      );
      if ((widthSum - width).abs() > sectionGeometryTolerance) {
        problems.add(
          'La somme des largeurs des sections ($widthSum mm) ne '
          'correspond pas à la largeur totale ($width mm).',
        );
      }
      for (final section in sections) {
        if ((section.height - height).abs() > sectionGeometryTolerance) {
          problems.add(
            'La section ${section.order + 1} a une hauteur '
            '(${section.height} mm) différente de la hauteur totale '
            '($height mm).',
          );
        }
      }
      break;

    case SectionLayoutDirection.vertical:
      final heightSum = sections.fold<double>(
        0,
        (sum, section) => sum + section.height,
      );
      if ((heightSum - height).abs() > sectionGeometryTolerance) {
        problems.add(
          'La somme des hauteurs des sections ($heightSum mm) ne '
          'correspond pas à la hauteur totale ($height mm).',
        );
      }
      for (final section in sections) {
        if ((section.width - width).abs() > sectionGeometryTolerance) {
          problems.add(
            'La section ${section.order + 1} a une largeur '
            '(${section.width} mm) différente de la largeur totale '
            '($width mm).',
          );
        }
      }
      break;
  }

  return problems;
}

/// The three states a [Construction]'s geometry can be in, distinguishing
/// "not finished being built yet" from "actually wrong".
///
/// This split exists because the construction editor must let a user build
/// a construction step by step -- entering a type and name, then
/// dimensions, then sections, in whatever order they like -- without every
/// intermediate state being flagged as an error. [incomplete] is the
/// normal, expected state while editing; [invalid] means there is enough
/// data to check consistency and it doesn't add up; [valid] means it
/// checks out. A UI should never block on [incomplete] the way it might
/// warn on [invalid].
enum GeometryStatus { incomplete, invalid, valid }

/// Combines "has enough data to check" with [validateSectionGeometry]'s
/// consistency check into one tri-state result.
///
/// Curtain walls are always [valid] here, matching
/// [validateSectionGeometry]'s deliberate no-op for that construction type
/// (see its doc comment) -- there is no 1D geometry check to be
/// "incomplete" about until a 2D grid model exists.
GeometryStatus constructionGeometryStatus(Construction construction) {
  if (construction.type == ConstructionType.curtainWall) {
    return GeometryStatus.valid;
  }

  if (construction.width == null ||
      construction.height == null ||
      construction.sections.isEmpty) {
    return GeometryStatus.incomplete;
  }

  final problems = validateSectionGeometry(construction);
  return problems.isEmpty ? GeometryStatus.valid : GeometryStatus.invalid;
}
