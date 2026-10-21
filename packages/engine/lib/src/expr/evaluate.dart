/// Evaluation of [Expr] trees into a value plus a full breakdown.
library;

import 'dart:math' as math;

import '../equality.dart';
import '../rng.dart';
import 'expr.dart';

/// Thrown when an expression cannot be evaluated with the values supplied:
/// a missing attribute or `var`, dice without an RNG, or division by zero.
///
/// Pack validation is meant to catch these before play; `decide` turns one
/// that slips through into a rejection.
final class EvaluationException implements Exception {
  /// Creates an exception with a readable [message].
  const EvaluationException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => 'EvaluationException: $message';
}

/// Evaluates [expr] and returns its breakdown, whose [Term.value] is the
/// result.
///
/// [attributes] supplies [Attr] nodes, [vars] supplies [Var] nodes and [rng]
/// rolls [Dice] nodes. Nodes are evaluated depth first, left to right, so the
/// same tree draws from the RNG in the same order every time.
///
/// Throws an [EvaluationException] when a needed value is missing.
Term evaluate(
  Expr expr, {
  Map<String, num> attributes = const {},
  Map<String, num> vars = const {},
  Rng? rng,
}) => _Evaluator(attributes, vars, rng).eval(expr);

/// Evaluates a formula (an expression without dice) and returns the number.
///
/// Throws an [EvaluationException] if [formula] rolls dice or a needed value
/// is missing.
num evaluateFormula(
  Expr formula, {
  Map<String, num> attributes = const {},
  Map<String, num> vars = const {},
}) {
  if (formula.rollsDice) {
    throw const EvaluationException('A formula may not roll dice.');
  }
  return evaluate(formula, attributes: attributes, vars: vars).value;
}

/// Returns [value] as an `int` when it is a whole number.
///
/// On the web every number is a double, so `10 / 2` prints as `5` there and
/// as `5.0` on the VM [V-14]. Normalizing whole results keeps breakdowns and
/// their encoded form identical on every platform.
num normalizeNumber(num value) {
  if (value is double &&
      value.isFinite &&
      value == value.truncateToDouble() &&
      value.abs() <= _maxSafeInteger) {
    return value.toInt();
  }
  return value;
}

/// Largest integer a double (and so a web `int`) holds exactly: 2^53 - 1.
const _maxSafeInteger = 9007199254740991;

final class _Evaluator {
  _Evaluator(this.attributes, this.vars, this.rng);

  final Map<String, num> attributes;
  final Map<String, num> vars;
  final Rng? rng;

  Term eval(Expr expr) => switch (expr) {
    Const(:final value) => ConstTerm(normalizeNumber(value)),
    Attr(:final key) => AttrTerm(key, _lookup(attributes, key, 'attribute')),
    Var(:final key) => VarTerm(key, _lookup(vars, key, 'var')),
    Dice() => _rollDice(expr),
    Sum(:final terms) => SumTerm(terms.map(eval).toList()),
    KeepHighest(:final pool, :final keep) => _keepHighest(pool, keep),
    Op(:final op, :final args) => _applyOp(op, args.map(eval).toList()),
  };

  num _lookup(Map<String, num> values, String key, String kind) {
    final value = values[key];
    if (value == null) {
      throw EvaluationException('No value supplied for $kind "$key".');
    }
    return normalizeNumber(value);
  }

  DiceTerm _rollDice(Dice dice) {
    final source = rng;
    if (source == null) {
      throw EvaluationException(
        'Rolling ${dice.count}d${dice.sides} needs an RNG.',
      );
    }
    final rolls = <DieRoll>[];
    for (var i = 0; i < dice.count; i++) {
      final faces = <int>[source.rollDie(dice.sides)];
      while (dice.explodes && faces.last == dice.sides) {
        faces.add(source.rollDie(dice.sides));
      }
      rolls.add(DieRoll(faces));
    }
    return DiceTerm(sides: dice.sides, explode: dice.explode, rolls: rolls);
  }

  KeepHighestTerm _keepHighest(List<Expr> pool, int keep) {
    final options = pool.map(eval).toList();
    // Highest value first; equal values keep pool order, so the earliest
    // option wins a tie and the choice is the same on every client.
    final order = List.generate(options.length, (i) => i)
      ..sort((a, b) {
        final byValue = options[b].value.compareTo(options[a].value);
        return byValue != 0 ? byValue : a.compareTo(b);
      });
    final kept = order.take(keep).toList()..sort();
    return KeepHighestTerm(options: options, kept: kept);
  }

  OpTerm _applyOp(OpKind op, List<Term> args) {
    final values = args.map((t) => t.value).toList();
    final num result = switch (op) {
      OpKind.add => values.reduce((a, b) => a + b),
      OpKind.sub => values[0] - values[1],
      OpKind.mul => values.reduce((a, b) => a * b),
      OpKind.div => _divide(values[0], values[1]),
      OpKind.min => values.reduce(math.min),
      OpKind.max => values.reduce(math.max),
      OpKind.floor => values[0].floor(),
    };
    if (!result.isFinite) {
      throw EvaluationException('${op.name} produced $result.');
    }
    return OpTerm(op, args, normalizeNumber(result));
  }

  num _divide(num a, num b) {
    if (b == 0) throw const EvaluationException('Division by zero.');
    return a / b;
  }
}

/// One node of an evaluated expression: its value and how it was reached.
///
/// Rolling events store these so the UI can show every die without
/// recomputing anything (01 §Commands and events).
sealed class Term {
  const Term();

