/// Data-only dice expressions and formulas (01 §Dice and checks, P4).
///
/// Packs write these as JSON trees; there is no scripting and no `eval`. A
/// *formula* is an expression with no [Dice] in it, so it evaluates without an
/// RNG. A *dice expression* may roll.
///
/// Constructors check their own invariants, so an invalid tree cannot exist.
library;

import '../equality.dart';

/// One node of an expression tree.
sealed class Expr {
  const Expr();

  /// Whether evaluating this tree rolls dice (and therefore needs an RNG).
  bool get rollsDice;

  /// The `var` keys this tree reads.
  Set<String> get varKeys;

  /// The attribute keys this tree reads.
  Set<String> get attributeKeys;
}

/// A fixed number.
final class Const extends Expr {
  /// Creates a constant node.
  const Const(this.value);

  /// The number.
  final num value;

  @override
  bool get rollsDice => false;

  @override
  Set<String> get varKeys => const {};

  @override
  Set<String> get attributeKeys => const {};

  @override
  bool operator ==(Object other) => other is Const && other.value == value;

  @override
  int get hashCode => Object.hash(Const, value);

  @override
  String toString() => 'Const($value)';
}

/// The score of a pack-declared attribute (`STR`, `LCK`, ...) on the entity
/// being evaluated.
final class Attr extends Expr {
  /// Creates an attribute reference.
  const Attr(this.key);

  /// Pack attribute key.
  final String key;

  @override
  bool get rollsDice => false;

  @override
  Set<String> get varKeys => const {};

  @override
  Set<String> get attributeKeys => {key};

  @override
  bool operator ==(Object other) => other is Attr && other.key == key;

  @override
  int get hashCode => Object.hash(Attr, key);

  @override
  String toString() => 'Attr($key)';
}

/// A named number the engine supplies at evaluation time (`var` node,
/// approved by R 2026-10-20).
///
/// Only the keys in `VarKeys` exist, each in one approved placement. Any new
/// key or placement goes to R first.
final class Var extends Expr {
  /// Creates a `var` node.
  const Var(this.key);

  /// Name of the engine-supplied value.
  final String key;

  @override
  bool get rollsDice => false;

  @override
  Set<String> get varKeys => {key};

  @override
  Set<String> get attributeKeys => const {};

  @override
  bool operator ==(Object other) => other is Var && other.key == key;

  @override
  int get hashCode => Object.hash(Var, key);

  @override
  String toString() => 'Var($key)';
}

/// [count] dice with [sides] faces each, summed.
///
/// When [explode] is `true`, a die that shows its maximum face is rolled
/// again and added, and that chains (rulebook §2). `null` means the pack's
/// author has not ruled (gap G3 in the provisional pack); it rolls like
/// `false` until a value is given.
final class Dice extends Expr {
  /// Creates a dice node.
  ///
  /// Throws an [ArgumentError] unless [count] and [sides] are at least 1, and
  /// [sides] is at least 2 when [explode] is `true` (a 1-sided exploding die
  /// would never stop).
  Dice({required this.count, required this.sides, this.explode}) {
    if (count < 1) {
      throw ArgumentError.value(count, 'count', 'must be at least 1');
    }
    if (sides < 1) {
      throw ArgumentError.value(sides, 'sides', 'must be at least 1');
    }
    if (explode == true && sides < 2) {
      throw ArgumentError.value(
        sides,
        'sides',
        'an exploding die needs at least 2 sides',
      );
    }
  }

  /// Number of dice.
  final int count;

  /// Faces per die.
  final int sides;

  /// Whether a maximum face rolls again; `null` = not ruled.
  final bool? explode;

  /// Whether dice actually explode when rolled (`explode == true`).
  bool get explodes => explode == true;

  @override
  bool get rollsDice => true;

  @override
  Set<String> get varKeys => const {};

  @override
  Set<String> get attributeKeys => const {};

  @override
  bool operator ==(Object other) =>
      other is Dice &&
      other.count == count &&
      other.sides == sides &&
      other.explode == explode;

  @override
  int get hashCode => Object.hash(Dice, count, sides, explode);

  @override
  String toString() => 'Dice(${count}d$sides, explode: $explode)';
}

