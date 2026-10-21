/// Data-only conditions: comparison nodes over formulas (P4 extension for the
/// stat-gated broadcast, approved by R; 11 §Messaging).
///
/// A condition compares two formulas, for example "WIL below 3":
///
/// ```json
/// {"type": "compare", "op": "lt",
///  "left": {"type": "attr", "key": "WIL"},
///  "right": {"type": "const", "value": 3}}
/// ```
///
/// `op` is one of `lt le eq ne ge gt`. Both sides are formulas: no dice and
/// no `var`. Only `compare` exists; combining conditions (and, or, not) is
/// not approved and would go to R first.
library;

import 'evaluate.dart';
import 'expr.dart';
import 'expr_json.dart';

/// A yes-or-no test on an entity's values.
sealed class Condition {
  const Condition();

  /// The attribute keys the condition reads.
  Set<String> get attributeKeys;
}

/// How [Compare] compares its sides.
enum CompareOp {
  /// Left is less than right.
  lt('<'),

  /// Left is at most right.
  le('≤'),

  /// Left equals right.
  eq('='),

  /// Left differs from right.
  ne('≠'),

  /// Left is at least right.
  ge('≥'),

  /// Left is greater than right.
  gt('>');

  const CompareOp(this.symbol);

  /// The symbol shown to the GM.
  final String symbol;

  /// Whether [left] and [right] pass this comparison.
  bool test(num left, num right) => switch (this) {
    lt => left < right,
    le => left <= right,
    eq => left == right,
    ne => left != right,
    ge => left >= right,
    gt => left > right,
  };
}

/// Compares two formulas.
final class Compare extends Condition {
  /// Creates a comparison. Throws an [ArgumentError] when either side rolls
  /// dice or reads a `var` value.
  Compare(this.op, this.left, this.right) {
    for (final (name, side) in [('left', left), ('right', right)]) {
      if (side.rollsDice || side.varKeys.isNotEmpty) {
        throw ArgumentError.value(
          side,
          name,
          'must be a formula with no dice and no var',
        );
      }
    }
  }

  /// The comparison.
  final CompareOp op;

  /// Left side.
  final Expr left;

  /// Right side.
  final Expr right;

  @override
  Set<String> get attributeKeys => {
    ...left.attributeKeys,
    ...right.attributeKeys,
  };

  @override
  bool operator ==(Object other) =>
      other is Compare &&
      other.op == op &&
      other.left == left &&
      other.right == right;

  @override
  int get hashCode => Object.hash(Compare, op, left, right);

  @override
  String toString() => 'Compare($left ${op.symbol} $right)';
}

/// The outcome of a condition for one entity, with the values compared.
final class ConditionResult {
  /// Creates a result.
  const ConditionResult({
    required this.passed,
    required this.left,
    required this.right,
  });

  /// Whether the condition held.
  final bool passed;

  /// The left side's value.
  final num left;

  /// The right side's value.
  final num right;

  @override
  bool operator ==(Object other) =>
      other is ConditionResult &&
      other.passed == passed &&
      other.left == left &&
      other.right == right;

  @override
  int get hashCode => Object.hash(passed, left, right);

  @override
  String toString() => 'ConditionResult($passed: $left vs $right)';
}

/// Evaluates [condition] over [attributes].
///
/// Throws an [EvaluationException] when a needed score is missing.
ConditionResult evaluateCondition(
  Condition condition, {
  Map<String, num> attributes = const {},
}) {
  switch (condition) {
    case Compare(:final op, :final left, :final right):
      final l = evaluateFormula(left, attributes: attributes);
      final r = evaluateFormula(right, attributes: attributes);
      return ConditionResult(passed: op.test(l, r), left: l, right: r);
  }
}

/// Decodes a condition from its JSON form. Throws a [FormatException]
/// describing the first problem, with [path] in the message.
Condition decodeCondition(Object? json, {String path = r'$'}) {
  if (json is! Map<String, Object?>) {
    throw FormatException('$path: expected a condition object.');
  }
  final type = json['type'];
  if (type != 'compare') {
    throw FormatException('$path: unknown condition type "$type".');
  }
  for (final key in json.keys) {
    if (!const {'type', 'op', 'left', 'right'}.contains(key)) {
      throw FormatException('$path: unknown key "$key".');
    }
  }
  final name = json['op'];
  final op = CompareOp.values.where((o) => o.name == name).firstOrNull;
  if (op == null) {
    final names = CompareOp.values.map((o) => o.name).join(', ');
    throw FormatException('$path.op: unknown comparison "$name" ($names).');
  }
  final left = decodeExpr(json['left'], path: '$path.left');
  final right = decodeExpr(json['right'], path: '$path.right');
  try {
    return Compare(op, left, right);
  } on ArgumentError catch (e) {
    throw FormatException('$path.${e.name}: ${e.message}');
  }
}

/// Encodes [condition] in the JSON form [decodeCondition] reads.
Map<String, Object?> encodeCondition(Condition condition) =>
    switch (condition) {
      Compare(:final op, :final left, :final right) => {
        'type': 'compare',
        'op': op.name,
        'left': encodeExpr(left),
        'right': encodeExpr(right),
      },
    };