  /// The node's result.
  num get value;
}

/// Result of a [Const] node.
final class ConstTerm extends Term {
  /// Creates a constant term.
  const ConstTerm(this.value);

  @override
  final num value;

  @override
  bool operator ==(Object other) => other is ConstTerm && other.value == value;

  @override
  int get hashCode => Object.hash(ConstTerm, value);

  @override
  String toString() => 'ConstTerm($value)';
}

/// Result of an [Attr] node: which attribute and its score.
final class AttrTerm extends Term {
  /// Creates an attribute term.
  const AttrTerm(this.key, this.value);

  /// Pack attribute key.
  final String key;

  @override
  final num value;

  @override
  bool operator ==(Object other) =>
      other is AttrTerm && other.key == key && other.value == value;

  @override
  int get hashCode => Object.hash(AttrTerm, key, value);

  @override
  String toString() => 'AttrTerm($key = $value)';
}

/// Result of a [Var] node: which engine value and what it was.
final class VarTerm extends Term {
  /// Creates a `var` term.
  const VarTerm(this.key, this.value);

  /// Name of the engine-supplied value.
  final String key;

  @override
  final num value;

  @override
  bool operator ==(Object other) =>
      other is VarTerm && other.key == key && other.value == value;

  @override
  int get hashCode => Object.hash(VarTerm, key, value);

  @override
  String toString() => 'VarTerm($key = $value)';
}

/// One die as rolled: its first face, then any explosion faces in order.
final class DieRoll {
  /// Creates a roll from its faces. Throws an [ArgumentError] when empty.
  DieRoll(List<int> faces) : faces = List.unmodifiable(faces) {
    if (faces.isEmpty) {
      throw ArgumentError.value(faces, 'faces', 'must not be empty');
    }
  }

  /// Every face rolled for this die, the first one included.
  final List<int> faces;

  /// Whether this die exploded at least once.
  bool get exploded => faces.length > 1;

  /// Sum of [faces].
  int get total => faces.fold(0, (a, b) => a + b);

  @override
  bool operator ==(Object other) =>
      other is DieRoll && listEquals(other.faces, faces);

  @override
  int get hashCode => Object.hashAll(faces);

  @override
  String toString() => 'DieRoll($faces)';
}

/// Result of a [Dice] node: each die with its faces.
final class DiceTerm extends Term {
  /// Creates a dice term.
  DiceTerm({
    required this.sides,
    required this.explode,
    required List<DieRoll> rolls,
  }) : rolls = List.unmodifiable(rolls);

  /// Faces per die.
  final int sides;

  /// The node's explode setting when it was rolled (`null` = not ruled).
  final bool? explode;

  /// One entry per die, in roll order.
  final List<DieRoll> rolls;

  @override
  int get value => rolls.fold(0, (a, r) => a + r.total);

  @override
  bool operator ==(Object other) =>
      other is DiceTerm &&
      other.sides == sides &&
      other.explode == explode &&
      listEquals(other.rolls, rolls);

  @override
  int get hashCode =>
      Object.hash(DiceTerm, sides, explode, Object.hashAll(rolls));

  @override
  String toString() => 'DiceTerm(d$sides: $rolls)';
}

/// Result of a [Sum] node.
final class SumTerm extends Term {
  /// Creates a sum term.
  SumTerm(List<Term> terms) : terms = List.unmodifiable(terms);

  /// Each part, in order.
  final List<Term> terms;

  @override
  num get value => normalizeNumber(terms.fold<num>(0, (a, t) => a + t.value));

  @override
  bool operator ==(Object other) =>
      other is SumTerm && listEquals(other.terms, terms);

  @override
  int get hashCode => Object.hash(SumTerm, Object.hashAll(terms));

  @override
  String toString() => 'SumTerm($terms)';
}

/// Result of a [KeepHighest] node: every option and which ones were kept.
final class KeepHighestTerm extends Term {
  /// Creates a keep-highest term.
  KeepHighestTerm({required List<Term> options, required List<int> kept})
    : options = List.unmodifiable(options),
      kept = List.unmodifiable(kept);

  /// Every option, in pool order.
  final List<Term> options;

  /// Indexes into [options] of the kept results, ascending.
  final List<int> kept;

  @override
  num get value =>
      normalizeNumber(kept.fold<num>(0, (a, i) => a + options[i].value));

  @override
  bool operator ==(Object other) =>
      other is KeepHighestTerm &&
      listEquals(other.options, options) &&
      listEquals(other.kept, kept);

  @override
  int get hashCode => Object.hash(
    KeepHighestTerm,
    Object.hashAll(options),
    Object.hashAll(kept),
  );

  @override
  String toString() => 'KeepHighestTerm($options, kept: $kept)';
}

/// Result of an [Op] node.
final class OpTerm extends Term {
  /// Creates an operator term.
  OpTerm(this.op, List<Term> args, this.value) : args = List.unmodifiable(args);

  /// The operator.
  final OpKind op;

  /// The evaluated operands, in order.
  final List<Term> args;

  @override
  final num value;

  @override
  bool operator ==(Object other) =>
      other is OpTerm &&
      other.op == op &&
      other.value == value &&
      listEquals(other.args, args);

  @override
  int get hashCode => Object.hash(OpTerm, op, value, Object.hashAll(args));

  @override
  String toString() => 'OpTerm(${op.name}, $args = $value)';
}