/// The sum of [terms], kept term by term in the breakdown.
final class Sum extends Expr {
  /// Creates a sum. Throws an [ArgumentError] when [terms] is empty.
  Sum(List<Expr> terms) : terms = List.unmodifiable(terms) {
    if (terms.isEmpty) {
      throw ArgumentError.value(terms, 'terms', 'must not be empty');
    }
  }

  /// The parts added together.
  final List<Expr> terms;

  @override
  bool get rollsDice => terms.any((t) => t.rollsDice);

  @override
  Set<String> get varKeys => {for (final t in terms) ...t.varKeys};

  @override
  Set<String> get attributeKeys => {for (final t in terms) ...t.attributeKeys};

  @override
  bool operator ==(Object other) =>
      other is Sum && listEquals(other.terms, terms);

  @override
  int get hashCode => Object.hash(Sum, Object.hashAll(terms));

  @override
  String toString() => 'Sum($terms)';
}

/// Evaluates every option in [pool] and adds up the [keep] highest.
///
/// Proposed vocabulary for Luck advantage ("roll extra primary dice, keep the
/// best total", rulebook §2). What grants advantage is gap G2, pending D.
final class KeepHighest extends Expr {
  /// Creates a keep-highest node.
  ///
  /// Throws an [ArgumentError] unless `1 <= keep <= pool.length`.
  KeepHighest(List<Expr> pool, this.keep) : pool = List.unmodifiable(pool) {
    if (keep < 1 || keep > pool.length) {
      throw ArgumentError.value(
        keep,
        'keep',
        'must be between 1 and the pool size (${pool.length})',
      );
    }
  }

  /// The options, each evaluated once.
  final List<Expr> pool;

  /// How many of the highest results are added together.
  final int keep;

  @override
  bool get rollsDice => pool.any((t) => t.rollsDice);

  @override
  Set<String> get varKeys => {for (final t in pool) ...t.varKeys};

  @override
  Set<String> get attributeKeys => {for (final t in pool) ...t.attributeKeys};

  @override
  bool operator ==(Object other) =>
      other is KeepHighest &&
      other.keep == keep &&
      listEquals(other.pool, pool);

  @override
  int get hashCode => Object.hash(KeepHighest, keep, Object.hashAll(pool));

  @override
  String toString() => 'KeepHighest($pool, keep: $keep)';
}

/// Arithmetic operators allowed in formulas: `+ − × ÷ min max floor`.
enum OpKind {
  /// Sum of one or more arguments.
  add(minArgs: 1),

  /// First argument minus the second.
  sub(minArgs: 2, maxArgs: 2),

  /// Product of one or more arguments.
  mul(minArgs: 1),

  /// First argument divided by the second (not rounded; wrap in [floor]).
  div(minArgs: 2, maxArgs: 2),

  /// Smallest of one or more arguments.
  min(minArgs: 1),

  /// Largest of one or more arguments.
  max(minArgs: 1),

  /// Its single argument rounded down.
  floor(minArgs: 1, maxArgs: 1);

  const OpKind({required this.minArgs, this.maxArgs});

  /// Fewest arguments the operator accepts.
  final int minArgs;

  /// Most arguments the operator accepts; `null` means no limit.
  final int? maxArgs;
}

/// An arithmetic operator applied to [args].
final class Op extends Expr {
  /// Creates an operator node.
  ///
  /// Throws an [ArgumentError] when the number of [args] does not fit [op].
  Op(this.op, List<Expr> args) : args = List.unmodifiable(args) {
    final max = op.maxArgs;
    if (args.length < op.minArgs || (max != null && args.length > max)) {
      final expected = max == null
          ? 'at least ${op.minArgs}'
          : max == op.minArgs
          ? 'exactly $max'
          : '${op.minArgs} to $max';
      throw ArgumentError.value(
        args.length,
        'args',
        '${op.name} takes $expected argument(s)',
      );
    }
  }

  /// The operator.
  final OpKind op;

  /// The operands, in order.
  final List<Expr> args;

  @override
  bool get rollsDice => args.any((t) => t.rollsDice);

  @override
  Set<String> get varKeys => {for (final t in args) ...t.varKeys};

  @override
  Set<String> get attributeKeys => {for (final t in args) ...t.attributeKeys};

  @override
  bool operator ==(Object other) =>
      other is Op && other.op == op && listEquals(other.args, args);

  @override
  int get hashCode => Object.hash(Op, op, Object.hashAll(args));

  @override
  String toString() => 'Op(${op.name}, $args)';
}
