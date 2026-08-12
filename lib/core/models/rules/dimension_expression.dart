/// A small, strongly-typed expression tree used to describe how a cut
/// length is derived from a construction's dimensions.
///
/// This intentionally avoids a generic "formula string + eval()" approach
/// and avoids `Map<String, dynamic>` bags, per project constraints. Instead
/// every node is a real Dart type, and evaluation is a simple recursive
/// switch. This is enough to express things like:
///
///   height - 2 * deduction
///   width / 2 - jointGap
///
/// without needing a full expression parser.
library;

/// The named inputs a [DimensionExpression] can reference. This is the
/// closed set of variables the calculation engine currently exposes from a
/// `Construction` + the opening being processed. Extend this enum as new
/// inputs become available (e.g. glassThickness) rather than reaching for
/// a dynamic map.
enum DimensionVariable {
  /// Overall construction width (mm).
  constructionWidth,

  /// Overall construction height (mm).
  constructionHeight,

  /// Width of the opening currently being processed (mm).
  openingWidth,

  /// Height of the opening currently being processed (mm).
  openingHeight,
}

/// Base type for all expression nodes.
///
/// Deliberately a sealed-style class hierarchy (via private constructor +
/// factory-only subclasses) so `evaluate` can exhaustively switch on the
/// runtime type without needing a discriminant field.
abstract class DimensionExpression {
  const DimensionExpression();

  /// Evaluate this expression against a set of resolved variable values.
  double evaluate(Map<DimensionVariable, double> variables);

  /// Convenience constructor for a fixed numeric value, e.g. a manufacturer
  /// deduction in millimetres.
  const factory DimensionExpression.constant(double value) = ConstantExpression;

  /// Convenience constructor referencing one of the known
  /// [DimensionVariable]s.
  const factory DimensionExpression.variable(DimensionVariable variable) =
      VariableExpression;
}

/// A fixed numeric literal, e.g. a 45mm deduction.
class ConstantExpression extends DimensionExpression {
  final double value;

  const ConstantExpression(this.value);

  @override
  double evaluate(Map<DimensionVariable, double> variables) => value;

  @override
  String toString() => value.toString();
}

/// A reference to a named construction/opening dimension.
class VariableExpression extends DimensionExpression {
  final DimensionVariable variable;

  const VariableExpression(this.variable);

  @override
  double evaluate(Map<DimensionVariable, double> variables) {
    final value = variables[variable];
    if (value == null) {
      throw StateError(
        'Missing value for $variable while evaluating a DimensionExpression. '
        'Ensure the calculation context provides it.',
      );
    }
    return value;
  }

  @override
  String toString() => variable.toString();
}

/// Arithmetic operators supported between two sub-expressions.
enum BinaryOperator { add, subtract, multiply, divide }

/// A binary arithmetic operation between two expressions, e.g.
/// `height - deduction` or `count * spacing`.
class BinaryExpression extends DimensionExpression {
  final DimensionExpression left;
  final BinaryOperator operator;
  final DimensionExpression right;

  const BinaryExpression({
    required this.left,
    required this.operator,
    required this.right,
  });

  @override
  double evaluate(Map<DimensionVariable, double> variables) {
    final l = left.evaluate(variables);
    final r = right.evaluate(variables);
    switch (operator) {
      case BinaryOperator.add:
        return l + r;
      case BinaryOperator.subtract:
        return l - r;
      case BinaryOperator.multiply:
        return l * r;
      case BinaryOperator.divide:
        if (r == 0) {
          throw StateError('Division by zero in DimensionExpression.');
        }
        return l / r;
    }
  }

  @override
  String toString() => '($left ${_symbolFor(operator)} $right)';

  static String _symbolFor(BinaryOperator op) {
    switch (op) {
      case BinaryOperator.add:
        return '+';
      case BinaryOperator.subtract:
        return '-';
      case BinaryOperator.multiply:
        return '*';
      case BinaryOperator.divide:
        return '/';
    }
  }
}
